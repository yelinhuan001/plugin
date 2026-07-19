# ClassDumpDylib — iOS Runtime 逆向工具箱

**纯 dylib，无 Substrate 依赖，TrollStore 可用，支持 iOS 14+。**

三指不用了：用 **双指长按 0.6 秒**，或 **音量 + 连按 3 次** 呼出面板。

## 功能

| 功能 | 说明 |
|------|------|
| Runtime 搜索 | 类名 / 实例方法 / 类方法 / 属性 / Ivar，关键词匹配 |
| App 优先过滤 | 默认只扫主程序与 App 内 Framework，结果更干净 |
| 一键 Hook | 点击搜索结果 → YES/NO/1/nil，自动识别返回类型 |
| 批量快速 Hook | 按方法名（如 `isVIP`）扫描全部类并批量替换 |
| 属性 Hook | 自动解析 getter / `isXxx` |
| UserDefaults | 搜索、编辑、新增、删除，支持 YES/NO/数字智能类型 |
| 导出代码 | 活跃 Hook 导出为 Logos / 纯 ObjC 片段 |
| 类 Dump | 一键复制完整 `@interface` 定义 |
| 自动复制 | 搜索报告 Markdown 自动进剪贴板 |
| 无依赖 | 纯 Objective-C + Runtime，无需 Cydia Substrate |

## 呼出方式

| 操作 | 效果 |
|------|------|
| 双指长按 0.6s | 打开工具箱面板 |
| 音量 + 连按 3 次（2 秒内） | 备用入口 |
| 底部 Tab | 搜索 / Hook / Defaults |
| 点 ✕ | 关闭面板 |

## 编译方法

### ① GitHub Actions（推荐，无需 Mac）

1. 推送到 GitHub
2. **Actions** → **Build ClassDumpDylib** → **Run workflow**
3. 下载工件 `ClassDumpDylib.dylib`

### ② 本地 / 设备

```bash
# macOS 或已装 Theos 的环境
chmod +x build.sh
./build.sh
# 或
make
```

产物：`packages/ClassDumpDylib.dylib`

**务必包含这 5 个源文件**（旧 Makefile 漏编会导致 Hook / Defaults 全挂）：

- `ClassDumpEntry.m`
- `ClassDumpSearcher.m`
- `SearchOverlayWindow.m`
- `MethodHacker.m`
- `UserDefaultsEditor.m`

## 注入（TrollStore）

```bash
cp ClassDumpDylib.dylib Payload/xxx.app/
insert_dylib @executable_path/ClassDumpDylib.dylib \
  Payload/xxx.app/xxx \
  --inplace --all-yes
```

也可用 Filza / TrollInject 图形化注入，再重打包用 TrollStore 安装。

## 使用建议

1. 打开 App → 双指长按 → 搜 `vip` / `premium` / `token`
2. 点结果 → **Hook → YES**（返回类型自动识别）
3. 或在 Hook Tab 点快速模板批量扫 `isVip` 等
4. Defaults Tab 改本地开关后杀进程重进验证

> 仅对「本地判断会员 / 本地广告」类逻辑有效。服务端校验、IAP 收据、加密登录态无法靠本地 Hook 变成真会员。

## 关键词示例

| 关键词 | 目标 |
|--------|------|
| `vip` / `svip` | 会员 |
| `premium` / `pro` | 高级版 |
| `token` / `auth` | 认证 |
| `pay` / `purchase` | 支付 |
| `ad` / `banner` | 广告 |
| `unlock` / `lock` | 解锁 |

## 文件结构

```
plugin/
├── ClassDumpEntry.m          # dylib 入口 + 手势 / 音量键
├── ClassDumpSearcher.h/.m    # Runtime 搜索 + dump
├── SearchOverlayWindow.h/.m  # 三 Tab UI 面板
├── MethodHacker.h/.m         # 方法 / 属性 Hook
├── UserDefaultsEditor.h/.m   # NSUserDefaults 读写
├── Makefile / build.sh
├── .github/workflows/build.yml
├── src/                      # 可选：悬浮球 VIP/去广告工具箱（独立入口）
└── frida/                    # 可选：Frida 脚本
```

## 变更摘要（本次修复）

- **构建漏文件**：Hook / Defaults 以前经常链接不进 dylib，现已全部编入
- **弹窗被挡**：Alert 改到工具箱自己的 `rootViewController` 上 present
- **导出崩溃**：补全缺失的 `exportTweakTapped`
- **Hook 更稳**：`returnType=auto`、属性 getter、父类方法复制、批量按方法名
- **搜索更准**：默认过滤系统类 + App 镜像优先，支持 Ivar / dump 类
- **入口更可靠**：多 Window 装手势 + 音量键备用 + 多次重试安装

## License

仅供学习与安全研究。请勿用于未授权破解商业软件。
