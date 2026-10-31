# 船长别回来（FishingIdle）— iOS 放置钓鱼游戏原型

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

## 第六轮：鱼种 · 海图 · 渔具 · 季节 · 小百科 · 生态鱼缸

### 免费版 / 完整版
- 免费：前两片海域、🎣鱼竿 + 🧺笼捕、真实四季轮换、基础图鉴（两片免费海域的图鉴一年内可全部集齐）、鱼缸（初始 4 格）。
- 一次性买断「解锁完整版」：其余 6 片海域、延绳钓/拖网/深海网、鱼缸扩容。宝石永不出售。
- 代码中唯一开关 `GameState.isFullVersion`（`grantFullVersion()`），下一轮接入 StoreKit 2。

### 季节（现实一天 = 游戏一季）
- 以 **UTC 零点** 为界轮换：春 → 夏 → 秋 → 冬 → 春……（`floor(Unix秒 / 86400) % 4`，Unix 第 0 天为春）。
- 离线结算按每趟的实际时间计算季节，所以挂机跨季也准确。
- 季节效果：🌸春 宝箱概率 ×1.5；☀️夏 鱼群概率 ×1.5；🍁秋 售价 +10%；❄️冬 风暴概率 ×2。
- 很多鱼只在特定季节出没（见图鉴卡片与海图）。

### 海域（8 个）与鱼种（32 种真实物种）
宁静海湾 → 红树林湿地 → 珊瑚礁 → 海藻森林 → 深蓝远洋 → 北冰浮岛 → 深渊海沟 → 传说之海，距离 6–60 海里。
「海图」页显示距离、单程航时、可捕鱼种（渔具/季节/稀有度）。

### 渔具（每条船独立购买、升级、装备）
🎣鱼竿（初始）/ 🧺笼捕 150 / 🪝延绳钓 600 / 🕸️拖网 2000 / 🌊深海网 **25 宝石**。
渔具决定能捕哪些鱼（当前海域+季节+渔具没有可捕鱼时空手而归）和渔获数量（倍率 1.0–1.5，每级 +15%，最高 5 级）。

### 平衡
- 升级经验 `60 × 等级^1.6`（原 40+30×(等级-1)）。
- 宝箱只出 1 颗宝石（幸运船长 1–2 颗），概率 3%。
- 宝石用途：买深海网、⚡️加速（2 宝石让一趟立刻完成结算）。

### 小百科
图鉴卡片点开即为小百科：学名、别名、体型、分布、食性、习性、现实渔季、冷知识、IUCN 保护等级，首次捕获后解锁全部内容（之前照片打码）。
照片全部来自 Wikimedia Commons（公有领域 / CC0 / CC BY / CC BY-SA），缩放后打包在 `App/Resources/FishPhotos/`，作者与许可见 [CREDITS.md](CREDITS.md)，并在条目页显示署名。

### 生态鱼缸
- 「鱼缸」页的“最近渔获”可把每趟最好的那条鱼**留下**（扣回它的售价）放进鱼缸。
- 初始容量 4，可花金币扩容（每次 +2）；可放生。
- 鱼会在缸里游动，点鱼打开小百科。
- 鱼缸纯属个人收藏，不产生任何收入。
