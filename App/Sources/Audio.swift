import AVFoundation
import UIKit

/// 音效 / 背景音乐 / 触感反馈（开关存 UserDefaults）
@MainActor
final class AudioManager {
    static let shared = AudioManager()
    enum Sfx: String { case tap = "sfx_tap", upgrade = "sfx_upgrade", open = "sfx_open", coin = "sfx_coin", error = "sfx_error", catchFish = "sfx_catch", rare = "sfx_rare", purr = "sfx_purr", shutter = "sfx_shutter", splash = "sfx_splash", gull = "sfx_gull" }

    private var players: [Sfx: AVAudioPlayer] = [:]
    private var bgm: AVAudioPlayer?
    private let defaults = UserDefaults.standard

    var sfxOn: Bool {
        get { defaults.object(forKey: "sfxOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "sfxOn") }
    }
    var musicOn: Bool {
        get { defaults.object(forKey: "musicOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "musicOn"); updateMusic() }
    }
    var hapticsOn: Bool {
        get { defaults.object(forKey: "hapticsOn") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hapticsOn") }
    }

    private init() {
        // ambient：不打断用户自己的音乐，静音键生效
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }

    private func url(_ name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Audio")
    }

    func play(_ s: Sfx, volume: Float = 0.7) {
        guard sfxOn else { return }
        if players[s] == nil, let u = url(s.rawValue) { players[s] = try? AVAudioPlayer(contentsOf: u) }
        guard let p = players[s] else { return }
        p.volume = volume * Float(AppSettings.shared.sfxVolume)
        p.currentTime = 0
        p.play()
    }

    private var musicVolume: Float { 0.5 * Float(AppSettings.shared.musicVolume) }
    func applyMusicVolume() { bgm?.volume = musicVolume }
    private var fadeToken = 0

    /// 回到前台：从静音淡入
    func startMusic() {
        fadeToken += 1
        guard musicOn else { return }
        if bgm == nil { updateMusic(); bgm?.volume = 0 }
        guard let p = bgm else { return }
        if !p.isPlaying { p.volume = 0; p.play() }
        p.setVolume(musicVolume, fadeDuration: 1.2)
    }

    /// 切到后台：淡出后暂停
    func stopMusic() {
        guard let p = bgm, p.isPlaying else { return }
        fadeToken += 1
        let token = fadeToken
        p.setVolume(0, fadeDuration: 0.5)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            if token == self.fadeToken { p.pause() }
        }
    }

    private func updateMusic() {
        if musicOn {
            if bgm == nil, let u = url("bgm_harbor") {
                bgm = try? AVAudioPlayer(contentsOf: u)
                bgm?.numberOfLoops = -1
                bgm?.volume = musicVolume
            }
            bgm?.play()
        } else {
            bgm?.pause()
        }
    }

    func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard hapticsOn else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsOn else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
