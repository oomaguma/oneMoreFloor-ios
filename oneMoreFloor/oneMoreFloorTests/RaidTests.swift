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
        #expect(game.heroHp == 37)
    }

    @Test func winNeverLeavesTheHeroDeadOrOverhealed() {
        let game = gameInRaid(floor: 10)
        game.completeRaid(success: true, heroHpAfterRaid: 0)
        #expect(game.heroHp == 1)

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
}
