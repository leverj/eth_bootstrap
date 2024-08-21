FROM golang:1.22.0-bookworm
COPY genesis.json config.yml install.sh /root/eth_bootstrap/
RUN apt-get update && apt-get install -y jq
RUN cd /root/eth_bootstrap && ./install.sh install_for_docker
COPY l2 /root/eth_bootstrap/
# eventually this will go away
COPY geth_password.txt jwt.hex secret.txt /root/eth_bootstrap/

WORKDIR /root/eth_bootstrap