#!/bin/bash
while true; do
    yarn cli mint-dft quark --satsbyte 85
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo "mint 1 张成功!, 当前时间：$current_time"
done
