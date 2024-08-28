#!/bin/bash

SCAN_DIR=$(realpath $(dirname $0))
function copy_config() {
  rm -rf $SCAN_DIR/config
  docker run -d --name beacon-tmp gobitfly/eth2-beaconchain-explorer:latest sleep 1000000
  docker cp beacon-tmp:/app/config $SCAN_DIR
  docker stop beacon-tmp
  docker rm beacon-tmp
}

function beacon_scan_start() {
  docker stop beacon-scan
  docker rm beacon-scan
  docker run -d --name beacon-scan -v $SCAN_DIR/config:/app/config gobitfly/eth2-beaconchain-explorer:latest
}

OPERATION=$1
shift
case $OPERATION in
  cp) copy_config ;;
  start) beacon_scan_start;;
  *) echo "Usage: $0 {cp|start}"
    exit 1
esac
