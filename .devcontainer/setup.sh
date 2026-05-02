#!/bin/bash

# 安装 Flutter
if [ ! -d "/home/codespace/flutter" ]; then
    echo "正在云端下载并安装 Flutter SDK..."
    git clone https://github.com/flutter/flutter.git -b stable /home/codespace/flutter
fi

# 将 Flutter 添加到环境变量
export PATH="$PATH:/home/codespace/flutter/bin"
echo 'export PATH="$PATH:/home/codespace/flutter/bin"' >> ~/.bashrc

# 运行 Flutter 医生检查环境
flutter doctor