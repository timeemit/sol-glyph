/**
 * @brief C-based ONNX BPF program
 */
#include <solana_sdk.h>
#include <string.h>

#ifndef _GLOW_BUNDLE_COMMON_DEFS
#define _GLOW_BUNDLE_COMMON_DEFS

// Glow bundle error code for correct execution.
#define GLOW_SUCCESS 0

// Glow Dynamic API

// Type describing a symbol table entry of a generated bundle.
typedef struct SymbolTableEntry {
  // Name of a variable.
  const char *name;
  // Offset of the variable inside the memory area.
  uint64_t offset;
  // The number of elements inside this variable.
  uint64_t size;
  // Variable kind: 1 if it is a mutable variable, 0 otherwise.
  char kind;
} SymbolTableEntry;

// Type describing the config of a generated bundle.
typedef struct BundleConfig {
  // Size of the constant weight variables memory area.
  uint64_t constantWeightVarsMemSize;
  // Size of the mutable weight variables memory area.
  uint64_t mutableWeightVarsMemSize;
  // Size of the activations memory area.
  uint64_t activationsMemSize;
  // Alignment to be used for weights and activations.
  uint64_t alignment;
  // Number of symbols in the symbol table.
  uint64_t numSymbols;
  // Symbol table.
  const SymbolTableEntry *symbolTable;
} BundleConfig;

// Glow Static API

// Memory alignment definition with given alignment size
// for static allocation of memory.
#define GLOW_MEM_ALIGN(size)  __attribute__((aligned(size)))

// Macro function to get the absolute address of a
// placeholder using the base address of the mutable
// weight buffer and placeholder offset definition.
#define GLOW_GET_ADDR(mutableBaseAddr, placeholderOff)  (((uint8_t*)(mutableBaseAddr)) + placeholderOff)
#endif

#include "DCGAN-trained-dynamic/DCGAN_trained_dynamic.h"
#include "DCGAN-trained-static/DCGAN_trained_static.h"

GLOW_MEM_ALIGN(DCGAN_TRAINED_STATIC_MEM_ALIGN)
const static uint8_t constantWeight[DCGAN_TRAINED_STATIC_CONSTANT_MEM_SIZE] = {
  #include "DCGAN-trained-static/DCGAN_trained_static.weights.txt"
};

#define HEAP_START_ADDRESS_ (uint64_t)0x300000000
#define HEAP_LENGTH_ (uint64_t)(32 * 1024)

#define INPUT_LENGTH_ 10
#define OUTPUT_LENGTH_ 192
static const char *INPUT_VAR = "A0";
static const char *OUTPUT_VAR = "A12";


const SymbolTableEntry *getWeightVar(const BundleConfig *config, const char *name) {
  for (unsigned i = 0, e = config->numSymbols; i < e; i++) {
    if (!strncmp(config->symbolTable[i].name, name, strlen(name))) {
      return &config->symbolTable[i];
    }
  }
  return NULL;
}

const SymbolTableEntry *getMutableWeightVar(const BundleConfig *config, const char *name) {
  const SymbolTableEntry *mutableWeightVar = getWeightVar(config, name);
  if (!mutableWeightVar) {
    sol_log("No mutableWeightVar found");
    return NULL;
  }
  if (mutableWeightVar->kind == 0) {
    sol_log("mutableWeightVar kind is immutable");
    return NULL;
  }
  return mutableWeightVar;
}

struct BumpAllocator {
  uint64_t start;
  uint64_t size;
};

void *alignedAlloc(struct BumpAllocator *self, uint64_t size, uint64_t align) {
  uint64_t *pos_ptr = (uint64_t *)self->start;

  uint64_t pos = *pos_ptr;
  if (pos == 0) {
    // First time, set starting position
    pos = self->start + self->size;
  }
  if (pos < size) {
    pos = 0;
  } else {
    pos = pos - size;
  }
  pos &= ~(align - 1);
  if (pos < self->start + sizeof(uint8_t)) {
    return NULL;
  }
  *pos_ptr = pos;
  return (void *)pos;
}

uint8_t *allocateMutableWeightVars(struct BumpAllocator *heap, const BundleConfig *config) {
  sol_log("Aligning memory for mutable weights in heap");
  uint8_t *weights = (uint8_t *)(alignedAlloc(heap, config->mutableWeightVarsMemSize, config->alignment));
  return weights;
}

float *getInferenceResults(const BundleConfig *config, uint8_t *mutableWeightVars) {
  sol_log(OUTPUT_VAR);
  const SymbolTableEntry *outputWeights = getMutableWeightVar(config, OUTPUT_VAR);
  float *results = (float *)(mutableWeightVars + outputWeights->offset);
  return results;
}

uint8_t *initMutableWeightVars(struct BumpAllocator *heap, const BundleConfig *config, float *paramData) {
  uint8_t *mutableWeightVarsAddr = allocateMutableWeightVars(heap, config);
  sol_log("Allocated mutableWeightVars");

  const SymbolTableEntry *inputA0Var = getMutableWeightVar(config, INPUT_VAR);
  sol_log("Retrieved a0 inputVar");

  sol_memcpy(mutableWeightVarsAddr + inputA0Var->offset, paramData, sizeof(float) * INPUT_LENGTH_);
  sol_log("Initalized a0 inputVar");

  return mutableWeightVarsAddr;
}

uint8_t *initActivations(struct BumpAllocator *heap, BundleConfig *config) {
  return (uint8_t *)(alignedAlloc(heap, config->activationsMemSize, config->alignment));
}

uint64_t exec_onnx(SolParameters *params) {
  float data[INPUT_LENGTH_];

  if (params->ka_num < 1) {
    sol_log("Program account not included in the instruction");
    return ERROR_NOT_ENOUGH_ACCOUNT_KEYS;
  }

  // Get the invoking account
  SolAccountInfo *program_account = &params->ka[0];

  // The account must be owned by the program in order to modify its data
  if (!SolPubkey_same(program_account->owner, params->program_id)) {
    sol_log("Program account is not owned by this program");
    return ERROR_INCORRECT_PROGRAM_ID;
  }

  sol_log("Hello!");

  // The program account's size must be large enough to hold the output
  if (program_account->data_len < sizeof(float) * OUTPUT_LENGTH_) {
    sol_log("Program account data length too small to hold the output");
    return ERROR_ACCOUNT_DATA_TOO_SMALL;
  }

  // Verify the input and point to data
  if (params->data_len == 0) {
    sol_log("No params passed in.  Looking for data in a previous account");
    if (params->ka_num < 2) {
      sol_log("A second program account is not present when no params were sent");
      return ERROR_NOT_ENOUGH_ACCOUNT_KEYS;
    }
    // Get the account holding the results of the previous account
    SolAccountInfo *previous_program_account = &params->ka[1];

    // if (previous_program_account->data_len < sizeof(float) * INPUT_LENGTH_) {
    //   sol_log("Program account does not have enough data to support INPUT_LENGTH_ floats");
    //   return ERROR_ACCOUNT_DATA_TOO_SMALL;
    // }

    // Read from program account
    sol_log("Reading data from the program account");
    sol_memcpy(data, previous_program_account->data, sizeof(float) * INPUT_LENGTH_);
  } else {
    if (params->data_len != sizeof(float) * INPUT_LENGTH_) {
      sol_log("Program parameters is not precisely INPUT_LENGTH_ floats");
      return ERROR_INVALID_INSTRUCTION_DATA;
    }
    // Read from params
    sol_log("Reading data from params");
    sol_memcpy(data, params->data, sizeof(float) * INPUT_LENGTH_);
  }

  struct BumpAllocator heap = {HEAP_START_ADDRESS_, HEAP_LENGTH_};
  uint8_t *mutableWeightVarsAddr = initMutableWeightVars(&heap, &DCGAN_trained_dynamic_config, data);
  sol_log("Initiated Mutable Weights");

  uint8_t *activationsAddr = initActivations(&heap, &DCGAN_trained_dynamic_config);
  sol_log("Initiated Activations");

  int errCode = DCGAN_trained_dynamic((uint8_t *)&constantWeight, mutableWeightVarsAddr, activationsAddr);
  sol_log("Executed DCGAN");

  if (errCode != GLOW_SUCCESS) {
    sol_log("Error running bundle");
    return ERROR_CUSTOM_ZERO;
  }
  
  float *output = getInferenceResults(&DCGAN_trained_dynamic_config, mutableWeightVarsAddr);
  sol_memcpy(program_account->data, output, sizeof(float) * OUTPUT_LENGTH_);
  
  sol_log_compute_units();
  return SUCCESS;
}

extern uint64_t entrypoint(const uint8_t *input) {
  sol_log("DCGAN C program entrypoint");

  SolAccountInfo accounts[2];
  SolParameters params = (SolParameters){.ka = accounts};

  if (!sol_deserialize(input, &params, SOL_ARRAY_SIZE(accounts))) {
    return ERROR_INVALID_ARGUMENT;
  }

  return exec_onnx(&params);
}
