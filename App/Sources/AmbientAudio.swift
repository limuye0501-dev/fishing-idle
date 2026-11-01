import AVFoundation
import FishingCore

/// v9：每片海独立环境声 + 雨声层 + 水下“闷声”。
/// 用 AVAudioPlayer 循环播放：它不会抛 Obj-C 异常。AVAudioEngine 的 play() 在模拟器/音频路由变化时会直接崩溃。
/// 水下效果：环境声压低并换成 amb_underwater 低频床。
@MainActor
final class AmbientAudio {
    static let shared = AmbientAudio()
    private var bed: AVAudioPlayer?, rain: AVAudioPlayer?
    private var bedName = "", rainOn = false
    private(set) var underwater = false
    private var lastVol: Float = 0.6

    static func bedFor(ocean: Ocean) -> String {
        switch ocean.id {
        case "coastal": return "amb_coastal"
        case "atlantic": return "amb_atlantic"
        case "pacific", "indian": return "amb_tropical"
        default: return ocean.polar ? "amb_polar" : "amb_coastal"
        }
    }

    private func player(_ name: String) -> AVAudioPlayer? {
        guard let u = Bundle.main.url(forResource: name, withExtension: "m4a") ?? Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio"),
              let p = try? AVAudioPlayer(contentsOf: u) else { return nil }
        p.numberOfLoops = -1; p.prepareToPlay(); return p
    }

    /// 每次状态刷新时调用；只有变化时才切换
    func update(state: VoyageState, now: Date) {
        let vol = Float(AppSettings.shared.ambienceVolume)
        guard vol > 0.001, AudioManager.shared.sfxOn else { stop(); return }
        lastVol = vol
        let name = underwater ? "amb_underwater" : (state.phase == .docked ? "amb_coastal" : Self.bedFor(ocean: state.ocean))
        if name != bedName { bedName = name; bed?.stop(); bed = player(name); bed?.play() }
        let w = state.weather(at: now)
        let wantRain = (w == .rain || w == .storm) && !underwater
        if wantRain != rainOn {
            rainOn = wantRain
            if wantRain { rain = player("amb_rain"); rain?.play() } else { rain?.stop(); rain = nil }
        }
        bed?.volume = vol * (underwater ? 0.8 : 0.6)
        rain?.volume = vol * (w == .storm ? 0.7 : 0.45)
    }

    /// 小游戏收线：切到水下低频床、压掉雨声
    func setUnderwater(_ on: Bool) {
        guard on != underwater else { return }
        underwater = on
        bedName = ""          // 下次 update 时切换
        if on { rain?.stop(); rain = nil; rainOn = false; bed?.stop(); bed = player("amb_underwater"); bed?.volume = lastVol * 0.8; bed?.play(); bedName = "amb_underwater" }
    }

    func stop() {
        bed?.stop(); rain?.stop(); bed = nil; rain = nil; bedName = ""; rainOn = false
    }
}
