# Generate NFTs with on-chain deep learning models

Stop templating your NFT collections.  Generate them from a trained machine learning smart contract.

# Install

Compile multiple file dependency C file with:

```
/home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/bin/ld.lld -z notext -shared --Bdynamic /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/bpf.ld --entry entrypoint -L /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/lib -lc  -o example-helloworld/dist/program/add-2inputs-3D.so example-helloworld/dist/program/add-2inputs-3D/add_2inputs_3D.o /home/liam/example-helloworld/src/program-c/src/add-2inputs-3D/add-2inputs-3D-dynamic/add_2inputs_3D_dynamic.o /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/rust/lib/rustlib/bpfel-unknown-unknown/lib/libcompiler_builtins-*.rlib
```

Mainnet is blocked by feature "transaction wide compute cap" (5ekBxc8itEnPv4NzGJtr8BVVQLNMQuLMNQQj7pHoLNZ9)
