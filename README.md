# 悠闲钓鱼港（FishingIdle）— iOS 放置钓鱼游戏原型

SwiftUI + SceneKit，iOS 17+，Swift 5.9+。Q 版轻 3D 风格、固定俯视斜角镜头。

## 玩法（已实现）
- 船长自动循环：**出海 → 捕鱼 → 返航 → 卸货**，卸货时按海域鱼种权重随机抽鱼并自动卖成金币。
- 升级每条船的 **航速**（缩短往返时间）和 **鱼舱容量**（每趟多捕鱼）。
- **雇佣更多船长**（最多 6 位，价格递增）。
- 解锁更远海域：宁静海湾 → 珊瑚礁(500) → 深蓝远洋(4000) → 传说之海(30000)，越远航程越长、鱼越值钱；可给每位船长指定海域。
- **离线收益**：重新打开时按离开时长结算（上限 8 小时），弹窗提示。
- 自动存档（JSON 文件，位于 Application Support，每 5 秒及切后台时保存）。

## 目录结构
```
project.yml                     XcodeGen 配置（CI 中生成 .xcodeproj）
Packages/FishingCore/           纯游戏逻辑 Swift Package（可在 Linux/mac 上 swift test）
  Sources/FishingCore/
    Models.swift                FishType / SeaArea / Boat / Captain / TripPhase
    EconomyConfig.swift         所有数值配置（价格、成长曲线、海域、鱼种）
    GameState.swift             状态推进、离线结算、升级/雇佣/解锁
    Persistence.swift           Codable JSON 存档
  Tests/FishingCoreTests/       单元测试
App/Sources/
  FishingIdleApp.swift          入口，监听前后台切换
  GameViewModel.swift           计时器（0.1s）、存档、离线收益弹窗
  ContentView.swift             HUD、船长/海域管理面板（中文 UI）
  Scene/OceanScene.swift        程序化 3D 场景：波浪海面、小岛、码头、玩具小船
  Scene/SeaSceneView.swift      SceneKit 嵌入 SwiftUI
App/Resources/Assets.xcassets   图标/强调色占位
.github/workflows/ios.yml       CI：逻辑测试 + 模拟器构建；TestFlight 上传（注释状态）
```

## 本地/CI 构建
```bash
brew install xcodegen
xcodegen generate
open FishingIdle.xcodeproj
# 逻辑测试
cd Packages/FishingCore && swift test
```

## 下一步
1. 推送到 GitHub，确认 Actions 中 `build-simulator` 通过。
2. 注册 Apple Developer（年费 $99），在 App Store Connect 创建 App，把 `project.yml` 中的 Bundle ID / Team ID 改成你的。
3. 按 `ios.yml` 注释准备证书、描述文件、App Store Connect API Key 并存入仓库 Secrets，取消注释 `testflight` 任务。
4. 在 iPhone 上安装 TestFlight 接收测试版。
5. 游戏方向：App 图标、音效、鱼类图鉴、船长特性、更细腻的船模型/水面着色、点击小船加速等。
