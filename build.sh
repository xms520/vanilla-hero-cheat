#!/bin/bash
# 香草英雄团 Cheat v2.0 编译脚本
# 在macOS上运行此脚本

set -e

echo "======================================"
echo "香草英雄团 Cheat v2.0 编译"
echo "======================================"

# 检查环境
if ! command -v xcodebuild &> /dev/null; then
    echo "错误: 需要 Xcode CLI Tools"
    echo "运行: xcode-select --install"
    exit 1
fi

# 创建输出目录
OUTPUT_DIR="/tmp/VanillaHeroCheat_output"
mkdir -p "$OUTPUT_DIR"

# 编译命令
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
CLANG=$(xcrun --find clang)

echo "SDK: $SDK"
echo "Clang: $CLANG"

# 编译
$CLANG \
    -arch arm64 \
    -isysroot "$SDK" \
    -miphoneos-version-min=14.0 \
    -fobjc-arc \
    -fobjc-abi-version=2 \
    -dynamiclib \
    -framework Foundation \
    -framework UIKit \
    -framework CoreGraphics \
    -framework QuartzCore \
    -o "$OUTPUT_DIR/VanillaHeroCheat.dylib" \
    /var/minis/workspace/vanilla_hero/VanillaHeroCheat_v2.xm

echo "编译成功!"
echo "输出: $OUTPUT_DIR/VanillaHeroCheat.dylib"

# 签名（如果需要）
if command -v ldid &> /dev/null; then
    ldid -S "$OUTPUT_DIR/VanillaHeroCheat.dylib"
    echo "已签名"
fi

# 显示文件信息
ls -lh "$OUTPUT_DIR/"*.dylib
md5 "$OUTPUT_DIR/VanillaHeroCheat.dylib" 2>/dev/null || md5sum "$OUTPUT_DIR/VanillaHeroCheat.dylib" 2>/dev/null

echo ""
echo "======================================"
echo "部署说明:"
echo "1. 将 dylib 传输到越狱设备"
echo "2. 放置到 /Library/MobileSubstrate/DynamicLibraries/"
echo "3. 重启SpringBoard或重装Cydia"
echo "======================================"
