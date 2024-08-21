#!/bin/bash
export DEBIAN_FRONTED=noninteractive
function setup_all_iface() {
    for i in $(ls /sys/class/net)
    do
      local ADDR=$(ip -br address show dev  "$i" | awk '{print $3}')
      [ -z "$ADDR" ] && setup_iface $i
    done
}

function setup_iface() {
  local IFACE=$1
  [ -z "$IFACE" ] && echo Usage: setup_iface inteface && return 0
  local EXISTS=$(grep "$IFACE" /etc/network/interfaces)
  [ -n "$EXISTS" ] && echo Already Installed: $IFACE && return 0

  cat <<EOF >>/etc/network/interfaces

allow-hotplug $IFACE
iface $IFACE inet dhcp

EOF
  ifup $IFACE
}

function setup_packages() {
  apt-get update
  DEBIAN_FRONTED=noninteractive apt-get install -y ufw dnsutils rsync \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg2 \
     software-properties-common \
     net-tools \
     lsb-release
}

function setup_debian() {
  echo Setting up $(lsb_release -is -cs)
  setup_packages
  setup_all_iface
  set_debian_ssh
  setup_mounts
  setup_log_rotate
  service bind9 stop
  setup_debian_docker # needs to be installed after firewall
}

function setup_debian_docker() {
  local ID=$(lsb_release -is | tr A-Z a-z)
  local REL=$(lsb_release -rs)
  local V=${REL%.*}
  [ -z "$ID" ] && echo Could not determine Distribution && exit 1
  local INST=$(apt-cache search '^docker-(ce|engine)' 2>/dev/null | awk '{print $1}')
  [ -n "$INST" ] && echo Skipping docker. Already installed: $INST && return 1
  [ "$ID" = "ubuntu" -a "$REL" \< "16.04" ] && echo Only Ubuntu 16.04+ supported && exit 1
  [ "$ID" = "debian" -a "$V" -lt 8 ] && echo Only Debian 8+ supported && exit 1

  apt-get remove -y docker docker-engine docker.io
  curl -fsSL https://download.docker.com/linux/$ID/gpg | apt-key add -
  add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/${ID} \
   $(lsb_release -cs) \
   stable"
   apt-get update
   apt-get install -y docker-ce
}

function set_debian_ssh() {
  echo "    Ciphers aes128-ctr,aes192-ctr,aes256-ctr" >> /etc/ssh/ssh_config
  cat /etc/ssh/sshd_config | perl -lpe 's/^\s*(PasswordAuthentication|ChallengeResponseAuthentication|UsePAM|X11Forwarding)\s+.*/#$_/i' > /tmp/sshd_config
  cat <<EOF >> /tmp/sshd_config
X11Forwarding no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
EOF
  mv -f /tmp/sshd_config /etc/ssh
  if [ -n "$PORT" ]
  then
    cat /etc/ssh/sshd_config | sed -e "s/Port 22\$/Port $PORT/" > /tmp/sshd_config
    mv -f /tmp/sshd_config /etc/ssh
  fi
  systemctl restart ssh
  service ssh restart
}

function setup_mounts(){
  [[ -n $(grep /dev/shm /etc/fstab) ]] && return
  cat <<EOF >> /etc/fstab
tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0
EOF
}

function setup_log_rotate() {
  cat > /etc/logrotate.d/docker-container <<EOF
/var/lib/docker/containers/*/*.log {
  rotate 7
  daily
  compress
  size=1M
  missingok
  delaycompress
  copytruncate
  postrotate
    /root/movelogs.sh
  endscript
}
EOF
}

RELEASE=$(lsb_release -is)
[ $RELEASE != "Debian" -a $RELEASE != "Ubuntu" ] && echo Only Debian or Ubuntu supported && exit 1
ifconfig
setup_debian
