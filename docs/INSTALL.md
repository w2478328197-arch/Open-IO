# 构建、签名与安装

## 准备条件

- Mac、完整 Xcode 和对应 iOS/watchOS SDK；手机扩展最低目标 iOS 16，手表目标 watchOS 11。实际配对还需满足 Apple 的系统兼容要求。
- Python 3、Node.js、Git、uv；提词卡／跑步还需 XcodeGen。
- 自己有权使用的原厂 iOS 1.0.5（201）`Runner.app`，可执行文件须可用于本机调试。打包器会检查宿主身份，无法使用加密或未知版本。项目不提供宿主下载或解密服务。
- 自己的 Apple 签名证书、手机 provisioning profile 和设备登记。跑步用的 Watch profile 需包含 HealthKit；手机与手表需同一开发团队、匹配 Bundle ID 和版本。
- 提词卡和跑步需自备有权使用的 Strix OS 1.0.4.12 原厂 OTA ZIP，并使用锁定的 LLVM 工具链重建 TWK1。源码包不包含这些厂商文件。

没有上述输入时，可以阅读代码和运行离线测试；还不能完成设备安装。

## 1. 选择功能并获取基础源码

从功能源码包解压后直接执行，包内已经设好默认功能：

```sh
python3 openio.py prepare --out /absolute/OpenIO-workspace
```

从 Git 仓库下载的完整源码默认包含三项；可以明确指定一项或组合：

```sh
python3 openio.py prepare --features todo,cue,run --out /absolute/OpenIO-workspace
```

支持 `todo`、`cue`、`run`。此步骤从公开仓库读取固定提交 `ca7bc09fbbf036eaf32e90797302d1c798d9e5a4`，校验增量文件，再生成独立构建目录。已有目录不会被覆盖。也可以传 `--upstream /absolute/local-Turbo-IO-repo`，只读取该仓库中的同一提交，不复制未提交内容。

## 2. 构建手机与手表组件

```sh
python3 openio.py build --workspace /absolute/OpenIO-workspace --bundle com.example.openio
```

`com.example.openio` 必须换成你自己签名描述文件允许的独立 Bundle ID，不能使用原厂 ID。手机扩展输出到构建目录的 `build/openio/TurboIOPrivateAddon.dylib`。提词卡／跑步同时生成未签名的 Watch App；待办配置不需要 Watch。

选择提词卡时，Watch 不声明跑步后台处理和 HealthKit 权限。选择跑步时，Watch 声明这些能力，并在用户开始运动时申请健康权限。构建成功仅证明能编译，不代表签名或安装已成功。

## 3. 提词卡／跑步：本机重建眼镜固件

创建 Python 虚拟环境，安装离线回归所需依赖：

```sh
python3 -m venv /absolute/OpenIO-firmware-env
/absolute/OpenIO-firmware-env/bin/pip install unicorn==2.1.4 capstone==5.0.6
/absolute/OpenIO-firmware-env/bin/python openio.py firmware \
  --workspace /absolute/OpenIO-workspace \
  --stock /absolute/StrixOS-1.0.4.12-ORIGINAL.zip \
  --llvm /absolute/pinned-llvm/bin \
  --out /absolute/OpenIO-firmware-output
```

LLVM 须满足构建目录中 `firmware-research/strix-1.0.4.12/native-navigation/cue-cards/toolchain.lock.json`。本次验证使用 OpenHarmony clang 15.0.4，提交 `02fbe8daf56b9704358bc2e7bea9da79938a7abf`。工具链来源与文件哈希写在锁文件中；不同编译器不能靠修改校验常量混用。

构建会运行 ARM 模拟、协议及显示回归，产物在 `candidate/Turbo-Workout-TWK1-CANDIDATE-NOT-DEVICE-VERIFIED.zip`。固定压缩元数据后，完整 ZIP 应为 9,308,080 字节，SHA-256：

```text
c9f441bced48ff56782f23ccdcc42c0545bda5ac719f8c6fa8429d8c24a619a4
```

生成文件不会触发刷写。升级可能导致设备无法启动；这条研究路径没有通用恢复保证。请仅在确认型号、原厂基线及恢复条件后，自行决定是否使用。旧版 TCC1 和 FOCUS 固件不能替代这份 TWK1 配对包。

## 4. 提词卡／跑步：给 Watch 签名

在 Xcode 中登录自己的 Apple Account，确保配对手机和手表可用，再执行：

```sh
python3 openio.py sign-watch --workspace /absolute/OpenIO-workspace \
  --team YOUR_TEAM_ID --watch YOUR_WATCH_DEVICE_ID
```

这一步允许 Xcode 为你指定的团队和手表更新本机签名配置。团队 ID、设备 ID 均由你自己填写。跑步所需 HealthKit 必须由签名 profile 实际授权，脚本不会自行补造权限。

签名输出路径为构建目录下 `apps/CueCardsWatch/build/Build/Products/Debug-watchos/CueCardsWatch.app`。提词卡只用手机控制时，可以不打包 Watch；跑步必须带 Watch。

## 5. 生成仅供自己设备使用的 App

以下示例为提词卡／跑步配置：

```sh
python3 openio.py package --workspace /absolute/OpenIO-workspace \
  --app /absolute/Runner.app \
  --profile /absolute/your-phone.mobileprovision \
  --identity YOUR_CERTIFICATE_SHA1 --device YOUR_IPHONE_DEVICE_ID \
  --firmware /absolute/OpenIO-firmware-output/candidate/Turbo-Workout-TWK1-CANDIDATE-NOT-DEVICE-VERIFIED.zip \
  --watch-app /absolute/OpenIO-workspace/apps/CueCardsWatch/build/Build/Products/Debug-watchos/CueCardsWatch.app \
  --out /absolute/OpenIO-signed-output
```

待办配置去掉 `--firmware` 和 `--watch-app`。提词卡不使用手表时只去掉 `--watch-app`。若宿主机型白名单需要补充，可明确传 `--product` 和自己的 iPhone 产品型号标识。

打包器校验源码配置、扩展指纹、证书、设备、profile、Watch 团队及固件。输出的 `TurboIO-local-only.ipa` 和 `Payload/Runner.app` 只留在本机。通过 Xcode Devices and Simulators 把生成的 App 装到已登记的手机；配对 Watch 的安装可在手机 Watch App 或 Xcode 中确认。

启动后按所选功能说明操作。提词卡／跑步先在 App 的 TWK1 固件入口准备本机下载，按界面逐步确认安装；构建脚本不会自动给眼镜发送升级命令。所有生成包、签名、设备标识和健康记录都不要加入公开仓库。
