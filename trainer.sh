INSTANCE='trainer-1'

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

announce 'Creating trainer'
e gcloud compute instances create $INSTANCE \
  --project=solana-paint \
  --zone=us-central1-a \
  --machine-type=n1-standard-2 \
  --network-interface=network-tier=PREMIUM,subnet=default \
  --maintenance-policy=TERMINATE \
  --service-account=914975206125-compute@developer.gserviceaccount.com \
  --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append \
  --accelerator=count=1,type=nvidia-tesla-t4 \
  --create-disk=auto-delete=yes,boot=yes,device-name=instance-1,image=projects/ubuntu-os-cloud/global/images/ubuntu-1804-bionic-v20220213,mode=rw,size=200,type=projects/solana-paint/zones/us-central1-a/diskTypes/pd-balanced \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --reservation-affinity=any && \
  sleep 30

announce 'Housekeeping'
gssh 'sudo apt-get update && sudo apt-get dist-upgrade'

announce 'Install Python & Pip'
gssh 'sudo apt-get install --yes python3 python3-pip python3-dev python3-setuptools && pip3 install --upgrade pip'

announce 'Install CUDA'
gssh 'curl https://raw.githubusercontent.com/GoogleCloudPlatform/compute-gpu-installation/main/linux/install_gpu_driver.py --output install_gpu_driver.py && sudo python3 install_gpu_driver.py'

announce 'Downloading Pytorch Examples'
gssh 'git clone https://github.com/pytorch/tutorials.git'

announce 'Install Cython'
gssh 'pip3 install cython'

announce 'Install Pillow dependencies'
gssh 'sudo apt-get install --yes libtiff5-dev libjpeg8-dev libopenjp2-7-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk libharfbuzz-dev libfribidi-dev libxcb1-dev zip'

announce 'Install Python requirements'
gssh 'pip3 install -r tutorials/requirements.txt'

announce 'Download dataset'
gssh 'make -C ./tutorials download'
gssh 'mkdir -p ./tutorials/data unzip ./tutorials/_data/img_align_celeba.zip -d ./tutorials/data/celeba/'
