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
//   -debugRaid <floor>    Put the hero at <floor>'s rest site with 100 gold at
//                         risk, so the Rest / Descend / Raid card is up.
//   -debugBlessings YES   Also grant War Surge, Thorn Mantle, and Blood Rush.

#if DEBUG
import Foundation

extension DungeonGame {

    // MARK: - Launch-argument shortcuts

    func applyDebugLaunchArguments() {
        let args = UserDefaults.standard

        let raidFloor = args.integer(forKey: "debugRaid")
        guard raidFloor > 0 else { return }

        currentFloor     = raidFloor
        deepestFloor     = max(deepestFloor, raidFloor)
        deepestFloorEver = max(deepestFloorEver, raidFloor)
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
