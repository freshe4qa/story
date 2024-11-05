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
"Check your wallet"
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
NODE="story"
DAEMON_HOME="$HOME/.story/story"
DAEMON_NAME="story"
if [ -d "$DAEMON_HOME" ]; then
    new_folder_name="${DAEMON_HOME}_$(date +"%Y%m%d_%H%M%S")"
    mv "$DAEMON_HOME" "$new_folder_name"
fi

if [ ! $VALIDATOR ]; then
    read -p "Enter validator name: " VALIDATOR
    echo 'export VALIDATOR='\"${VALIDATOR}\" >> $HOME/.bash_profile
fi

# update
sudo apt update && sudo apt upgrade -y

# packages
apt install curl iptables build-essential git wget jq make gcc nano tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev lz4 aria2 pv -y

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
ufw allow 26660 comment story_prometheus_port
ufw allow 6060 comment story_geth_prometheus_port

mkdir -p $HOME/go/bin/
# download binary
cd
wget -O story-geth https://github.com/piplabs/story-geth/releases/download/v0.10.0/geth-linux-amd64
chmod +x story-geth
mv story-geth $HOME/go/bin/story-geth

story-geth version

cd
git clone https://github.com/piplabs/story && cd story
git checkout v0.12.0
go build -o story ./client
mv $HOME/story/story $HOME/go/bin/

story version

# init
$DAEMON_NAME init --network iliad  --moniker "${VALIDATOR}"
sleep 1
$DAEMON_NAME validator export --export-evm-key --evm-key-path $HOME/.story/.env
$DAEMON_NAME validator export --export-evm-key >>$HOME/.story/story/config/wallet.txt
cat $HOME/.story/.env >>$HOME/.story/story/config/wallet.txt

# download genesis and addrbook
wget -O $HOME/.story/story/config/addrbook.json "https://share102.utsa.tech/story/addrbook.json"

# set peers and seeds
peers="c5c214377b438742523749bb43a2176ec9ec983c@176.9.54.69:26656,5dec0b793789d85c28b1619bffab30d5668039b7@150.136.113.152:26656,89a07021f98914fbac07aae9fbb12a92c5b6b781@152.53.102.226:26656,443896c7ec4c695234467da5e503c78fcd75c18e@80.241.215.215:26656,2df2b0b66f267939fea7fe098cfee696d6243cec@65.108.193.224:23656,7cc415203fc4c1a6e534e5fed8292467cf14d291@65.21.29.250:3610,fa294c4091379f84d0fc4a27e6163c956fc08e73@65.108.103.184:26656,81eaee3be00b21d0a124016b62fb7176fa05a4f9@185.198.49.133:33556,3508ef280392bd431ea078dec16dcfae89e8eb78@213.239.192.18:26656,b04bae4f88ca12d45fc14be29ce96837b61a72b8@65.109.49.115:26656"
sed -i -e "s|^persistent_peers *=.*|persistent_peers = \"$peers\"|" $HOME/.story/story/config/config.toml
seeds="434af9dae402ab9f1c8a8fc15eae2d68b5be3387@story-testnet-seed.itrocket.net:29656"
sed -i.bak -e "s/^seeds =.*/seeds = \"$seeds\"/" $HOME/.story/story/config/config.toml

# create service
tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target

[Service]
User=$USER
ExecStart=$HOME/go/bin/story-geth --odyssey --syncmode full --http --http.api eth,net,web3,engine --http.vhosts '*' --http.addr 127.0.0.1 --http.port 8545 --ws --ws.api eth,web3,net,txpool --ws.addr 127.0.0.1 --ws.port 8546
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

#start service
systemctl daemon-reload
systemctl enable story
systemctl enable story-geth
systemctl restart story-geth
systemctl restart story

break
;;

"Check your wallet")
story validator export | grep "EVM Public Key:" | awk '{print $NF}'

break
;;

"Create Validator")
cd $HOME/.story
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
