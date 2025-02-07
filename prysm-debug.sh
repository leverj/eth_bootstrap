#!/usr/bin/bash

# This script is used to build the prysm docker image for debugging purposes
# real path of the folder
ETH_DIR=$(realpath $(dirname $0))
PRYSM_DEBUG=$ETH_DIR/prysm-debug
CONSENSUS=$ETH_DIR/eth_node/consensus
EXECUTION=$ETH_DIR/eth_node/execution

function keys(){
  local FILE=$1
  [[ ! -f $FILE ]] && return
  local KEYS=$(cat $FILE | grep -v '^#' | grep -v '^$' | sed 's/^\(.*\)=\(.*\)$/ \1/')
  echo $KEYS
}

function read_properties(){
  [[ ! -f ./default.env ]] && return
  local KEYS=$(keys ./default.env)
  if [ -f ./.env ]; then KEYS="$KEYS $(keys ./.env)"; fi
  KEYS=$(echo $KEYS | tr ' ' '\n' | sort | uniq)
  [[ -f ./default.env ]] && source ./default.env
  [[ -f ./.env ]] && source ./.env
  local PROPERTIES=''
  for KEY in $KEYS; do
    PROPERTIES="$PROPERTIES -e $KEY=${!KEY}"
  done
  echo "$PROPERTIES"
}

DOCKER_ENV=$(read_properties)

function build_it() {
  docker build -t prysm-debug . -f $ETH_DIR/Dockerfile_prysm
}

# this runs inside the container
function install_it() {
  echo "Installing prysm"
  cd $PRYSM_DEBUG
  # if prysm does not exist, clone it
  if [ ! -d prysm ]; then
#    original codebase
#    git clone --branch v5.0.3 https://github.com/prysmaticlabs/prysm.git
    git clone --branch workaround-hack  https://github.com/leverj/prysm.git
  fi
  cd prysm
  CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$PRYSM_DEBUG/prysmctl ./cmd/prysmctl
  case "$1" in
    beacon) CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$PRYSM_DEBUG/beacon-chain ./cmd/beacon-chain ;;
    validator) CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$PRYSM_DEBUG/validator ./cmd/validator ;;
    *) CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$PRYSM_DEBUG/beacon-chain ./cmd/beacon-chain
       CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$PRYSM_DEBUG/validator ./cmd/validator ;;
  esac
}

function beacon_peer(){
  local PEER_ID=$(curl --silent http://$GENESIS_BEACON_IP:$GENESIS_BEACON_RPC_PORT/eth/v1/node/identity | jq --raw-output '.data.peer_id')
  echo "/ip4/$GENESIS_BEACON_IP/tcp/$GENESIS_BEACON_TCP_PORT/p2p/$PEER_ID"
}

function docker_beacon() {
  time install_it beacon
  [[ "$BEACON_MIN_SYNC_PEERS" -eq 1 ]] && BEACON_PEER="--peer $(beacon_peer)"
  $PRYSM_DEBUG/beacon-chain --datadir $CONSENSUS/.beacondata \
    --min-sync-peers $BEACON_MIN_SYNC_PEERS $BEACON_PEER \
    --p2p-host-ip $P2P_HOST_IP \
    --genesis-state $CONSENSUS/genesis.ssz \
    --interop-eth1data-votes \
    --chain-config-file $CONSENSUS/config.yml \
    --contract-deployment-block 0 \
    --chain-id $CHAIN_ID \
    --network-id $NETWORK_ID \
    --rpc-host 0.0.0.0 \
    --grpc-gateway-host 0.0.0.0 \
    --execution-endpoint $EXECUTION/.gethdata/geth.ipc \
    --accept-terms-of-use \
    --jwt-secret $ETH_DIR/eth_node/jwt.hex \
    --suggested-fee-recipient $SUGGESTED_FEE_RECIPIENT \
    --minimum-peers-per-subnet 0 \
    --verbosity $VERBOSITY \
    --enable-debug-rpc-endpoints
}

function run_beacon() {
  docker stop beacon
  docker rm beacon
  docker run -d --name beacon \
    $DOCKER_ENV \
    -v $PRYSM_DEBUG:/root/eth_bootstrap/prysm-debug \
    -v $ETH_DIR/eth_node:/root/eth_bootstrap/eth_node \
    -p 4000:4000 \
    -p 3500:3500 \
    -p 8080:8080 \
    -p 6060:6060 \
    -p 9090:9090 \
    -p 13000:13000\
    -p 12000:12000 \
    prysm-debug ./prysm-debug.sh docker_beacon
}

function docker_validator() {
  install_it validator
  $PRYSM_DEBUG/validator --datadir $CONSENSUS/.validatordata \
      --accept-terms-of-use --interop-num-validators 64 --chain-config-file $CONSENSUS/config.yml \
      --beacon-rpc-provider=172.17.0.1:4000
}

function run_validator() {
  docker stop validator
  docker rm validator
  docker run -d --name validator \
    $DOCKER_ENV \
    -v $PRYSM_DEBUG:/root/eth_bootstrap/prysm-debug \
    -v $ETH_DIR/eth_node:/root/eth_bootstrap/eth_node \
    prysm-debug ./prysm-debug.sh docker_validator
}

function run_it(){
  build_it
  local OPERATION=$1
  shift
  case "$OPERATION" in
    beacon) run_beacon $@ ;;
    validator) run_validator $@ ;;
    *) run_validator ; run_beacon ;;
  esac
}

OPERATION=$1
shift
case "$OPERATION" in
  start) run_it $@ ;;
  docker_validator) docker_validator $@ ;;
  docker_beacon) docker_beacon $@ ;;
  *) echo "Usage: $0 {run validator|beacon}"; exit 1 ;;
esac

