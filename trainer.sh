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

announce 'Install correct kernel headers'
gssh 'sudo apt-get install linux-headers-$(uname -r)'

announce 'Download PIN'
gssh 'wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin && sudo mv cuda-ubuntu1804.pin /etc/apt/preferences.d/cuda-repository-pin-600'

announce 'Download CUDA'
gssh 'wget https://developer.download.nvidia.com/compute/cuda/11.6.0/local_installers/cuda-repo-ubuntu1804-11-6-local_11.6.0-510.39.01-1_amd64.deb'

announce 'Install CUDA'
gssh 'sudo dpkg -i cuda-repo-ubuntu1804-11-6-local_11.6.0-510.39.01-1_amd64.deb && sudo apt-key add /var/cuda-repo-ubuntu1804-11-6-local/7fa2af80.pub && sudo apt-get update && sudo apt-get -y install cuda'
gssh 'echo "export PATH=/usr/local/cuda-11.6/bin${PATH:+:${PATH}}" >> ~/.profile && export LD_LIBRARY_PATH=/usr/local/cuda-11.6/lib64 ${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}} >> ~/.profile'
gssh '/usr/bin/nvidia-persistenced --verbose'

announce 'Downloading Pytorch Examples'
gssh 'git clone https://github.com/pytorch/tutorials.git'

announce 'Install Python & Pip'
gssh 'sudo apt-get install --yes python3 python3-pip python3-dev python3-setuptools && pip install --upgrade pip'

announce 'Install Cython'
gssh 'pip3 install cython'

announce 'Install Pillow dependencies'
gssh 'sudo apt-get install --yes libtiff5-dev libjpeg8-dev libopenjp2-7-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk libharfbuzz-dev libfribidi-dev libxcb1-dev'

announce 'Install Python requirements'
gssh 'pip3 install -r tutorials/requirements.txt'

announce 'Build documentation'
gssh 'sudo apt-get install --yes zip'
gssh 'cd tutorials && make docs'
