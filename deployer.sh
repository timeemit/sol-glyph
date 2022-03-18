INSTANCE='builder-3'
ZONE='us-central1-a'

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

announce 'Building instance'
e gcloud compute instances create $INSTANCE \
  --project=solana-paint \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --network-interface=network-tier=PREMIUM,subnet=default \
  --maintenance-policy=MIGRATE \
  --service-account=914975206125-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --create-disk=auto-delete=yes,boot=yes,device-name=$INSTANCE,image=projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20220213,mode=rw,size=200,type=projects/solana-paint/zones/us-central1-a/diskTypes/pd-balanced \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --reservation-affinity=any && \
  sleep 30

announce 'Housekeeping'
gssh 'sudo apt-get update && sudo apt-get dist-upgrade'

announce 'Installing rust'
gssh 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' 'rustup --version'

announce 'Installing Solana'
gssh 'curl -sSfL https://release.solana.com/v1.9.9/install | sh' 'solana --version'

announce 'Setting up Solana Testnet Validator'
gcloud compute scp --zone $ZONE --project solana-paint ./provisioning/webserver-service root@$INSTANCE:/etc/systemd/system/solana-test-validator.service
gssh 'sudo systemctl enable solana-test-validator'
gssh 'sudo systemctl start solana-test-validator'

announce 'Downloading Glow repository'
gssh 'git clone https://github.com/pytorch/glow.git && cd glow && git submodule update --init --recursive'

announce 'Installing Glow dependencies'
gssh 'sudo apt-get update && sudo apt-get install --yes clang clang-8 cmake graphviz libpng-dev libprotobuf-dev llvm-8 llvm-8-dev ninja-build protobuf-compiler wget opencl-headers libgoogle-glog-dev libboost-all-dev libdouble-conversion-dev libevent-dev libssl-dev libgflags-dev libjemalloc-dev libpthread-stubs0-dev liblz4-dev libzstd-dev libbz2-dev libsodium-dev libfmt-dev'

announce 'Clang version 50'
gssh 'sudo update-alternatives --install /usr/bin/clang clang /usr/lib/llvm-8/bin/clang 50'

announce 'Clang++ version 50'
gssh 'sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/lib/llvm-8/bin/clang++ 50'

announce 'Specify Clang binary'
gssh 'sudo update-alternatives --set cc /usr/bin/clang'

announce 'Specify Clang++ binary'
gssh 'sudo update-alternatives --set c++ /usr/bin/clang++'

announce 'Build Fmt from source'
gssh 'git clone https://github.com/fmtlib/fmt.git; mkdir -p fmt/_build && cd fmt/_build && cmake .. && make -j$(nproc) && sudo make install'

# announce 'Configure & Build Glow in Debug Mode'
# gssh 'mkdir -p build_Debug && cd build_Debug && cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug ../glow && ninja all'

announce 'Configure & Build Glow in Release Mode'
gssh 'mkdir -p build_Release && cd build_Release && cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ../glow && ninja all'

# announce 'Configure & Build Glow in Release Mode with Bundles'
# gssh 'mkdir -p build_Release && cd build_Release && cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DGLOW_WITH_BUNDLES=ON ../glow && ninja all'


announce 'Compiling a trained model generating'
ONNX="DCGAN-trained-8x8-full-celeb.onnx"
gssh 'rm -rf example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-{static,dynamic}'
gssh "./build_Release/bin/model-compiler -backend=CPU -model=/home/liam/$ONNX -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-static/ -network-name=DCGAN-trained-static -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static"
gssh "./build_Release/bin/model-compiler -backend=CPU -model=/home/liam/$ONNX -emit-bundle=./example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/ -network-name=DCGAN-trained-dynamic -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic"
gssh "find example-helloworld/src/program-c/src/DCGAN/ -name '*.h' -type f -exec sed -i 's/#include.*//' {} \;"  # Remove directive conflicting with Solana SDK
gssh 'V=1 make -C example-helloworld/src/program-c DCGAN && /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/bin/ld.lld -z notext -shared --Bdynamic /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/bpf.ld --entry entrypoint -L /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/lib -lc  -o example-helloworld/dist/program/DCGAN.so example-helloworld/src/program-c/src/DCGAN/DCGAN-trained-dynamic/DCGAN_trained_dynamic.o example-helloworld/dist/program/DCGAN/DCGAN.o /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/rust/lib/rustlib/bpfel-unknown-unknown/lib/libcompiler_builtins-*.rlib'
gssh "solana program deploy /home/liam/example-helloworld/dist/program/DCGAN.so"

INPUTS=(10 128 128 128 256 256 256 256)
OUTPUTS=(128 128 128 256 256 256 256 256)
INPUT_VARS=(A0 input input A0 input input A0 A0)
OUTPUT_VARS=(A2 A6 A1 A2 A6 A1 A2 A1)

for i in {0..7};
do
  ONNX="DCGAN-trained-16x16-full-$i.onnx"
  DIR="example-helloworld/src/program-c/src/DCGAN-$i"

  announce "Compiling a layer $i trained model"

  gssh "rm -rf $DIR/DCGAN-trained-{static,dynamic} && mkdir -p $DIR"
  # Grab the image
  # gcloud compute scp --zone us-central1-c --project solana-paint trainer-2:~/tutorials/$ONNX ./$ONNX

  # Upload the image
  # gcloud compute scp --zone $ZONE --project solana-paint ./$ONNX $INSTANCE:./$ONNX
  gcloud compute scp --zone $ZONE --project solana-paint ./src/compiler/DCGAN.c $INSTANCE:$DIR/DCGAN.c
  gssh "./build_Release/bin/model-compiler -backend=CPU -model=/home/liam/$ONNX -emit-bundle=$DIR/DCGAN-trained-static/ -network-name=DCGAN-trained-static-$i -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=static"
  gssh "./build_Release/bin/model-compiler -backend=CPU -model=/home/liam/$ONNX -emit-bundle=$DIR/DCGAN-trained-dynamic/ -network-name=DCGAN-trained-dynamic-$i -target=bpfel -mcpu=generic -relocation-model=pic -bundle-api=dynamic"
  gssh "find $DIR -name '*.h' -type f -exec sed -i 's/#include.*//' {} \;"  # Remove directive conflicting with Solana SDK

  # Code modifications per model
  gssh "sed -i 's/DCGAN_trained_dynamic.h/DCGAN_trained_dynamic_$i.h/' $DIR/DCGAN.c"
  gssh "sed -i 's/DCGAN_trained_static.h/DCGAN_trained_static_$i.h/' $DIR/DCGAN.c"
  gssh "sed -i 's/10$/${INPUTS[i]}/' $DIR/DCGAN.c"
  gssh "sed -i 's/192$/${OUTPUTS[i]}/' $DIR/DCGAN.c"
  gssh "sed -i 's/DCGAN_trained_static.weights.txt/DCGAN_trained_static_$i.weights.txt/' $DIR/DCGAN.c"
  gssh "sed -i 's/DCGAN_TRAINED_STATIC_MEM_ALIGN/DCGAN_TRAINED_STATIC_${i}_MEM_ALIGN/' $DIR/DCGAN.c"
  gssh "sed -i 's/DCGAN_TRAINED_STATIC_CONSTANT_MEM_SIZE/DCGAN_TRAINED_STATIC_${i}_CONSTANT_MEM_SIZE/' $DIR/DCGAN.c"
  gssh "sed -i 's/DCGAN_TRAINED_STATIC_CONSTANT_MEM_SIZE/DCGAN_TRAINED_STATIC_${i}_CONSTANT_MEM_SIZE/' $DIR/DCGAN.c"
  gssh "sed -i 's/DCGAN_trained_dynamic_config/DCGAN_trained_dynamic_${i}_config/' $DIR/DCGAN.c"
  gssh "sed -i 's/DCGAN_trained_dynamic[\\\\\(]/DCGAN_trained_dynamic_$i\\\\\(/' $DIR/DCGAN.c"
  gssh "sed -i 's/A0/${INPUT_VARS[i]}/' $DIR/DCGAN.c"
  gssh "sed -i 's/A12/${OUTPUT_VARS[i]}/' $DIR/DCGAN.c"

  # Compile
  gssh "V=1 make -C example-helloworld/src/program-c DCGAN-$i && /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/bin/ld.lld -z notext -shared --Bdynamic /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/bpf.ld --entry entrypoint -L /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/llvm/lib -lc  -o example-helloworld/dist/program/DCGAN-$i.so $DIR/DCGAN-trained-dynamic/DCGAN_trained_dynamic_$i.o example-helloworld/dist/program/DCGAN-$i/DCGAN.o /home/liam/.local/share/solana/install/active_release/bin/sdk/bpf/c/../dependencies/bpf-tools/rust/lib/rustlib/bpfel-unknown-unknown/lib/libcompiler_builtins-*.rlib"

  # Deploy
  gssh "solana program deploy /home/liam/example-helloworld/dist/program/DCGAN-$i.so"
done
