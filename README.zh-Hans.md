# Provika

[English](README.md) · [한국어](README.ko.md) · **简体中文** · [繁體中文](README.zh-Hant.md) · [日本語](README.ja.md)

**拍摄、封装、核验。**

Provika 是一款 iOS 应用，用于记录拍摄时间、地点与原始完整性十分重要的照片和视频。它可以创建便于携带和导出的证据包，并支持无网络离线核验。

Provika 并非只用于交通举报。它也适用于事件现场、设施巡检、交付与财产状况、现场作业，以及其他需要保留可复核拍摄记录的场景。

> Provika 提供用于检查文件完整性的技术信息，不替代司法鉴定、不判断法律证据效力，也不保证任何机构接受。拍摄、导出或分享时，请遵守当地法律并尊重隐私。

## Provika 的工作流程

1. 拍摄照片或视频，同时记录时间、经授权获取的位置与设备环境信息。
2. 保留原始媒体并生成规范化 claim。
3. 计算 SHA-256 摘要，并使用 ECDSA P-256 密钥为证据包签名。
4. 将签名 envelope 和独立核验所需的材料存入证据包。
5. 无需依赖签名时使用的 Keychain 条目，即可独立核验证据包完整性。
6. 将核验通过的阅读副本导出为安全 ZIP 与多语言 PDF 报告。

## 核心功能

| 领域 | 功能 |
| --- | --- |
| 照片与视频证据 | 带版本的 evidence claim、原始媒体保留、确定性的证据包定稿与有效性检查 |
| 完整性 | SHA-256 摘要、ECDSA P-256 签名、导出的公钥材料与离线核验 |
| 相机 | 实时预览、对焦和曝光、闪光灯、变焦控制、0.5 倍超广角、方向自适应输出与连续录制 |
| 预录 | 可配置的 0 / 5 / 15 / 30 秒预录缓冲 |
| 可视环境信息 | 可选地将日期、时间、GPS 与应用/设备信息渲染到视频帧中 |
| 导出 | 已核验的 ZIP 与五种语言的人类可读 PDF 报告 |
| 资料库 | 浏览、筛选、播放、查看核验状态、选择、分享和删除本地记录 |
| 快速拍摄 | 控制中心和锁定屏幕入口、App Intents 与 ExtensionKit 锁屏相机扩展 |
| 数据安全 | 旧录像迁移、原始文件不变策略、安全文件名、符号链接拒绝与原子 staging |
| 地区适配 | 同一个全球离线 Evidence Core 支持中国大陆的 claim 与界面策略，不建立中国专用证据核心 |

## 证据包

定稿后的 v2 证据包包含原始媒体与机器可读的核验记录，例如：

```text
EvidencePackage/
  <原始媒体>
  claim.json
  signature.json
  manifest.json       # 由相应流程生成时包含
Photo Evidence Report.pdf
```

PDF 是便于阅读的副本，本身并不是已签名的原始证据。完整性核验必须针对原始证据包文件进行。

## 支持语言

应用界面、权限说明、证据报告文本和 App Store 元数据支持：

- 简体中文
- 繁体中文
- 英语
- 韩语
- 日语

签名后的 Evidence Core 与语言无关。翻译后的显示文本不会替换已签名的原始观测值。

## 隐私与离线边界

- 在用户主动导出或分享之前，证据媒体和证据包数据保留在设备上。
- 拍摄、哈希、签名、证据包定稿、核验与 ZIP 导出均设计为无需服务连接即可完成。
- 只有获得系统授权后才会记录位置；原始设备坐标与显示用转换坐标保持可区分。
- 仅当本地存在 `GoogleService-Info.plist` 时才会初始化 Firebase。发布前应检查实际 Release 配置和隐私清单。
- 锁屏相机扩展运行在 Apple 受限的 ExtensionKit 环境中，并使用临时会话容器。

## 技术栈

| 项目 | 内容 |
| --- | --- |
| 语言 | Swift 5.9+ |
| 最低系统 | iOS 18.0 |
| 界面 | SwiftUI + UIKit 桥接 |
| 相机与媒体 | AVFoundation、Core Image |
| 存储 | SwiftData、FileManager |
| 位置 | CoreLocation |
| 完整性 | CryptoKit、Security framework，以及可用时的 Secure Enclave |
| 快速拍摄 | App Intents、WidgetKit、LockedCameraCapture、ExtensionKit |
| 项目生成 | Tuist 4.x |

## 仓库结构

```text
Sources/
  App/                     应用入口与导航
  Core/
    Evidence/V2/           规范化 claim、签名 payload、finalizer、verifier
    Export/                安全 ZIP 与多语言 PDF 导出
    Localization/          与语言无关的已确认文本策略
    LockedCapture/         锁屏拍摄导入与 handoff 策略
    Policy/                离线与地区 claim 边界
    Storage/               模型、迁移与证据数据安全
    Workflow/              拍摄、录像与导出状态机
  Features/
    Camera/                照片/视频拍摄管线与控制
    Gallery/               本地浏览与详细核验界面
    Settings/              用户设置、密钥与支持界面
  LockedCaptureExtension/  ExtensionKit 锁屏相机体验
  Widgets/                 快速拍摄控件
Resources/                 资源、隐私清单、策略与字符串目录
Tests/                     证据、工作流、本地化与发布测试
Documentation/             设计边界与特性说明
```

## 构建与测试

### 要求

- 带 iOS 18 SDK 或更高版本的 Xcode
- Tuist 4.x

### 生成项目

```bash
tuist install
tuist generate --no-open
```

### 构建

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

### 测试

```bash
xcodebuild \
  -workspace Provika.xcworkspace \
  -scheme Provika \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

必要时请将模拟器名称替换为本机已安装的设备。涉及硬件、相机行为、Secure Enclave、无线状态或锁定设备环境的结论，仍需要真实设备证据。

## 许可证

Apache License 2.0。详见 [LICENSE](LICENSE)。
