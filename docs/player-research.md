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

## X (Twitter) social listening — cozy/idle fishing (collected 2026-11-01)

Method: 11 X API searches (EN/JA/ZH) for "cozy fishing game", "idle fishing", Cast n Chill, DREDGE/Webfishing, 釣りゲーム 癒し, 放置ゲーム/旅かえる, 治愈/放置 钓鱼, #cozygames/#indiedev fishing, cozy mobile + ads/energy. The index returned mostly Oct 2026 posts. Engagement is as of collection time (L = likes, RT = reposts, BM = bookmarks, Imp = impressions).

### What excites players
- **Ambient "leave it on screen" play.** Desktop/taskbar idle fishing is a crowded trend: Tiny Harbor, Desktop Harbor, River Whisker, Taskbar Fishing & Aquarium, Fishing Tales. A player on Tiny Harbor: "A cozy fishing game I can leave idling on the side of my screen while I work?? … understood the assignment" — https://x.com/thesoftspine0/status/2106119318157021199. JP: "Cast n Chillを画面に置いてぼーっと眺めるの、良い" — https://x.com/3_8_ts/status/2114211414982426840
- **Big/legendary catch screenshots** are the most common thing players post. A JP player made a whole Cast n Chill series ("伝説級キングサーモンとの一騎打ち", "デカいの釣れました🎣🦈" 7L/2RT — https://x.com/Sfera03269315/status/2109296674111975781), plus "伝説級は出現する時間帯があるらしい" (legendaries only show up at certain times of day).
- **Scenery and atmosphere:** auroras, mountains reflected in the water, night lantern light. "水面に映る山々まで描きこまれたドット絵に驚愕…癒し体験" 14L — https://x.com/zeromoku_game/status/2108891862358786290. The "turquoise water, boats rocking at the pier… night mode where the only light is your lantern" clip spread widely (its repost by @HelloVyom got 1,113L/423BM/54K Imp — https://x.com/HelloVyom/status/2109532406663479712; note it was flagged as stolen footage from @ForkedPush).
- **Companions and pets:** "犬撫でれる" (you can pet the dog) for Cast n Chill; cats in Tiny Harbor, River Whisker and Plai.
- **Home and room upgrades:** "リフォームしました" posts; a Yesday catch "went straight on the wall of Pip's room".
- **Good for chatting while you play:** JP VTubers and streamers use Cast n Chill as a background game for talk streams ("雑談に向いているCast n Chill" 21L — https://x.com/mokamohu/status/2111733838825320642). ASMR fishing streams also do well ("ASMR釣りゲーム…水の音と鳥の鳴き声" 41L/20RT — https://x.com/rukuinumi_vt/status/2105964674663825721).
- **Cute UI and character art from devs:** Orca Girl: Idle Fishing Story got 121L/21BM for its farm station (https://x.com/hujinniandiaoyu/status/2112728479435542718) and 100L/11 replies for a "which UI vibe?" poll (https://x.com/hujinniandiaoyu/status/2114514781919154334).

### Complaints / friction
- **Mislabelled idle games (JP):** "50時間程度で終わる放置ゲームとか放置ゲームのタグつけるのやめてほしい" (stop tagging ~50-hour games as idle games) — https://x.com/lix_wh/status/2116394401169891354. Another JP post separates true idle games (long-horizon) from incrementals (fast inflation) — https://x.com/Uzel_FF14/status/2112556684501741906
- **"Cozy" games that turn into a second job / debt grind:** https://x.com/glitchvault247/status/2112465316110295427, https://x.com/HansMarvel3/status/2109162084613181779
- **Energy bars and ads are pitched against as a selling point:** "No energy bar, no waiting to play the next level" — https://x.com/ZofloqDev/status/2113312437663359364; "a cozy Android game with no ads and no purchases" — https://x.com/KhanjanKavani/status/2115337773095993448. The ZH 放置/钓鱼 results are dominated by crypto play-to-earn spam, which is a reputational risk.
- **AI "built a cozy fishing game solo" viral posts** draw accusations of stolen content — https://x.com/Cayden970207/status/2111885851890491698

### What goes viral
- Deal/aggregator accounts: Wario64's "Cast n Chill is $10.04 on Steam" got 94K Imp/50L — https://x.com/Wario64/status/2106068828820291753
- Media pieces: AUTOMATON JP's idle-game article got 255L/99RT/75K Imp — https://x.com/AUTOMATONJapan/status/2105889702016618997
- Short scenic clips with a "made by one person" hook (above, 1.1K L).
- Ordinary dev posts with #cozygames/#indiedev usually get under 10 likes. Cute character art plus a question/poll does 10× better (Orca Girl).

### Marketing patterns & amplifiers on X
- Hashtags: #cozygames #cozygaming #indiedev #gamedev #indiegame #pixelart #ScreenshotSaturday #WishlistWednesday; JP: #個人開発 #インディーゲーム #癒しゲーム #放置ゲーム #ドット絵
- Post formats: "Hi, I'm X, a solo dev from Y" intros; one-feature GIFs ("Pick a fish, pack it up, let the little whale deliver it"); "what should be the rarest fish? I'll add the best answer" engagement asks — https://x.com/AgantaBurinaaa/status/2116823337846423888
- Amplifiers: @cozygamingclub (monthly cozy release roundups — https://x.com/cozygamingclub/status/2106068499009536384), @Wario64 (deals), @AUTOMATONJapan and @gamebiznews (JP media; gamebiz covered Tiny Trawler, https://x.com/gamebiznews/status/2110953037326168135), @DualShockers lists, JP/EN VTubers and small streamers (Cast n Chill, DREDGE).
- Competitors to watch: Tiny Trawler (Mathias, a "handline → shrimp trawler" fleet with 55 species, very close to our pitch — https://x.com/MathiasIndie/status/2109058796555297212), Tiny Harbor, Idle Fishing Empire, FishX, Fishing Inc: Legendary Catch (mobile pre-registration).

### Implications for 船长别回来
1. Our pitch (free + one-time unlock, no ads, no stamina) matches what cozy players say they want. Put "no ads · no stamina · one-time unlock" in the first line of the App Store listing and our X bio.
2. Build shareable moments on purpose: a legendary-catch card (size, rarity, time/weather), aquarium and boat photo modes, and scenic night and aurora oceans.
3. Make idle sessions genuinely long-horizon, and avoid an inflation curve that finishes in 50 hours (the JP 放置 complaint).
4. Give the chibi captain a pet (a cat or dog) to pet. Companions show up again and again in shared posts.
5. On X: post weekly devlog GIFs of a single feature, run a "name the rarest fish" community ask, and post JP versions with JP tags. Pitch @cozygamingclub, JP media (AUTOMATON/gamebiz) and JP VTubers who stream chill games. Show real dev footage to avoid looking like the "AI-made" posts. In ZH copy, keep 治愈/放置 away from crypto wording.

## 7. 游戏社区横向调研（Reddit / Steam 社区 / TapTap / 巴哈姆特 / 5ch・APPLION / 媒体，2026-11-01）

**方法与边界**：通过 WebSearch 拿到的社区页面片段，加上 WebFetch 直接抓取的页面。所有引用都是原文摘录。本次只引用读到原文的帖子，没做全量统计，所以下面的“频次”是按“出现的独立来源数”粗排的。
- **可用**：Reddit（r/Castnchill、r/gaming、r/incremental_games，经搜索快照）、Steam 社区评测与讨论页（经搜索快照）、TapTap 评价页（5 款中国钓鱼/放置游戏）、巴哈姆特（直接抓取）、5ch アプリ板旅かえる スレ（2chb 镜像）、APPLION/GameWith 日区口碑、界面新闻（旅行青蛙分析）、Google Play 评论。
- **被挡或失败**：`store.steampowered.com/appreviews` 的 JSON 接口用 curl 和 WebFetch 都被 302 到首页；`old.reddit.com/*.json` 返回 302，`reddit.com/*.json` 的 WebFetch 超时。
- **本轮没取到有效内容**：Metacritic/OpenCritic、ResetEra、GameFAQs、TouchArcade/148Apps（搜索结果不相关）、4Gamer/ファミ通App、哔哩哔哩、贴吧/NGA/小黑盒/知乎/小红书（搜索只返回 TapTap 和媒体）、Ruliweb。

### 7.1 喜欢的点（按跨来源出现次数和情绪强度排序）
1. **“当壁纸/副屏/助眠”的陪伴感**：EN、CN、TW 都有，而且是情绪最强的一类。
   - “Perfect game for side monitor content. The idle mode is great!” — [r/Castnchill](https://www.reddit.com/r/Castnchill/comments/1ugegnc/your_thoughts_on_cast_n_chill/)
   - “It's meditative. It's a headspace game… I like to play while listening to my audiobooks” — [r/Castnchill](https://www.reddit.com/r/Castnchill/comments/1qa8h01/how_good_is_this_game_i_heard_its_very_simplistic/)
   - “把这款游戏当成电脑壁纸，而且还能互动…妥妥的上班办公摸鱼神器” — [TapTap 桌面挂机钓鱼](https://www.taptap.cn/app/866326/review)
   - “适合睡不着的时候催眠…听鸟声风声很快能睡着” — [TapTap 电子钓鱼](https://www.taptap.cn/app/381495/review)
2. **失败不惩罚**：“Some games the fish disappears if you fail to catch it. I'm glad this game stayed chill about it.” — [r/Castnchill](https://www.reddit.com/r/Castnchill/comments/1ugegnc/your_thoughts_on_cast_n_chill/)
3. **收集图鉴 + 鱼缸造景**：
   - “collecting all the fish like Pokémon” — 同上
   - “最吸引我的是鱼缸造景对自己造的景特别满意” — [TapTap 上钩了!](https://www.taptap.cn/app/829794/review)
   - 巴哈姆特读者：“當初看介紹時很期待它有魚缸系統” — [巴哈 Cast n Chill 心得](https://forum.gamer.com.tw/C.php?bsn=31587&snA=34999)
4. **陪伴宠物**：“Dog/Cat: Dogs and Kitties. Need I say more?” — [Steam 社区 Cast n Chill](https://steamcommunity.com/app/3483740/negativereviews/?browsefilter=toprated)
5. **场景里的生物细节和昼夜**：“熊在石頭上抓魚、母鴨帶小鴨游泳…清晨、上午、黃昏與夜晚四種變化” — [巴哈](https://forum.gamer.com.tw/C.php?bsn=31587&snA=34999)
6. **“少操作”本身就是卖点（日区）**：“ちょこっと操作してあとは放置してればいいってのがすごくいい これが忙しなくタップしてあれこれクエストやってってゲームだったら…すぐ飽きて” — [5ch 旅かえる 5泊目](http://m.2chb.net/r/applism/1517032229/)
7. **从“写真/留白”里想象故事**：“写真から想像するしかないストーリーや情報量の少なさが、｢放置されてる｣感が満載” — [APPLION 旅かえる](https://applion.jp/%E6%97%85%E3%81%8B%E3%81%88%E3%82%8B/android-jp.co.hit_point.tabikaeru/review/)
8. **离线/无网也能玩**：“最棒的是没网也能玩” — [TapTap 上钩了!](https://www.taptap.cn/app/829794/review)
9. **随机钓到非鱼物件和“钓到一首歌”这样的惊喜**：“直到我钓到第一首歌，我就知道这游戏我高低得深入品鉴一下了” — [TapTap Fishing](https://www.taptap.cn/app/865143/review)

### 7.2 雷点（按出现次数和杀伤力排序）
1. **内容见底太快、后期空洞**：几乎每个来源都提到，最常见。
   - “once you've caught every fish it kinda dies quick” — [r/Castnchill](https://www.reddit.com/r/Castnchill/comments/1qa8h01/how_good_is_this_game_i_heard_its_very_simplistic/)
   - “I've beaten the game with all fish caught, 7.8 hours. Not a great price value.” — [Steam Cast n Chill](https://steamcommunity.com/app/3483740/negativereviews/?browsefilter=toprated)
   - “after you have done anything in Dredge you have done everything” — [Steam DREDGE 讨论](https://steamcommunity.com/app/1562430/discussions/0/3806155895399959049/)
   - “最近は荷造りするだけ…何も増えない…飽きてしまう” — [APPLION 旅かえる](https://applion.jp/%E6%97%85%E3%81%8B%E3%81%88%E3%82%8B/iphone-1255032913/review/?start=60)
   - 界面新闻把旅行青蛙的快速退潮归因于“玩法单一、内容重复”（媒体综述，不是玩家原话）— [界面](https://www.jiemian.com/article/1956733.html)
2. **小游戏从头到尾不变，升级“感觉像装饰”**：
   - “The fishing and dredging you experience in the first hour are the [same]” — [Steam DREDGE](https://steamcommunity.com/app/1562430/negativereviews/?browsefilter=toprated)
   - “each of the upgrades feel almost cosmetic… The fish is always in control” — [Steam Cast n Chill](https://steamcommunity.com/app/3483740/negativereviews/?browsefilter=toprated)
   - “主要还是反复钓鱼刷鱼的变种我觉得可能有些枯燥” — [TapTap 上钩了!](https://www.taptap.cn/app/829794/review)
3. **收线没有反馈，鱼跑出屏幕**：“There's really no feedback as to whether you are doing well during a catch… fish will often swim off-screen” — [Steam Cast n Chill](https://steamcommunity.com/app/3483740/negativereviews/?browsefilter=toprated)。中区也有人点名 Stardew 式收线：“只有星露谷里的中鱼后小游戏是让我觉得很恶心，完全玩不下去的” — [TapTap 上钩了!](https://www.taptap.cn/app/829794/review)
4. **离线收益虚假或失效**：中区一星评价集中在这里。
   - “看广告提升离线收，实际上根本就没有离线收益” — [TapTap 增量放置摸鱼](https://www.taptap.cn/app/871107/review)
   - “五六个小时一分钱没涨” — [TapTap 电子钓鱼](https://www.taptap.cn/app/381495/review)
5. **挂机 AI 太笨、不按玩家设定走**：“'Idle Mode' is not: The idle mode will only use one bait, and rarely catches fish”（作者后来补记已修复）；“set my rod up to catch pike… the games switched my rod and bait and is back to trout fishing” — [Steam 讨论](https://steamcommunity.com/app/3483740/discussions/0/603036969475353968/)
6. **广告绑定所有动作**：“投放鱼苗看广告，升级船看广告” — [TapTap 增量放置摸鱼](https://www.taptap.cn/app/871107/review)；“希望有买断或者月卡免广告” — [TapTap 电子钓鱼](https://www.taptap.cn/app/381495/review)。日区旅かえる的低俗大音量广告曾导致卸载 — [APPLION](https://applion.jp/%E6%97%85%E3%81%8B%E3%81%88%E3%82%8B/iphone-1255032913/)
7. **引导缺失、系统要靠论坛才搞懂**：“我一路钓鱼钓到第四个地图才发现船可以升级，翻到论坛才知道宝箱有什么用” — [TapTap 上钩了!](https://www.taptap.cn/app/829794/review)
8. **数值失衡让钓鱼本身失去意义**：“水族馆的收益好高啊，远超钓鱼收益…鱼的价值更多体现在图鉴上，而不是金币收益了”；“深度升级收益极其小，一亿多砸下去，钓到的依旧是几金币的小鱼” — [TapTap 上钩了!](https://www.taptap.cn/app/829794/review)
9. **等待时间过长，让人不再打开**：“1、2時間くらいかな？と思ってたら数時間帰って来ない…アプリを開かない時間が長すぎてだんだん開くことすらなくなりそう” — [GameWith 旅かえる](https://gamewith.jp/gamedb/2577)
10. **相册/纪念品上限和管理差**：“写真の一覧表示、任意の並び替え、一括共有ができるようになれば最高” — [APPLION](https://applion.jp/%E6%97%85%E3%81%8B%E3%81%88%E3%82%8B/android-jp.co.hit_point.tabikaeru/review/)
11. **UI 遮挡、菜单难关**：“Wish I could tap the background when a menu is open to close that menu” — [r/incremental_games](https://www.reddit.com/r/incremental_games/comments/1kf9oxy/i_released_my_game_on_androidios_for_free_with/)；Google Play 上有评论抱怨“camera keeps resetting to an extreme zoom” — [Play](https://play.google.com/store/apps/details?hl=en_US&id=com.AOGames.IdleFishing)
12. **昼夜周期太短，被迫来回跑**：“the day cycle is like 10 minutes long you are forced to constantly run back to port” — [Steam DREDGE 讨论](https://steamcommunity.com/app/1562430/discussions/0/6620894968762863550/)

### 7.3 区域差异
- **EN（Reddit/Steam）**：会按“每美元能玩几小时”算账，所以容量和深度是最大争议点。好评集中在“副屏/有声书伴侣”；差评集中在“像壁纸不像游戏”“upgrades cosmetic”。r/incremental_games 关心长线节奏（Patient Angler 的开发者主动征求“8–10 个月”节奏的反馈）以及有没有“Remove all ads”。
- **JP（5ch/APPLION/GameWith）**：最认可“放置されゲー”式的少操作、留白和角色可爱。抱怨集中在内容不再更新、相册上限、机型迁移，以及等待过长导致不再打开。“攻略/效率厨不适合”被当作中性描述，不算缺点。
- **CN（TapTap）**：用“摸鱼神器/助眠/白噪音”来形容。对离线收益是否真的有效、广告绑定、数值崩坏极其敏感，会写长文算数值；也会主动要求“加充值系统，我支持一下”和买断。对引导缺失容忍度低。
- **TW（巴哈）**：偏向写心得长文，看重美术和场景细节，“買藝術品送遊戲”；对鱼缸有期待。

### 7.4 对照现有设计的审计
| 玩家关注点 | 我们现状 | 判定 |
|---|---|---|
| 副屏/挂着看、助眠 | iOS 无副屏；有离线明信片 | **部分**：缺“观赏/常亮模式” |
| 失败不丢鱼 | §5 P0-3 已建议 | 已规划 |
| 图鉴 + 水族箱 | 有 | **有**；缺造景自由度（P1-9 已提） |
| 宠物 | 无 | **缺失**（X 节已提，社区再次印证） |
| 离线收益真实可信 | 有 12h 上限 | **风险**：需要可解释的明细账 |
| 挂机按玩家选择的目标/渔具 | 未定义 | **缺失** |
| 收线反馈清晰 | sonar-cast-reel 小游戏 | **风险**：张力/进度反馈要明确 |
| 升级能改变手感（不只是数值） | 燃油/鱼舱/新鲜度升级 | **部分**：改变的是航程，钓鱼手感没变 |
| 内容长度对得起价格 | 可解锁海域 | **风险**：EN 玩家会按小时算账 |
| 各收入来源平衡 | 鱼缸是否产金币未定 | **风险**：不能让水族箱收益压过钓鱼 |
| 引导/系统可发现 | P1-12 已提 | 已规划 |
| 无广告、买断 | 有 | **有**（核心优势） |
| 等待时长适中 | 燃油/补给冷却 | **部分**：需要验证最长冷却 |
| 明信片相册管理 | 有明信片 | **部分**：上限、排序、批量导出未定 |

### 7.5 新增建议（不与 §5、X 节重复）
1. **P0 离线收益“账单化”**：回港报告逐条列出时长、渔获、放生、燃油耗用，并保证杀进程或重启后也能正确结算（写进 QA 用例）。CN 一星主要来自“离线没收益”。
2. **P0 挂机目标设置**：玩家可以锁定海域、目标鱼种和渔具，挂机 AI 不能擅自替换；锁定的目标在明信片里体现。
3. **P0 收线反馈**：张力条、鱼的体力条、触觉反馈（Haptics），三者都要有；鱼不能游出可视范围。
4. **P1 升级要改变“玩法”**：每片海或每档声呐解锁一种新钓法或新判定（拖网、夜钓灯、深水慢收），避免“upgrades feel cosmetic”。
5. **P1 经济护栏**：水族箱只产少量“观赏点/装饰币”，不能成为主收入；高级海域的期望收益要明显随投入增长（参考《上钩了!》“一亿砸下去仍是小鱼”）。
6. **P1 “观赏模式”**：一键隐藏 UI、自动机位慢摇、可以开着当助眠（配合低功耗帧率和定时关闭），同时满足副屏、助眠和录屏传播。
7. **P1 内容容量透明**：商店页写清海域数、鱼种数和预估通关时长；终局提供纪录鱼、季节鱼和“自定挑战”（Reddit 玩家自发在做）。
8. **P1 明信片相册**：上限足够高，支持排序/筛选和批量保存到相册，重复的自动合并。
9. **P2 等待节奏**：任何“回来查看”的周期默认不超过约 2–4 小时就有小回报（旅かえる 数小时不回被指让人不再打开）。
10. **P2 钓到非鱼物件**：漂流瓶小故事、唱片/BGM 曲目，作为可收集的惊喜（TapTap 两款都被点名）。
11. **P2 菜单 QoL**：点背景关闭菜单，镜头不重置，事件弹层不遮挡主操作。

**局限**：样本来自搜索引擎快照，偏向高赞和长评；中文社区只有 TapTap 有直接内容。Steam 评测接口和 Reddit JSON 都没能直接抓取，所以没有统计星级分布。
