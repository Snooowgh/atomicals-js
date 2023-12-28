#!/bin/bash
sudo apt-get update -y
sudo apt-get install -y npm
sudo npm install -g n
sudo n latest
sudo npm install -g yarn
yarn
yarn run build
yarn cli wallet-init
