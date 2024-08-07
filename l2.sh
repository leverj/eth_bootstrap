#!/usr/bin/bash

ETH_DIR=/root/eth_bootstrap
CONSENSUS=$ETH_DIR/eth_node/consensus
EXECUTION=$ETH_DIR/eth_node/execution
ETH_BIN=$ETH_DIR/eth_bin
function init(){
    rm -rf $ETH_DIR/prysm
    rm -rf $ETH_DIR/eth_bin
    mkdir -p $ETH_BIN
}

function get_geth(){
    cd $ETH_DIR
    wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.14.7-aa55f5ea.tar.gz
    gunzip geth-linux-amd64-1.14.7-aa55f5ea.tar.gz
    tar -xvf geth-linux-amd64-1.14.7-aa55f5ea.tar
    mv geth-linux-amd64-1.14.7-aa55f5ea/geth $ETH_BIN/
    rm -rf geth-linux*
}

function create_prysm(){
    cd $ETH_DIR
    git clone --branch v5.0.3 https://github.com/prysmaticlabs/prysm.git
    cd prysm
    CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$ETH_BIN/beacon-chain ./cmd/beacon-chain
    CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$ETH_BIN/validator ./cmd/validator
    CGO_CFLAGS="-O2 -D__BLST_PORTABLE__" go build -o=$ETH_BIN/prysmctl ./cmd/prysmctl
}

function beacon_genesis(){
    cd $CONSENSUS
    cp $ETH_DIR/config.yml .
    cp $ETH_DIR/genesis.json .
    $ETH_BIN/prysmctl testnet generate-genesis --fork capella --num-validators 64 --genesis-time-delay 120 --chain-config-file $CONSENSUS/config.yml --geth-genesis-json-in $CONSENSUS/genesis.json --geth-genesis-json-out $EXECUTION/genesis.json --output-ssz $CONSENSUS/genesis.ssz
}

function account_import(){
    cd $EXECUTION
    rm -rf .gethdata/keystore
    $ETH_BIN/geth --datadir=$EXECUTION/.gethdata account import $ETH_DIR/secret.txt
}

function geth_genesis(){
    cd $EXECUTION
    rm -rf .gethdata/geth
    $ETH_BIN/geth --datadir=$EXECUTION/.gethdata init $EXECUTION/genesis.json
}

function geth_start(){
    cd $EXECUTION
    nohup $ETH_BIN/geth --http --http.addr 0.0.0.0 --http.corsdomain=* --authrpc.vhosts=* --authrpc.addr 0.0.0.0 --http.api eth,net,web3 --ws --ws.api eth,net,web3 --authrpc.jwtsecret $ETH_DIR/jwt.hex --datadir $EXECUTION/.gethdata --nodiscover --syncmode full --allow-insecure-unlock --unlock "0x123463a4b065722e99115d6c222f267d9cabb524" --password $ETH_DIR/geth_password.txt --authrpc.port 8551 &> $ETH_DIR/eth_node/execution.log &
}

function beacon_start(){
    cd $CONSENSUS
    nohup $ETH_BIN/beacon-chain --datadir $CONSENSUS/.beacondata \
        --min-sync-peers 0 \
        --genesis-state $CONSENSUS/genesis.ssz \
        --interop-eth1data-votes \
        --chain-config-file $CONSENSUS/config.yml \
        --contract-deployment-block 0 \
        --chain-id 32382 \
        --network-id 32382 \
        --rpc-host 0.0.0.0 \
        --grpc-gateway-host 0.0.0.0 \
        --execution-endpoint $EXECUTION/.gethdata/geth.ipc \
        --accept-terms-of-use \
        --jwt-secret $ETH_DIR/jwt.hex \
        --suggested-fee-recipient 0x123463a4b065722e99115d6c222f267d9cabb524 \
        --minimum-peers-per-subnet 0 \
        --enable-debug-rpc-endpoints &> $ETH_DIR/eth_node/beacon.log &
}
function validator_start(){
    cd $CONSENSUS
    nohup $ETH_BIN/validator --datadir $CONSENSUS/.validatordata --accept-terms-of-use --interop-num-validators 64 --chain-config-file $CONSENSUS/config.yml --beacon-rpc-provider=localhost:4000 &> $ETH_DIR/eth_node/validator.log &
}

function genesis(){
    rm -rf $ETH_DIR/eth_node
    mkdir -p $CONSENSUS
    mkdir -p $EXECUTION
    beacon_genesis
    geth_genesis
    account_import
}

function install_it(){
    init
    get_geth
    create_prysm
    deposit_cli
#    genesis
}


function start_it(){
    geth_start
    beacon_start
    validator_start
}

function processes(){
  ps -ef | grep '/root/eth_bootstrap' | grep -v 'run /root/eth_bootstrap' | grep -v 'grep /root/eth_bootstrap'
}

function stop_it(){
  processes
  processes | perl -lane 'print "kill $F[1]"' | sh
}

function  deposit_cli() {
    cd $ETH_DIR
    rmdir staking_deposit-cli-fdab65d-linux-amd64
    rm staking_deposit-cli-fdab65d-linux-amd64.tar.gz
    wget https://github.com/ethereum/staking-deposit-cli/releases/download/v2.7.0/staking_deposit-cli-fdab65d-linux-amd64.tar.gz
    tar -xvzf staking_deposit-cli-fdab65d-linux-amd64.tar.gz
    mv staking_deposit-cli-fdab65d-linux-amd64/deposit $ETH_BIN/deposit-cli
    rmdir staking_deposit-cli-fdab65d-linux-amd64
    rm staking_deposit-cli-fdab65d-linux-amd64.tar.gz
}

function new_mnemonic(){
  cd $ETH_DIR
  rm -rf validator_keys
  LC_ALL=C.UTF-8 LANG=C.UTF-8 $ETH_BIN/deposit-cli --language english  --non_interactive new-mnemonic  \
                                            --mnemonic_language english \
                                            --num_validators 1 \
                                            --chain mainnet \
                                            --keystore_password gluon_gluon
}

function verify_chain(){
  local ADDRESS=$1
  curl --silent -X POST -H "Content-Type: application/json"  \
       --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$ADDRESS\", \"latest\"],\"id\":1}" \
        http://localhost:8545 | jq --raw-output '.result' | perl -lane 'print hex($F[0])'
}

function log_it() {
  case "$1" in
    bea) tail -f $ETH_DIR/eth_node/beacon.log;;
    val) tail -f $ETH_DIR/eth_node/validator.log;;
    *) tail -f $ETH_DIR/eth_node/execution.log;;
  esac
}

function usage(){
    echo './l2.sh install|import|run'
}


OPERATION=$1
shift
case "${OPERATION}" in
install) install_it ;;

genesis) genesis;;
import) account_import ;;

ps) processes;;
start) start_it;;
stop) stop_it ;;

deposit_cli) deposit_cli;;
new_mnemonic) new_mnemonic;;

verify) verify_chain "$@";;
log) log_it "$@" ;;

*) usage ;;
esac
