// Codex.swift
// The bestiary and gear codex: a permanent record of every monster you've
// slain and every piece of gear you've found, at every rarity.
//
// Why: collection is one of the strongest "come back tomorrow" loops in the
// engagement chart. Blank silhouettes and empty rarity pips are goals the
// player sets for themselves ("I still haven't found a Legendary Bow"), and
// unlike a timer or a streak, there's no punishment for missing a day.
//
// Like the Hall of the Fallen it lives under its own UserDefaults key, NOT in
// the run save — "New Hero" wipes the run, and a collection that resets when
// you start over isn't a collection.

import Foundation

// MARK: - Codex Data

struct Codex: Codable, Equatable {
    /// Kills per monster type, keyed by `EnemyType.id`.
    var kills: [String: Int] = [:]
    /// Boss kills per zone, keyed by `Zone.id`. Bosses are tracked by zone
    /// (not by monster) because each zone's boss has its own gimmick.
    var bossKills: [String: Int] = [:]
    /// Rarities found per gear piece, keyed by the piece's base name
    /// ("Sword", "Ring of Life"), stored as `ItemRarity` raw values.
    var gear: [String: Set<String>] = [:]

    // MARK: Recording

    mutating func recordKill(enemyID: String, bossOfZone zoneID: String?) {
        kills[enemyID, default: 0] += 1
        if let zoneID { bossKills[zoneID, default: 0] += 1 }
    }

    mutating func recordGear(_ item: Equipment) {
        gear[item.baseName, default: []].insert(item.rarity.rawValue)
    }

    // MARK: Questions the views ask

    func killCount(_ enemyID: String) -> Int { kills[enemyID] ?? 0 }
    func bossKillCount(zone zoneID: String) -> Int { bossKills[zoneID] ?? 0 }

    func hasFound(_ baseName: String, rarity: ItemRarity) -> Bool {
        gear[baseName]?.contains(rarity.rawValue) ?? false
    }

    /// How many gear + rarity combinations have been found, out of how many exist.
    var gearProgress: (found: Int, total: Int) {
        let total = EquipmentDrop.codexEntries.count * ItemRarity.allCases.count
        let found = EquipmentDrop.codexEntries.reduce(0) { sum, entry in
            sum + ItemRarity.allCases.filter { hasFound(entry.baseName, rarity: $0) }.count
        }
        return (found, total)
    }

    /// Monsters + zone bosses discovered, out of how many exist.
    var bestiaryProgress: (found: Int, total: Int) {
        let monsters = EnemyType.all.filter { killCount($0.id) > 0 }.count
        let bosses   = DungeonGame.zones.filter { bossKillCount(zone: $0.id) > 0 }.count
        return (monsters + bosses, EnemyType.all.count + DungeonGame.zones.count)
    }
}

// MARK: - Store

extension Codex {
    static let storageKey = "com.oneMoreFloor.codex"

    static func load() -> Codex {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let codex = try? JSONDecoder().decode(Codex.self, from: data)
        else { return Codex() }
        return codex
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Codex.storageKey)
        }
    }

    /// Wipes the collection (tests only).
    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
