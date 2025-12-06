#!/bin/bash

sudo apt update && sudo apt ugprade -y

sudo apt install python3-pip python3.12-venv -y

cd /opt

python3 -m venv .venv
source ./.venv/bin/activate

pip3 install -r /opt/requirements.txt

nohup python3 /opt/main.py >> /var/log/app_output.log 2>&1 &