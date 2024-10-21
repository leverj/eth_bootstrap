#!/bin/bash

function restart(){
  kill_validator
  ./l2 docker clean
  ./l2 docker genesis bootstrap
  ./l2 docker start geth
  ./prysm-debug.sh start
  validator
}

function kill_validator(){
  cd prysm-debug
  if [ -f validator.pid ]; then
    kill -9 `cat validator.pid`
    rm validator.pid
  fi
  cd ..
}

function validator(){
  kill_validator
  cd prysm-debug
  nohup ./validator --datadir validatordata_new --accept-terms-of-use --chain-config-file /root/eth_bootstrap/config.yml \
    --wallet-password-file=wallet_password.txt --wallet-dir=/root/.eth2validators/prysm-wallet-v2 --beacon-rpc-provider=localhost:4000 \
    --suggested-fee-recipient=0x7d2373b65C23727e7d6Faa68C07D974f2044020F > validator.log 2>&1 &
  # save the pid
  echo $! > validator.pid
  cd ..
}

COMMAND=$1
shift
case $COMMAND in
  restart) restart;;
  new_validator) validator;;
  *)
    echo "Usage: $0 {restart|validator}"
    exit 1
esac