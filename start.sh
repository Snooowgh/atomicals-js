#!/bin/bash
# https://dashboard.tatum.io/

send_slack_notify() {
  url="https://hooks.slack.com/services/$slack_api"
    # 构建 JSON 数据
  json_data="{\"text\": \"$1\"}"
  # 发送 POST 请求并获取响应
  curl -s -X POST -H "Content-type: application/json" -d "$json_data" "$url"
}

get_btc_gas_price() {
  gas_price_info=$(curl -s -X GET \
  'https://api.tatum.io/v3/blockchain/fee/BTC' \
    -H "x-api-key: $api_key")
  #echo $gas_price_info
  medium_value=$(echo "$gas_price_info" | jq -r '.medium')
  int_num=$(printf "%.0f" "$medium_value")
  echo "$int_num"
}

# 定义函数以获取比特币地址的未确认交易数
get_unconfirmed_transaction_count() {
  # 接收比特币地址作为参数
  local bitcoin_address="$1"

  # Blockchain.com API endpoint
  local api_url="https://blockchain.info/rawaddr/$bitcoin_address"
  echo "$api_url"
  # 发送 HTTP GET 请求并存储响应
  local response=$(curl -s "$api_url")
  echo "$response"
  # 使用 jq 提取未确认交易数
  local unconfirmed_count=$(echo "$response" | jq '.unconfirmed_txrefs | length')

  # 输出未确认交易数
  echo "$unconfirmed_count"
}

if [ -z "$1" ]; then
  # 如果没有参数传递，设置默认值为85
  gas_price_limit=85
else
  # 如果有参数传递，使用用户传递的值
  gas_price_limit=$1
fi
yarn cli wallets > wallet_info.txt
line_text=$(sed -n '25p' "wallet_info.txt")
line_text1=$(sed -n '77p' "wallet_info.txt")
regex='.* - Funding Address - (.*)'
if [[ $line_text1 =~ $regex ]]; then
    funding_addr="${BASH_REMATCH[1]}"
else
    funding_addr=""
fi

regex='.* - Primary Address - (.*)'
if [[ $line_text =~ $regex ]]; then
    primary_addr="${BASH_REMATCH[1]}"
else
    primary_addr=""
fi
echo "Funding地址: $funding_addr Primary地址: $primary_addr Gas费上限: $gas_price_limit"

# 更新gas price
gas_price=$(get_btc_gas_price)
echo "⚠️ 当前gas price: $gas_price"
if [ $gas_price -lt $gas_price_limit ]; then
  use_gas_price=$gas_price
else
  use_gas_price=$gas_price_limit
fi

start_time=$(date +%s.%N)
while true; do
    echo "🔨 开始执行命令函数: mint-dft quark"
    execution_text=$(yarn cli mint-dft quark --satsbyte $use_gas_price)
    end_time=$(date +%s.%N)
    execution_time=$(echo "$end_time - $start_time" | bc)
    if echo "$execution_text" | grep -q "the transaction was rejected by network rules"; then
      error_msg="❌ 达到交易上限 $primary_addr/$funding_addr Gas费: $use_gas_price 未确认交易数: $unconfirmed_count 函数执行耗时: $execution_time 秒"
      send_slack_notify "$msg"
      break
    fi
    if echo "$execution_text" | grep -q "success: false"; then
      error_msg="❌ 未知错误 $primary_addr/$funding_addr Gas费: $use_gas_price 未确认交易数: $unconfirmed_count 函数执行耗时: $execution_time 秒"
      send_slack_notify "$msg"
      break
    fi
    msg="✅  $primary_addr/$funding_addr Gas费: $use_gas_price 未确认交易数: $unconfirmed_count 函数执行耗时: $execution_time 秒"
    echo $msg
    send_slack_notify "$msg"
    start_time=$end_time
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "当前时间: $current_time"
#    unconfirmed_count=$(get_unconfirmed_transaction_count "$primary_addr")
    unconfirmed_count=0
    gas_price=$(get_btc_gas_price)
    if [ $gas_price -lt $gas_price_limit ]; then
      use_gas_price=$gas_price
      echo "更新gas price: $use_gas_price"
    fi
done
