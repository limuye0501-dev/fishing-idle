import XCTest
@testable import FishingCore

/// 关闭事件与等级加成的“纯净”配置
func quietConfig() -> EconomyConfig {
    var c = EconomyConfig()
    c.fishSchoolChance = 0; c.stormChance = 0; c.treasureChance = 0
    c.levelValueBonus = 0; c.levelSpeedBonus = 0
    return c
}

/// 指定季节中间时刻（一季 = 86400 秒，第 0 天为春）
func date(in season: Season, cycle: Int = 100) -> Date {
    Date(timeIntervalSince1970: Double(cycle * 4 + season.rawValue) * 86_400 + 3_600)
}

func plainState(_ cfg: EconomyConfig, at t: Date) -> GameState {
    var s = GameState(config: cfg, now: t)
    s.captains[0].trait = .veteran   // 近海无效果
    return s
}
