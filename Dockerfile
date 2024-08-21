FROM golang:1.22.0-bookworm
COPY genesis.json config.yml l2 /root/eth_bootstrap/
RUN apt-get update && apt-get install -y jq
RUN cd /root/eth_bootstrap && ./l2 install_for_docker
WORKDIR /root/eth_bootstrap