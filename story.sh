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

# download binary
cd && rm -rf story
git clone https://github.com/piplabs/story.git
cd story
git checkout v0.12.1
story-geth version

mkdir -p $HOME/go/bin/
go build -o $HOME/go/bin/story ./client

cd && rm -rf story-geth
git clone https://github.com/piplabs/story-geth.git
cd story-geth
git checkout v0.10.0

make geth
mv build/bin/geth $HOME/go/bin/

# init
story init --moniker $VALIDATOR --network odyssey
sleep 1
$DAEMON_NAME validator export --export-evm-key --evm-key-path $HOME/.story/.env
$DAEMON_NAME validator export --export-evm-key >>$HOME/.story/story/config/wallet.txt
cat $HOME/.story/.env >>$HOME/.story/story/config/wallet.txt

# download genesis and addrbook
wget -O $HOME/.story/story/config/addrbook.json "https://share102.utsa.tech/story/addrbook.json"

# set peers and seeds
peers="02e9fac0fab468724db00e5e3328b2cbca258fdc@95.217.193.182:26656,b8ad3364924728ef0f434102d3f7803fb18c6f90@37.60.236.104:656,75ac7b193e93e928d6c83c273397517cb60603c0@3.142.16.95:26656,8903b32fe2a4eeb41c4e74c715cc1760e39adb9f@37.60.229.77:656,5c001659b68370e7198e9c6c72bfc4c3c15dba41@211.218.55.32:50656,e1245ea24138ff16ca144962f72146d6afcbfe15@221.148.45.118:26656,a7909c1f6a43615d32febe2e61ca017d934e641c@144.76.26.62:26656,e8d2732e64d3dcedb3960cbed9aeb325e6ffec51@37.60.234.34:656,cc4d5da92dc08162a4f657d411971902f3dd26e1@212.47.71.202:26656,29d7d1d203ccf8c9afe593eab7bee485f1e6bbfa@37.252.186.234:26656,bf975933a1169221e3bd04164a7ba9abc5d164c8@3.16.175.31:26656,69950ba769347d99938a171da6084ea7985a09ed@37.60.236.169:656,04e5734295da362f09a61dd0a9999449448a0e5c@52.14.39.177:26656,046909534c2849ff8dccc15ee43ee63d2c60b21c@54.190.123.194:26656,9e2fabda41e3c3317c25f5ef6c604c1d78370aba@50.112.252.101:26656,0d3bff0cbc1a649c88f64f3888537710e7fec0f5@184.107.182.148:58300,7cc415203fc4c1a6e534e5fed8292467cf14d291@65.21.29.250:3610,1dae5464f40b0715b1c84fda4c19d18d50466976@161.97.161.144:26656,c3f3b40f66bf70fad77c6efc0ee5d5e47bfc0fa0@95.217.119.56:26556,f2cfc1c48d5b270e9f22a9cf367ae25d945358b6@95.216.39.239:10456"
sed -i -e "s|^persistent_peers *=.*|persistent_peers = \"$peers\"|" $HOME/.story/story/config/config.toml
seeds="ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@testnet-seeds.polkachu.com:29256,3f472746f46493309650e5a033076689996c8881@story-testnet.rpc.kjnodes.com:26659,434af9dae402ab9f1c8a8fc15eae2d68b5be3387@@story-testnet-seed.itrocket.net:29656"
sed -i.bak -e "s/^seeds =.*/seeds = \"$seeds\"/" $HOME/.story/story/config/config.toml

mkdir -p $HOME/.story/geth

sed -i -e "s%:1317%:29217%; s%:8080%:29280%; s%:9090%:29290%; s%:9091%:29291%; s%:8545%:29245%; s%:8546%:29246%; s%:6065%:29265%" $HOME/.story/story/config/app.toml
sed -i -e "s%:26658%:29258%; s%:26657%:29257%; s%:6060%:29260%; s%:26656%:29256%; s%:26660%:29261%" $HOME/.story/story/config/config.toml

curl "https://snapshots-testnet.nodejumper.io/story/story_latest.tar.lz4" | lz4 -dc - | tar -xf - -C "$HOME/.story/story"
curl "https://snapshots-testnet.nodejumper.io/story/story_latest_geth.tar.lz4" | lz4 -dc - | tar -xf - -C "$HOME/.story/geth/odyssey/geth"

# create service
sudo tee /etc/systemd/system/story-geth.service > /dev/null << EOF
[Unit]
Description=Story Execution Client service
After=network-online.target

[Service]
User=$USER
WorkingDirectory=$HOME/.story/geth
ExecStart=$HOME/go/bin/geth --odyssey --syncmode full --http --ws
Restart=on-failure
RestartSec=5
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
