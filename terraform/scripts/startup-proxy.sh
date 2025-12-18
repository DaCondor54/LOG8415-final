#!/bin/bash

sudo apt update && sudo apt ugprade -y

sudo apt install python3-pip python3.12-venv -y

cd /opt

python3 -m venv .venv
source ./.venv/bin/activate

pip3 install -r /opt/requirements.txt

nohup python3 /opt/main.py >> /var/log/app_output.log 2>&1 &

GATEKEEPER_IP="$(dig +short gatekeeper.internal)"

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow from $GATEKEEPER_IP to any port 3000 proto tcp
ufw allow 22/tcp
ufw --force enable



