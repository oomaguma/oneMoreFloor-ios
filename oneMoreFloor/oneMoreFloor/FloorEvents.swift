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
    case ancientShrine, goldCache, atkBlessing, defBlessing, regenBlessing
    // Shrines (pay gold for buff)
    case bloodPactAltar, ironForge, lifeVessel
    // Curses (debuff, or pay gold to resist)
    case cursedSigil, witherTouch, voidFog
    // Mystery (random outcome)
    case strangeAltar

    // MARK: Category

    enum Category { case blessing, shrine, curse, mystery }

    var category: Category {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing:
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
        case .bloodPactAltar: return "A dark altar offers power in exchange for gold."
        case .ironForge:      return "A dwarven forge flickers — it can temper your defenses."
        case .lifeVessel:     return "A crystalline vessel pulses with lifegiving energy."
        case .cursedSigil:    return "Dark runes sear into the stone before you."
        case .witherTouch:    return "A spectral hand reaches out, hungry for your vitality."
        case .voidFog:        return "A creeping mist drains your life force with every breath."
        case .strangeAltar:   return "An unmarked altar hums with unknown energy. Risky — but tempting."
        }
    }

    // MARK: Primary action

    var primaryLabel: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing:
            return "ACCEPT"
        case .bloodPactAltar, .ironForge: return "OFFER  50g"
        case .lifeVessel:                 return "OFFER  40g"
        case .cursedSigil:                return "RESIST  60g"
        case .witherTouch:                return "WARD  40g"
        case .voidFog:                    return "FLEE  30g"
        case .strangeAltar:               return "RISK IT  30g"
        }
    }

    var primaryGoldCost: Int {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing:
            return 0
        case .bloodPactAltar, .ironForge: return 50
        case .lifeVessel:                 return 40
        case .cursedSigil:                return 60
        case .witherTouch:                return 40
        case .voidFog:                    return 30
        case .strangeAltar:               return 30
        }
    }

    var primaryEffectSummary: String {
        switch self {
        case .ancientShrine:  return "Restore HP to full"
        case .goldCache:      return "+50 Gold"
        case .atkBlessing:    return "+2 ATK (this run)"
        case .defBlessing:    return "+2 DEF (this run)"
        case .regenBlessing:  return "+1 Regen (this run)"
        case .bloodPactAltar: return "+5 ATK (this run)"
        case .ironForge:      return "+5 DEF (this run)"
        case .lifeVessel:     return "+40 Max HP (this run)"
        case .cursedSigil:    return "Avoid −3 ATK curse"
        case .witherTouch:    return "Avoid −15 Max HP curse"
        case .voidFog:        return "Avoid losing 25% HP"
        case .strangeAltar:   return "60% blessing / 40% curse"
        }
    }

    // MARK: Secondary action

    var secondaryLabel: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing:
            return "SKIP"
        case .bloodPactAltar, .ironForge, .lifeVessel, .strangeAltar:
            return "PASS"
        case .cursedSigil, .witherTouch:
            return "ACCEPT"
        case .voidFog:
            return "ENDURE"
        }
    }

    var secondaryEffectSummary: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing:
            return "Nothing happens"
        case .bloodPactAltar, .ironForge, .lifeVessel, .strangeAltar:
            return "Nothing happens"
        case .cursedSigil: return "−3 ATK (this run)"
        case .witherTouch: return "−15 Max HP (this run)"
        case .voidFog:     return "Lose 25% current HP"
        }
    }

    // MARK: Pool

    static func random() -> FloorEventTemplate {
        // Blessings are most common; curses less common; mystery rare
        let pool: [FloorEventTemplate] = [
            .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
            .ancientShrine, .goldCache, .atkBlessing,   // extra weight for blessings
            .bloodPactAltar, .ironForge, .lifeVessel,
            .cursedSigil, .witherTouch, .voidFog,
            .strangeAltar
        ]
        return pool.randomElement()!
    }
}
