#!/bin/bash

SCAN_DIR=$(realpath $(dirname $0))
function copy_config() {
#  rm -rf $SCAN_DIR/config
  docker run -d --name beacon-tmp gobitfly/eth2-beaconchain-explorer:latest sleep 1000000
  docker cp beacon-tmp:/app/config $SCAN_DIR
  docker stop beacon-tmp
  docker rm beacon-tmp
}

function beacon_scan_start() {
  docker stop beacon-scan
  docker rm beacon-scan
  docker run -d --name beacon-scan -v $SCAN_DIR/config:/app/config gobitfly/eth2-beaconchain-explorer:latest ./explorer --config /app/config/default.config.yml
  docker logs -f beacon-scan
}

function build_it() {
  get_light_chain
  make_it
}
function get_light_chain(){
  cd $SCAN_DIR
  rm -rf light-beaconchain-explorer
  git clone https://github.com/dapplion/light-beaconchain-explorer
}

function make_it(){
  cd $SCAN_DIR/light-beaconchain-explorer
  make linux
}

function start_it(){
    cd $SCAN_DIR/light-beaconchain-explorer
    stop_it
    sleep 5
    cp ../gluon.chain.yml config/
    echo start and save pid
    export LOGGING_OUTPUT_LEVEL=debug
    export FRONTEND_SERVER_PORT=8888
    export FRONTEND_SERVER_HOST='0.0.0.0'
    export CHAIN_NAME=gluon
    export CHAIN_DISPLAY_NAME=Gluon
    export CHAIN_GENESIS_TIMESTAMP=$(cat ../../current.genesis.json | jq -r .config.shanghaiTime)
    export CHAIN_CONFIG_PATH="./config/gluon.chain.yml"
    export BEACONAPI_ENDPOINT="http://127.0.0.1:3500"
    export DATABASE_ENGINE=sqlite
    export DATABASE_SQLITE_FILE="./explorer-db.sqlite"
    echo  "CHAIN_GENESIS_TIMESTAMP=$CHAIN_GENESIS_TIMESTAMP"
    nohup ./bin/explorer_linux_amd64 -config config/default.config.yml > beacon_scan.log 2>&1 &
    echo $! > beacon_scan.pid
}

function stop_it(){
    cd $SCAN_DIR/light-beaconchain-explorer
    echo stop
    kill `cat beacon_scan.pid`
    rm beacon_scan.pid
    rm -f explorer-db.sqlite*
    rm -f beacon_scan.log
}

function docker_it() {
    cd $SCAN_DIR
    get_light_chain
    cd $SCAN_DIR/light-beaconchain-explorer
    cp ../gluon.chain.yml config/
    docker build -t beacon-scan .
    docker stop beacon-scan
    docker rm beacon-scan
    local CHAIN_GENESIS_TIMESTAMP=$(cat ../../current.genesis.json | jq -r .config.shanghaiTime)
    local DOCKER_ENV="-e LOGGING_OUTPUT_LEVEL=debug -e FRONTEND_SERVER_PORT=8888 -e FRONTEND_SERVER_HOST=0.0.0.0 -e CHAIN_NAME=gluon -e CHAIN_DISPLAY_NAME=Gluon -e CHAIN_GENESIS_TIMESTAMP=$CHAIN_GENESIS_TIMESTAMP -e CHAIN_CONFIG_PATH=/app/config/gluon.chain.yml -e BEACONAPI_ENDPOINT=http://172.17.0.1:3500 -e DATABASE_ENGINE=sqlite -e DATABASE_SQLITE_FILE=/app/beacon-data/explorer-db.sqlite"
    docker run -d --name beacon-scan $DOCKER_ENV -p 8888:8888 -v $SCAN_DIR/beacon-data:/app/beacon-data beacon-scan
}

OPERATION=$1
shift
case $OPERATION in
  build) build_it ;;
  start) start_it;;
  stop) stop_it;;
  docker) docker_it;;
  *) echo "Usage: $0 {cp|start}"
    exit 1
esac
