//
//  RaidTests.swift
//  oneMoreFloorTests
//
//  Guards the raid fixes from the glow-up branch: the shard reward has one
//  source of truth, raid damage sticks on a win, a loss costs what the rest
//  card promises, and blessing special effects reach the raid scene.
//

import Testing
@testable import oneMoreFloor

struct RaidTests {

    // MARK: - Helpers

    /// A fresh Soldier run sitting at the given floor, mid-raid.
    private func gameInRaid(floor: Int) -> DungeonGame {
        let game = DungeonGame(character: CharacterClass.all[0])
        game.currentFloor = floor
        game.launchRaid()
        return game
    }

    // MARK: - Shard reward

    @Test func rewardHasAFloorOfFive() {
        // Shallow raids still pay at least 5 shards.
        #expect(gameInRaid(floor: 10).raidShardReward == 5)
    }

    @Test func rewardScalesWithDepth() {
        // Deeper raids pay floor / 3.
        #expect(gameInRaid(floor: 30).raidShardReward == 10)
    }

    @Test func winPaysExactlyTheAdvertisedReward() {
        // The result screen shows raidShardReward, so the payout must match it.
        let game = gameInRaid(floor: 30)
        let advertised = game.raidShardReward
        let before = game.soulShards
        game.completeRaid(success: true, heroHpAfterRaid: game.heroHp)
        #expect(game.soulShards - before == advertised)
        #expect(game.isRaidActive == false)
    }

    // MARK: - HP after the raid

    @Test func winKeepsRaidDamage() {
        // Damage taken in the raid sticks — a win no longer restores pre-raid HP.
        let game = gameInRaid(floor: 10)
        game.completeRaid(success: true, heroHpAfterRaid: 37)
        // The full-clear loot is random; if it was HP gear and got equipped, it
        // adds its bonus to current HP too. Account for that, or the test flakes.
        var expected = 37
        if let loot = game.raidOutcome?.loot,
           game.equippedItems[loot.slot.rawValue]?.id == loot.id {
            expected += loot.hpBonus
        }
        #expect(game.heroHp == min(expected, game.heroMaxHp))
    }

    @Test func winNeverLeavesTheHeroDeadOrOverhealed() {
        // A full clear also auto-equips its boss loot, and HP gear raises both
        // current and max HP — so check the bounds, not exact numbers.
        let game = gameInRaid(floor: 10)
        game.completeRaid(success: true, heroHpAfterRaid: 0)
        #expect(game.heroHp >= 1)
        #expect(game.heroHp <= game.heroMaxHp)

        let game2 = gameInRaid(floor: 10)
        game2.completeRaid(success: true, heroHpAfterRaid: game2.heroMaxHp + 50)
        #expect(game2.heroHp == game2.heroMaxHp)
    }

    // MARK: - Loss penalty

    @Test func lossForfeitsThePotAndBlessings() {
        let game = gameInRaid(floor: 10)
        game.atRiskGold = 120
        game.activeEffects = [ActiveEffect(name: "War Surge", icon: "💥",
                                           isBlessing: true, splashDamagePercent: 0.40)]
        game.completeRaid(success: false, heroHpAfterRaid: 0)
        #expect(game.atRiskGold == 0)
        #expect(game.activeEffects.isEmpty)
        #expect(game.heroHp == max(1, game.heroMaxHp / 3))
    }

    // MARK: - Blessings carried into the raid

    @Test func blessingEffectsAreSummedForTheRaid() {
        let game = gameInRaid(floor: 10)
        game.activeEffects = [
            ActiveEffect(name: "War Surge",    icon: "💥",  isBlessing: true, splashDamagePercent: 0.40),
            ActiveEffect(name: "Thorn Mantle", icon: "🌿",  isBlessing: true, thornsDamagePercent: 0.20),
            ActiveEffect(name: "Blood Rush",   icon: "❤️‍🔥", isBlessing: true, onKillHealPercent: 0.08),
        ]
        #expect(game.splashFraction == 0.40)
        #expect(game.thornsFraction == 0.20)
        #expect(game.killHealFraction == 0.08)
    }

    // MARK: - Tuning (RaidScene knobs)

    @Test func wavesGrowTwoThreeFour() {
        #expect((1...3).map { RaidScene.enemyCount(wave: $0) } == [2, 3, 4])
    }

    @Test func raidEnemiesAreScaledDown() {
        // The floor-11 Crypts boss (Armored Skeleton): 162 HP / 19 ATK in a normal fight.
        #expect(RaidScene.raidScaled(162, by: RaidScene.enemyHpScale) == 72)
        #expect(RaidScene.raidScaled(19,  by: RaidScene.enemyAtkScale) == 10)
    }

    @Test func scaledStatsNeverDropBelowOne() {
        #expect(RaidScene.raidScaled(1, by: RaidScene.enemyHpScale) == 1)
    }

    @Test func breatherHealIsAShareOfMaxHp() {
        // 15% of a 120-HP hero → 18 between waves.
        #expect(RaidScene.raidScaled(120, by: RaidScene.breatherHealFraction) == 18)
    }

    // MARK: - Greed, escape, outcome (raid glow-up)

    @Test func greedMultipliesTheReward() {
        let game = gameInRaid(floor: 30)        // base 10
        game.greedMultiplier = 2.0
        #expect(game.raidShardReward == 20)
    }

    @Test func escapePaysAShareOfTheFullReward() {
        let game = gameInRaid(floor: 30)        // full reward 10
        #expect(game.raidEscapeReward(wavesCleared: 1) == 3)   // 25%, rounded
        #expect(game.raidEscapeReward(wavesCleared: 2) == 5)   // 50%
        #expect(game.raidEscapeReward(wavesCleared: 3) == 0)   // no escaping after the boss
    }

    @Test func escapingKeepsBlessingsAndThePot() {
        let game = gameInRaid(floor: 30)
        game.atRiskGold = 120
        game.activeEffects = [ActiveEffect(name: "War Surge", icon: "💥",
                                           isBlessing: true, splashDamagePercent: 0.40)]
        let before = game.soulShards
        game.escapeRaid(wavesCleared: 2, heroHpAfterRaid: 50)

        #expect(game.isRaidActive == false)
        #expect(game.soulShards - before == 5)
        #expect(game.atRiskGold == 120)
        #expect(game.activeEffects.count == 1)
        #expect(game.heroHp == 50)
        #expect(game.raidOutcome?.kind == .escaped(afterWave: 2))
    }

    @Test func fullClearRecordsShardsAndLoot() {
        let game = gameInRaid(floor: 30)
        game.completeRaid(success: true, heroHpAfterRaid: game.heroHp)
        #expect(game.raidOutcome?.kind == .cleared)
        #expect(game.raidOutcome?.shards == 10)
        #expect(game.raidOutcome?.loot != nil)          // boss-tier drop is guaranteed
        // The result screen stays up until Continue, then goes away.
        #expect(game.isRaidScreenUp)
        game.dismissRaidOutcome()
        #expect(game.isRaidScreenUp == false)
    }

    @Test func lossOutcomeListsWhatWasLost() {
        let game = gameInRaid(floor: 10)
        game.atRiskGold = 70
        game.completeRaid(success: false, heroHpAfterRaid: 0)
        #expect(game.raidOutcome == DungeonGame.RaidOutcome(kind: .lost, shards: 0, loot: nil,
                                                            blessingsLost: 0, goldLost: 70))
    }

    // MARK: - Danger read

    @Test func dangerRisesWithDepth() {
        let shallow = gameInRaid(floor: 11)
        let deep    = gameInRaid(floor: 18)     // same zone, same hero, tougher enemies
        #expect(deep.raidDangerRatio > shallow.raidDangerRatio)
    }

    @Test func dangerFallsWithAStrongerHero() {
        let weak   = gameInRaid(floor: 11)
        let strong = gameInRaid(floor: 11)
        strong.heroAtk = 40
        #expect(strong.raidDangerRatio < weak.raidDangerRatio)
    }

    // MARK: - Heavies, dodge, guard (raid abilities)

    @Test func aHeavyHitsHarderThanANormalHit() {
        let normal = RaidScene.incomingDamage(atk: 20, def: 2, heavy: false, guardReduction: 0)
        let heavy  = RaidScene.incomingDamage(atk: 20, def: 2, heavy: true,  guardReduction: 0)
        #expect(normal == 18)
        #expect(heavy  == 28)                    // 20 × 1.5 = 30, minus 2 DEF
    }

    @Test func aGuardCutsIncomingDamage() {
        // Shield Wall: 70% reduction after DEF.
        let guarded = RaidScene.incomingDamage(atk: 20, def: 0, heavy: true, guardReduction: 0.7)
        #expect(guarded == 9)                    // 30 × 0.3
    }

    @Test func everyHitDealsAtLeastOne() {
        #expect(RaidScene.incomingDamage(atk: 1, def: 50, heavy: true, guardReduction: 0.9) == 1)
    }

    @Test func theRaidUsesTheHerosOwnAbilityAndCooldown() {
        let soldier = CharacterClass.all[0]
        let scene = RaidScene(hero: soldier, heroHp: 100, heroMaxHp: 100, heroAtk: 10, heroDef: 1,
                              zoneID: "crypts", floor: 11, critChance: 0, abilityCooldown: 9)
        #expect(scene.ability.name == soldier.signatureAbility.name)
        #expect(scene.isAbilityReady)            // ready the moment the raid starts
        #expect(scene.canDodge)
    }
}
