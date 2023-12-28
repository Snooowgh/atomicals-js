#!/bin/bash
rm -r wallets/wallet.json
yarn cli wallet-init
cat wallets/wallet.json
