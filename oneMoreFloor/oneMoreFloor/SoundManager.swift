import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private var players: [String: [AVAudioPlayer]] = [:]
    private var nextIndex: [String: Int] = [:]

    // Combat sounds get a pool of 3 so rapid hits don't cut each other off.
    private static let pooledSounds: Set<String> = [
        "sword_slice", "sword_light", "punch", "punch_2", "sword_clash", "crunch_quick"
    ]

    private static let allSounds: [String] = [
        "sword_slice", "sword_light", "punch", "punch_2",
        "sword_clash", "crunch_quick",
        "coin_collect", "heart_collect", "item_equip", "weapon_upgrade",
        "8_bit_positive_long", "8_bit_defeated",
        "8_bit_chime_positive", "8_bit_negative",
        "pop_1", "cancel"
    ]

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        for name in Self.allSounds {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
            let count = Self.pooledSounds.contains(name) ? 3 : 1
            var pool: [AVAudioPlayer] = []
            for _ in 0..<count {
                if let p = try? AVAudioPlayer(contentsOf: url) {
                    p.prepareToPlay()
                    pool.append(p)
                }
            }
            if !pool.isEmpty {
                players[name] = pool
                nextIndex[name] = 0
            }
        }
    }

    func play(_ name: String) {
        guard UserDefaults.standard.object(forKey: "com.oneMoreFloor.soundEnabled") as? Bool ?? true else { return }
        guard let pool = players[name], !pool.isEmpty else { return }
        let idx = nextIndex[name, default: 0] % pool.count
        let player = pool[idx]
        player.currentTime = 0
        player.play()
        nextIndex[name] = idx + 1
    }
}
