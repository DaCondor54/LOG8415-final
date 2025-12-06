#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install mysql-server sysbench -y

SOURCE_PUBLIC_IP=$(hostname -I)
CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"

sudo sed -i "s/^bind-address.*$/bind-address = $SOURCE_PUBLIC_IP/" "$CONFIG_FILE"
sudo sed -i "s/^# server-id.*$/server-id = 100/" "$CONFIG_FILE"
sudo sed -i "s/^# log_bin/log_bin/" "$CONFIG_FILE"
sudo sed -i "s/^# binlog_do_db.*$/binlog_do_db = sakila/" "$CONFIG_FILE"

sudo systemctl restart mysql 

PROXY="'proxy'@'%'"
REPLICA_1="'replica_1'@'10.0.4.%'"
REPLICA_2="'replica_2'@'10.0.4.%'"

sudo mysql <<EOF

CREATE DATABASE sakila;

CREATE USER $REPLICA_1 IDENTIFIED WITH mysql_native_password BY 'Replic@1';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO $REPLICA_1;

CREATE USER $REPLICA_2 IDENTIFIED WITH mysql_native_password BY 'Replic@2';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO $REPLICA_2;

CREATE USER $PROXY IDENTIFIED WITH mysql_native_password BY 'P@ssword123';
GRANT SELECT, UPDATE, INSERT, DELETE ON sakila.* TO $PROXY;

FLUSH PRIVILEGES;

FLUSH TABLES WITH READ LOCK;

UNLOCK TABLES;
EOF