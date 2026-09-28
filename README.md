# Open IO

为雷鸟眼镜整理的三个功能：待办同步、提词卡、户外跑步心率看板。选择需要的功能，下载对应源码包，在自己的 Mac 上构建并签名。

**当前版本面向有 Xcode 使用经验的开发者。下载内容是源码和构建工具，不能直接点开安装。** 手机端沿用 Turbo IO 的厂商 App 扩展方式，需要自行准备有权使用、版本匹配且可用于本机调试的宿主 App；仓库不提供宿主 App、合并 IPA、原厂固件或个人签名。

## 按功能下载

| 功能 | 可以做什么 | 需要的设备与组件 | 下载与使用 |
| --- | --- | --- | --- |
| 待办同步 | 连接眼镜待办与 Apple 提醒事项，处理关联、完成状态与重复回执 | iPhone、眼镜；无需新装本项目眼镜固件 | [下载待办源码包](https://github.com/w2478328197-arch/Open-IO/releases/download/v0.1.1/OpenIO-todo-source-v0.1.1.zip) · [说明](docs/TODO.md) |
| 提词卡 | 手机建立、编辑、导入卡片；手表追加卡片；眼镜显示与翻页同步 | iPhone、眼镜 TWK1 固件；Apple Watch 可选 | [下载提词卡源码包](https://github.com/w2478328197-arch/Open-IO/releases/download/v0.1.1/OpenIO-cue-source-v0.1.1.zip) · [说明](docs/CUE.md) |
| 心率看板 · 户外跑步 | 手表记录跑步，眼镜显示心率及运动数据，结束后保存到 Apple 健康／健身 | iPhone、Apple Watch、眼镜 TWK1 固件 | [下载跑步源码包](https://github.com/w2478328197-arch/Open-IO/releases/download/v0.1.1/OpenIO-run-source-v0.1.1.zip) · [说明](docs/RUN.md) |

三个包共享基础代码，包内默认选择对应功能；也可组合构建 `todo,cue,run`。同一 Bundle ID 每次安装会更新同一个 App，需要多项功能时请选择组合配置。提词卡和跑步共用 TWK1 固件，眼镜菜单中会同时保留两项入口；手机和手表按所选配置显示新增功能。Turbo IO 原有界面仍可能存在。

## 开始使用

解压任一源码包，在该目录打开终端：

```sh
python3 openio.py prepare --out /absolute/OpenIO-workspace
python3 openio.py build --workspace /absolute/OpenIO-workspace --bundle com.example.openio
```

第一条命令读取固定版本的公开 Turbo IO 源码，再应用本包经过校验的增量源码。第二条构建手机扩展和适用的未签名手表 App。请将示例路径、Bundle ID 换成自己的值。

[完整构建、签名与安装步骤](docs/INSTALL.md) · [版本与验证记录](docs/PRODUCT_SPEC.md) · [源码来源与许可](docs/LICENSING.md) · [发布附件与校验值](https://github.com/w2478328197-arch/Open-IO/releases/tag/v0.1.1)

## 费用与分发

下载源码不需要购买 Apple 开发者会员。Apple 允许用免费 Apple Account 在 Xcode 中做个人设备测试；本项目的完整组合还受到设备、签名和 HealthKit 等能力限制，不保证免费签名能够安装所有配置。TestFlight、App Store 等正式分发属于 Apple Developer Program，目前年费为 99 美元或当地等值价格。购买会员也不会授予厂商 App 的再分发权。参见 [Apple 会员说明](https://developer.apple.com/programs/) 与 [分发文档](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)。

项目基于 [Turbo1123/Turbo-IO](https://github.com/Turbo1123/Turbo-IO/tree/ca7bc09fbbf036eaf32e90797302d1c798d9e5a4)，保留其 PolyForm Noncommercial 1.0.0 许可及第三方声明。Open IO 是独立整理的源码项目，名称不表示获得 Apple 或眼镜厂商的官方支持。
