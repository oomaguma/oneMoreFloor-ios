//
//  DailyQuestTests.swift
//  oneMoreFloorTests
//
//  Dailies are three achievable goals (easy / medium / stretch), not a
//  twelve-item chore list. These pin that down across a whole year of dates.
//

import Testing
import Foundation
@testable import oneMoreFloor

struct DailyQuestTests {

    // MARK: - Helpers

    /// Every date key in 2026 ("2026-01-01" ... "2026-12-31").
    private var yearOfDays: [String] {
        let daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        return daysInMonth.enumerated().flatMap { month, days in
            (1...days).map { String(format: "2026-%02d-%02d", month + 1, $0) }
        }
    }

    // MARK: - Shape of a day

    @Test func everyDayHasThreeQuestsOnePerTier() {
        let tiers = DungeonGame.questTiers.map { Set($0.map(\.id)) }
        for day in yearOfDays {
            let quests = DungeonGame.selectQuestsForDay(day)
            #expect(quests.count == 3, "\(day)")
            for (quest, tier) in zip(quests, tiers) {
                #expect(tier.contains(quest.id), "\(day): \(quest.id) not in its tier")
            }
        }
    }

    @Test func noDayRepeatsAQuestType() {
        for day in yearOfDays {
            let types = DungeonGame.selectQuestsForDay(day).map(\.type)
            #expect(Set(types).count == types.count, "\(day): \(types)")
        }
    }

    @Test func theSameDayAlwaysGetsTheSameQuests() {
        // Saved progress is matched by id, so a day's picks must be stable.
        let first  = DungeonGame.selectQuestsForDay("2026-10-29").map(\.id)
        let second = DungeonGame.selectQuestsForDay("2026-10-29").map(\.id)
        #expect(first == second)
    }

    @Test func daysActuallyVary() {
        let distinctDays = Set(yearOfDays.map { DungeonGame.selectQuestsForDay($0).map(\.id) })
        #expect(distinctDays.count > 20)
    }

    // MARK: - Achievable

    @Test func noDailyAsksForSomethingOutOfReach() {
        // The old pool had "Reach floor 100" and "Defeat 12 bosses" as dailies.
        for quest in DungeonGame.questTiers.flatMap({ $0 }) {
            switch quest.type {
            case .reachFloor:  #expect(quest.goalCount <= 25, "\(quest.id)")
            case .killBoss:    #expect(quest.goalCount <= 5,  "\(quest.id)")
            case .clearFloors: #expect(quest.goalCount <= 35, "\(quest.id)")
            case .killAny:     #expect(quest.goalCount <= 200, "\(quest.id)")
            case .earnGold:    #expect(quest.goalCount <= 700, "\(quest.id)")
            }
        }
    }
}
