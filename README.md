# 巡检打卡 iOS 工程

界面对照为《巡检打卡_点卡片即完成》Android 2.77。工程沿用 SwiftUI、iOS 15.0 起和 com.patrol.checkin。正式业务使用已有账号的单位。登录页的「设置 → 本地巡检演示」可直接试用两类任务及单击点位完成。示例数据仅在本次演示有效。正式点位卡显示服务端状态，现场核验仍需接入。

## 用 Codemagic 构建（Windows 用户）

1. 解压工程并保留隐藏目录 `.github`。在仓库根目录应能直接看到 `codemagic.yaml`、`project.yml`、`PatrolCheckin/`、`SmokeTests/`、`ci/`。
2. 在 Codemagic 的 Applications 中打开关联此源码仓库的应用。选择含修复代码的分支，使用 **Check for configuration file** 读取根目录配置。[Codemagic iOS 文档](https://docs.codemagic.io/yaml-quick-start/building-a-native-ios-app/)
3. 点击 **Start new build**，确认分支和工作流 **PatrolCheckin unsigned IPA**（ID 为 `ios-unsigned`）。构建日志会输出 Xcode 和 XcodeGen 版本，生成 Xcode 工程，再用真机 SDK 编译 Release。
4. 在此次构建的 Artifacts 中下载 **PatrolCheckin-unsigned.ipa**。一起提供的 `commit.txt` 和 `SHA256.txt` 用于核对版本，`XcodeProject.zip` 解压到 `project.yml` 旁即可用 Xcode 打开。模拟器步骤另测登录页、两类示例任务、点卡片和返回，并保存截图。

## 用 GitHub Actions 构建

1. Windows 上使用 GitHub Desktop 将解压后的**内容**提交到自己的仓库，确保根目录包含 `.github/workflows/ios.yml`。若复用现有仓库，先核对分支并保留原主分支。要让手动运行按钮出现，默认分支须包含手动触发的工作流。
2. 在仓库打开 **Actions → Build unsigned IPA → Run workflow**，选择需要构建的分支并运行。[GitHub 手动运行文档](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
3. 打开对应运行记录，在 **Artifacts** 下载 **PatrolCheckin-unsigned**。解开 GitHub 的外层 ZIP，得到里面的 IPA。另一个附件 **Simulator-results** 包含可用的测试结果。若编译失败，查看 **Build device IPA** 中第一条编译错误；模拟器失败则看后续测试步骤。
4. 两种平台共用 `ci/build-ipa.sh`。它编译 arm64 真机程序，检查 Bundle ID、平台、可执行文件与资源，再打包 `Payload/PatrolCheckin.app`。不需要在构建平台配置签名证书。

## 在 iPhone 上用全能签安装

1. 将构建产出的 `.ipa` 保存到 iPhone「文件」。在全能签的文件导入入口导入 IPA。
2. 在全能签中选用自己的有效签名身份。首次使用时导入带私钥的 `.p12`、输入其密码，并导入与证书和 App ID 匹配的 `.mobileprovision`。Ad Hoc 描述文件还须包含该 iPhone 的 UDID。[Apple 描述文件说明](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/)
3. 选择应用签名，核对包名 `com.patrol.checkin`，开始签名，再选择安装。界面名称随全能签版本有所差异。若提示无法验证，先核对证书有效期、描述文件、设备 UDID 和包名。
4. 签名资料留在全能签。Codemagic 或 GitHub 出现绿色构建表示相应步骤通过；登录、视频、相机、任务写入等还需要各自的真机和服务端验收。

## 开发与验证

`project.yml` 是工程配置源。在安装了 Xcode、Homebrew 的 Mac 上，仓库根目录运行 `bash ci/build-ipa.sh`。有 iPhone 模拟器时再运行 `bash ci/simulator.sh`。整个过程使用 XcodeGen，从 Swift 源文件与 Assets.xcassets 生成单应用及 UI 测试目标。

视频目录使用已有账号访问；播放仅支持摄像头列表实际返回的 HTTPS HLS、MP4 或 MOV。RTSP、专用协议、录像回放尚待对接。离线页保存当前账号及单位下的任务和点位快照，供登录会话中查看。备注是本机草稿。GIS 图层编辑、NFC 核验、通知和后台离线提交尚待接入。
