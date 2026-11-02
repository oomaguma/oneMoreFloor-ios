//
//  NextBossTests.swift
//  oneMoreFloorTests
//
//  The next-boss preview counts down to the zone's boss floor (every 10th
//  floor) and names the right boss. Off-by-one here would show "BOSS IN 0"
//  or point at the wrong zone's boss.
//

import Testing
@testable import oneMoreFloor

struct NextBossTests {

    // MARK: - Countdown

    @Test func countsDownToTheEndOfTheZone() {
        let game = DungeonGame(character: CharacterClass.all[0])
        game.currentFloor = 1
        #expect(game.nextBossFloor == 10)
        #expect(game.floorsUntilBoss == 9)

        game.currentFloor = 9
        #expect(game.floorsUntilBoss == 1)
    }

    @Test func onTheBossFloorThereIsNothingLeftToCountDown() {
        let game = DungeonGame(character: CharacterClass.all[0])
        game.currentFloor = 20
        #expect(game.nextBossFloor == 20)
        #expect(game.floorsUntilBoss == 0)
    }

    @Test func theFloorAfterABossPointsAtTheNextZonesBoss() {
        let game = DungeonGame(character: CharacterClass.all[0])
        game.currentFloor = 11                        // first floor of the Crypts
        #expect(game.nextBossFloor == 20)
        #expect(game.nextBossEnemy?.id == DungeonGame.zoneBossEnemies["crypts"]?.id)
        #expect(game.nextBossGimmick == .shield)
    }
}
