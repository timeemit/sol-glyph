import { strict as assert } from 'assert';
import { v4 as uuidv4 } from 'uuid';

import {
  Keypair,
  Connection,
  PublicKey,
  LAMPORTS_PER_SOL,
  SystemProgram,
  TransactionInstruction,
  Transaction,
  sendAndConfirmTransaction,
} from '@solana/web3.js';
import path from 'path';

import {getPayer, getRpcUrl, createKeypairFromFile} from './utils';

const web3 = require("@solana/web3.js");
const {struct, seq, u8, u32, f32, ns64} = require("@solana/buffer-layout");
const {Buffer} = require('buffer');
const rawKeypair = process.env.PROGRAM_KEYPAIR;

assert.ok(rawKeypair, 'Need to set environment variable PROGRAM_KEYPAIR');

/**
 * Connection to the network
 */
let connection: Connection;

/**
 * Keypair associated to the fees' payer
 */
let payer: Keypair;

/*
 * Implements the expected payloads struct to request a lift to the compute limit
 */
const computeBudgetRequestStruct = struct([
  u8('instruction'),
  u32('units'),
  u32('additional_fee'),
]);

/*
 * Implements the expected payload struct to send into the DCGAN program:
 * An array of 10 floats
 */
const dcganPayloadStruct = seq(f32(), 10);

/*
 * Implements the expected payload struct to send into the DCGAN program:
 * A vector of 3 (color channel) x 8 (width) x 8 (heigth) floats flattened into a single array
 */
const dcganResultStruct = seq(f32(), 192);

/**
 * Establish a connection to the cluster
 */
export async function establishConnection(): Promise<void> {
  const rpcUrl = await getRpcUrl();
  connection = new Connection(rpcUrl, 'confirmed');
  const version = await connection.getVersion();
  console.log('Connection to cluster established:', rpcUrl, version);
}

/**
 * Establish an account to pay for everything
 */
export async function establishPayer(): Promise<void> {
  let fees = 0;
  if (!payer) {
    const {feeCalculator} = await connection.getRecentBlockhash();

    // Calculate the cost of sending transactions
    fees += feeCalculator.lamportsPerSignature * 100; // wag

    payer = await getPayer();
  }

  let lamports = await connection.getBalance(payer.publicKey);
  if (lamports < fees) {
    // If current balance is not enough to pay for fees, request an airdrop
    const sig = await connection.requestAirdrop(
      payer.publicKey,
      fees - lamports,
    );
    await connection.confirmTransaction(sig);
    lamports = await connection.getBalance(payer.publicKey);
  }

  console.log(
    'Using account',
    payer.publicKey.toBase58(),
    'containing',
    lamports / LAMPORTS_PER_SOL,
    'SOL to pay for fees',
  );
}

async function createAccount(programId: PublicKey): Promise<PublicKey> {
  const seed = uuidv4().slice(0, 8);
  const programAccountPubkey = await PublicKey.createWithSeed(
    payer.publicKey,
    seed,
    programId,
  );

  const createdAccount = await connection.getAccountInfo(programAccountPubkey);
  if (createdAccount === null) {
    console.log(
      'Creating account',
      programAccountPubkey.toBase58(),
      'to persist',
      dcganResultStruct.span,
      'bytes into',
    );

    const lamports = await connection.getMinimumBalanceForRentExemption(
      dcganResultStruct.span,
    );

    const transaction = new Transaction().add(
      SystemProgram.createAccountWithSeed({
        fromPubkey: payer.publicKey,
        basePubkey: payer.publicKey,
        seed,
        newAccountPubkey: programAccountPubkey,
        lamports,
        space: dcganResultStruct.span,
        programId,
      }),
    );
    await sendAndConfirmTransaction(connection, transaction, [payer]);
  }

  return programAccountPubkey;
}


/**
 * Execute Onnx Program
 */
export async function executeOnnx(inputVector: Array<number>): Promise<PublicKey> {
  const keypair = Uint8Array.from(JSON.parse(rawKeypair || ''))
  const programKeypair = await Keypair.fromSecretKey(keypair)
	const programAccountPubkey = await createAccount(programKeypair.publicKey);
  console.log('Program account created:', programAccountPubkey.toBase58());

  /*
   * Establish Compute Budget Payload
   */
  let allocateParams = { instruction: 0, units: 1400000, additional_fee: 1 };
  let allocateData = Buffer.alloc(computeBudgetRequestStruct.span);
  computeBudgetRequestStruct.encode(allocateParams, allocateData);

  /*
   * Bump Compute Budget Instruction
   */
  const allocate = new web3.TransactionInstruction({
    keys: [{pubkey: payer.publicKey, isSigner: false, isWritable: false}],
    programId: 'ComputeBudget111111111111111111111111111111',
    data: allocateData,
  });

  /*
   * Establish Onnx Compute Budget Payload
   */
  let onnxParams = inputVector;
  let onnxData = Buffer.alloc(dcganPayloadStruct.span);
  dcganPayloadStruct.encode(onnxParams, onnxData);

  /*
   * Execute Onnx Program
   */
  const instruction = new TransactionInstruction({
    keys: [{pubkey: programAccountPubkey, isSigner: false, isWritable: true}],
    programId: programKeypair.publicKey,
    data: onnxData,
  });

  await sendAndConfirmTransaction(
    connection,
    new Transaction().add(allocate).add(instruction),
    [payer],
  );

  return programAccountPubkey;
}

/**
 * Report the number of times the greeted account has been said hello to
 */
export async function report(programAccountPubkey: PublicKey): Promise<Array<number>> {
  const accountInfo = await connection.getAccountInfo(programAccountPubkey);
  if (accountInfo === null) {
    throw 'Error: cannot find the greeted account';
  }
  return dcganResultStruct.decode(accountInfo.data);
}
