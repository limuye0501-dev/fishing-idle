# Audio credits

| File | Source | License |
|---|---|---|
| bgm_harbor, sfx_tap/upgrade/open/coin/error/catch | 见 CREDITS.md（v1 已有） | 见 CREDITS.md |
| amb_coastal, amb_atlantic, amb_tropical, amb_polar, amb_rain, amb_underwater | 本项目原创，程序合成：`tools/audio/gen.py`（numpy/scipy 噪声 + 滤波 + FM 合成） | CC0 1.0（本项目放弃权利） |
| sfx_rare, sfx_splash, sfx_purr, sfx_shutter | 同上，程序合成 | CC0 1.0 |

说明：本轮原计划从 freesound（CC0 筛选）/ Kenney（CC0）下载素材，但两站都拦截了服务器端的自动下载（Kenney 返回 199 字节拦截页；freesound 下载需要登录）。为了保证许可干净，改为全部程序合成，可用 `python3 tools/audio/gen.py App/Resources/Audio` 重新生成。
上线前建议换成真实录音（推荐 freesound 上 CC0 筛选的 “ocean waves”“seagulls”“tropical birds”“arctic wind”“rain on boat”），替换时把作者/链接/许可补进这张表。
