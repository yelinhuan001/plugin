# ClassDumpTweak — iOS Runtime 类信息检索工具

支持 iOS 14+ 越狱设备。

## 功能

- 三指长按 0.8 秒呼出搜索面板
- 遍历当前 App 所有 OC 类/方法/属性，按关键词搜索
- 结果自动格式化为 Markdown 并复制到剪贴板
- 可直接粘贴给 AI 分析

## 无需 Mac 的编译方法

### 方法一：在 iOS 设备上直接用 Theos 编译

**前提：** 越狱设备已安装 Theos。

```bash
# SSH 到越狱设备，或使用 NewTerm 终端
su -c 'apt update && apt install -y theos'  # 如果还没装

# 将本项目通过 SCP / Filza 复制到设备
# 例如放到 /var/mobile/ClassDumpTweak

cd /var/mobile/ClassDumpTweak
make clean
make package
```

编译产物 `.deb` 在 `packages/` 目录下，直接用 Filza 安装即可。

### 方法二：GitHub Actions 远程编译

1. 将此项目推送到 GitHub 仓库
2. 创建 `.github/workflows/build.yml`（见下方）
3. Actions 会自动编译出 `.deb` 文件，下载后通过 Filza 安装

```yaml
# .github/workflows/build.yml
name: Build Tweak
on: [push, workflow_dispatch]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Theos
        run: |
          bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
          echo "THEOS=~/theos" >> $GITHUB_ENV
      - name: Build
        run: |
          export THEOS=~/theos
          make clean package
      - name: Upload .deb
        uses: actions/upload-artifact@v4
        with:
          name: ClassDumpTweak
          path: packages/*.deb
```

### 方法三：使用 iOS SDK 编译裸 dylib

如果不用 Theos，也可以用 `clang` 直接在 iOS 或 macOS 上编译：

```bash
# 在设备上（需安装 iOS SDK）
clang -shared -fobjc-arc \
  -framework UIKit -framework Foundation \
  -o ClassDump.dylib \
  Tweak.xm ClassDumpSearcher.m SearchOverlayWindow.m
```

然后用 `insert_dylib` 或 `ldid` 注入到目标 App。

## 使用方法

1. 安装 deb 后，打开任意 App
2. **三指同时按住屏幕 0.8 秒**，呼出搜索面板
3. 输入关键词（如 `vip`、`token`、`user`）
4. 点击搜索，结果会自动复制到剪贴板
5. 直接粘贴给 ChatGPT / Grok 等 AI 分析

## 触发方式

| 手势 | 操作 |
|------|------|
| 三指长按 0.8 秒 | 打开搜索面板 |
| 点击搜索面板外区域 | 收起键盘 |
| 点击 ✕ 按钮 | 关闭面板 |

## 核心 API 说明

| API | 用途 |
|-----|------|
| `objc_getClassList()` | 获取当前进程所有注册的类 |
| `class_copyMethodList()` | 获取类的实例方法列表 |
| `objc_getMetaClass()` | 获取元类（用于遍历类方法） |
| `class_copyPropertyList()` | 获取类的属性列表 |
| `method_getName()` | 获取方法名的 SEL |
| `NSStringFromSelector()` | 将 SEL 转为字符串 |
| `UIPasteboard.generalPasteboard.string` | 写入系统剪贴板 |
