# iOS 移植 · 完成度

## 代码：全部页面已写完

| 模块 | 文件 | 状态 |
|---|---|---|
| 登录 / 主框架 | AppShell.swift | ✅ |
| 网络层（form / JSON / multipart） | Core/Net.swift | ✅ |
| 99 个接口登记表 | Core/Endpoints.swift | ✅ |
| 通用表单引擎（文本/多行/下拉/日期/拍照） | Core/FormEngine.swift | ✅ |
| 巡检列表 + 详情 + 点卡片打卡 + 整班点完 | Modules/PatrolScreen.swift | ✅ |
| 异常处理 5 页签 | Modules/FaultScreen.swift | ✅ |
| 故障上报（含拍照） | Modules/FaultReportScreen.swift | ✅ |
| **调度单（拍照上传完成）** | Modules/DispatchScreen.swift | ✅ |
| 故障详情/处理、故障审核、维保详情、排班详情、历史详情 | Modules/DetailScreens.swift | ✅ |
| 备件选择、人员选择、工艺段树、图片补充 | Modules/Pickers.swift | ✅ |
| 设置 / 改密 / 关于 / 知识库 / 设备查询 / WebView | Modules/MiscScreens.swift | ✅ |
| 通用列表（维保/报警/更多） | Modules/GenericModules.swift | ✅ |
| 转下一节点、维保填报、新建调度、测点趋势图 | Modules/ExtraScreens.swift | ✅ |

**13 个 Swift 文件，约 4500 行。**

结构自检：括号平衡、引号成对、`@main` 唯一、无重复类型定义。

---

## 还差什么

### 1. 编译（必须做，我这边做不了）

没有 macOS / Xcode，无法本地编译验证。
推 GitHub → Actions 跑 `xcodebuild` → 有报错发我。

预计来回 1–3 次，每次几分钟。

### 2. 真机验证（必须做，需要你）

以下接口的参数是**从 smali 读出来的，但没有用真实数据跑过**，需要在手机上点一次确认：

| 功能 | 风险点 |
|---|---|
| 调度单 上传+提交 | 参数已由真实附件反证，成功率最高 |
| 故障上报 | `dosave.do` 返回的 id 字段位置不确定，做了三种兼容 |
| 维保填报 | `insetMaintenanceDetailNoFlow.do` 参数名来自 smali，未实测 |
| 新建调度 | `dostart.do` 只传了 id，实际可能需要更多参数 |
| 转下一节点 | `getRoutesForSelect2` 返回结构未实测 |
| 测点趋势 | `getHistory.do` 字段名做了兼容，可能对不上 |

每项十几分钟，报错就把弹窗文字发我。

### 3. 明确不做的

| 功能 | 原因 |
|---|---|
| 大华视频监控 | 需厂商 SDK 授权 |
| ArcGIS / 百度地图 | 需许可 / AK |
| NFC 刷卡 | iOS 不支持 MIFARE Classic |
| 锁屏推送 | 需 APNs，且你不需要 |
| 热更新 | iOS 禁止 |

---

## 时间估算（真实）

| 阶段 | 时间 |
|---|---|
| 代码编写 | **已完成** |
| 编译调通 | 半天内（几次来回） |
| 真机逐屏验证 | 半天到一天 |
| **合计** | **1–2 天** |
