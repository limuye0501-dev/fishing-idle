# 《船长别回来》玩家研究报告（2026-11-01）

## 0. 方法与数据
- **App Store 评论**：从 `apps.apple.com/{us,jp}/app/id…?see-all=reviews` 页面抓取 17 款同类游戏（美区 + 日区）共 **283 条玩家评论**（另有若干开发者回复已剔除）。原始数据：`docs/player-research-reviews.json`（含游戏、区服、星级、全文、来源链接）。
  - 游戏：DREDGE、Stardew Valley、Ridiculous Fishing (旧版/EX)、Neko Atsume 1/2、Tsuki's Odyssey、旅かえる、Fishing and Life、Hooked Inc、Fish Away Idle、Fishing Paradiso、Pocket Camp Complete、AbyssRium、Idle Shark World、Creatures of the Deep、Fishing Master。
  - 关键词粗统计（283 条中提及次数，一条可多类）：视觉/可爱 130、存档/bug 61、广告 60、付费/价格 56、放松/治愈 46、体力/等待 45、收集/图鉴/水族箱 33、音乐/音效 28、重复/刷 27、离线/放置 19、后期没内容 16。
- **YouTube**：yt-dlp 搜索 + 自动字幕，拿到 7 支评测视频的转录（Cast n Chill ×2、DREDGE IGN、Webfishing ×2、Idle Fishing ×2）。
- **未能获取**：Steam 评论 API 从本机被重定向（无数据）；Reddit 返回 403；Apple RSS 评论接口返回空；TapTap 未抓。所以 Steam/Reddit 独占的 Cast n Chill / Webfishing / A Short Hike / Cat Goes Fishing 只依赖视频。
- 所有引用均为原文截取，链接指向该游戏的 App Store 评论页（无法给单条评论永久链接）。

## 1. 玩家喜欢什么（Delight）
1. **“放着也舒服”的氛围 + 主动时刻**：同时兼顾主动钓鱼和挂机是被反复点名的卖点。
   - Cast n Chill 视频：“What makes it special is how it balances being both an active fishing experience and a chill idol game you can leave running while doing other stuff” — [The Singleplayer Squad](https://youtu.be/CKX4TgF_8lc)
   - SwitchUp：“The loop is catch fish, sell fish, earn a bunch of coins, and upgrade your gear … it just has that gradual, steady progression” — [youtu.be/2dS3LXx2vyM](https://youtu.be/2dS3LXx2vyM)
2. **视觉层次与水面/水下切换**：SwitchUp：“You can sit and look at the different layers of parallax, the way the water shifts as you go below the surface, and that's also where the soundscape changes to reflect the fact that you're submerged, but you can still see your boat shimmering just above the surface” — [视频](https://youtu.be/2dS3LXx2vyM)；IGN DREDGE：“I'm immediately treated to a gorgeous Sunrise stretching Over the Horizon” — [youtu.be/Qae88uZDvtg](https://youtu.be/Qae88uZDvtg)
3. **环境声/ASMR**：Creatures of the Deep：“I love the music and sound effects, which I found very ASMR and therefore very soothing. The graphics and color schemes also play a role in making the game feel very Zen” — [App Store](https://apps.apple.com/us/app/id1556204048?see-all=reviews)；日区：“臨場感のある環境音、まったりとした釣り体験は本当に心地よく” — [JP](https://apps.apple.com/jp/app/id1556204048?see-all=reviews)；Hooked Inc：“The music and the noises when you catch the fish are great” — [US](https://apps.apple.com/us/app/id1436213906?see-all=reviews)
4. **“不在时的惊喜”回报（旅かえる/Neko Atsume）**：“敢えて目つきを悪く、一言も喋らないキャラにしていることによって土産や写真を送ってきてくれた時の喜びが倍増します” — [旅かえる JP](https://apps.apple.com/jp/app/id1255032913?see-all=reviews)；“i love how i can go away for an hour or two while leaving food out and come back to see a bunch of kitties in my yard!” — [Neko Atsume US](https://apps.apple.com/us/app/id923917775?see-all=reviews)；“The fact that you have to leave the app for the cats to come is so smart, it forces you to spend less time on your phone” — 同上。
5. **收集与“稀有变种”**：DREDGE 日区：“奇形の魚が釣れることもありそこも全て収集したくなるほどコレクター心をくすぐってくれた” — [JP](https://apps.apple.com/jp/app/id6526463862?see-all=reviews)；Fishing Paradiso：“図鑑のお魚の説明が好きでコンプ目指してハマってしまいました” — [JP](https://apps.apple.com/jp/app/id1441716978?see-all=reviews)；Tsuki 玩家主动要水族箱：“can we PLEASE GET A FISHTANK !!” — [US](https://apps.apple.com/us/app/id1564146071?see-all=reviews)
6. **有意义的升级 + 回港的贪心张力**：DREDGE：“the upgrades are very well made and feel actually meaningfull once you buy them” — [US](https://apps.apple.com/us/app/id6526463862?see-all=reviews)；“何時に、どこまでで港に引き返すかなど、欲と自制心がせめぎ合うゲーム” — [JP](https://apps.apple.com/jp/app/id6526463862?see-all=reviews)；“釣った魚や拾った物資を倉庫内に整理する時間が好きです。パズルみたいに詰める” — 同上（→我们的鱼舱/新鲜度方向被验证）。
7. **天气/昼夜带来的情绪**：Stardew 日区：“雨もいい。外には動物や人の姿もまばらで、世界は灰色に染まり、雨音だけが優しく包み込む” — [JP](https://apps.apple.com/jp/app/id1406710800?see-all=reviews)；Neko Atsume 玩家要求：“朝昼晩の時間経過とか日によって天気が違うとかがあるとより楽しい” — [JP](https://apps.apple.com/jp/app/id923917775?see-all=reviews)；Creatures of the Deep：“The day/night cycle and having to explore and search for the various fish is super fun” — [US](https://apps.apple.com/us/app/id1556204048?see-all=reviews)
8. **宽容的小游戏**：IGN 评 DREDGE：“it's forgiving in that no matter how many times you mess up the prompts you won't lose the fish only in-game hours” — [视频](https://youtu.be/Qae88uZDvtg)
9. **买断 = 安心**：Stardew 日区：“ガチャや協力プレイ強要やギルド、スタミナなどの煩わしい要素がなく、やりたい時にやりたいだけどっぷり遊べる” — [JP](https://apps.apple.com/jp/app/id1406710800?see-all=reviews)；Pocket Camp Complete：“買い切りなので追加課金の心配がない” — [JP](https://apps.apple.com/jp/app/id6547834967?see-all=reviews)

## 2. 主要抱怨（Top complaints）
1. **强制广告/广告变多**（最致命，直接卸载）：“i have watched more ads in the ONE HOUR that ive had this game than i have MY WHOLE LIFE” — [Fish Away](https://apps.apple.com/us/app/id6787988987?see-all=reviews)；“Three times today I've missed a big fish right…”（插屏打断钓大鱼）— [Hooked Inc](https://apps.apple.com/us/app/id1436213906?see-all=reviews)；“今日から急に「荷物開けるときに5秒の広告+解除したけりゃ金払え」になったので終了です” — [Hooked JP](https://apps.apple.com/jp/app/id1436213906?see-all=reviews)；旅かえる因不当广告：“限界なのでアンインストールさせて頂きます” — [JP](https://apps.apple.com/jp/app/id1255032913?see-all=reviews)
2. **体力/能量限制**：“なんと5分に1ずつしか回復しません … 全快するのに13時間以上かかります” — [Fishing Master JP](https://apps.apple.com/jp/app/id6471659176?see-all=reviews)；“エナジーの量が少なすぎて釣りがしたくても待つしかない” — 同上。
3. **进度墙/经济太紧**：“you eventually hit a point where you can’t progress further until you watch a bunch of ads or buy” — [Fishing and Life US](https://apps.apple.com/us/app/id1457176367?see-all=reviews)；“初めの船で行ける範囲が狭すぎて楽しくない … その長い時間をこの狭い範囲で過ごせとは鬼畜すぎる” — [JP](https://apps.apple.com/jp/app/id1457176367?see-all=reviews)
4. **“治愈”被杂鱼/噪音破坏**：“癒しをもらえるゲームかと思ったら邪魔な小魚にイラついてストレスが溜まるゲームです” ；“釣りって狙って狙って釣れるのが楽しいのに、竿落とすだけでこのゲームは釣れてしまう” — [Fishing and Life JP](https://apps.apple.com/jp/app/id1457176367?see-all=reviews)
5. **后期没东西可买/内容见底**：“後半にお金と強化アイテムの使い道が無くなる” — [DREDGE JP](https://apps.apple.com/jp/app/id6526463862?see-all=reviews)；“after gaining a decent aquarium, that I had all the best gear and boats” — [Fishing and Life US](https://apps.apple.com/us/app/id1457176367?see-all=reviews)；“にぼしと金にぼしを集めても買いたいものがなかった” — [Neko Atsume 2 JP](https://apps.apple.com/jp/app/id6499131935?see-all=reviews)
6. **丢档/无法换机**：“データ移行を可能にして頂きたいのです … 前回データのかえるちゃん(名を権助)とお別れをしなければならなくなって” — [旅かえる JP](https://apps.apple.com/jp/app/id1255032913?see-all=reviews)；“Why has my archive been lost for several months? All my efforts have been lost.” — [Tsuki JP](https://apps.apple.com/jp/app/id1564146071?see-all=reviews)；“I just lost all my progression today..” — [Ridiculous Fishing EX JP](https://apps.apple.com/jp/app/id1610164691?see-all=reviews)
7. **发热/耗电/掉帧**：“My iPhone 13 gets super hot” — [RF EX](https://apps.apple.com/jp/app/id1610164691?see-all=reviews)；“バッテリー消費えぐいので一日ちょこちょこ” — [Creatures of the Deep JP](https://apps.apple.com/jp/app/id1556204048?see-all=reviews)；“釣りの最中に画面が重くなり、画面が重い間にラインを切られる” — [Fishing Master JP](https://apps.apple.com/jp/app/id6471659176?see-all=reviews)
8. **镜头晃动晕屏、触控笨拙**：“船が進むのに合わせてカメラワークがグラグラ動くため、画面酔いしやすいです” — [DREDGE JP](https://apps.apple.com/jp/app/id6526463862?see-all=reviews)
9. **教程不足/系统说明不清**：“there is no place you can ask about the system, or restart the tutorial and check” — [Fishing and Life JP](https://apps.apple.com/jp/app/id1457176367?see-all=reviews)；“Baits are way too expensive and are unexplained” — [Creatures of the Deep](https://apps.apple.com/us/app/id1556204048?see-all=reviews)
10. **机翻本地化**（日区重灾）：“動物たちとの会話はGoogle翻訳で日本語に訳した感じで会話の内容がよくわからない” — [Tsuki JP](https://apps.apple.com/jp/app/id1564146071?see-all=reviews)
11. **离线不可玩**：“I wish I could play offline because if I am traveling and lose signal…” — [Creatures of the Deep](https://apps.apple.com/us/app/id1556204048?see-all=reviews)；“前作がオフラインで遊べるのも魅力だった” — [Neko Atsume 2 JP](https://apps.apple.com/jp/app/id6499131935?see-all=reviews)
12. **只能狂点**：“I just don’t enjoying having to tap so much. Not sure why you can’t hold the button down to level up faster” — [Idle Shark World](https://apps.apple.com/us/app/id1494439866?see-all=reviews)

## 3. 视频里“治愈”的视听模式
- 低饱和暖色 + 日出/晚霞的大天空（IGN 对 DREDGE 首个记忆点就是日出）。
- 多层视差 + 水面下镜头/音景切换（Cast n Chill 被列入“最美 Switch 游戏”的原因）。
- 环境声优先：海浪、海鸥（Idle Fishing 视频主播反复 “damn I love these seagull”— [youtu.be/FTLXfm8kuVM](https://youtu.be/FTLXfm8kuVM)）、“sound effects really reminiscent of being out on the ocean” — [youtu.be/5XSM4yu5Zvg](https://youtu.be/5XSM4yu5Zvg)。
- 雨天/夜晚不是惩罚而是情绪（Stardew 日区评论）。
- 收鱼瞬间的“叮”与小动画（Hooked Inc 评论点名 catch noises）。
- 角色不说话、表情克制，反而放大情感（旅かえる）。

## 4. 留存技巧：被喜欢 vs 被讨厌
| 喜欢 | 讨厌 |
|---|---|
| 离开再回来有惊喜（Neko/旅かえる 写真、纪念品） | 体力条、5 分钟回 1 点 |
| 渐进解锁新区域（Cast n Chill license） | 新区域只是换皮“to essentially do the same thing”（SwitchUp 提醒） |
| 每日小报纸/登录小礼（Neko 2 “ログボ代わりのしんぶん”） | 每日任务强迫、事件随机奖池（AbyssRium “ランダムって一番タチが悪い”） |
| 可选激励广告且有冷却（Hooked 玩家点名要 ad cooldown） | 插屏打断关键时刻、付费去广告后仍有 banner |
| 一次性买断、试用到一定进度再买（DREDGE 体験版、Neko 2 一个月试用被称“良心”） | 免费→收费后进度被锁（Pocket Camp C 差评） |
| 后期持续有目标（纪录鱼、稀有变种、装饰） | 钱没处花、升级早早满级 |

## 5. 对《船长别回来》的优先级改动清单（映射 design-v2）
**P0 —— 上线前必须做**
1. **离线收益“回来报告”做成惊喜时刻**（§3 挂机）：回到游戏弹出“航海日志明信片”——船长在某天气下的插画/截图 + 本次渔获 + 稀有事件（漂流瓶、鲸群）。对标旅かえる写真、Neko 纪念品。12 小时上限保留，但不惩罚。
2. **绝不加体力/能量**，主动小游戏无次数限制（§3）。燃油只影响航行，不阻止钓鱼；燃油耗尽 30% 挂机效率改为 **50%** 并提示“补给船可到”，避免“卡死感”。
3. **小游戏宽容化**（§3 收线 9 秒）：失败不丢鱼，只降低品质/体型；新增“辅助模式”（张力带加宽）。参考 IGN 对 DREDGE 的称赞。
4. **iCloud 存档同步 + 手动导出**（§8）：丢档/换机是日区一星主因。
5. **性能/发热预算**：程序化 3D 默认 30fps 省电模式、可选 60/120；后台/静置画面时降帧。不要相机随浪剧烈晃动，提供“减少镜头晃动”开关（DREDGE 日区晕屏反馈）。
6. **买断定价与试玩边界清晰**（§5）：首屏即说明“前两片海免费、一次性解锁、无广告无体力”，商店页文案也写清。把这句话作为 App Store 首图卖点——评论显示这类玩家主动奖励买断。

**P1 —— 首版内尽量做**
7. **音景**（§7 美术外新增“音频方向”）：每片海独立环境声（大西洋海鸥/浪、太平洋热带鸟、极地冰裂与风）、雨声、夜间虫鸣/船舱灯嗡声；收鱼“叮”+稀有鱼专属音；水下镜头切换低通滤波。
8. **天气是情绪而非惩罚**（§4 天气）：海雾、小雨给少量“氛围加成”（例如稀有鱼概率小幅提升），而非只降速度；晚霞时段（×1.2 已有）配合粉金色光——视频和评论都把晚霞/雨当作治愈核心。
9. **后期目标**（§4 纪录鱼、部件）：每种鱼加“稀有色变/奇形”变种（DREDGE 日区最爱）、纪录体型排行、水族箱装饰与布置；保证金币后期有用途（船体涂装、船长服装、水族箱造景），避免“钱没处花”。
10. **钓鱼要有“瞄准感”，减少杂鱼**（§3/§4）：声呐阶段可选择目标鱼群（显示可能的鱼种剪影），让玩家“狙”特定图鉴空位；满舱自动放生最便宜鱼——保留，但显示“放生了 X”轻提示。
11. **长按连续升级 / 批量出售**（§6 UI）：避免狂点。
12. **教程可重看 + 图鉴内说明**（§6）：图鉴每条写栖息海域、应季、时段提示（Tsuki/Creatures 玩家抱怨说明不足）。
13. **日/繁中人工本地化**（上架 JP/HK/TW）：机翻是日区稳定差评点；鱼名使用当地常用名。

**P2 —— 上线后迭代**
14. 航海日志“明信片”可保存到相册/分享（Neko 2 玩家要“動画保存”）。
15. 季节性小事件（不限时奖池，不做随机抽）；补给船 3 宝石跳冷却保持纯游戏内货币（§4/§5 已符合）。
16. 每日“港口小报”（类 Neko 2 新闻）：显示今天应季鱼、天气预报，而非强制每日任务。
17. 船长角色互动：点他会有小动作（钓鱼时打盹、雨天披雨衣），船名在日志里被提到——强化“我的船”情感。

**先做顺序建议**：1 → 2 → 3 → 4 → 5 → 6（P0 全部，主要是机制/系统）→ 7、8（视听，成本低收益大）→ 9、10。

## 6. 局限
- Steam / Reddit / TapTap 未取得数据；Cast n Chill、Webfishing、A Short Hike、Cat Goes Fishing 只有视频侧证据。
- App Store 网页每区每款只露出约 10 条“精选”评论，存在偏向长评与高赞的选择偏差；关键词统计仅为粗略计数，不代表评分分布。
- 视频转录为 YouTube 自动字幕，个别词有识别错误（如 "idol" = idle）。
