INSTANCE='builder-1'

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
  --machine-type=e2-medium \
  --network-interface=network-tier=PREMIUM,subnet=default \
  --maintenance-policy=MIGRATE \
  --service-account=914975206125-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --create-disk=auto-delete=yes,boot=yes,device-name=builder-2,image=projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20220213,mode=rw,size=200,type=projects/solana-paint/zones/us-central1-a/diskTypes/pd-balanced \
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
gssh 'curl -sSfL https://release.solana.com/v1.9.6/install | sh' 'solana --version'

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

announce 'Configure & Build Glow in Debug Mode'
gssh 'mkdir -p build_Debug && cd build_Debug && cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug ../glow && ninja all'

# announce 'Configure & Build Glow in Release Mode'
# gssh 'mkdir -p build_Release && cd build_Release && cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ../glow && ninja all'

announce 'Configure & Build Glow in Release Mode with Bundles'
gssh 'mkdir -p build_Release && cd build_Release && cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DGLOW_WITH_BUNDLES=ON ../glow && ninja all'

announce 'Compiling a test model'
gssh './build_Release/bin/model-compiler -backend=CPU -model=./build_Release/tests/models/onnxModels/add_2inputs_3D.onnx -emit-bundle=./bundles-add_2inputs_3D -target=bpf -mcpu=generic -relocation-model=pic -bundle-api=dynamic'

announce 'Compiling an randomly generated model'
gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-Generator.onnx -emit-bundle=./bundles-DCGAN-Generator-Random -target=bpf -mcpu=generic -relocation-model=pic'

announce 'Compiling an randomly generated model with quantization'
gssh './build_Release/bin/model-profiler -model=/home/liam/DCGAN-Generator.onnx -dump-profile=profile.yaml -input-dataset=0,rawtxt,dir,/home/liam/rand -relocation-model=pic -verbose'
gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-Generator.onnx -load-profile=profile.yaml -emit-bundle=./bundles-DCGAN-Generator-Random-quantized -target=bpf -mcpu=generic -verbose -relocation-model=pic'

announce 'Compiling an initialized model with just one input variable'
gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-init.onnx -emit-bundle=./bundles-DCGAN-init -target=bpf -mcpu=generic -relocation-model=pic -bundle-api=dynamic'

announce 'Compiling an initialized model with just one input variable with quantization'
gssh './build_Release/bin/model-profiler -model=/home/liam/DCGAN-init.onnx -dump-profile=profile-init-quantized.yaml -input-dataset=0,rawtxt,dir,/home/liam/rand -relocation-model=pic -verbose'
gssh './build_Release/bin/model-compiler -backend=CPU -model=/home/liam/DCGAN-init.onnx -load-profile=profile.yaml -emit-bundle=./bundles-DCGAN-init-quantized -target=bpf -mcpu=generic -verbose -relocation-model=pic -bundle-api=dynamic'
