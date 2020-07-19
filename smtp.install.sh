#!/bin/sh
MAILNAME=widiastono.my.id
HOSTNAME=mail.widiastono.my.id

sudo apt update -y
sudo apt install -y postfix mailutils

sudo cat main.cf >> /etc/postfix/main.cf