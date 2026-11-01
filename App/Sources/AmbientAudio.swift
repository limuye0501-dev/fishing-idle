import AVFoundation
import FishingCore

/// v9：每片海独立环境声 + 雨声层 + 水下低通“闷声”（AVAudioEngine）
@MainActor
final class AmbientAudio {
    static let shared = AmbientAudio()
    private let engine = AVAudioEngine()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private let bed = AVAudioPlayerNode(), rain = AVAudioPlayerNode()
    private var bedName = "", rainOn = false, started = false
    private(set) var underwater = false

    private init() {
        engine.attach(bed); engine.attach(rain); engine.attach(eq)
        let b = eq.bands[0]; b.filterType = .lowPass; b.frequency = 20_000; b.bandwidth = 1; b.bypass = false
        engine.connect(bed, to: eq, format: nil)
        engine.connect(rain, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
    }

    static func bedFor(ocean: Ocean) -> String {
        switch ocean.id {
        case "coastal": return "amb_coastal"
        case "atlantic": return "amb_atlantic"
        case "pacific", "indian": return "amb_tropical"
        default: return ocean.polar ? "amb_polar" : "amb_coastal"
        }
    }

    private func buffer(_ name: String) -> AVAudioPCMBuffer? {
        guard let u = Bundle.main.url(forResource: name, withExtension: "m4a") ?? Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio"),
              let f = try? AVAudioFile(forReading: u),
              let buf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)) else { return nil }
        try? f.read(into: buf); return buf
    }

    private func loop(_ node: AVAudioPlayerNode, _ name: String) {
        guard let b = buffer(name) else { return }
        node.stop()
        engine.disconnectNodeOutput(node)
        engine.connect(node, to: eq, format: b.format)
        node.scheduleBuffer(b, at: nil, options: .loops)
        node.play()
    }

    /// 每次状态刷新时调用；只有变化时才切换
    func update(state: VoyageState, now: Date) {
        let vol = Float(AppSettings.shared.ambienceVolume)
        guard vol > 0.001, AudioManager.shared.sfxOn else { stop(); return }
        if !started {
            do { try engine.start(); started = true } catch { return }
        }
        let name = state.phase == .docked ? "amb_coastal" : Self.bedFor(ocean: state.ocean)
        if name != bedName { bedName = name; loop(bed, name) }
        let w = state.weather(at: now)
        let wantRain = w == .rain || w == .storm
        if wantRain != rainOn { rainOn = wantRain; if wantRain { loop(rain, "amb_rain") } else { rain.stop() } }
        bed.volume = vol * (underwater ? 0.8 : 0.6)
        rain.volume = vol * (w == .storm ? 0.7 : 0.45)
    }

    /// 水下镜头/小游戏收线：低通到 600Hz
    func setUnderwater(_ on: Bool) {
        underwater = on
        eq.bands[0].frequency = on ? 600 : 20_000
    }

    func stop() {
        guard started else { return }
        bed.stop(); rain.stop(); engine.pause(); started = false; bedName = ""; rainOn = false
    }
}
