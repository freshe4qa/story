#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"

# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
if [ ! $WALLET ]; then
	echo "export WALLET=wallet" >> $HOME/.bash_profile
fi
echo "export STORY_CHAIN_ID=iliad" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y

# packages
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 -y

# install go
ver="1.23.1" && \
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz" && \
sudo rm -rf /usr/local/go && \
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz" && \
rm "go$ver.linux-amd64.tar.gz" && \
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> $HOME/.bash_profile && \
source $HOME/.bash_profile && \
go version

ufw allow 30303 comment story_geth_p2p_port
ufw allow 26656 comment story_p2p_port

# download binary
mkdir -p $HOME/go/bin/
cd $HOME
mkdir -p $HOME/story && cd story
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
tar -xvf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
mv $HOME/story/geth-linux-amd64-0.9.2-ea9f0d2/geth $HOME/go/bin/story-geth
story-geth version
rm -r geth-linux-amd64*

wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.10.0-9603826.tar.gz
tar -xvf story-linux-amd64-0.10.0-9603826.tar.gz
mv $HOME/story/story-linux-amd64-0.10.0-9603826/story $HOME/go/bin/story
story version
rm -r story-linux-amd64*

# init
story init --moniker "$NODENAME" --network $STORY_CHAIN_ID

# download genesis and addrbook
wget -O $HOME/.story/story/config/addrbook.json "https://share102.utsa.tech/story/addrbook.json"

# set peers and seeds
SEEDS="6a07e2f396519b55ea05f195bac7800b451983c0@story-seed.mandragora.io:26656"
PEERS="90161a7f82ce5dbfbed1a2a9d40d4103730cff0f@5.9.87.231:26656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.story/story/config/config.toml

# create service
tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=$USER
ExecStart=$HOME/go/bin/story-geth --iliad --syncmode full --http --http.api eth,net,web3,engine --http.vhosts '*' --http.addr 127.0.0.1 --http.port 8545 --ws --ws.api eth,web3,net,txpool --ws.addr 127.0.0.1 --ws.port 8546
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/story
ExecStart=$HOME/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# reset
story_snapshot_url=$(curl -sL 'https://story-testnet-snapshots.f5nodes.com' | grep -Eo '>iliad-0_story.*\.tar\.lz4' | sed 's/^>//' | head -n1)
geth_snapshot_url=$(curl -sL 'https://story-testnet-snapshots.f5nodes.com' | grep -Eo '>iliad-0_geth.*\.tar\.lz4' | sed 's/^>//' | head -n1)

wget "https://story-testnet-snapshots.f5nodes.com/${story_snapshot_url}" -O - | lz4 -dc - | tar -xf - -C $HOME/.story
wget "https://story-testnet-snapshots.f5nodes.com/${geth_snapshot_url}" -O - | lz4 -dc - | tar -xf - -C $HOME/.story/geth/iliad/geth

# start service
systemctl daemon-reload
systemctl enable story
systemctl enable story-geth

break
;;

"Create Validator")
story validator export \
story validator export --export-evm-key \
story validator export --export-evm-key --evm-key-path $HOME/.story/story/.env \
cat /root/.story/story/config/private_key.txt \
story validator create --stake 1000000000000000000
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
