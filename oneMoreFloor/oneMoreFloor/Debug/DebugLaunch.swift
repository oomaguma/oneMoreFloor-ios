// DebugLaunch.swift
// QA shortcuts driven by launch arguments. DEBUG builds only — none of this
// exists in a Release (App Store) build.
//
// Why: some features sit deep in a run. Reaching the first raid means beating
// the floor-10 boss, which a fresh hero often can't. These arguments jump
// straight to the moment you want to test.
//
// Usage (launch arguments land in UserDefaults' argument domain for that one
// launch only, so nothing sticks around afterwards):
//
//   xcrun simctl launch booted jmyers.oneMoreFloor -debugRaid 10
//   xcrun simctl launch booted jmyers.oneMoreFloor -debugRaid 10 -debugBlessings YES
//
// In Xcode: Edit Scheme → Run → Arguments → "Arguments Passed On Launch".
//
//   -debugRaid <floor>    Put the hero at the rest site after <floor>'s boss
//                         (so on floor <floor>+1) with 100 gold at risk, with
//                         the Rest / Descend / Raid card up. Use a boss floor: 10, 20, …
//   -debugBlessings YES   Also grant War Surge, Thorn Mantle, and Blood Rush.

#if DEBUG
import Foundation

extension DungeonGame {

    // MARK: - Launch-argument shortcuts

    func applyDebugLaunchArguments() {
        let args = UserDefaults.standard

        let raidFloor = args.integer(forKey: "debugRaid")
        guard raidFloor > 0 else { return }

        // Match the real flow: beating floor N's boss advances to N+1, and the
        // rest site appears there. (Staying on N would respawn the boss after.)
        currentFloor     = raidFloor + 1
        deepestFloor     = max(deepestFloor, raidFloor + 1)
        deepestFloorEver = max(deepestFloorEver, raidFloor + 1)
        heroHp           = heroMaxHp
        atRiskGold       = 100
        isGameOver       = false
        pendingRestSite  = true

        if args.bool(forKey: "debugBlessings") {
            // These three carry no flat stat mods, so appending them directly
            // (instead of going through the floor-event path) is accurate.
            activeEffects.removeAll { $0.isBlessing }
            activeEffects += [
                ActiveEffect(name: "War Surge",    icon: "💥",  isBlessing: true, splashDamagePercent: 0.40),
                ActiveEffect(name: "Thorn Mantle", icon: "🌿",  isBlessing: true, thornsDamagePercent: 0.20),
                ActiveEffect(name: "Blood Rush",   icon: "❤️‍🔥", isBlessing: true, onKillHealPercent: 0.08),
            ]
        }
        log("🛠 DEBUG: jumped to floor \(raidFloor) rest site")
    }
}
#endif
