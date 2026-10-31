import Foundation

/// Core 文案语言开关：App 启动时根据系统首选语言设置。默认中文（测试也按中文断言）。
public enum CoreLang {
    nonisolated(unsafe) public static var english = false
}

/// 中英文二选一
@inline(__always) public func tr(_ zh: String, _ en: @autoclosure () -> String) -> String {
    CoreLang.english ? en() : zh
}

/// 英文名称表（常用英文名参照 FishBase / Wikipedia）
public enum CoreEN {
    public static let fish: [String: String] = [
        "sardine": "European Pilchard", "mackerel": "Chub Mackerel", "crab": "Gazami Crab", "seabream": "Red Seabream",
        "mudskipper": "Shuttles Hoppfish", "tigerprawn": "Giant Tiger Prawn", "mudcrab": "Mud Crab", "barramundi": "Barramundi",
        "clown": "Ocellaris Clownfish", "squid": "Bigfin Reef Squid", "lobster": "Ornate Spiny Lobster", "coraltrout": "Leopard Coralgrouper",
        "urchin": "Purple Sea Urchin", "abalone": "Disk Abalone", "yellowtail": "Japanese Amberjack", "seadragon": "Leafy Seadragon",
        "tuna": "Yellowfin Tuna", "mahimahi": "Mahi-mahi", "puffer": "Japanese Pufferfish", "swordfish": "Swordfish",
        "cod": "Atlantic Cod", "salmon": "Atlantic Salmon", "charr": "Arctic Char", "kingcrab": "Red King Crab",
        "monkfish": "Yellow Goosefish", "octopus": "Giant Pacific Octopus", "giantsquid": "Giant Squid", "oarfish": "Giant Oarfish",
        "bluefin": "Atlantic Bluefin Tuna", "sunfish": "Ocean Sunfish", "megamouth": "Megamouth Shark", "coelacanth": "West Indian Ocean Coelacanth",
    ]
    public static let area: [String: String] = [
        "bay": "Quiet Bay", "mangrove": "Mangrove Wetlands", "reef": "Coral Reef", "kelp": "Kelp Forest",
        "deep": "Deep Blue", "ice": "Arctic Floes", "trench": "Abyssal Trench", "legend": "Legendary Sea",
    ]
    public static let blurb: [String: String] = [
        "bay": "A sheltered bay just outside the harbor — every rookie captain's first stop",
        "mangrove": "Brackish mudflats where fresh water meets the sea, teeming with crabs and prawns",
        "reef": "A riot of tropical coral — lively and fragile",
        "kelp": "Towering giant kelp sways in the swell, hiding the sea's own “dragon”",
        "deep": "Blue water out of sight of land, home of the great migratory fish",
        "ice": "Icy seas dotted with icebergs — winter brings the best hauls",
        "trench": "A sunless abyss where strange fish lurk",
        "legend": "At the edge of the chart: living fossils and legendary giants",
    ]
    public static let captain: [String: String] = [
        "老王": "Old Wang", "阿海": "Hai", "小渔": "Little Yu", "大胡子": "Big Beard", "珍珠": "Pearl", "阿浪": "Lang",
    ]
}

/// 船长显示名（存档里保存中文名，英文界面下翻译）
public func displayCaptainName(_ name: String) -> String {
    guard CoreLang.english else { return name }
    if let n = CoreEN.captain[name] { return n }
    // 形如“老王2”的重名后缀
    for (zh, en) in CoreEN.captain where name.hasPrefix(zh) {
        return en + " " + name.dropFirst(zh.count)
    }
    return name
}

extension CoreEN {
    public static let extraFish: [String: String] = [
        "snowcrab": "Snow Crab", "polarcod": "Polar Cod", "halibut": "Greenland Halibut", "greenlandshark": "Greenland Shark",
        "krill": "Antarctic Krill", "icefish": "Mackerel Icefish", "toothfish": "Antarctic Toothfish",
    ]
}
