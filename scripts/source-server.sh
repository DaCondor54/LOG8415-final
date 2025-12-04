#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install mysql-server sysbench -y

export SOURCE_PUBLIC_IP=$(hostname -I)
export CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

sudo sed -i "s/^bind-address.*$/bind-address = $SOURCE_PUBLIC_IP/" "$CONFIG_FILE"
sudo sed -i "s/^# server-id/server-id/" "$CONFIG_FILE"
sudo sed -i "s/^# log_bin/log_bin/" "$CONFIG_FILE"
sudo sed -i "s/^# binlog_do_db.*$/binlog_do_db = sakila/" "$CONFIG_FILE"

sudo systemctl restart mysql

sudo mysql <<EOF

CREATE USER 'replica_1'@'10.0.4.%' IDENTIFIED WITH mysql_native_password BY 'Replic@1';
GRANT REPLICATION SLAVE ON *.* TO 'replica_1'@'10.0.4.%';
FLUSH PRIVILEGES;

FLUSH TABLES WITH READ LOCK;

UNLOCK TABLES;
CREATE DATABASE sakila;
exit
EOF