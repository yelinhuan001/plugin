# ClassDumpDylib — iOS Runtime 类信息检索 dylib

**纯 dylib，无 Substrate 依赖，TrollStore 可用，支持 iOS 14+。**

## 功能

| 功能 | 说明 |
|------|------|
| 🔍 Runtime 搜索 | 遍历 App 所有 OC 类/方法/属性，按关键词匹配 |
| 📋 自动复制 | 结果格式化为 Markdown，自动复制到剪贴板 |
| 🖐️ 三指长按 | 0.8 秒呼出半透明搜索面板 |
| 📱 iOS 14+ | 兼容 iOS 14 ~ 18 |
| 🧩 无依赖 | 纯 Objective-C + Runtime API，无需 Cydia Substrate |

## 编译方法（三选一）

### ① GitHub Actions（推荐，无需 Mac）

1. 把整个 `ClassDumpTweak/` 文件夹推送到 GitHub 仓库
2. 在 GitHub 页面点 **Actions** → **Build ClassDumpDylib** → **Run workflow**
3. 构建完成后下载 `ClassDumpDylib.dylib` 工件

### ② 在 iOS 设备上编译（需已安装 Theos）

```bash
# SSH 到设备或使用 NewTerm
cd /path/to/ClassDumpTweak
export THEOS=/var/theos
make
```

产物在 `packages/ClassDumpDylib.dylib`。

### ③ macOS 本地编译

```bash
cd /path/to/ClassDumpTweak
chmod +x build.sh
./build.sh
```

## 注入方法（TrollStore）

### 步骤

1. **获取目标 App 的 IPA**（用 TrollDecrypt 砸壳或从其他来源获取）
2. **解压 IPA**，找到其中的 App 二进制（`Payload/xxx.app/xxx`）
3. **用 `insert_dylib` 注入 dylib**：
   ```bash
   # 将 dylib 复制到 App 包内
   cp ClassDumpDylib.dylib Payload/xxx.app/
   
   # 注入
   insert_dylib @executable_path/ClassDumpDylib.dylib \
     Payload/xxx.app/xxx \
     --inplace \
     --all-yes
   ```
4. **重新打包 IPA**，用 **TrollStore** 安装
5. **打开 App**，三指长按 0.8 秒呼出搜索面板

### 一键注入脚本（可选）

在 iOS 设备上，也可以用 **Filza** 直接操作：
1. 把 `.dylib` 复制到 `/var/containers/Bundle/Application/xxx/xxx.app/`
2. 用 Filza 打开 App 二进制，选择「二进制转换器」→「添加加载命令」
3. 或者用 `TrollInject` 工具图形化注入

## 使用说明

| 操作 | 效果 |
|------|------|
| 三指长按 0.8s | 打开搜索面板 |
| 输入关键词 → 点搜索 | 遍历并显示结果 |
| 结果自动复制 | 粘贴给 AI 分析 |
| 点击面板外 | 收起键盘 |
| 点击 ✕ | 关闭面板 |

## 关键词搜索示例

| 关键词 | 搜索目标 |
|--------|----------|
| `vip` | 会员相关类/方法 |
| `token` | 令牌/认证相关 |
| `user` | 用户模型相关 |
| `pay` | 支付相关 |
| `api` | 网络请求相关 |
| `secret` | 密钥相关 |

## 输出示例

```
# iOS 应用逆向分析报告
## 搜索关键词: vip
## Bundle ID: com.example.app
----
找到 5 个相关结果：

1. **VIPManager**
    - 匹配类型：类名
    - 名称：`VIPManager`

2. **UserInfo**
    - 匹配类型：实例方法
    - 名称：`isVIPMember`

3. **PurchaseManager**
    - 匹配类型：属性
    - 名称：`vipExpireDate`
...
```

## 核心 API

| Runtime API | 用途 |
|-------------|------|
| `objc_getClassList()` | 获取所有已注册类 |
| `class_copyMethodList()` | 获取实例方法列表 |
| `objc_getMetaClass()` | 获取元类（遍历类方法） |
| `class_copyPropertyList()` | 获取属性列表 |
| `method_getName()` | 获取方法名 SEL |
| `NSStringFromSelector()` | SEL → 字符串 |
| `UIPasteboard.generalPasteboard.string` | 写入剪贴板 |

## 文件结构

```
ClassDumpTweak/
├── ClassDumpEntry.m          # dylib 入口（constructor + Method Swizzle）
├── ClassDumpSearcher.h       # 核心搜索接口
├── ClassDumpSearcher.m       # Runtime 遍历实现
├── SearchOverlayWindow.h     # UI 覆盖层接口
├── SearchOverlayWindow.m     # 搜索面板 UI 实现
├── Makefile                  # 编译配置（支持 Theos / 原生 clang）
├── build.sh                  # iOS 设备一键编译脚本
├── control                   # 包信息
├── .github/workflows/        # GitHub Actions 自动编译
└── README.md
```
