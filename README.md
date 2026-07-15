# iOS 14 巨魔通用工具箱 v2（悬浮球 / 会员 / 去广告）

> ## 没有 Mac？
> 见 **[无Mac-直接下载dylib.md](./无Mac-直接下载dylib.md)**  
> GitHub Actions 编译 → 下载 `TrollDylibPlugin.dylib` → TrollFools 注入。

## 功能

| 功能 | 说明 |
|------|------|
| **悬浮球** | 可拖动，点「魔」打开深色设置面板 |
| **会员扫描** | 扫描 UserDefaults 可疑 key + 已加载类中 `isVip` 等方法 |
| **强制会员** | 启发式写入本地会员标记，并对布尔/整型方法 Hook 返回 YES/1 |
| **去广告** | 隐藏类名像广告的视图；Hook 常见广告 SDK 的 load/show |
| **全 App** | 注入到哪个 App 就对哪个 App 生效（需对每个 App 各注入一次） |

## 能力边界（必读）

- **不是** 系统级全局插件：巨魔 + TrollFools 是 **按 App 注入**。
- **强制会员** 只对「本地读写开关/等级」的实现可能有效。  
  服务端鉴权、Apple IAP 收据、签名 Token → **无法**本地变成真会员。
- **去广告** 为启发式，无法保证覆盖所有广告 SDK / 网页广告。
- 请仅在自有设备上用于学习与调试，勿用于侵犯他人版权或传播破解。

## 目录

```
src/
  TweakStandalone.m   # 入口
  TDPFloatingBall.*   # 悬浮球 + 面板
  TDPVipEngine.*      # 会员扫描/修改
  TDPAdBlocker.*      # 去广告
  TDPConfig.*         # 开关持久化
  HookHelper.* / fishhook.*
```

## 编译

```bash
make -f Makefile.standalone
# → packages/TrollDylibPlugin.dylib
```

或 push 到 GitHub 等 Actions 产物。

## 使用

1. TrollFools 注入 dylib 到目标 App  
2. 强杀后打开 → 见蓝色 **「魔」** 悬浮球  
3. 面板中打开 **强制会员** / **去广告**，或点「立即应用」  
4. 「扫描会员状态」查看识别结果  

设置按 **App 沙盒** 分别保存（每个 App 一套开关）。

## 版本

- **2.0.0** 悬浮球 UI、会员引擎、去广告、自动应用  
- **1.0.0** 注入验证弹窗模板  
