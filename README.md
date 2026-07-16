# ClassDumpSearch

iOS 注入式 dylib：在目标 App 进程内用 Objective-C Runtime 搜索类名 / 方法名 / 属性名，生成 Markdown 分析报告并复制到剪贴板。

**定位：仅检索与分析，不自动 Hook、不强制会员、不修改方法返回值。** 是否 Hook 由你自己手动决定。

## 功能

1. Runtime 遍历已加载 ObjC 类，按关键词搜索（不区分大小写）
2. 匹配类名、实例方法、类方法、属性
3. 输出 Markdown 报告到 `UIPasteboard`
4. 可选顶层 `UIWindow` 搜索面板（手动输入关键词）

## 文件

| 文件 | 说明 |
|------|------|
| `ClassDumpSearch.h/m` | 核心检索 + 报告 + 剪贴板 |
| `CDSOverlay.h/m` | 悬浮搜索 UI |
| `TweakEntry.m` | dylib 构造函数入口 |

## 编译（需 macOS + Xcode / 交叉工具链）

源码可在 Windows 上编辑；编译 arm64 dylib 通常需要 Mac 或已有 iOS 工具链。

```bash
xcrun -sdk iphoneos clang -arch arm64 -shared -fobjc-arc \
  -miphoneos-version-min=14.0 \
  -framework Foundation -framework UIKit \
  ClassDumpSearch.m CDSOverlay.m TweakEntry.m \
  -o ClassDumpSearch.dylib
```

## 注入（iOS 14+ / 巨魔 TrollStore 思路）

用 TrollFools、insert_dylib 等工具将 `ClassDumpSearch.dylib` 插入目标 App，重新签名后安装。具体步骤因工具而异。

## 使用

1. App 启动约 3 秒后弹出搜索面板（可在 `TweakEntry.m` 关闭 `CDS_AUTO_SHOW_OVERLAY`）
2. 输入关键词（如 `vip`）→ 点「搜索」
3. 报告显示在面板中，并已复制到剪贴板，可粘贴给 AI 分析
4. 默认只搜索 App 自身 image 内的类；全进程扫描请调用：

```objc
[ClassDumpSearch setSearchAppOwnClassesOnly:NO];
```

## 免责声明

仅供学习与对你有权分析的应用做安全研究。请遵守当地法律与软件许可协议。
