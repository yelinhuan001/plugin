# plugin（yelinhuan001）

巨魔可注入 dylib 工具箱 + ClassDump 检索。

**当前策略：默认全手动，不强制会员、不自动去广告，降低闪退概率。**

仓库：https://github.com/yelinhuan001/plugin

---

## 你该注入哪个文件？

| 产物 | 说明 | 建议 |
|------|------|------|
| `TrollDylibPlugin.dylib` | 悬浮球「魔」面板：扫描会员 / 手动开关 | 功能完整 |
| `ClassDumpSearch.dylib` | 仅关键词检索 + 报告剪贴板 | 做 AI 分析 |
| `ClassDumpSearch-noauto.dylib` | 同上但不自动弹窗 | **最稳，闪退时优先** |

下载：仓库 **Actions** → 最新成功构建 → Artifact **`compiled-dylibs`**

---

## 没有 Mac 怎么编译？

1. 把本仓库代码推到 GitHub（你已有：`yelinhuan001/plugin`）
2. 打开 [Actions](https://github.com/yelinhuan001/plugin/actions)
3. 等 **Build Dylib** 变绿
4. 下载 **compiled-dylibs**，解压得到 `.dylib`
5. 用 **TrollFools** 注入目标 App → 巨魔安装

本地 Windows **不能**编 iOS dylib；云 Mac（Actions）可以。

更省事、不注入：用 `frida/class_dump_search.js`（需 frida-server）。

```text
frida -U -f 包名 -l frida/class_dump_search.js --no-pause
rpc.exports.search("vip", 200)
```

---

## 默认行为（v2.1 safe）

| 开关 | 默认 | 说明 |
|------|------|------|
| 悬浮球 | 开 | 约 5 秒后出现「魔」 |
| 强制会员 | **关** | 面板里手动开 |
| 去广告 | **关** | 面板里手动开 |
| 启动自动应用 | **关** | 避免一启动就 Hook 闪退 |

### 已修闪退点

- 去掉 `makeKeyAndVisible`（抢焦点）
- constructor 不碰 UI / 不立刻 Hook
- 等 `DidBecomeActive` 再延迟启动
- 扫描类时跳过元类 + 异常隔离

---

## 目录

```text
src/                 TrollDylibPlugin 主工程
ClassDumpSearch.*    纯检索 dylib 源码
frida/               无编译检索脚本
.github/workflows/   云编译
```

---

## 免责声明

仅供学习与对你有权分析的软件做研究。请遵守法律与许可协议。
