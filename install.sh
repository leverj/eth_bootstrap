#!/bin/bash

ETH_DIR=/root/eth_bootstrap
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

init
get_geth
create_prysm