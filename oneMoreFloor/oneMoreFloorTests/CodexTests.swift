//
//  CodexTests.swift
//  oneMoreFloorTests
//
//  The codex remembers every monster slain and every gear rarity found, and
//  it outlives the run. Serialized because it lives in one shared
//  UserDefaults key.
//

import Testing
import Foundation
@testable import oneMoreFloor

@Suite(.serialized)
struct CodexTests {

    // MARK: - Recording

    @Test func killsCountPerMonsterAndBossesPerZone() {
        var codex = Codex()
        codex.recordKill(enemyID: "slime", bossOfZone: nil)
        codex.recordKill(enemyID: "slime", bossOfZone: nil)
        codex.recordKill(enemyID: "skeleton", bossOfZone: "entrance")

        #expect(codex.killCount("slime") == 2)
        #expect(codex.killCount("skeleton") == 1)
        #expect(codex.bossKillCount(zone: "entrance") == 1)
        #expect(codex.bossKillCount(zone: "crypts") == 0)
    }

    @Test func gearIsTrackedByBaseNameAndRarity() {
        var codex = Codex()
        let item = EquipmentDrop.debugItem(rarity: .epic, floor: 10)
        codex.recordGear(item)

        #expect(codex.hasFound(item.baseName, rarity: .epic))
        #expect(!codex.hasFound(item.baseName, rarity: .common))
        #expect(codex.gearProgress.found == 1)
    }

    @Test func baseNameDropsTheRarityPrefix() {
        let item = EquipmentDrop.debugItem(rarity: .legendary, floor: 1)
        #expect(!item.baseName.hasPrefix("Legendary"))
        #expect(EquipmentDrop.codexEntries.contains { $0.baseName == item.baseName })
    }

    // MARK: - In the game

    @Test func aDropIsRecordedInTheCodex() {
        Codex.clear()
        defer { Codex.clear() }
        let game = DungeonGame(character: CharacterClass.all[0])
        let item = EquipmentDrop.debugItem(rarity: .rare, floor: 5)
        game.receiveDrop(item)
        #expect(game.codex.hasFound(item.baseName, rarity: .rare))
    }

    @Test func theCodexSurvivesStartingANewHero() {
        Codex.clear()
        defer { Codex.clear() }
        let game = DungeonGame(character: CharacterClass.all[0])
        game.receiveDrop(EquipmentDrop.debugItem(rarity: .uncommon, floor: 3))
        game.save()
        DungeonGame.clearSave()                       // what "New Hero" does
        let fresh = DungeonGame(character: CharacterClass.all[1])
        #expect(fresh.codex.gearProgress.found == 1)
    }
}
