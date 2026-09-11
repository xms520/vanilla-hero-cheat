# VanillaHeroCheat - 香草英雄团外挂

基于逆向分析的 cheat dylib，支持 iOS 越狱设备。

## 功能

- 💀 秒杀开关
- 🛡️ 无敌开关  
- ⚡ 变速调节 (0.5x ~ 3.0x)
- 🚫 免广告开关
- 🎮 悬浮控制面板

## 快速编译

### 方式1: GitHub Actions（推荐）

1. **创建GitHub仓库**
   ```bash
   # 在GitHub创建新仓库，如: yourname/vanilla-hero-cheat
   ```

2. **推送代码**
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/vanilla-hero-cheat.git
   git branch -M main
   git push -u origin main
   ```

3. **触发编译**
   - 进入 GitHub 仓库 → Actions 标签
   - 点击 "VanillaHeroCheat Build" → Run workflow
   - 输入版本号（默认 2.0）
   - 等待编译完成

4. **下载产物**
   - 在 Actions 页面点击最新的 workflow run
   - 下载 artifact: `VanillaHeroCheat_v2.0.zip`
   - 解压得到 `VanillaHeroCheat.dylib`

### 方式2: 本地编译

需要 macOS + Xcode:

```bash
# 安装Xcode命令行工具
xcode-select --install

# 编译
make
# 或使用 xcrun 直接编译
xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=14.0 \
  -fobjc-arc -fobjc-abi-version=2 -dynamiclib \
  -framework Foundation -framework UIKit \
  -framework CoreGraphics -framework QuartzCore \
  -o VanillaHeroCheat.dylib VanillaHeroCheat_v2.xm
```

### 方式3: 在线编译器

使用 [Compiler Explorer](https://godbolt.org/) 或类似服务。

## 部署

```bash
# 1. 传输到越狱设备
scp VanillaHeroCheat.dylib root@YOUR_DEVICE_IP:/Library/MobileSubstrate/DynamicLibraries/

# 2. 重启SpringBoard
ssh root@YOUR_DEVICE_IP "restart SpringBoard"
```

或者使用 iMazing、Filza 等文件管理器手动传输。

## 日志

查看日志：
```
/var/mobile/Library/Logs/vh_cheat.log
```

## 注意事项

⚠️ **重要**: 香草英雄团是服务器验证游戏
- 客户端内存修改可能无效
- 部分功能需要服务端配合
- 存在封号风险，请谨慎使用

## 文件结构

```
├── VanillaHeroCheat_v2.xm    # 主源码
├── Makefile                  # Theos构建配置
├── control                   # deb控制文件
├── build.sh                  # 编译脚本
├── README.md                 # 说明文档
└── .github/workflows/        # GitHub Actions配置
    └── build.yml
```

## 许可证

MIT License

## 相关项目

- 合兵定三国 Cheat: https://github.com/xms520/sgzcheat (单机游戏，已验证有效)
- 香草英雄团 VHCheat v1-v11: 历史版本（终局判决：客户端干预路线终结）
