INSTANCE='builder-3'

function announce() {
  echo '=='
  echo "-  $1"
}
function e() {
  echo '=='
  echo "Running \`$@\`"
  eval $@
  echo
}

function gssh() {
  E=$1
  CHECK="$(check "$2")"
  [ -n "$CHECK" ] && E="$CHECK $E"
  COMMAND="gcloud compute ssh --zone us-central1-a $INSTANCE --project solana-paint -- -C 'bash -lc \"$E\"'"
  e $COMMAND
}

function check() {
  [ -n "$1" ] && echo "$1 && echo \\\"$1 short-circuited execution\\\" ||" || echo ''
}

# announce 'Building instance'
# e gcloud compute instances create $INSTANCE \
#   --project=solana-paint \
#   --zone=us-central1-a \
#   --machine-type=e2-standard-2 \
#   --network-interface=network-tier=PREMIUM,subnet=default \
#   --maintenance-policy=MIGRATE \
#   --service-account=914975206125-compute@developer.gserviceaccount.com \
#   --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
#   --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE,image=projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20220213,mode=rw,size=200,type=projects/solana-paint/zones/us-central1-a/diskTypes/pd-balanced \
#   --no-shielded-secure-boot \
#   --shielded-vtpm \
#   --shielded-integrity-monitoring \
#   --reservation-affinity=any && \
#   sleep 30
# 
# announce 'Housekeeping'
# gssh 'sudo apt-get update && sudo apt-get dist-upgrade'
# 
# announce 'Installing rust'
# gssh 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' 'rustup --version'
# 
# announce 'Installing Solana'
# gssh 'curl -sSfL https://release.solana.com/v1.9.9/install | sh' 'solana --version'
# 
# announce 'Downloading Glow repository'
# gssh 'git clone https://github.com/pytorch/glow.git && cd glow && git submodule update --init --recursive'
# 
# announce 'Installing Glow dependencies'
# gssh 'sudo apt-get update && sudo apt-get install --yes clang clang-8 cmake graphviz libpng-dev libprotobuf-dev llvm-8 llvm-8-dev ninja-build protobuf-compiler wget opencl-headers libgoogle-glog-dev libboost-all-dev libdouble-conversion-dev libevent-dev libssl-dev libgflags-dev libjemalloc-dev libpthread-stubs0-dev liblz4-dev libzstd-dev libbz2-dev libsodium-dev libfmt-dev'
# 
# announce 'Clang version 50'
# gssh 'sudo update-alternatives --install /usr/bin/clang clang /usr/lib/llvm-8/bin/clang 50'
# 
# announce 'Clang++ version 50'
# gssh 'sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/lib/llvm-8/bin/clang++ 50'
# 
# announce 'Specify Clang binary'
# gssh 'sudo update-alternatives --set cc /usr/bin/clang'
# 
# announce 'Specify Clang++ binary'
# gssh 'sudo update-alternatives --set c++ /usr/bin/clang++'
# 
# announce 'Build Fmt from source'
# gssh 'git clone https://github.com/fmtlib/fmt.git; mkdir -p fmt/_build && cd fmt/_build && cmake .. && make -j$(nproc) && sudo make install'
# 
# # announce 'Configure & Build Glow in Debug Mode'
# # gssh 'mkdir -p build_Debug && cd build_Debug && cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug ../glow && ninja all'
# 
# announce 'Configure & Build Glow in Release Mode'
# gssh 'mkdir -p build_Release && cd build_Release && cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ../glow && ninja all'
# 
# # announce 'Configure & Build Glow in Release Mode with Bundles'
# # gssh 'mkdir -p build_Release && cd build_Release && cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DGLOW_WITH_BUNDLES=ON ../glow && ninja all'
# 
# announce 'Compiling a test model with the Static API'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=./build_Release/tests/models/onnxModels/add_2inputs_3D.onnx -emit-bundle=./bundles-add_2inputs_3D-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static -network-name=add_2inputs_3D_static'
# 
# announce 'Compiling a test model with the Dynamic API'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=./build_Release/tests/models/onnxModels/add_2inputs_3D.onnx -emit-bundle=./bundles-add_2inputs_3D-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic -network-name=add_2inputs_3D_dynamic'
# 
# announce 'Compiling an randomly generated model'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-Generator.onnx -emit-bundle=./bundles-DCGAN-Generator-Random -target=bpf -mcpu=generic -relocation-model=pic'
# 
# announce 'Compiling an randomly generated model with quantization'
# gssh './build_Release/bin/model-profiler -model=/home/liam/DCGAN-Generator.onnx -dump-profile=profile.yaml -input-dataset=0,rawtxt,dir,/home/liam/rand -relocation-model=pic -verbose'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-Generator.onnx -load-profile=profile.yaml.first -emit-bundle=./bundles-DCGAN-Generator-Random-quantized -target=bpf -mcpu=generic -verbose -relocation-model=pic'
# 
# announce 'Compiling an initialized model with just one input variable'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-init.onnx -emit-bundle=./bundles-DCGAN-init -target=bpf -mcpu=generic -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'Compiling an initialized model with just one input variable with quantization'
# gssh './build_Release/bin/model-profiler -model=/home/liam/DCGAN-init.onnx -dump-profile=profile-init-quantized.yaml -input-dataset=0,rawtxt,dir,/home/liam/rand -relocation-model=pic -verbose'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-init.onnx -load-profile=profile.yaml -emit-bundle=./bundles-DCGAN-init-quantized -target=bpf -mcpu=generic -verbose -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'Compiling an initialized model with just one input variable'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-init-8x8.onnx -emit-bundle=./bundles-DCGAN-init-8x8 -target=bpf -mcpu=generic -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'Compiling a trained model with just one input variable with the static & dynamic API'
# gssh 'rm -rf example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-{static,dynamic}'
# e gcloud compute scp --zone us-central1-a --project solana-paint DCGAN-trained.onnx $INSTANCE:
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-static/ -network-name=DCGAN-trained-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/ -network-name=DCGAN-trained-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'Compiling a trained model with just one input variable with quantization'
# gssh './build_Release/bin/model-profiler -model=/home/liam/DCGAN-trained.onnx -dump-profile=profile-trained-quantized.yaml -input-dataset=0,rawtxt,dir,/home/liam/rand -relocation-model=pic -verbose'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained.onnx -load-profile=profile-trained-quantized.yaml -emit-bundle=./bundles-DCGAN-trained-quantized -target=bpfel-mcpu=generic -verbose -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'Compiling a trained model generating 16x16 with the static & dynamic APIs'
# gssh 'rm -rf example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-{static,dynamic}'
# e gcloud compute scp --zone us-central1-a --project solana-paint DCGAN-trained-16x16.onnx $INSTANCE:
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-16x16.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-static/ -network-name=DCGAN-trained-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-16x16.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/ -network-name=DCGAN-trained-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'Compiling a trained model generating 8x8 with the static API'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-8x8.onnx -emit-bundle=./bundles-DCGAN-trained-8x8-static -network-name=DCGAN-trained-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static'
# 
# announce 'Compiling a trained model generating 8x8 with the dynamic API'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-8x8.onnx -emit-bundle=./bundles-DCGAN-trained-8x8-dynamic -network-name=DCGAN-trained-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'SCP Grayscale 8x8 w/ 1 element latent vector'
# e gcloud compute scp --zone us-central1-a --project solana-paint DCGAN-trained-8x8-grayscale-for-1.onnx $INSTANCE:
# 
# announce 'Compiling a trained model generating 8x8 with the static & dynamic APIs'
# gssh 'rm -rf example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-{static,dynamic}'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-8x8-grayscale-for-1.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-static/ -network-name=DCGAN-trained-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-8x8-grayscale-for-1.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/ -network-name=DCGAN-trained-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic'
# 
# announce 'Compiling a trained model generating 8x8 with reduced internal dimensions with the static & dynamic APIs'
# gssh 'rm -rf example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-{static,dynamic}'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-8x8-grayscale-for-1-with-reduced-dims.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-static/ -network-name=DCGAN-trained-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static'
# gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-trained-8x8-grayscale-for-1-with-reduced-dims.onnx -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/ -network-name=DCGAN-trained-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic'

announce 'Compiling a trained model generating'
ONNX="DCGAN-trained-8x8-full-celeb.onnx"
gssh 'rm -rf example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-{static,dynamic}'
gssh "./build_Release/bin/model-compiler -backend=CPU -model=/home/liam/$ONNX -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-static/ -network-name=DCGAN-trained-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static"
gssh "./build_Release/bin/model-compiler -backend=CPU -model=/home/liam/$ONNX -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/ -network-name=DCGAN-trained-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic"
gssh "find example-helloworld/src/program-c/src/DCGAN/ -name '*.h' -type f -exec sed -i 's/#include.*//' {} \;"  # Remove directive conflicting with Solana SDK
gssh 'make -C example-helloworld/src/program-c/ clean && V=1 make -C example-helloworld/src/program-c DCGAN && /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/bin/ld.lld -z notext -shared --Bdynamic /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/bpf.ld --entry entrypoint -L /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/lib -lc  -o example-helloworld/dist/program/DCGAN.so example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/DCGAN_trained_dynamic.o example-helloworld/dist/program/DCGAN/DCGAN.o /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/rust/lib/rustlib/bpfel-unknown-unknown/lib/libcompiler_builtins-*.rlib'
gssh "solana program deploy /home/liam/example-helloworld/dist/program/DCGAN.so"
