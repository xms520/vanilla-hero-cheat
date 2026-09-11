# 香草英雄团 Cheat v2.0

基于逆向分析的原外挂提取版，包含秒杀、无敌、变速、免广告等功能。

## 功能列表

| 功能 | 状态 | 说明 |
|------|------|------|
| 秒杀 | ⚠️ 需要Hook | 尝试修改伤害计算 |
| 无敌 | ⚠️ 需要Hook | 尝试防止受伤 |
| 变速 | ✅ 可用 | 修改游戏时间倍率 |
| 免广告 | ⚠️ 需要Hook | 拦截广告请求 |
| UI面板 | ✅ 可用 | 悬浮窗控制面板 |

## 架构说明

```
原dylib分析结果:
├── QZ9M8 类 (UI面板)
│   ├── p001-p012: 12个UI控件
│   └── actionBlock: 回调系统
├── HTTPServer + WebSocket
│   └── api.isilo.cn 远程控制
├── SNYKeychain 加密存储
└── func1-func5 核心逻辑
    └── func5: 密钥解密
```

## 编译

### 方法1: macOS本地编译

```bash
# 安装Xcode CLI Tools
xcode-select --install

# 编译
chmod +x build.sh
./build.sh
```

### 方法2: GitHub Actions

```yaml
# 触发 workflow
curl -X POST https://api.github.com/repos/xms520/vhcheat/dispatches \
  -H "Authorization: token YOUR_TOKEN" \
  -d '{"event_type": "build"}'
```

### 方法3: 在线编译 (推荐)

使用 [Compiler Explorer](https://godbolt.org/) 或类似服务。

## 部署

1. 将 `VanillaHeroCheat.dylib` 传输到越狱设备
2. 放置到 `/Library/MobileSubstrate/DynamicLibraries/`
3. 重启SpringBoard或重装Cydia

```bash
# SSH到设备
scp VanillaHeroCheat.dylib root@DEVICE_IP:/Library/MobileSubstrate/DynamicLibraries/
ssh root@DEVICE_IP "restart SpringBoard"
```

## 日志

日志文件位置：`/var/mobile/Library/Logs/vh_cheat.log`

## 注意事项

⚠️ **重要**: 香草英雄团是**服务器验证**游戏（VHCheat v1-v11已证明）

- 客户端内存修改可能无效
- 部分功能可能需要服务端配合
- 建议先用诊断模式测试
- 存在封号风险

## 诊断模式

启动时自动启用诊断：
- 记录所有Hook尝试
- 输出到日志文件
- 可根据日志调整参数

## 源代码结构

```
workspace/vanilla_hero/
├── VanillaHeroCheat_v2.xm    # 主源码
├── Makefile                   # Theos构建配置
├── control                    # deb控制文件
├── build.sh                   # 编译脚本
└── .github/workflows/         # CI配置
```

## 依赖

- iOS 14.0+
- 越狱设备 (Cydia/Substitute)
- Theos (可选，用于本地编译)

## 版本历史

- v2.0: 完整UI面板 + 基础功能框架
- v1.0: 初始版本（已终结）

## 许可证

MIT License
