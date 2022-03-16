import express from 'express';
import * as path from 'path';
import {fileURLToPath} from 'url';

import {
    establishConnection,
    establishPayer,
    executeOnnx,
    report,
} from './solana';


const app = express();
const port = process.env.PORT || 3000;

app.use('/', express.static(path.resolve(__dirname, 'dist')));

app.use(express.json());

app.post('/img', async (req, res) => {
  console.log("Let's say hello to a Solana account...");

  // Establish connection to the cluster
  await establishConnection();

  // Determine who pays for the fees
  await establishPayer();

  // Say hello to an account
  const programAccountPubkey = await executeOnnx(req.body.values);

  // Find out how many times that account has been greeted
  const data = await report(programAccountPubkey);
  res.json({result: data})
});

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
});
