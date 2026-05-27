import Foundation

// MARK: - Rarity

enum ItemRarity: String, Codable, CaseIterable {
    case common, uncommon, rare, epic, legendary

    var label: String {
        switch self {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        }
    }

    var namePrefix: String {
        switch self {
        case .common:    return "Worn"
        case .uncommon:  return "Fine"
        case .rare:      return "Enchanted"
        case .epic:      return "Ancient"
        case .legendary: return "Legendary"
        }
    }

    var statMultiplier: Double {
        switch self {
        case .common:    return 1.0
        case .uncommon:  return 1.8
        case .rare:      return 3.2
        case .epic:      return 6.0
        case .legendary: return 11.0
        }
    }
}

// MARK: - Slot

enum EquipmentSlot: String, Codable, CaseIterable {
    case weapon, armor, ring

    var label: String {
        switch self {
        case .weapon: return "Weapon"
        case .armor:  return "Armor"
        case .ring:   return "Ring"
        }
    }

    var emptyLabel: String {
        switch self {
        case .weapon: return "No Weapon Equipped"
        case .armor:  return "No Armor Equipped"
        case .ring:   return "No Ring Equipped"
        }
    }
}

// MARK: - Equipment

struct Equipment: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let slot: EquipmentSlot
    let rarity: ItemRarity
    let atkBonus: Int
    let defBonus: Int
    let hpBonus: Int
    let regenBonus: Int
    let iconName: String
    let floorFound: Int

    var sellValue: Int { max(1, floorFound * Int(rarity.statMultiplier)) }

    var statSummary: String {
        var parts: [String] = []
        if atkBonus > 0   { parts.append("+\(atkBonus) ATK") }
        if defBonus > 0   { parts.append("+\(defBonus) DEF") }
        if hpBonus > 0    { parts.append("+\(hpBonus) HP") }
        if regenBonus > 0 { parts.append("+\(regenBonus) Regen") }
        return parts.isEmpty ? "No bonuses" : parts.joined(separator: "  ")
    }
}

// MARK: - Templates

private struct EquipmentTemplate {
    let baseName: String
    let slot: EquipmentSlot
    let iconName: String
    let baseAtk: Int
    let baseDef: Int
    let baseHp: Int
    let baseRegen: Int

    func generate(rarity: ItemRarity, floor: Int) -> Equipment {
        let floorScale = 1.0 + Double(floor) * 0.02
        let mult = floorScale * rarity.statMultiplier
        return Equipment(
            id: UUID(),
            name: "\(rarity.namePrefix) \(baseName)",
            slot: slot,
            rarity: rarity,
            atkBonus:   baseAtk   > 0 ? max(1, Int(Double(baseAtk)   * mult)) : 0,
            defBonus:   baseDef   > 0 ? max(1, Int(Double(baseDef)   * mult)) : 0,
            hpBonus:    baseHp    > 0 ? max(5, Int(Double(baseHp)    * mult)) : 0,
            regenBonus: baseRegen > 0 ? max(1, Int(Double(baseRegen) * mult)) : 0,
            iconName: iconName,
            floorFound: floor
        )
    }

    static func pool(for slot: EquipmentSlot) -> [EquipmentTemplate] {
        switch slot {
        case .weapon: return weapons
        case .armor:  return armors
        case .ring:   return rings
        }
    }

    private static let weapons: [EquipmentTemplate] = [
        .init(baseName: "Sword",      slot: .weapon, iconName: "eq_sword",       baseAtk: 2, baseDef: 0, baseHp: 0, baseRegen: 0),
        .init(baseName: "Battle Axe", slot: .weapon, iconName: "eq_axe",         baseAtk: 3, baseDef: 0, baseHp: 0, baseRegen: 0),
        .init(baseName: "Bow",        slot: .weapon, iconName: "eq_bow",         baseAtk: 2, baseDef: 0, baseHp: 0, baseRegen: 0),
        .init(baseName: "Staff",      slot: .weapon, iconName: "eq_staff",       baseAtk: 2, baseDef: 0, baseHp: 0, baseRegen: 0),
        .init(baseName: "Arcane Rod", slot: .weapon, iconName: "eq_magic_staff", baseAtk: 3, baseDef: 0, baseHp: 0, baseRegen: 0),
    ]

    private static let armors: [EquipmentTemplate] = [
        .init(baseName: "Tunic",      slot: .armor, iconName: "eq_tunic",      baseAtk: 0, baseDef: 2, baseHp: 0, baseRegen: 0),
        .init(baseName: "Plate Mail", slot: .armor, iconName: "eq_plate",      baseAtk: 0, baseDef: 3, baseHp: 0, baseRegen: 0),
        .init(baseName: "Dark Armor", slot: .armor, iconName: "eq_dark_armor", baseAtk: 0, baseDef: 2, baseHp: 0, baseRegen: 0),
    ]

    private static let rings: [EquipmentTemplate] = [
        .init(baseName: "Ring of Power",   slot: .ring, iconName: "eq_ring",     baseAtk: 1, baseDef: 0, baseHp: 15, baseRegen: 0),
        .init(baseName: "Ring of Life",    slot: .ring, iconName: "eq_gem_ring", baseAtk: 0, baseDef: 0, baseHp: 20, baseRegen: 1),
    ]
}

// MARK: - Drop generation

enum EquipmentDrop {
    static let inventoryLimit = 15

    static func roll(floor: Int) -> Equipment? {
        let dropChance = 0.15 + Double(floor) * 0.001
        guard Double.random(in: 0...1) < dropChance else { return nil }
        let rarity   = rollRarity(floor: floor)
        let slot     = EquipmentSlot.allCases.randomElement()!
        let template = EquipmentTemplate.pool(for: slot).randomElement()!
        return template.generate(rarity: rarity, floor: floor)
    }

    private static func rollRarity(floor: Int) -> ItemRarity {
        let f = min(floor, 100)
        // Epic unlocks at floor 20, Legendary at floor 50
        let weights: [(ItemRarity, Int)] = [
            (.common,    max(10, 75 - f / 3)),
            (.uncommon,  20),
            (.rare,      max( 1,  3 + f / 6)),
            (.epic,      f >= 20 ? max(1, (f - 18) / 8) : 0),
            (.legendary, f >= 50 ? max(1, (f - 48) / 15) : 0),
        ]
        let total = weights.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return .common }
        var roll  = Int.random(in: 0..<total)
        for (rarity, weight) in weights {
            roll -= weight
            if roll < 0 { return rarity }
        }
        return .common
    }

    // Boss fights always drop an item, minimum Uncommon rarity
    static func rollBoss(floor: Int) -> Equipment? {
        let rarity   = rollBossRarity(floor: floor)
        let slot     = EquipmentSlot.allCases.randomElement()!
        let template = EquipmentTemplate.pool(for: slot).randomElement()!
        return template.generate(rarity: rarity, floor: floor)
    }

    private static func rollBossRarity(floor: Int) -> ItemRarity {
        let f = min(floor, 100)
        // No common drops from bosses; Epic unlocks floor 10, Legendary floor 30
        let weights: [(ItemRarity, Int)] = [
            (.uncommon,  max(5, 50 - f / 3)),
            (.rare,      max(5, 25 + f / 6)),
            (.epic,      f >= 10 ? max(1, (f - 8) / 8) : 0),
            (.legendary, f >= 30 ? max(1, (f - 28) / 15) : 0),
        ]
        let total = weights.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return .uncommon }
        var roll  = Int.random(in: 0..<total)
        for (rarity, weight) in weights {
            roll -= weight
            if roll < 0 { return rarity }
        }
        return .uncommon
    }
}
