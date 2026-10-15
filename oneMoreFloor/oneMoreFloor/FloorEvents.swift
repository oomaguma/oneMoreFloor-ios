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
    // Triggered effects added in v2 — these fire on combat events rather than
    // modifying base stats directly, so they are NOT applied in applyAndRecord /
    // stripActiveEffects. They default to 0 so saves from before this field
    // existed still decode cleanly via the custom init(from:) below.
    let onKillHealPercent: Double   // % of max HP restored on each kill
    let thornsDamagePercent: Double  // % of incoming damage reflected back to the attacker
    let splashDamagePercent: Double  // % of strike damage dealt to adjacent enemies (raid only)

    init(id: UUID = UUID(), name: String, icon: String, isBlessing: Bool,
         atkMod: Int = 0, defMod: Int = 0, maxHpMod: Int = 0, regenMod: Int = 0,
         onKillHealPercent: Double = 0, thornsDamagePercent: Double = 0,
         splashDamagePercent: Double = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isBlessing = isBlessing
        self.atkMod = atkMod
        self.defMod = defMod
        self.maxHpMod = maxHpMod
        self.regenMod = regenMod
        self.onKillHealPercent = onKillHealPercent
        self.thornsDamagePercent = thornsDamagePercent
        self.splashDamagePercent = splashDamagePercent
    }

    // Custom decoder: any key absent in older saves falls back to 0 rather
    // than crashing. The synthesised encoder still writes all fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(UUID.self,   forKey: .id)
        name            = try c.decode(String.self, forKey: .name)
        icon            = try c.decode(String.self, forKey: .icon)
        isBlessing      = try c.decode(Bool.self,   forKey: .isBlessing)
        atkMod          = try c.decode(Int.self,    forKey: .atkMod)
        defMod          = try c.decode(Int.self,    forKey: .defMod)
        maxHpMod        = try c.decode(Int.self,    forKey: .maxHpMod)
        regenMod        = try c.decode(Int.self,    forKey: .regenMod)
        onKillHealPercent   = try c.decodeIfPresent(Double.self, forKey: .onKillHealPercent)   ?? 0
        thornsDamagePercent = try c.decodeIfPresent(Double.self, forKey: .thornsDamagePercent) ?? 0
        splashDamagePercent = try c.decodeIfPresent(Double.self, forKey: .splashDamagePercent) ?? 0
    }
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
    // Blessings (free) — flat stat boosts
    case ancientShrine, goldCache, atkBlessing, defBlessing, regenBlessing, reviveBlessing
    // Blessings (free) — triggered effects that shine in multi-enemy situations
    case bloodRush, thornMantle
    // Shrines (pay gold for buff) — flat stat boosts
    case bloodPactAltar, ironForge, lifeVessel
    // Shrines (pay gold for buff) — triggered effect
    case warSurge
    // Curses (50/50 gamble)
    case cursedSigil, witherTouch, voidFog
    // Mystery (random outcome)
    case strangeAltar

    // MARK: Category

    enum Category { case blessing, shrine, curse, mystery }

    var category: Category {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
             .reviveBlessing, .bloodRush, .thornMantle:
            return .blessing
        case .bloodPactAltar, .ironForge, .lifeVessel, .warSurge:
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
        case .bloodRush:      return "❤️‍🔥"
        case .thornMantle:    return "🌿"
        case .bloodPactAltar: return "🩸"
        case .ironForge:      return "⚒️"
        case .lifeVessel:     return "💎"
        case .warSurge:       return "💥"
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
        case .bloodRush:      return "Blood Rush"
        case .thornMantle:    return "Thorn Mantle"
        case .bloodPactAltar: return "Blood Pact Altar"
        case .ironForge:      return "Iron Forge"
        case .lifeVessel:     return "Life Vessel"
        case .warSurge:       return "War Surge"
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
        case .bloodRush:      return "Each fallen foe feeds the fire within. Kill to survive."
        case .thornMantle:    return "Razor bark weaves into your skin. Strike me, and bleed."
        case .bloodPactAltar: return "A dark altar offers power in exchange for gold."
        case .ironForge:      return "A dwarven forge flickers — it can temper your defenses."
        case .lifeVessel:     return "A crystalline vessel pulses with lifegiving energy."
        case .warSurge:       return "The altar thrums with violent potential — one blow becomes many."
        case .cursedSigil:    return "Dark runes pulse with wild energy — power or pain in equal measure."
        case .witherTouch:    return "The spectral hand offers strength or sorrow. The choice is the gamble."
        case .voidFog:        return "The mist churns unpredictably — boon or bane, you won't know until it's done."
        case .strangeAltar:   return "An unmarked altar hums with unknown energy. Risky — but tempting."
        }
    }

    // MARK: Primary action

    var primaryLabel: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
             .reviveBlessing, .bloodRush, .thornMantle:
            return "ACCEPT"
        case .bloodPactAltar, .ironForge: return "OFFER  50g"
        case .lifeVessel:                 return "OFFER  40g"
        case .warSurge:                   return "OFFER  50g"
        case .cursedSigil, .witherTouch, .voidFog:
            return "GAMBLE"
        case .strangeAltar:               return "RISK IT  30g"
        }
    }

    var primaryGoldCost: Int {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
             .reviveBlessing, .bloodRush, .thornMantle:
            return 0
        case .bloodPactAltar, .ironForge: return 50
        case .lifeVessel:                 return 40
        case .warSurge:                   return 50
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
        case .bloodRush:      return "On kill: restore 8% max HP"
        case .thornMantle:    return "On hit: reflect 20% damage back"
        case .bloodPactAltar: return "+5 ATK (this run)"
        case .ironForge:      return "+5 DEF (this run)"
        case .lifeVessel:     return "+40 Max HP (this run)"
        case .warSurge:       return "On hit: splash 40% to nearby foe"
        case .cursedSigil:    return "50% +3 ATK / 50% −3 ATK"
        case .witherTouch:    return "50% +15 Max HP / 50% −15 Max HP"
        case .voidFog:        return "50% heal 25% HP / 50% lose 25% HP"
        case .strangeAltar:   return "60% blessing / 40% curse"
        }
    }

    // MARK: Secondary action

    var secondaryLabel: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
             .reviveBlessing, .bloodRush, .thornMantle:
            return "SKIP"
        case .bloodPactAltar, .ironForge, .lifeVessel, .warSurge, .strangeAltar:
            return "PASS"
        case .cursedSigil, .witherTouch, .voidFog:
            return "FLEE"
        }
    }

    var secondaryEffectSummary: String {
        switch self {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
             .reviveBlessing, .bloodRush, .thornMantle:
            return "Nothing happens"
        case .bloodPactAltar, .ironForge, .lifeVessel, .warSurge, .strangeAltar:
            return "Nothing happens"
        case .cursedSigil, .witherTouch, .voidFog:
            return "Nothing happens"
        }
    }

    // MARK: Pool

    static func random() -> FloorEventTemplate {
        // Blessings most common; triggered blessings and shrines moderate; revive and mystery rare.
        let pool: [FloorEventTemplate] = [
            .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing,
            .ancientShrine, .goldCache, .atkBlessing,   // extra weight for the most common blessings
            .bloodRush, .thornMantle,                   // triggered blessings — same tier as shrines
            .bloodPactAltar, .ironForge, .lifeVessel,
            .cursedSigil, .witherTouch, .voidFog,
            .warSurge,                                  // triggered shrine
            .strangeAltar, .reviveBlessing              // revive and mystery are rare
        ]
        return pool.randomElement()!
    }
}
