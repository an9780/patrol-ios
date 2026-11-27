# 上传到 GitHub 的步骤（纯网页操作，不用装任何软件）

你现在在 `github.com/an9780` 的首页。跟着做。

---

## 第 1 步：建仓库

1. 右上角 **+** → **New repository**
2. Repository name 填：`patrol-ios`
3. 选 **Private**（私有，别人看不到）
4. **不要**勾 "Add a README file"
5. 点 **Create repository**

建好后是一个空仓库页面，上面有几行命令行提示，忽略它们。

---

## 第 2 步：上传工程文件

在空仓库页面上，找到 **uploading an existing file** 这个链接（在 "Quick setup" 那一段里），点它。

然后：

1. 解压 `巡检打卡_iOS工程.zip` 到一个文件夹
2. 把解压出来的这些**拖进浏览器上传区**：
   - `project.yml`
   - `PatrolCheckin` 文件夹（整个拖）
   - `README.md`
   - `覆盖对照表.md`

> **先不要管 `.github` 文件夹**（Windows 默认隐藏它，拖不进去，下一步单独建）

3. 下面 Commit changes 的说明框随便写，点绿色 **Commit changes**

---

## 第 3 步：建 workflow 文件（关键一步）

因为 `.github` 是隐藏文件夹，网页上传容易漏，我们手动建：

1. 点仓库上方的 **Actions** 标签
2. 如果出现欢迎页，点 **set up a workflow yourself**
   （如果没出现，点左侧 **New workflow** → 搜 "simple workflow" → **Configure**）
3. 编辑器里会有一段默认内容，**全选删掉**
4. 打开 `workflow内容_复制粘贴.txt`，**全选复制**，粘进去
5. 右上角文件名改成：`ios.yml`
6. 点 **Commit changes...** → 再点 **Commit changes**

---

## 第 4 步：等编译

1. 点 **Actions** 标签
2. 会看到 `Build iOS IPA` 正在跑（黄色转圈）
3. 点进去能看实时日志
4. 大约 **5–10 分钟**跑完

---

## 第 5 步：下载 ipa

跑完后：

1. 点进那次运行
2. 页面最下方 **Artifacts** 区域
3. 下载 **PatrolCheckin-unsigned.zip**
4. 解压出 `unsigned.ipa`

这就是你的 iOS 安装包（未签名）。

---

## 第 6 步：签名安装

用 **zsign**（Windows 命令行）或 **Sideloadly**（图形界面，更简单）。

### 用 Sideloadly

1. 下载安装 Sideloadly（sideloadly.io）
2. iPhone 插电脑，信任
3. 把 `unsigned.ipa` 拖进 Sideloadly
4. Apple ID 填你的
5. 点 Start

免费 Apple ID 签的包 7 天有效，到期重签一次。

### 用 zsign

```bat
zsign.exe -k 你的证书.p12 -p 密码 -m 描述文件.mobileprovision -o 巡检打卡.ipa unsigned.ipa
```

---

## 如果第 4 步报错

把 **Actions → 那次运行 → 报错那一步的日志**截图或复制给我。

最可能的几个：

| 报错 | 原因 |
|---|---|
| `project.yml not found` | 第 2 步没传 project.yml |
| `xcodegen: command not found` | workflow 内容没粘全 |
| `No such module 'UIKit'` | project.yml 被改坏了 |
| `Signing ... requires a development team` | 不用管，未签名版能出就行 |

---

## 备选：装个 GitHub Desktop 更省事

如果网页上传老是漏文件，装 **GitHub Desktop**（desktop.github.com）：

1. 登录你的账号
2. File → Add local repository → 选解压后的文件夹
3. 它会自动发现所有文件（包括 `.github`）
4. 点 **Publish repository**
5. 之后改动也是点一下就同步

这条路不用手动建 workflow，`.github` 会一起传上去。
