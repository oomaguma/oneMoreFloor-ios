import Foundation

// MARK: - Active Effect

struct ActiveEffect: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String
    let isBlessing: Bool
    let atkMod: Int
    let defMod: Int
    let maxHpMod: Int
    let regenMod: Int
}

// MARK: - Usable Item

enum UsableItemKind: String, Codable {
    case fullHeal
    case revive
}

struct UsableItem: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String
    let kind: UsableItemKind
}

// MARK: - Floor Event

struct FloorEvent: Codable, Identifiable {
    let id: UUID
    let template: FloorEventTemplate

    init(template: FloorEventTemplate) {
        self.id = UUID()
        self.template = template
    }
}

// MARK: - Floor Event Template

enum FloorEventTemplate: String, Codable, CaseIterable {
    // Blessings (free)
    case ancientShrine, goldCache, atkBlessing, defBlessing, regenBlessing, reviveBlessing
    // Shrines (pay gold for buff)
    case bloodPactAltar, ironForge, lifeVessel
    // Curses (50/50 gamble)
    case cursedSigil, witherTouch, voidFog
    // Mystery (random outcome)
    case strangeAltar

    // MARK: Category

    enum Category { case blessing, shrine, curse, mystery }

    var category: Category {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing, .reviveBlessing:
            return .blessing
        case .bloodPactAltar, .ironForge, .lifeVessel:
            return .shrine
        case .cursedSigil, .witherTouch, .voidFog:
            return .curse
        case .strangeAltar:
            return .mystery
        }
    }

    // MARK: Display

    var icon: String {
        switch self {
        case .ancientShrine:  return "⛩️"
        case .goldCache:      return "💰"
        case .atkBlessing:    return "⚔️"
        case .defBlessing:    return "🛡️"
        case .regenBlessing:  return "💉"
        case .reviveBlessing: return "🔮"
        case .bloodPactAltar: return "🩸"
        case .ironForge:      return "⚒️"
        case .lifeVessel:     return "💎"
        case .cursedSigil:    return "💀"
        case .witherTouch:    return "👻"
        case .voidFog:        return "🌫️"
        case .strangeAltar:   return "❓"
        }
    }

    var title: String {
        switch self {
        case .ancientShrine:  return "Ancient Shrine"
        case .goldCache:      return "Gold Cache"
        case .atkBlessing:    return "War God's Mark"
        case .defBlessing:    return "Iron Will"
        case .regenBlessing:  return "Life Spring"
        case .reviveBlessing: return "Phoenix Blessing"
        case .bloodPactAltar: return "Blood Pact Altar"
        case .ironForge:      return "Iron Forge"
        case .lifeVessel:     return "Life Vessel"
        case .cursedSigil:    return "Cursed Sigil"
        case .witherTouch:    return "Wither Touch"
        case .voidFog:        return "Void Fog"
        case .strangeAltar:   return "Strange Altar"
        }
    }

    var flavorText: String {
        switch self {
        case .ancientShrine:  return "A warm glow pulses from an old stone shrine."
        case .goldCache:      return "A crumbling wall reveals a hidden merchant's stash."
        case .atkBlessing:    return "Ancient runes burn bright, granting a warrior's strength."
        case .defBlessing:    return "A shimmering ward settles over your armor like cold iron."
        case .regenBlessing:  return "Enchanted water seeps from the stone, healing as you walk."
        case .reviveBlessing: return "A spectral flame flickers above the shrine — death may not be the end."
        case .bloodPactAltar: return "A dark altar offers power in exchange for gold."
        case .ironForge:      return "A dwarven forge flickers — it can temper your defenses."
        case .lifeVessel:     return "A crystalline vessel pulses with lifegiving energy."
        case .cursedSigil:    return "Dark runes pulse with wild energy — power or pain in equal measure."
        case .witherTouch:    return "The spectral hand offers strength or sorrow. The choice is the gamble."
        case .voidFog:        return "The mist churns unpredictably — boon or bane, you won't know until it's done."
        case .strangeAltar:   return "An unmarked altar hums with unknown energy. Risky — but tempting."
        }
    }

    // MARK: Primary action

    var primaryLabel: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing, .reviveBlessing:
            return "ACCEPT"
        case .bloodPactAltar, .ironForge: return "OFFER  50g"
        case .lifeVessel:                 return "OFFER  40g"
        case .cursedSigil, .witherTouch, .voidFog:
            return "GAMBLE"
        case .strangeAltar:               return "RISK IT  30g"
        }
    }

    var primaryGoldCost: Int {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing, .reviveBlessing:
            return 0
        case .bloodPactAltar, .ironForge: return 50
        case .lifeVessel:                 return 40
        case .cursedSigil, .witherTouch, .voidFog:
            return 0
        case .strangeAltar:               return 30
        }
    }

    var primaryEffectSummary: String {
        switch self {
        case .ancientShrine:  return "Add Holy Vial to bag"
        case .goldCache:      return "+50 Gold"
        case .atkBlessing:    return "+2 ATK (this run)"
        case .defBlessing:    return "+2 DEF (this run)"
        case .regenBlessing:  return "+1 Regen (this run)"
        case .reviveBlessing: return "Add Phoenix Charm to bag"
        case .bloodPactAltar: return "+5 ATK (this run)"
        case .ironForge:      return "+5 DEF (this run)"
        case .lifeVessel:     return "+40 Max HP (this run)"
        case .cursedSigil:    return "50% +3 ATK / 50% −3 ATK"
        case .witherTouch:    return "50% +15 Max HP / 50% −15 Max HP"
        case .voidFog:        return "50% heal 25% HP / 50% lose 25% HP"
        case .strangeAltar:   return "60% blessing / 40% curse"
        }
    }

    // MARK: Secondary action

    var secondaryLabel: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing, .reviveBlessing:
            return "SKIP"
        case .bloodPactAltar, .ironForge, .lifeVessel, .strangeAltar:
            return "PASS"
        case .cursedSigil, .witherTouch, .voidFog:
            return "FLEE"
        }
    }

    var secondaryEffectSummary: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing, .reviveBlessing:
            return "Nothing happens"
        case .bloodPactAltar, .ironForge, .lifeVessel, .strangeAltar:
            return "Nothing happens"
        case .cursedSigil, .witherTouch, .voidFog:
            return "Nothing happens"
        }
    }

    // MARK: Pool

    static func random() -> FloorEventTemplate {
        // Blessings most common; curses and shrines moderate; revive and mystery rare
        let pool: [FloorEventTemplate] = [
            .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
            .ancientShrine, .goldCache, .atkBlessing,   // extra weight for blessings
            .bloodPactAltar, .ironForge, .lifeVessel,
            .cursedSigil, .witherTouch, .voidFog,
            .strangeAltar, .reviveBlessing              // revive is very rare
        ]
        return pool.randomElement()!
    }
}
