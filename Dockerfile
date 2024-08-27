FROM golang:1.22.0-bookworm
COPY install.sh /root/eth_bootstrap/
RUN apt-get update && apt-get install -y jq
RUN cd /root/eth_bootstrap && ./install.sh
COPY default.genesis.json config.yml current.genesis.ssz current.genesis.json l2 /root/eth_bootstrap/
# eventually this will go away
COPY geth_password.txt jwt.hex secret.txt /root/eth_bootstrap/

WORKDIR /root/eth_bootstrap