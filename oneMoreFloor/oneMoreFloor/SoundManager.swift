import AVFoundation

// MARK: - Sound Manager
//
// Plays the game's sound effects. Callers ask for a *sound group* by name
// ("swing", "enemy_hit", …) and the manager picks one of the group's takes.
//
// Why groups: a sound that fires every second (the hero's swing, every enemy
// hit) gets repetitive fast when it's one or two files. Each group holds
// several takes of the same sound; we play a random one, never the same take
// twice in a row, and combat sounds also get a tiny random pitch shift (±5%),
// so even a single file doesn't sound identical every time.
//
// Sources: the original 8-bit set, Helton Yan's Pixel Combat (`hy_*` files),
// and ObsydianX's Interface SFX Pack 1, CC0 (`ui_*` files). New takes were
// trimmed, mono'd and level-matched with Tools/process_sounds.py.

final class SoundManager {
    static let shared = SoundManager()

    // MARK: Groups

    /// Group name → the files (without extension) it plays from.
    /// A plain file name with no group (e.g. "coin_collect") still works:
    /// it's treated as a group of one.
    private static let groups: [String: [String]] = [
        // Combat — the frequent ones get the most takes.
        "swing":         ["sword_slice", "sword_light"] + takes("hy_sword_slash", 6),
        "enemy_hit":     ["crunch_quick"] + takes("hy_smack", 6),
        "hero_hurt":     ["punch_2"] + takes("hy_gut_punch", 6),
        "crit":          takes("hy_sword_critical", 6),
        "enemy_death":   takes("hy_bit_bomb", 6),
        "heavy_windup":  takes("hy_energy_riser", 6),
        "dodge":         takes("hy_whoosh", 6),
        "dodged":        takes("hy_sword_parry", 6),
        "heal":          ["heart_collect"] + takes("hy_simple_heal", 3),
        "ability_ready": takes("hy_skill_ready", 3),
        "boss_arrives":  takes("hy_bass_hit", 3),
        // Gold from every kill: a short, quiet tink. It used to be the 1.3 s
        // coin_collect jingle on every single floor, which got grating fast;
        // that jingle is kept for quest claims, where a reward sound fits.
        "gold_tick":     takes("hy_coin_zap", 6),
        // Loot — the rarer the drop, the brighter the sound.
        "loot":          ["item_equip"] + takes("hy_magic_item", 3),
        "loot_rare":     takes("hy_sparkly_star", 3),
        // Interface.
        "ui_confirm":    takes("ui_confirm", 3),
        "ui_back":       takes("ui_back", 2),
        "ui_tab":        takes("ui_tab", 1),
    ]

    /// Groups that get the ±5% pitch wobble. Interface sounds stay steady —
    /// a menu click that changes pitch reads as a glitch, not variety.
    private static let variedGroups: Set<String> = [
        "swing", "enemy_hit", "hero_hurt", "crit", "enemy_death",
        "dodge", "dodged", "punch", "sword_clash", "gold_tick"
    ]

    /// Single files that fire rapidly and could cut themselves off: they get
    /// 3 players each so overlapping hits all play.
    private static let pooledFiles: Set<String> = ["punch", "punch_2", "sword_clash", "crunch_quick"]

    /// Files played directly by name (not through a group).
    private static let standaloneFiles: [String] = [
        "punch", "sword_clash", "coin_collect", "weapon_upgrade",
        "8_bit_positive_long", "8_bit_defeated", "8_bit_chime_positive",
        "8_bit_negative", "pop_1", "cancel"
    ]

    /// "hy_smack", 3 → ["hy_smack_1", "hy_smack_2", "hy_smack_3"]
    private static func takes(_ stem: String, _ count: Int) -> [String] {
        (1...count).map { "\(stem)_\($0)" }
    }

    // MARK: State
    //
    // All of this is touched only on `audioQueue`. AVAudioPlayer's play() and
    // seek calls wait on the system audio service, and profiling showed them
    // costing ~1.2 s of main-thread time per 15 s of combat — time the game
    // couldn't spend drawing frames. So the main thread just hands each
    // request to this serial queue and moves on.

    private let audioQueue = DispatchQueue(label: "com.oneMoreFloor.sound", qos: .userInteractive)

    /// One or more players per file (more for `pooledFiles`).
    private var players: [String: [AVAudioPlayer]] = [:]
    private var nextPlayer: [String: Int] = [:]
    /// The take each group played last, so it's never repeated back-to-back.
    private var lastTake: [String: String] = [:]

    // MARK: Setup

    /// Creating ~90 players took ~140 ms, which used to land on the first hit
    /// of a session as a visible hitch. Loading now happens on the audio queue
    /// (and AppDelegate touches `shared` at launch so it's done before battle).
    /// Any play() that arrives early simply waits in the queue behind it.
    private init() {
        audioQueue.async { [self] in
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)

            let files = Set(Self.groups.values.flatMap { $0 } + Self.standaloneFiles)
            for file in files {
                // Original sounds are .wav; the new takes are compact .m4a.
                guard let url = Bundle.main.url(forResource: file, withExtension: "wav")
                             ?? Bundle.main.url(forResource: file, withExtension: "m4a") else { continue }
                let count = Self.pooledFiles.contains(file) ? 3 : 1
                var pool: [AVAudioPlayer] = []
                for _ in 0..<count {
                    if let p = try? AVAudioPlayer(contentsOf: url) {
                        p.enableRate = true          // must be set before prepareToPlay
                        p.prepareToPlay()
                        pool.append(p)
                    }
                }
                if !pool.isEmpty { players[file] = pool }
            }
        }
    }

    // MARK: Playing

    /// Plays a group (random take, never the same one twice in a row) or,
    /// if `name` isn't a group, the single file with that name. Returns
    /// immediately; the actual playback happens on the audio queue.
    func play(_ name: String) {
        guard UserDefaults.standard.object(forKey: "com.oneMoreFloor.soundEnabled") as? Bool ?? true else { return }
        audioQueue.async { [self] in
            let candidates = (Self.groups[name] ?? [name]).filter { players[$0] != nil }
            guard !candidates.isEmpty else { return }
            let fresh = candidates.count > 1 ? candidates.filter { $0 != lastTake[name] } : candidates
            guard let file = fresh.randomElement(), let pool = players[file] else { return }
            lastTake[name] = file

            let idx = nextPlayer[file, default: 0] % pool.count
            nextPlayer[file] = idx + 1
            let player = pool[idx]
            player.rate = Self.variedGroups.contains(name) ? Float.random(in: 0.95...1.05) : 1.0
            // A finished player is already back at the start; only rewind one
            // that's still playing (seeking costs a round trip too).
            if player.isPlaying { player.currentTime = 0 }
            player.play()
        }
    }
}
