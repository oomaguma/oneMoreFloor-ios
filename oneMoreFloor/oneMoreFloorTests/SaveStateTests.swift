//
//  SaveStateTests.swift
//  oneMoreFloorTests
//
//  Mid-decision state must survive the app closing: a rest-site choice can't
//  be skipped by quitting, and a raid can't be escaped by quitting.
//
//  These go through the real save()/handleForeground() path, which uses one
//  shared UserDefaults key — so the suite runs serialized (Swift Testing runs
//  tests in parallel by default) and clears the save after each test.
//

import Testing
@testable import oneMoreFloor

@Suite(.serialized)
struct SaveStateTests {

    // MARK: - Helpers

    private func freshGame() -> DungeonGame {
        DungeonGame(character: CharacterClass.all[0])
    }

    /// A game mid-raid with something on the line, saved to disk.
    private func savedMidRaid() -> DungeonGame {
        let game = freshGame()
        game.currentFloor = 10
        game.atRiskGold = 80
        game.activeEffects = [ActiveEffect(name: "War Surge", icon: "💥",
                                           isBlessing: true, splashDamagePercent: 0.40)]
        game.launchRaid()
        game.save()
        return game
    }

    // MARK: - Raids

    @Test func closingTheAppMidRaidCountsAsALoss() {
        defer { DungeonGame.clearSave() }
        _ = savedMidRaid()

        // A brand-new game instance = a fresh launch after the app was closed.
        let relaunched = freshGame()
        _ = relaunched.handleForeground()

        #expect(relaunched.isRaidActive == false)
        #expect(relaunched.atRiskGold == 0)
        #expect(relaunched.activeEffects.isEmpty)
        #expect(relaunched.abandonedRaid == DungeonGame.AbandonedRaid(blessingsLost: 1, goldLost: 80))
        // The alert explains it — no raid result screen should be left up.
        #expect(relaunched.raidOutcome == nil)
    }

    @Test func backgroundingMidRaidKeepsTheRaidGoing() {
        defer { DungeonGame.clearSave() }
        // Same instance coming back = the app was only backgrounded.
        let game = savedMidRaid()
        _ = game.handleForeground()

        #expect(game.isRaidActive == true)
        #expect(game.atRiskGold == 80)
        #expect(game.abandonedRaid == nil)
    }

    // MARK: - Rest sites

    @Test func restSiteChoiceSurvivesARelaunch() {
        defer { DungeonGame.clearSave() }
        let game = freshGame()
        game.pendingRestSite = true
        game.save()

        let relaunched = freshGame()
        _ = relaunched.handleForeground()
        #expect(relaunched.pendingRestSite == true)
    }
}
