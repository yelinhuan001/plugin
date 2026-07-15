# iOS 14 巨魔 (TrollStore) dylib 插件模板

> ## 没有 Mac？要「直接能注入」的 dylib
>
> Windows **编不出**真机 `.dylib`。请看：  
> **[无Mac-直接下载dylib.md](./无Mac-直接下载dylib.md)**  
> 用 GitHub 免费云 Mac 自动编译 → 下载 `TrollDylibPlugin.dylib` → TrollFools 注入。

一套可直接扩展的 **arm64 dylib 插件** 工程，面向：

| 场景 | 方式 |
|------|------|
| **巨魔 / TrollStore** | 编译出 `.dylib`，用 **TrollFools（巨魔助手）** 注入到目标 App |
| **越狱** | 用 Theos 打 deb，配合 Substrate / ElleKit |

支持 **iOS 14.0+**，架构默认 **arm64**。

---

## 目录结构

```
TrollDylibPlugin/
├── Makefile                 # Theos 编译
├── Makefile.standalone      # 无 Theos，纯 clang 编译（推荐巨魔）
├── control                  # deb 包信息
├── TrollDylibPlugin.plist   # 越狱 Filter（指定注入进程）
├── README.md
├── scripts/
│   └── build_on_mac.sh      # 一键编译脚本
└── src/
    ├── Tweak.x              # Logos 版（Theos）
    ├── TweakStandalone.m    # 纯 ObjC 版（巨魔推荐）
    ├── HookHelper.h/.m      # Method Swizzle 工具
    └── fishhook.h/.c        # C 函数 rebind（Facebook fishhook）
```

---

## 一、编译（在 Mac 上）

### 方式 A：无 Theos（巨魔注入推荐）

```bash
cd TrollDylibPlugin
chmod +x scripts/build_on_mac.sh
./scripts/build_on_mac.sh
# 产物: packages/TrollDylibPlugin.dylib
```

或：

```bash
make -f Makefile.standalone
```

需要：macOS + Xcode / Command Line Tools。

### 方式 B：Theos

```bash
export THEOS=~/theos   # 按你的路径改
make clean
make package
# 产物: packages/TrollDylibPlugin.dylib  以及 .deb
```

---

## 二、安装到设备（巨魔）

### 前置条件

1. 设备已安装 **TrollStore（巨魔）**
2. 已安装 **TrollFools** 或其它 dylib 注入工具（如 巨魔助手 / TrollInject）
3. 目标 App 尽量用巨魔安装（权限更完整）

### 注入步骤（TrollFools）

1. 打开 **TrollFools**
2. 选择目标 App
3. 点 **注入** → 选 `TrollDylibPlugin.dylib`
4. 注入成功后 **强杀并重启** 该 App
5. 若插件正常，会弹出 **「巨魔插件 / 插件已注入」** 提示

### 卸载

在 TrollFools 中对该 App 选择 **清除注入** 即可。

---

## 三、自定义你的逻辑

### 1. 限定只注入某个 App

编辑 `src/TweakStandalone.m`（或 `Tweak.x`）：

```objc
static NSString * const kTargetBundleID = @"com.example.app";
```

### 2. Hook 某个方法（Method Swizzle）

```objc
static IMP orig_isVip = NULL;

static BOOL hook_isVip(id self, SEL _cmd) {
    return YES; // 改返回值示例
}

// 在 TDP_CustomLogic 里:
Class cls = NSClassFromString(@"UserManager");
TDP_SwizzleInstanceMethod(cls, NSSelectorFromString(@"isVip"),
                          (IMP)hook_isVip, &orig_isVip);
```

### 3. Hook C 函数（fishhook）

在入口里：

```c
static int (*orig_open)(const char *, int, ...);
// ... 定义 hook_open ...
struct rebinding binds[] = {
    { "open", (void *)hook_open, (void **)&orig_open },
};
rebind_symbols(binds, 1);
```

### 4. 验证注入

1. 看弹窗是否出现  
2. Mac 连设备后：

```bash
idevicesyslog | grep TrollDylibPlugin
# 或 Xcode Devices 控制台过滤 [TrollDylibPlugin]
```

---

## 四、技术说明

| 项目 | 说明 |
|------|------|
| 入口 | `__attribute__((constructor))`，dylib 加载即执行 |
| UI 安全 | 延迟到主队列再弹窗 / Hook UI |
| 无 Substrate | 巨魔场景用 **ObjC Runtime Swizzle + fishhook** |
| 有 Substrate | `Tweak.x` 里 `%hook` 可在越狱环境使用 |
| 签名 | standalone 脚本会 `codesign -s -` 做 ad-hoc 签名；巨魔注入一般仍可加载 |
| 架构 | 默认 `arm64`；A12+ 若目标是 arm64e 切片，按需改 `ARCHS` |

### iOS 14 注意点

- 最低版本已设为 **14.0**
- 弹窗兼容 UIScene（iOS 13+）与旧 `keyWindow`
- 不要在 constructor 里立刻碰 UI，务必 `dispatch_async` / `dispatch_after`

### 常见失败原因

1. **架构不对**：模拟器是 x86_64/arm64 模拟器，真机要用 `iphoneos` SDK  
2. **注入了错误 App / 未强杀**  
3. **目标类名/方法名错误**（用 class-dump / frida-trace 确认）  
4. **系统 App 有额外保护**，优先选第三方 App 做实验  
5. **依赖了 Substrate 符号**却在无越狱环境加载 → 请用 `Makefile.standalone` 产物

---

## 五、合法与安全

- 仅建议用于 **自己的设备、自己有权修改的 App** 学习与调试  
- 不要用于破解付费、绕过版权或攻击他人服务  
- 分发修改后的第三方 App 可能违反当地法律与开发者协议  

---

## 六、快速改名

全局替换 `TrollDylibPlugin` / `com.example.trolldylibplugin` 为你的名字，并同步改：

- `Makefile` / `Makefile.standalone` 输出名  
- `control` 包名  
- `TrollDylibPlugin.plist` 文件名（Theos 约定：与 `TWEAK_NAME` 一致）

---

## 七、最小验证清单

- [ ] Mac 上编译出 `packages/TrollDylibPlugin.dylib`  
- [ ] 传到手机，用 TrollFools 注入测试 App  
- [ ] 打开 App 出现「插件已注入」  
- [ ] 日志里有 `[TrollDylibPlugin] loaded`  
- [ ] 再改 `TDP_CustomLogic` 写真实业务 Hook  

祝折腾顺利。
