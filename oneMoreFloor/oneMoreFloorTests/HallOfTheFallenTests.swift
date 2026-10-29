//
//  HallOfTheFallenTests.swift
//  oneMoreFloorTests
//
//  Every run that ends in death is remembered — and only those. Serialized
//  because the Hall lives in one shared UserDefaults key.
//

import Testing
import Foundation
@testable import oneMoreFloor

@Suite(.serialized)
struct HallOfTheFallenTests {

    // MARK: - Helpers

    /// A Soldier who just died on `floor` carrying `pot` gold.
    private func deadHero(floor: Int, pot: Int) -> DungeonGame {
        HallOfTheFallen.clear()
        let game = DungeonGame(character: CharacterClass.all[0])
        game.currentFloor = floor
        game.atRiskGold = pot
        game.isGameOver = true
        return game
    }

    // MARK: - Recording

    @Test func restartingAfterDeathRecordsTheFall() {
        defer { HallOfTheFallen.clear() }
        let game = deadHero(floor: 23, pot: 120)
        game.restart()

        let fall = try? #require(game.fallenHeroes.first)
        #expect(game.fallenHeroes.count == 1)
        #expect(fall?.floor == 23)
        #expect(fall?.goldLost == 120)
        #expect(fall?.heroName == CharacterClass.all[0].name)
        // Persisted, not just in memory.
        #expect(HallOfTheFallen.load().count == 1)
    }

    @Test func aReviveIsNotAFall() {
        defer { HallOfTheFallen.clear() }
        let game = deadHero(floor: 12, pot: 50)
        game.revive()
        #expect(game.fallenHeroes.isEmpty)
        #expect(HallOfTheFallen.load().isEmpty)
    }

    @Test func restartingWithoutDyingRecordsNothing() {
        defer { HallOfTheFallen.clear() }
        let game = deadHero(floor: 8, pot: 0)
        game.isGameOver = false
        game.restart()
        #expect(game.fallenHeroes.isEmpty)
    }

    @Test func theCurrentFallShowsWhatWillBeRecorded() {
        defer { HallOfTheFallen.clear() }
        let game = deadHero(floor: 17, pot: 90)
        #expect(game.currentFall?.floor == 17)
        game.isGameOver = false
        #expect(game.currentFall == nil)
    }

    // MARK: - Persistence

    @Test func theHallSurvivesStartingANewHero() {
        defer { HallOfTheFallen.clear() }
        deadHero(floor: 30, pot: 10).restart()
        DungeonGame.clearSave()                       // what "New Hero" does
        let fresh = DungeonGame(character: CharacterClass.all[1])
        #expect(fresh.fallenHeroes.count == 1)
        #expect(fresh.fallenHeroes.first?.floor == 30)
    }

    @Test func theHallKeepsTheMostRecentFifty() {
        defer { HallOfTheFallen.clear() }
        HallOfTheFallen.clear()
        for floor in 1...60 {
            HallOfTheFallen.record(FallenHero(heroName: "Test", characterID: "soldier", floor: floor,
                                              goldLost: 0, greed: 1, slainBy: nil, date: .now))
        }
        let hall = HallOfTheFallen.load()
        #expect(hall.count == HallOfTheFallen.capacity)
        #expect(hall.first?.floor == 60)   // newest first
    }
}
