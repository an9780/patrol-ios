# 巡检打卡 · iOS 版

这是按原安卓 App 重写的 iOS 版本。**不是把 APK 转成 IPA**（技术上做不到），而是用 SwiftUI 重新实现同样的功能。

能编出可安装的 `.ipa`，用你自己的证书签名。

---

## 一、上传到 GitHub（两种放法都行）

### 放法 A：全部放仓库根目录

```
你的仓库/
├── .github/workflows/ios.yml
├── project.yml
└── PatrolCheckin/
    ├── AppShell.swift
    ├── Core/
    └── Modules/
```

### 放法 B：整个 ios 文件夹放进去

```
你的仓库/
└── ios/
    ├── .github/workflows/ios.yml
    ├── project.yml
    └── PatrolCheckin/
```

workflow 会自动识别 `project.yml` 在哪，不用改路径。

> 注意：`.github` 是隐藏文件夹，用网页上传时直接把 `.github` 文件夹拖进去就行。如果拖不进去，改用 GitHub Desktop 或 git 命令行。

---

## 二、编译

push 到 `main` 或 `master` 后自动触发，也可以手动：
**Actions → Build iOS IPA → Run workflow**

跑完在 Actions 页面底部 **Artifacts** 下载：

| 产物 | 说明 |
|---|---|
| `PatrolCheckin-unsigned` | 未签名 ipa，自己签 |
| `PatrolCheckin-signed` | 配了证书才有，直接可装 |

---

## 三、签名（Windows 用 zsign）

下载 `unsigned.ipa`，然后：

```bat
zsign.exe -k 你的证书.p12 -p 证书密码 -m 你的描述文件.mobileprovision -o 巡检打卡.ipa unsigned.ipa
```

或者用 **Sideloadly**（图形界面，填 Apple ID 自动签，免费证书 7 天有效）。

**Bundle ID 要对上**：如果描述文件是具体 ID（不是 `com.xxx.*` 通配符），改 `project.yml` 里的：

```yaml
PRODUCT_BUNDLE_IDENTIFIER: com.patrol.checkin
```

改成描述文件里的那个，再 push。

### 让 Actions 自动签

仓库 **Settings → Secrets and variables → Actions** 加三个 Secret：

| Secret | 内容 |
|---|---|
| `P12_BASE64` | p12 文件的 base64 |
| `P12_PASSWORD` | p12 密码 |
| `PROFILE_BASE64` | mobileprovision 的 base64 |

生成 base64（PowerShell）：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("cert.p12")) | Set-Content p12.txt
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Set-Content profile.txt
```

把 txt 里的内容粘进 Secret。之后每次 push 都会自动签好。

---

## 四、安装到 iPhone

| 方式 | 说明 |
|---|---|
| Sideloadly（Windows） | 插线，拖 ipa，填 Apple ID |
| Apple Configurator 2（Mac） | 插线拖进去 |
| 企业分发页 | 上传 ipa，扫码安装 |

---

## 五、App 里怎么用
2. 底部 5 个 Tab：巡检 / 故障 / 维保 / 报警 / 更多
3. **调度单**：故障 Tab → 调度单 → 点单 → 拍照 → 上传并完成
4. **巡检打卡**：巡检 Tab → 点班次 → 点点位卡片即完成

---

## 六、文件说明

```
PatrolCheckin/
├── AppShell.swift              入口、登录、5 个 Tab、通用组件
├── Core/
│   ├── Net.swift               网络层（form / JSON / multipart 上传）
│   ├── Endpoints.swift         99 个接口登记表（含参数名）
│   └── FormEngine.swift        通用表单引擎
└── Modules/
    ├── PatrolScreen.swift      巡检列表 / 详情 / 点卡片打卡
    ├── FaultScreen.swift       异常处理 5 个页签
    ├── FaultReportScreen.swift 故障上报（含拍照）
    ├── DispatchScreen.swift    调度单（拍照上传完成）
    ├── DetailScreens.swift     故障/维保/排班/历史 详情与审核
    ├── Pickers.swift           备件/人员/工艺段/图片补充
    ├── MiscScreens.swift       设置/改密/关于/知识库/设备查询
    ├── GenericModules.swift    通用列表
    └── ExtraScreens.swift      转下一节点/维保填报/新建调度/测点趋势
```

13 个 Swift 文件，约 4500 行。

---

## 七、接口协议已验证（关键）

iOS 端要能打卡、能上传，关键不是"平台"，而是**请求参数和安卓端完全一致**。
这一点用一台 Windows 电脑的 Python 客户端实测过（既不是安卓也不是 iOS）：

| 操作 | 接口 | 实测结果 |
|---|---|---|
| 登录 | `j_spring_security_check` | ✅ 返回 Access_Token |
| 拉任务 | `getPatrolRecord4APP.do` | ✅ 4 个班次 |
| 拉点位 | `getPatrolPointForRecord4APP.do` | ✅ 12 个点位 |
| 点位打卡 | `updatePatrolPointByAPP.do` | ✅ `{"code":1,"result":1}`，时间与打卡人真实变更 |
| 照片上传 | `base/updateFile.do` (multipart) | ✅ `{"suc":true}` |

**上传的三个必填字段（实测）：**

```
masterId   当前步骤 taskid
tbName     tb_common_file
nameSpace  taskmaterial
filelist   图片文件
```

漏了 `tbName` 会返回 `{"suc":false}` —— 这是实测出来的坑，代码里已处理。

**另一个坑**：上传成功的返回是 `{"suc":true}`，不是 `{"code":1}`。
代码里的 `Net.isOK()` 同时识别 `code==1 / status / suc / success` 四种，避免"传成功却报失败"。

---

## 八、常见报错

| 报错 | 原因 | 处理 |
|---|---|---|
| `project.yml not found` | 文件没传到正确位置 | 按第一节的两种放法之一重传 |
| `xcodegen: command not found` | workflow 第一步没跑 | 检查 Actions 日志 |
| `No such module 'UIKit'` | 用了 macOS 目标 | 确认 project.yml 里 `platform: iOS` |
| `bundle identifier mismatch` | 描述文件和 Bundle ID 不符 | 改 project.yml 的 PRODUCT_BUNDLE_IDENTIFIER |
| 装上闪退 | 证书过期或设备未授权 | 重新签名；免费证书 7 天续一次 |
| 打开相机崩溃 | 缺权限声明（已修） | 确认 Info.plist 有 NSCameraUsageDescription |

---

## 九、不包含的模块

| 模块 | 原因 |
|---|---|
| 大华视频监控 | 需厂商 SDK 授权 |
| ArcGIS / 百度地图 | 需许可 / AK |
| NFC 刷卡 | iOS 不支持 MIFARE Classic |
| 锁屏推送 | 需 APNs |
| 热更新 | iOS 禁止 |
