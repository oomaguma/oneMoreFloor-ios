//
//  BlessingCombatTests.swift
//  oneMoreFloorTests
//
//  Covers the special-blessing math (War Surge splash, Thorn Mantle thorns,
//  Blood Rush kill-heal) that both the dungeon and raids share, plus how the
//  raid picks War Surge's second target. RaidScene itself needs a live SKView
//  to run, so these tests drive the pure pieces it's built from.
//

import Testing
import SpriteKit
@testable import oneMoreFloor

struct BlessingCombatTests {

    // MARK: - War Surge (splash)

    @Test func splashIsAShareOfTheStrike() {
        // 40% of a 25-damage strike → 10.
        #expect(BlessingCombat.splashDamage(strike: 25, fraction: 0.40) == 10)
    }

    @Test func splashAlwaysDealsAtLeastOne() {
        // 40% of 1 rounds down to 0, but an active splash still chips for 1.
        #expect(BlessingCombat.splashDamage(strike: 1, fraction: 0.40) == 1)
    }

    @Test func noSplashWithoutTheBlessing() {
        #expect(BlessingCombat.splashDamage(strike: 25, fraction: 0) == 0)
    }

    // MARK: - Thorn Mantle (reflect)

    @Test func thornsReflectAShareOfTheHit() {
        // 20% of a 30-damage hit → 6.
        #expect(BlessingCombat.thornsReflect(incoming: 30, fraction: 0.20, attackerHp: 100) == 6)
    }

    @Test func thornsNeverLandTheKillingBlow() {
        // Attacker at 4 HP would take 6 — capped to 3 so it survives at 1.
        #expect(BlessingCombat.thornsReflect(incoming: 30, fraction: 0.20, attackerHp: 4) == 3)
        // Already at 1 HP: nothing to reflect.
        #expect(BlessingCombat.thornsReflect(incoming: 30, fraction: 0.20, attackerHp: 1) == 0)
    }

    @Test func noThornsWithoutTheBlessing() {
        #expect(BlessingCombat.thornsReflect(incoming: 30, fraction: 0, attackerHp: 100) == 0)
    }

    // MARK: - Blood Rush (heal on kill)

    @Test func killHealIsAShareOfMaxHp() {
        // 8% of 150 max HP → 12.
        #expect(BlessingCombat.killHeal(maxHp: 150, fraction: 0.08) == 12)
    }

    @Test func noKillHealWithoutTheBlessing() {
        #expect(BlessingCombat.killHeal(maxHp: 150, fraction: 0) == 0)
    }

    // MARK: - War Surge target selection (raid)

    /// A bare raid enemy at an x position. Empty animation frames are fine —
    /// target selection only looks at position and HP.
    private func enemy(x: CGFloat, hp: Int = 10) -> RaidEnemy {
        let e = RaidEnemy(name: "Test", hp: hp, atk: 1, isBoss: false,
                          idleFrames: [], attackFrames: [], hurtFrames: [], deathFrames: [])
        e.node.position = CGPoint(x: x, y: 62)
        return e
    }

    @Test func splashHitsTheClosestOtherEnemyInRange() {
        let struck = enemy(x: 95)
        let near   = enemy(x: 115)
        let far    = enemy(x: 155)
        let target = RaidScene.splashTarget(after: struck, among: [struck, far, near], hitRange: 170)
        #expect(target === near)
    }

    @Test func splashNeverHitsTheSameEnemyTwice() {
        let struck = enemy(x: 95)
        #expect(RaidScene.splashTarget(after: struck, among: [struck], hitRange: 170) == nil)
    }

    @Test func splashSkipsDeadAndOutOfRangeEnemies() {
        let struck     = enemy(x: 95)
        let dead       = enemy(x: 100, hp: 0)
        let stillWalking = enemy(x: 250)   // beyond the 170 hit range
        #expect(RaidScene.splashTarget(after: struck, among: [struck, dead, stillWalking],
                                       hitRange: 170) == nil)
    }
}
