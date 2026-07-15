# 没有 Mac？这样拿到可注入的 dylib（免费）

Windows **不能**直接编译 iOS 真机 `.dylib`。  
下面用 **GitHub 免费云 Mac** 自动编，大约 **2～5 分钟**，下载即可给巨魔注入。

---

## 准备

1. 注册免费账号：https://github.com  
2. 手机已装 **TrollStore（巨魔）** + **TrollFools**（或巨魔助手）

---

## 步骤（全网页操作，不用装 Git）

### ① 新建仓库

1. 打开 https://github.com/new  
2. Repository name 填：`TrollDylibPlugin`（随意）  
3. 选 **Public**  
4. **不要**勾选 “Add a README”  
5. 点 **Create repository**

### ② 上传本工程全部文件

1. 在新建好的空仓库页，点 **uploading an existing file**  
   （或 Add file → Upload files）  
2. 打开电脑文件夹：  
   `桌面\TrollDylibPlugin`  
3. **全选里面的所有内容** 拖进网页（包括 `.github` 文件夹）  
   - 若看不到 `.github`：资源管理器 → 查看 → 勾选「隐藏的项目」  
4. 点 **Commit changes**

> 必须带上：`.github/workflows/build.yml` + `src/` + `Makefile.standalone`

### ③ 等云端编译

1. 点仓库上方 **Actions**  
2. 若提示 Enable workflows，点允许  
3. 左侧点 **Build iOS dylib**  
4. 点最新一条运行记录（黄/绿色圆点）  
5. 等变成 **绿色勾**（约几分钟）

### ④ 下载 dylib

1. 进入该次成功运行的详情页  
2. 拉到最下面 **Artifacts**  
3. 下载 **TrollDylibPlugin-dylib**（是个 zip）  
4. 解压得到：

```text
TrollDylibPlugin.dylib    ← 这个就是注入用的
```

### ⑤ 巨魔注入

1. 把 `TrollDylibPlugin.dylib` 传到手机  
2. 打开 **TrollFools** → 选目标 App → 注入该 dylib  
3. 强杀 App 再打开  
4. 应弹出：**「巨魔插件 / 插件已注入」**

---

## 以后改代码再编译

1. 改 `src/TweakStandalone.m`  
2. 在 GitHub 网页上重新上传覆盖该文件  
3. 或 **Actions → Build iOS dylib → Run workflow**  
4. 再下一次新的 Artifact

---

## 常见问题

| 问题 | 处理 |
|------|------|
| Actions 里没有 workflow | 确认上传了 `.github/workflows/build.yml` |
| 编译红叉失败 | 点进失败步骤看日志，把报错发我 |
| 只有 zip 没有 dylib | 解压 zip，里面才是 `.dylib` |
| 注入后无弹窗 | 强杀 App；确认注入的是真机 arm64 这份产物 |
| 不想公开源码 | 仓库建为 **Private**，Actions 对个人免费额度一般够用 |

---

## 为什么不能在这里直接给你 dylib？

- `.dylib` 是 **针对 iPhone 的二进制**，必须在带 **iOS SDK 的 Mac/Xcode** 上链接 UIKit 等框架  
- 当前是 Windows，没有 iPhone SDK，**编不出来**，也不能伪造一个能加载的假文件  
- GitHub Actions 提供的就是免费远程 Mac，结果和你自己有 Mac 编译一样  

按上面做完，你拿到的就是 **直接可用** 的注入文件。
