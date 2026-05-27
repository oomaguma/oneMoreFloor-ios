import Foundation
import Observation

// MARK: - Daily Quests

enum DailyQuestType: String, Codable {
    case killAny, killBoss, earnGold, clearFloors, reachFloor
}

struct DailyQuest: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let type: DailyQuestType
    let goalCount: Int
    let rewardGold: Int
    var progress: Int = 0
    var claimed: Bool = false

    var isComplete: Bool { progress >= goalCount }
    var progressFraction: Double {
        goalCount > 0 ? min(1.0, Double(progress) / Double(goalCount)) : 0
    }
    var progressLabel: String { "\(min(progress, goalCount)) / \(goalCount)" }
}

// MARK: - Other model types

struct BossVictory {
    let stageLabel: String
    let zoneName: String
    let zoneIcon: String
    let bossName: String
    let goldEarned: Int
}

struct OfflineSummary {
    let goldEarned: Int
    let deaths: Int
    let floorsCleared: Int
    let deepestFloor: Int
    let duration: TimeInterval

    var hasContent: Bool { goldEarned > 0 || deaths > 0 }

    var durationString: String {
        let s = Int(duration)
        let h = s / 3600; let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }
}

struct Zone: Identifiable {
    let id: String
    let name: String
    let shortName: String
    let icon: String
    let minFloor: Int
    let maxFloor: Int?
}

struct Upgrade: Identifiable {
    let id: String
    let name: String
    let baseCost: Int
    var level: Int = 0
    var unlockFloor: Int = 0

    var cost: Int { baseCost * (level + 1) * (level + 1) }

    var currentEffect: String {
        switch id {
        case "atk":      return level == 0 ? "+1 ATK per level"           : "ATK +\(level)"
        case "def":      return level == 0 ? "+1 DEF per level"           : "DEF +\(level)"
        case "maxhp":    return level == 0 ? "+10 MaxHP per level"        : "MaxHP +\(level * 10)"
        case "regen":    return level == 0 ? "+1 HP regen per level"      : "Regen \(level)/s"
        case "goldmult": return level == 0 ? "+10% gold per level"        : "Gold +\(level * 10)%"
        case "speed":    return level == 0 ? "+5% attack speed per level" : "Speed +\(level * 5)%"
        default:         return "Lv\(level)"
        }
    }
}

struct PrestigeUpgrade: Identifiable {
    let id: String
    let name: String
    let detail: String
    let shardCost: Int
    let maxLevel: Int
    var level: Int = 0

    var isMaxed: Bool { level >= maxLevel }

    var currentEffect: String {
        switch id {
        case "constitution": return "MaxHP +\(level * 20) at run start"
        case "goldrush":     return "Gold +\(level * 15)% bonus"
        case "veteran":      return "Start with Regen \(level)/s"
        case "cunning":      return "Upgrades cost -\(level * 10)%"
        case "hunger":       return "Prestige from floor \(max(1, 5 - level * 2))+"
        case "speed":        return "Attack \(level * 6)% faster always"
        case "autorestart":  return "Auto-restart on death"
        case "warchest":     return "Start each run with \(level * 50) gold"
        case "autosell":
            if level == 0 { return "Auto-sell Common drops" }
            return "Auto-sell ≤ \(ItemRarity.allCases[level - 1].label)"
        default:             return "Lv\(level)"
        }
    }
}

@Observable
class DungeonGame {
    var heroHp: Int
    var heroMaxHp: Int
    var heroAtk: Int
    var heroDef: Int
    var heroRegen: Int

    var gold: Int = 0
    var currentFloor: Int = 1
    var deepestFloor: Int = 0
    var soulShards: Int = 0
    var deepestFloorEver: Int = 0
    var isGameOver: Bool = false

    private(set) var characterID: String
    var character: CharacterClass {
        CharacterClass.all.first { $0.id == characterID } ?? .soldier
    }

    var currentEnemyType: EnemyType?

    private var monsterHp: Int = 0
    private var monsterMaxHp: Int = 0
    private var monsterAtk: Int = 0
    private var monsterName: String = ""
    private var inCombat: Bool = false
    private var ticksUntilFight: Int = 3
    private(set) var currentFightFloor: Int = 0

    var upgrades: [Upgrade] = [
        Upgrade(id: "atk",      name: "Sharpen Blade", baseCost: 3,  unlockFloor: 0),
        Upgrade(id: "def",      name: "Forge Armor",   baseCost: 4,  unlockFloor: 0),
        Upgrade(id: "maxhp",    name: "Fortify Body",  baseCost: 5,  unlockFloor: 11),
        Upgrade(id: "regen",    name: "Meditate",      baseCost: 6,  unlockFloor: 11),
        Upgrade(id: "goldmult", name: "Eye for Loot",  baseCost: 7,  unlockFloor: 21),
        Upgrade(id: "speed",    name: "Swift Strikes", baseCost: 5,  unlockFloor: 21),
    ]

    var prestigeUpgrades: [PrestigeUpgrade] = [
        PrestigeUpgrade(id: "warchest",     name: "War Chest",         detail: "Start each prestige run with bonus gold", shardCost: 2,  maxLevel: 5),
        PrestigeUpgrade(id: "constitution", name: "Iron Constitution", detail: "+20 MaxHP per level at run start",        shardCost: 10, maxLevel: 5),
        PrestigeUpgrade(id: "goldrush",     name: "Gold Rush",         detail: "+15% gold earned per level",              shardCost: 8,  maxLevel: 5),
        PrestigeUpgrade(id: "veteran",      name: "Veteran's Blood",   detail: "Start each run with base regen",          shardCost: 12, maxLevel: 3),
        PrestigeUpgrade(id: "cunning",      name: "Cunning Mind",      detail: "Reduce upgrade gold costs per level",     shardCost: 12, maxLevel: 3),
        PrestigeUpgrade(id: "hunger",       name: "Endless Hunger",    detail: "Lower prestige floor requirement",        shardCost: 20, maxLevel: 2),
        PrestigeUpgrade(id: "speed",        name: "Battle Hardened",   detail: "Permanently faster attack speed",         shardCost: 12, maxLevel: 3),
        PrestigeUpgrade(id: "autorestart",  name: "Undying Will",      detail: "Automatically restart on death",          shardCost: 30, maxLevel: 1),
        PrestigeUpgrade(id: "autosell",     name: "Merchant's Eye",    detail: "Auto-sell drops below a rarity threshold", shardCost: 12, maxLevel: 3),
    ]

    var combatLog: [String] = []

    // MARK: - Equipment
    var equippedItems: [String: Equipment] = [:]
    var inventory: [Equipment] = []
    var pendingDrop: Equipment? = nil
    var pendingBossVictory: BossVictory? = nil
    var pendingFloorEvent: FloorEvent? = nil
    var activeEffects: [ActiveEffect] = []
    private(set) var appliedSetBonus: ItemRarity? = nil

    // MARK: - Zone unlock
    var pendingZoneUnlock: Zone? = nil

    // MARK: - Daily Quests
    private(set) var dailyQuests: [DailyQuest] = []
    private var dailyQuestDateString: String = ""
    private(set) var dailyCompletionBonusClaimed: Bool = false

    // MARK: - Callbacks
    var onHeroAttack: (() -> Void)?
    var onHeroHurt:   (() -> Void)?
    var onHeroDeath:  (() -> Void)?
    var onHeroBlock:  (() -> Void)?
    var onHeroCrit:   ((Int) -> Void)?
    var onHeroHeal:   ((Int) -> Void)?

    var onMonsterSpawn:  ((EnemyType) -> Void)?
    var onMonsterHurt:   (() -> Void)?
    var onMonsterAttack: (() -> Void)?
    var onMonsterDeath:  (() -> Void)?

    var onHeroDamageTaken:    ((Int) -> Void)?
    var onMonsterDamageTaken: ((Int) -> Void)?
    var onGoldEarned:         ((Int) -> Void)?

    var displayMonsterHp:    Int    = 0
    var displayMonsterMaxHp: Int    = 0
    var displayMonsterName:  String = ""

    // MARK: - Zone / enemy data

    static let zones: [Zone] = [
        Zone(id: "entrance", name: "Dungeon Entrance", shortName: "Entrance",  icon: "▪", minFloor: 1,  maxFloor: 10),
        Zone(id: "crypts",   name: "The Crypts",       shortName: "Crypts",    icon: "✦", minFloor: 11, maxFloor: 20),
        Zone(id: "orc",      name: "Orc Stronghold",   shortName: "Orc Fort",  icon: "◆", minFloor: 21, maxFloor: 30),
        Zone(id: "sunken",   name: "Sunken City",       shortName: "Sunken",    icon: "≈", minFloor: 31, maxFloor: 40),
        Zone(id: "abyss",    name: "The Abyss",         shortName: "Abyss",     icon: "▼", minFloor: 41, maxFloor: 50),
        Zone(id: "citadel",  name: "Iron Citadel",      shortName: "Citadel",   icon: "△", minFloor: 51, maxFloor: 60),
        Zone(id: "hellgate", name: "Hell's Gate",       shortName: "Hell Gate", icon: "∞", minFloor: 61, maxFloor: nil),
    ]

    static let zoneEnemyPools: [String: [EnemyType]] = [
        "entrance": [.slime, .skeleton],
        "crypts":   [.skeleton, .skeletonArcher, .armoredSkeleton],
        "orc":      [.orc, .orcRider],
        "sunken":   [.werebear, .werewolf],
        "abyss":    [.eliteOrc, .armoredOrc],
        "citadel":  [.armoredAxeman, .greatswordSkeleton],
        "hellgate": [.armoredOrc, .eliteOrc, .greatswordSkeleton],
    ]

    static let zoneBossEnemies: [String: EnemyType] = [
        "entrance": .skeleton,
        "crypts":   .armoredSkeleton,
        "orc":      .orcRider,
        "sunken":   .werebear,
        "abyss":    .armoredOrc,
        "citadel":  .greatswordSkeleton,
        "hellgate": .greatswordSkeleton,
    ]

    static func stageLabel(floor: Int) -> String {
        let zone  = (floor - 1) / 10 + 1
        let stage = (floor - 1) % 10 + 1
        return "\(zone)-\(stage)"
    }

    static func isBoss(floor: Int) -> Bool { floor % 10 == 0 }

    // MARK: - Computed properties

    private var goldMultiplier: Double {
        let runLvl      = upgrades.first(where: { $0.id == "goldmult" })?.level ?? 0
        let prestigeLvl = prestigeUpgrades.first(where: { $0.id == "goldrush" })?.level ?? 0
        return 1.0 + Double(runLvl) * 0.10 + Double(prestigeLvl) * 0.15
    }

    var prestigeThreshold: Int {
        let hungerLevel = prestigeUpgrades.first(where: { $0.id == "hunger" })?.level ?? 0
        return max(1, 5 - hungerLevel * 2)
    }

    func effectiveCost(for upgrade: Upgrade) -> Int {
        let cunningLevel = prestigeUpgrades.first(where: { $0.id == "cunning" })?.level ?? 0
        let discount = 1.0 - Double(cunningLevel) * 0.10
        return max(1, Int(Double(upgrade.cost) * discount))
    }

    var autoRestartEnabled: Bool {
        (prestigeUpgrades.first(where: { $0.id == "autorestart" })?.level ?? 0) > 0
    }

    var currentZone: Zone {
        DungeonGame.zones.last(where: { currentFloor >= $0.minFloor }) ?? DungeonGame.zones[0]
    }

    var currentStageLabel: String { DungeonGame.stageLabel(floor: currentFloor) }

    var displayIsBoss: Bool {
        guard displayMonsterMaxHp > 0 else { return false }
        return DungeonGame.isBoss(floor: currentFightFloor)
    }

    var tickInterval: Double {
        let runLvl      = upgrades.first(where: { $0.id == "speed" })?.level ?? 0
        let prestigeLvl = prestigeUpgrades.first(where: { $0.id == "speed" })?.level ?? 0
        return max(0.30, 0.80 - Double(runLvl) * 0.05 - Double(prestigeLvl) * 0.06)
    }

    private var equippedSetBonusRarity: ItemRarity? {
        guard equippedItems.count == EquipmentSlot.allCases.count else { return nil }
        let rarities = Set(equippedItems.values.map { $0.rarity })
        return rarities.count == 1 ? rarities.first : nil
    }

    var hasClaimableQuest: Bool {
        dailyQuests.contains { $0.isComplete && !$0.claimed } ||
        (!dailyCompletionBonusClaimed && dailyQuests.allSatisfy { $0.claimed })
    }

    var allQuestsClaimed: Bool {
        !dailyQuests.isEmpty && dailyQuests.allSatisfy { $0.claimed }
    }

    // MARK: - Init

    init(character: CharacterClass) {
        characterID = character.id
        heroMaxHp   = character.baseHP
        heroHp      = character.baseHP
        heroAtk     = character.baseATK
        heroDef     = character.baseDEF
        heroRegen   = character.baseRegen

        let today = DungeonGame.todayDateKey()
        dailyQuestDateString = today
        dailyQuests = DungeonGame.selectQuestsForDay(today)
    }

    // MARK: - Gameplay

    func log(_ msg: String) {
        combatLog.append(msg)
        if combatLog.count > 60 { combatLog.removeFirst() }
    }

    func tick() {
        guard !isGameOver else { return }

        if heroHp <= 0 {
            isGameOver = true
            inCombat   = false
            log("Hero has fallen. Tap Restart to try again.")
            onHeroDeath?()
            return
        }

        if inCombat {
            doCombatTick()
        } else {
            if heroRegen > 0 && heroHp < heroMaxHp {
                heroHp = min(heroMaxHp, heroHp + heroRegen)
            }
            ticksUntilFight -= 1
            if ticksUntilFight <= 0 { spawnMonster() }
        }
    }

    func restart() {
        stripActiveEffects()
        pendingFloorEvent   = nil
        heroHp              = heroMaxHp
        currentFloor        = 1
        currentFightFloor   = 0
        inCombat            = false
        ticksUntilFight     = 3
        isGameOver          = false
        pendingBossVictory  = nil
        pendingZoneUnlock   = nil
        displayMonsterHp    = 0
        displayMonsterMaxHp = 0
        displayMonsterName  = ""
        log("The hero rises again. Descending...")
        checkAndRefreshDailyQuests()
    }

    private func spawnMonster() {
        let f      = currentFloor
        currentFightFloor = f
        let isBoss = DungeonGame.isBoss(floor: f)

        let enemy: EnemyType
        if isBoss, let bossEnemy = DungeonGame.zoneBossEnemies[currentZone.id] {
            enemy = bossEnemy
        } else {
            let pool = DungeonGame.zoneEnemyPools[currentZone.id] ?? [.skeleton]
            enemy = pool.randomElement()!
        }

        currentEnemyType = enemy
        monsterName      = enemy.name
        monsterMaxHp     = isBoss ? Int(Double(enemy.hp(floor: f)) * 2.5) : enemy.hp(floor: f)
        monsterHp        = monsterMaxHp
        monsterAtk       = isBoss ? Int(Double(enemy.atk(floor: f)) * 1.5) : enemy.atk(floor: f)
        inCombat         = true
        displayMonsterHp    = monsterHp
        displayMonsterMaxHp = monsterMaxHp
        displayMonsterName  = monsterName
        onMonsterSpawn?(enemy)
        if isBoss {
            log("⚔ BOSS \(DungeonGame.stageLabel(floor: f)): \(monsterName) [\(monsterHp) hp] — Defeat for rewards!")
        } else {
            log("Stage \(DungeonGame.stageLabel(floor: f)): \(monsterName) [\(monsterHp) hp] appears!")
        }
    }

    private func doCombatTick() {
        onHeroAttack?()

        let isCrit  = Double.random(in: 0...1) < character.critChance
        let heroDmg = max(1, isCrit ? heroAtk * 2 : heroAtk)
        monsterHp -= heroDmg

        if monsterHp <= 0 {
            let killedOnFloor = currentFloor
            let isBossKill    = DungeonGame.isBoss(floor: killedOnFloor)
            let bossBonus     = isBossKill ? 3.0 : 1.0
            let earned = Int(Double(killedOnFloor + Int.random(in: 1...3)) * goldMultiplier * bossBonus)
            gold += earned
            inCombat        = false
            ticksUntilFight = 2

            let prevDeepest = deepestFloorEver
            currentFloor   += 1
            deepestFloorEver = max(deepestFloorEver, currentFloor)
            checkForFloorEvent()
            if currentFloor > deepestFloor {
                deepestFloor = currentFloor
                if deepestFloor > 1 && deepestFloor % 5 == 0 {
                    log("--- STAGE \(DungeonGame.stageLabel(floor: deepestFloor)) REACHED ---")
                }
            }

            // Quest progress
            updateQuestProgress(type: .killAny, value: 1)
            updateQuestProgress(type: .clearFloors, value: 1)
            updateQuestProgress(type: .earnGold, value: earned)
            updateQuestProgress(type: .reachFloor, value: currentFloor)
            if isBossKill { updateQuestProgress(type: .killBoss, value: 1) }

            // Zone unlock — first time ever entering this zone
            if let zone = DungeonGame.zones.first(where: { $0.minFloor == currentFloor }),
               zone.minFloor > 1, currentFloor > prevDeepest {
                pendingZoneUnlock = zone
            }

            if isCrit { onHeroCrit?(heroDmg) } else { onMonsterDamageTaken?(heroDmg) }
            onGoldEarned?(earned)
            onMonsterDeath?()
            displayMonsterHp    = 0
            displayMonsterMaxHp = 0
            displayMonsterName  = ""

            // Priest passive heal after each kill
            if character.healChance > 0 && Double.random(in: 0...1) < character.healChance {
                let healAmt = max(1, heroMaxHp / 8)
                heroHp = min(heroMaxHp, heroHp + healAmt)
                onHeroHeal?(healAmt)
                log("Divine light heals +\(healAmt) HP")
            }

            if isBossKill {
                let killedZone = DungeonGame.zones.last(where: { killedOnFloor >= $0.minFloor }) ?? DungeonGame.zones[0]
                pendingBossVictory = BossVictory(
                    stageLabel: DungeonGame.stageLabel(floor: killedOnFloor),
                    zoneName:   killedZone.name,
                    zoneIcon:   killedZone.icon,
                    bossName:   monsterName,
                    goldEarned: earned
                )
                log(isCrit
                    ? "⚡ CRITICAL BLOW! BOSS DEFEATED! +\(earned)g  |  Stage -> \(DungeonGame.stageLabel(floor: currentFloor))"
                    : "⚔ BOSS DEFEATED! +\(earned)g  |  Stage -> \(DungeonGame.stageLabel(floor: currentFloor))")
                if let drop = EquipmentDrop.rollBoss(floor: killedOnFloor) { receiveDrop(drop) }
            } else {
                log(isCrit
                    ? "⚡ CRIT! \(monsterName) slain! +\(earned)g  |  Stage -> \(DungeonGame.stageLabel(floor: currentFloor))"
                    : "\(monsterName) slain! +\(earned)g  |  Stage -> \(DungeonGame.stageLabel(floor: currentFloor))")
                if let drop = EquipmentDrop.roll(floor: killedOnFloor) { receiveDrop(drop) }
            }
        } else {
            onMonsterHurt?()
            if isCrit { onHeroCrit?(heroDmg) } else { onMonsterDamageTaken?(heroDmg) }
            displayMonsterHp = max(0, monsterHp)
            if isCrit {
                log("⚡ CRITICAL HIT! \(monsterName) takes \(heroDmg)! [\(monsterHp)/\(monsterMaxHp) hp]")
            } else {
                log("You strike \(monsterName) for \(heroDmg). [\(monsterHp)/\(monsterMaxHp) hp]")
            }

            // Knight/Paladin block passive
            let isBlocked = character.blockChance > 0 && Double.random(in: 0...1) < character.blockChance
            if isBlocked {
                onHeroBlock?()
                log("\(character.name) blocks the attack!")
            } else {
                let dmg = max(1, monsterAtk - heroDef)
                heroHp = max(0, heroHp - dmg)
                onMonsterAttack?()
                onHeroHurt?()
                onHeroDamageTaken?(dmg)
                log("\(monsterName) hits \(dmg) — Hero \(heroHp)/\(heroMaxHp)hp")
            }
        }
    }

    @discardableResult
    func buyUpgrade(id: String) -> Bool {
        guard let i = upgrades.firstIndex(where: { $0.id == id }) else { return false }
        let cost = effectiveCost(for: upgrades[i])
        guard gold >= cost else { return false }

        gold -= cost
        upgrades[i].level += 1
        let lvl = upgrades[i].level

        switch id {
        case "atk":
            heroAtk += 1
            log("Blade honed -> ATK \(heroAtk)")
        case "def":
            heroDef += 1
            log("Armor forged -> DEF \(heroDef)")
        case "maxhp":
            heroMaxHp += 10
            heroHp = min(heroHp + 10, heroMaxHp)
            log("Body fortified -> MaxHP \(heroMaxHp)")
        case "regen":
            heroRegen += 1
            log("Mind honed -> Regen \(heroRegen)/s")
        case "goldmult":
            log("Eye trained -> Gold +\(lvl * 10)%")
        case "speed":
            log("Strikes quickened -> Speed +\(lvl * 5)%")
        default:
            break
        }
        return true
    }

    @discardableResult
    func buyPrestigeUpgrade(id: String) -> Bool {
        guard let i = prestigeUpgrades.firstIndex(where: { $0.id == id }),
              !prestigeUpgrades[i].isMaxed,
              soulShards >= prestigeUpgrades[i].shardCost else { return false }

        soulShards -= prestigeUpgrades[i].shardCost
        prestigeUpgrades[i].level += 1
        let u = prestigeUpgrades[i]
        log("Unlocked: \(u.name) Lv\(u.level) — \(u.currentEffect)")
        return true
    }

    func prestigeShardValue() -> Int { max(0, deepestFloor - (prestigeThreshold - 1)) }
    func canPrestige() -> Bool       { prestigeShardValue() > 0 }

    func prestige() {
        guard canPrestige() else { return }
        let earned = prestigeShardValue()
        soulShards += earned

        log("=== PRESTIGE ===")
        log("Earned \(earned) Soul Shard\(earned == 1 ? "" : "s"). Total: \(soulShards)")
        log("Resetting run...")

        activeEffects      = []
        pendingFloorEvent  = nil
        currentFloor       = 1
        currentFightFloor  = 0
        deepestFloor       = 0
        inCombat           = false
        pendingBossVictory = nil
        pendingZoneUnlock  = nil
        ticksUntilFight    = 3
        upgrades           = upgrades.map { var u = $0; u.level = 0; return u }

        let warchestLevel     = prestigeUpgrades.first(where: { $0.id == "warchest" })?.level     ?? 0
        let constitutionLevel = prestigeUpgrades.first(where: { $0.id == "constitution" })?.level ?? 0
        let veteranLevel      = prestigeUpgrades.first(where: { $0.id == "veteran" })?.level      ?? 0

        gold      = warchestLevel * 50
        heroMaxHp = character.baseHP  + soulShards * 5 + constitutionLevel * 20
        heroAtk   = character.baseATK + soulShards / 2
        heroDef   = character.baseDEF
        heroRegen = character.baseRegen + veteranLevel
        for item in equippedItems.values {
            heroAtk   += item.atkBonus
            heroDef   += item.defBonus
            heroMaxHp += item.hpBonus
            heroRegen += item.regenBonus
        }
        // Re-apply set bonus from scratch
        appliedSetBonus = nil
        if let bonus = equippedSetBonusRarity {
            applySetBonusStats(bonus)
            appliedSetBonus = bonus
        }
        heroHp = heroMaxHp
        displayMonsterHp    = 0
        displayMonsterMaxHp = 0
        displayMonsterName  = ""

        var bonusParts = ["ATK \(heroAtk)", "MaxHP \(heroMaxHp)"]
        if heroRegen > 0 { bonusParts.append("Regen \(heroRegen)/s") }
        log("Bonuses: \(bonusParts.joined(separator: ", "))")
    }

    func revive() {
        heroHp             = heroMaxHp
        isGameOver         = false
        inCombat           = false
        currentFightFloor  = 0
        pendingBossVictory = nil
        ticksUntilFight    = 3
        displayMonsterHp    = 0
        displayMonsterMaxHp = 0
        displayMonsterName  = ""
        log("A divine force pulls you back from death. HP fully restored to \(heroHp).")
    }

    func immediateSpawn() {
        guard !inCombat && !isGameOver else { return }
        spawnMonster()
    }

    func dismissZoneUnlock() { pendingZoneUnlock = nil }

    // MARK: - Equipment methods

    func equip(item: Equipment) {
        let key = item.slot.rawValue
        if let old = equippedItems[key] {
            stripBonuses(of: old)
            addToInventory(old)
        }
        inventory.removeAll { $0.id == item.id }
        equippedItems[key] = item
        applyBonuses(of: item)
        updateSetBonus()
        log("Equipped \(item.rarity.label) \(item.name) [\(item.statSummary)]")
    }

    func unequip(slot: EquipmentSlot) {
        let key = slot.rawValue
        guard let item = equippedItems[key] else { return }
        stripBonuses(of: item)
        equippedItems.removeValue(forKey: key)
        updateSetBonus()
        addToInventory(item)
        log("Unequipped \(item.name)")
    }

    func sellItem(_ item: Equipment) {
        inventory.removeAll { $0.id == item.id }
        gold += item.sellValue
        log("Sold \(item.name) for \(item.sellValue)g")
    }

    func sellEquipped(slot: EquipmentSlot) {
        let key = slot.rawValue
        guard let item = equippedItems[key] else { return }
        stripBonuses(of: item)
        equippedItems.removeValue(forKey: key)
        updateSetBonus()
        gold += item.sellValue
        log("Sold \(item.name) for \(item.sellValue)g")
    }

    func optimizeEquipment() {
        for slot in EquipmentSlot.allCases {
            let equippedScore = equippedItems[slot.rawValue].map { itemScore($0) } ?? -1
            guard let best = inventory.filter({ $0.slot == slot }).max(by: { itemScore($0) < itemScore($1) }),
                  itemScore(best) > equippedScore else { continue }
            equip(item: best)
        }
    }

    private func itemScore(_ item: Equipment) -> Int {
        item.atkBonus + item.defBonus + item.hpBonus + item.regenBonus * 5
    }

    // MARK: - Floor Events

    private func checkForFloorEvent() {
        guard pendingFloorEvent == nil,
              pendingBossVictory == nil,
              !DungeonGame.isBoss(floor: currentFloor),
              currentFloor > 1 else { return }
        guard Double.random(in: 0...1) < 0.22 else { return }
        pendingFloorEvent = FloorEvent(template: FloorEventTemplate.random())
    }

    func resolveFloorEvent(primary: Bool) {
        guard let event = pendingFloorEvent else { return }
        pendingFloorEvent = nil
        let t = event.template

        if primary {
            let cost = t.primaryGoldCost
            if cost > 0 && gold < cost {
                // Can't afford — curses auto-apply, shrines/mystery just pass
                if t.category == .curse {
                    applySecondaryEffect(t)
                }
                log("Not enough gold (\(cost)g required).")
                return
            }
            gold -= cost
            applyPrimaryEffect(t)
        } else {
            applySecondaryEffect(t)
        }
    }

    private func applyPrimaryEffect(_ t: FloorEventTemplate) {
        switch t {
        case .ancientShrine:
            heroHp = heroMaxHp
            log("⛩️ The shrine restores your HP to full.")
        case .goldCache:
            gold += 50
            log("💰 You find 50 gold hidden in the rubble!")
        case .atkBlessing:
            applyAndRecord(ActiveEffect(id: UUID(), name: "War God's Mark", icon: "⚔️",
                                        isBlessing: true, atkMod: 2, defMod: 0, maxHpMod: 0, regenMod: 0))
            log("⚔️ War God's Mark: +2 ATK for this run!")
        case .defBlessing:
            applyAndRecord(ActiveEffect(id: UUID(), name: "Iron Will", icon: "🛡️",
                                        isBlessing: true, atkMod: 0, defMod: 2, maxHpMod: 0, regenMod: 0))
            log("🛡️ Iron Will: +2 DEF for this run!")
        case .regenBlessing:
            applyAndRecord(ActiveEffect(id: UUID(), name: "Life Spring", icon: "💉",
                                        isBlessing: true, atkMod: 0, defMod: 0, maxHpMod: 0, regenMod: 1))
            log("💉 Life Spring: +1 Regen for this run!")
        case .bloodPactAltar:
            applyAndRecord(ActiveEffect(id: UUID(), name: "Blood Pact", icon: "🩸",
                                        isBlessing: true, atkMod: 5, defMod: 0, maxHpMod: 0, regenMod: 0))
            log("🩸 Blood Pact sealed. +5 ATK for this run!")
        case .ironForge:
            applyAndRecord(ActiveEffect(id: UUID(), name: "Iron Forge", icon: "⚒️",
                                        isBlessing: true, atkMod: 0, defMod: 5, maxHpMod: 0, regenMod: 0))
            log("⚒️ Iron Forge tempered. +5 DEF for this run!")
        case .lifeVessel:
            applyAndRecord(ActiveEffect(id: UUID(), name: "Life Vessel", icon: "💎",
                                        isBlessing: true, atkMod: 0, defMod: 0, maxHpMod: 40, regenMod: 0))
            log("💎 Life Vessel: +40 Max HP for this run!")
        case .cursedSigil:
            log("💀 You resist the cursed sigil. -60 gold.")
        case .witherTouch:
            log("👻 You ward off the withering touch. -40 gold.")
        case .voidFog:
            log("🌫️ You flee the void fog. -30 gold.")
        case .strangeAltar:
            applyMysteryOutcome()
        }
    }

    private func applySecondaryEffect(_ t: FloorEventTemplate) {
        switch t {
        case .ancientShrine, .goldCache, .atkBlessing, .defBlessing, .regenBlessing:
            log("You pass by without stopping.")
        case .bloodPactAltar, .ironForge, .lifeVessel:
            log("You leave the altar untouched.")
        case .strangeAltar:
            log("You leave the strange altar behind.")
        case .cursedSigil:
            applyAndRecord(ActiveEffect(id: UUID(), name: "Cursed Sigil", icon: "💀",
                                        isBlessing: false, atkMod: -3, defMod: 0, maxHpMod: 0, regenMod: 0))
            log("💀 The sigil brands you. -3 ATK for this run!")
        case .witherTouch:
            applyAndRecord(ActiveEffect(id: UUID(), name: "Withered", icon: "👻",
                                        isBlessing: false, atkMod: 0, defMod: 0, maxHpMod: -15, regenMod: 0))
            log("👻 Wither Touch drains your vitality. -15 Max HP!")
        case .voidFog:
            let damage = max(1, heroHp / 4)
            heroHp = max(1, heroHp - damage)
            log("🌫️ The void fog saps \(damage) HP from you!")
        }
    }

    private func applyMysteryOutcome() {
        let lucky = Double.random(in: 0...1) < 0.60
        if lucky {
            let roll = Int.random(in: 0...2)
            switch roll {
            case 0:
                applyAndRecord(ActiveEffect(id: UUID(), name: "Strange Gift", icon: "✨",
                                            isBlessing: true, atkMod: 3, defMod: 0, maxHpMod: 0, regenMod: 0))
                log("❓ The altar blesses you! +3 ATK!")
            case 1:
                applyAndRecord(ActiveEffect(id: UUID(), name: "Strange Gift", icon: "✨",
                                            isBlessing: true, atkMod: 0, defMod: 3, maxHpMod: 0, regenMod: 0))
                log("❓ The altar blesses you! +3 DEF!")
            default:
                heroHp = heroMaxHp
                log("❓ The altar pulses with warmth. HP restored!")
            }
        } else {
            let roll = Int.random(in: 0...1)
            if roll == 0 {
                applyAndRecord(ActiveEffect(id: UUID(), name: "Strange Curse", icon: "💀",
                                            isBlessing: false, atkMod: -2, defMod: 0, maxHpMod: 0, regenMod: 0))
                log("❓ The altar curses you! -2 ATK!")
            } else {
                let damage = max(1, heroHp / 4)
                heroHp = max(1, heroHp - damage)
                log("❓ The altar drains you! -\(damage) HP!")
            }
        }
    }

    private func applyAndRecord(_ effect: ActiveEffect) {
        heroAtk   += effect.atkMod
        heroDef   += effect.defMod
        heroMaxHp += effect.maxHpMod
        heroRegen += effect.regenMod
        if effect.maxHpMod > 0 { heroHp = min(heroMaxHp, heroHp + effect.maxHpMod) }
        heroHp = min(heroHp, heroMaxHp)
        activeEffects.append(effect)
    }

    func stripActiveEffects() {
        for effect in activeEffects {
            heroAtk   = max(1, heroAtk   - effect.atkMod)
            heroDef   = max(0, heroDef   - effect.defMod)
            heroMaxHp = max(1, heroMaxHp - effect.maxHpMod)
            heroRegen = max(0, heroRegen - effect.regenMod)
        }
        heroHp = min(heroHp, heroMaxHp)
        activeEffects = []
    }

    func dismissDrop() { pendingDrop = nil }
    func dismissBossVictory() { pendingBossVictory = nil }

    private func receiveDrop(_ item: Equipment) {
        let autoSellLevel = prestigeUpgrades.first(where: { $0.id == "autosell" })?.level ?? 0
        if autoSellLevel > 0,
           let itemIdx      = ItemRarity.allCases.firstIndex(of: item.rarity),
           itemIdx <= autoSellLevel - 1 {
            gold += item.sellValue
            log("🪙 Auto-sold \(item.rarity.label) \(item.name) for \(item.sellValue)g")
            return
        }

        let slotEmpty = equippedItems[item.slot.rawValue] == nil
        if slotEmpty {
            equippedItems[item.slot.rawValue] = item
            applyBonuses(of: item)
            updateSetBonus()
            log("⚔ Found & equipped \(item.rarity.label) \(item.name)! [\(item.statSummary)]")
        } else {
            addToInventory(item)
            log("⚔ Found \(item.rarity.label) \(item.name)! [\(item.statSummary)] — Check ITEMS tab.")
        }
        pendingDrop = item
    }

    private func addToInventory(_ item: Equipment) {
        if inventory.count >= EquipmentDrop.inventoryLimit { inventory.removeFirst() }
        inventory.append(item)
    }

    private func applyBonuses(of item: Equipment) {
        heroAtk   += item.atkBonus
        heroDef   += item.defBonus
        heroMaxHp += item.hpBonus
        heroHp     = min(heroHp + item.hpBonus, heroMaxHp)
        heroRegen += item.regenBonus
    }

    private func stripBonuses(of item: Equipment) {
        heroAtk   = max(1, heroAtk   - item.atkBonus)
        heroDef   = max(0, heroDef   - item.defBonus)
        heroMaxHp = max(1, heroMaxHp - item.hpBonus)
        heroHp    = min(heroHp, heroMaxHp)
        heroRegen = max(0, heroRegen - item.regenBonus)
    }

    // MARK: - Set Bonus

    private func setBonusStats(_ rarity: ItemRarity) -> (atk: Int, def: Int, hp: Int, regen: Int) {
        switch rarity {
        case .common:    return (1, 1,  0, 0)
        case .uncommon:  return (2, 2, 15, 0)
        case .rare:      return (4, 3, 30, 1)
        case .epic:      return (7, 6, 60, 1)
        case .legendary: return (12, 10, 100, 2)
        }
    }

    private func applySetBonusStats(_ rarity: ItemRarity) {
        let s = setBonusStats(rarity)
        heroAtk += s.atk; heroDef += s.def
        heroMaxHp += s.hp; heroHp = min(heroHp + s.hp, heroMaxHp)
        heroRegen += s.regen
    }

    private func stripSetBonusStats(_ rarity: ItemRarity) {
        let s = setBonusStats(rarity)
        heroAtk   = max(1, heroAtk   - s.atk)
        heroDef   = max(0, heroDef   - s.def)
        heroMaxHp = max(1, heroMaxHp - s.hp)
        heroHp    = min(heroHp, heroMaxHp)
        heroRegen = max(0, heroRegen - s.regen)
    }

    private func updateSetBonus() {
        let newBonus = equippedSetBonusRarity
        guard newBonus != appliedSetBonus else { return }
        if let old = appliedSetBonus { stripSetBonusStats(old) }
        if let new = newBonus {
            applySetBonusStats(new)
            log("✦ \(new.label) Set Bonus! \(setBonusSummary(new))")
        } else if appliedSetBonus != nil {
            log("Set bonus lost.")
        }
        appliedSetBonus = newBonus
    }

    func setBonusSummary(_ rarity: ItemRarity) -> String {
        let s = setBonusStats(rarity)
        var parts: [String] = []
        if s.atk  > 0 { parts.append("+\(s.atk) ATK") }
        if s.def  > 0 { parts.append("+\(s.def) DEF") }
        if s.hp   > 0 { parts.append("+\(s.hp) HP") }
        if s.regen > 0 { parts.append("+\(s.regen) Regen") }
        return parts.joined(separator: "  ")
    }

    // MARK: - Daily Quests

    private static let questPool: [DailyQuest] = [
        // Kill any
        DailyQuest(id: "kill_15",   title: "Skirmisher",       description: "Slay 15 enemies",    type: .killAny,     goalCount: 15,   rewardGold: 35),
        DailyQuest(id: "kill_30",   title: "Monster Slayer",   description: "Slay 30 enemies",    type: .killAny,     goalCount: 30,   rewardGold: 55),
        DailyQuest(id: "kill_50",   title: "Fighter",          description: "Slay 50 enemies",    type: .killAny,     goalCount: 50,   rewardGold: 75),
        DailyQuest(id: "kill_75",   title: "Relentless",       description: "Slay 75 enemies",    type: .killAny,     goalCount: 75,   rewardGold: 100),
        DailyQuest(id: "kill_125",  title: "Unstoppable",      description: "Slay 125 enemies",   type: .killAny,     goalCount: 125,  rewardGold: 155),
        DailyQuest(id: "kill_200",  title: "Berserker",        description: "Slay 200 enemies",   type: .killAny,     goalCount: 200,  rewardGold: 220),
        DailyQuest(id: "kill_350",  title: "Warlord",          description: "Slay 350 enemies",   type: .killAny,     goalCount: 350,  rewardGold: 295),
        // Kill boss
        DailyQuest(id: "boss_1",    title: "First Blood",      description: "Defeat a boss",      type: .killBoss,    goalCount: 1,    rewardGold: 50),
        DailyQuest(id: "boss_2",    title: "Boss Hunter",      description: "Defeat 2 bosses",    type: .killBoss,    goalCount: 2,    rewardGold: 80),
        DailyQuest(id: "boss_5",    title: "Boss Crusher",     description: "Defeat 5 bosses",    type: .killBoss,    goalCount: 5,    rewardGold: 160),
        DailyQuest(id: "boss_8",    title: "Boss Slayer",      description: "Defeat 8 bosses",    type: .killBoss,    goalCount: 8,    rewardGold: 240),
        DailyQuest(id: "boss_12",   title: "Boss Breaker",     description: "Defeat 12 bosses",   type: .killBoss,    goalCount: 12,   rewardGold: 320),
        // Earn gold
        DailyQuest(id: "gold_100",  title: "Coin Collector",   description: "Earn 100 gold",      type: .earnGold,    goalCount: 100,  rewardGold: 35),
        DailyQuest(id: "gold_300",  title: "Gold Seeker",      description: "Earn 300 gold",      type: .earnGold,    goalCount: 300,  rewardGold: 70),
        DailyQuest(id: "gold_500",  title: "Wealth Seeker",    description: "Earn 500 gold",      type: .earnGold,    goalCount: 500,  rewardGold: 110),
        DailyQuest(id: "gold_700",  title: "Fortune Hunter",   description: "Earn 700 gold",      type: .earnGold,    goalCount: 700,  rewardGold: 140),
        DailyQuest(id: "gold_1200", title: "Treasure Hoarder", description: "Earn 1,200 gold",    type: .earnGold,    goalCount: 1200, rewardGold: 210),
        DailyQuest(id: "gold_2000", title: "Gold Hoarder",     description: "Earn 2,000 gold",    type: .earnGold,    goalCount: 2000, rewardGold: 285),
        // Clear floors
        DailyQuest(id: "floors_10", title: "Floor Crawler",    description: "Clear 10 floors",    type: .clearFloors, goalCount: 10,   rewardGold: 35),
        DailyQuest(id: "floors_20", title: "Dungeon Diver",    description: "Clear 20 floors",    type: .clearFloors, goalCount: 20,   rewardGold: 60),
        DailyQuest(id: "floors_35", title: "Dungeon Runner",   description: "Clear 35 floors",    type: .clearFloors, goalCount: 35,   rewardGold: 90),
        DailyQuest(id: "floors_50", title: "Deep Delver",      description: "Clear 50 floors",    type: .clearFloors, goalCount: 50,   rewardGold: 130),
        DailyQuest(id: "floors_80", title: "Abyss Diver",      description: "Clear 80 floors",    type: .clearFloors, goalCount: 80,   rewardGold: 190),
        DailyQuest(id: "floors_100",title: "Abyss Conqueror",  description: "Clear 100 floors",   type: .clearFloors, goalCount: 100,  rewardGold: 250),
        // Reach floor
        DailyQuest(id: "reach_5",   title: "Adventurer",       description: "Reach floor 5",      type: .reachFloor,  goalCount: 5,    rewardGold: 30),
        DailyQuest(id: "reach_15",  title: "First Steps",      description: "Reach floor 15",     type: .reachFloor,  goalCount: 15,   rewardGold: 55),
        DailyQuest(id: "reach_25",  title: "Dungeon Walker",   description: "Reach floor 25",     type: .reachFloor,  goalCount: 25,   rewardGold: 75),
        DailyQuest(id: "reach_40",  title: "Depths Explorer",  description: "Reach floor 40",     type: .reachFloor,  goalCount: 40,   rewardGold: 110),
        DailyQuest(id: "reach_50",  title: "Spelunker",        description: "Reach floor 50",     type: .reachFloor,  goalCount: 50,   rewardGold: 130),
        DailyQuest(id: "reach_60",  title: "Abyss Walker",     description: "Reach floor 60",     type: .reachFloor,  goalCount: 60,   rewardGold: 170),
        DailyQuest(id: "reach_80",  title: "Floor Master",     description: "Reach floor 80",     type: .reachFloor,  goalCount: 80,   rewardGold: 230),
        DailyQuest(id: "reach_100", title: "Abyss Lord",       description: "Reach floor 100",    type: .reachFloor,  goalCount: 100,  rewardGold: 290),
    ]

    static func todayDateKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func questSeed(for dayKey: String) -> Int {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return 20260526 }
        return parts[0] * 10000 + parts[1] * 100 + parts[2]
    }

    static func selectQuestsForDay(_ dayKey: String) -> [DailyQuest] {
        let pool = questPool
        var seed = questSeed(for: dayKey)
        var indices: [Int] = []
        while indices.count < min(12, pool.count) {
            seed = seed &* 1664525 &+ 1013904223
            let idx = ((seed % pool.count) + pool.count) % pool.count
            if !indices.contains(idx) { indices.append(idx) }
        }
        return indices.map { pool[$0] }
    }

    private func checkAndRefreshDailyQuests() {
        let today = DungeonGame.todayDateKey()
        guard today != dailyQuestDateString else { return }
        dailyQuestDateString = today
        var fresh = DungeonGame.selectQuestsForDay(today)
        // Seed reachFloor quests with current floor so mid-run refreshes feel fair
        for i in fresh.indices where fresh[i].type == .reachFloor {
            fresh[i].progress = currentFloor
        }
        dailyQuests = fresh
        dailyCompletionBonusClaimed = false
    }

    private func updateQuestProgress(type: DailyQuestType, value: Int) {
        for i in dailyQuests.indices {
            guard dailyQuests[i].type == type, !dailyQuests[i].claimed else { continue }
            switch type {
            case .reachFloor:
                dailyQuests[i].progress = max(dailyQuests[i].progress, value)
            default:
                dailyQuests[i].progress = min(dailyQuests[i].progress + value, dailyQuests[i].goalCount)
            }
        }
    }

    func claimDailyQuest(id: String) {
        guard let i = dailyQuests.firstIndex(where: { $0.id == id }),
              dailyQuests[i].isComplete, !dailyQuests[i].claimed else { return }
        dailyQuests[i].claimed = true
        gold += dailyQuests[i].rewardGold
        log("Quest: \(dailyQuests[i].title) — +\(dailyQuests[i].rewardGold)g!")
    }

    static let dailyCompletionBonusShards = 1

    func claimDailyCompletionBonus() {
        guard allQuestsClaimed, !dailyCompletionBonusClaimed else { return }
        dailyCompletionBonusClaimed = true
        soulShards += Self.dailyCompletionBonusShards
        log("Daily complete! +\(Self.dailyCompletionBonusShards) ◈")
    }

    // MARK: - Persistence

    private struct SaveData: Codable {
        var characterID: String
        var heroHp, heroMaxHp, heroAtk, heroDef, heroRegen: Int
        var gold, currentFloor, deepestFloor, deepestFloorEver, soulShards: Int
        var isGameOver: Bool
        var monsterHp, monsterMaxHp, monsterAtk: Int
        var monsterName: String
        var inCombat: Bool
        var ticksUntilFight: Int
        var upgradeLevels: [Int]
        var prestigeUpgradeLevels: [Int]
        var currentEnemyID: String?
        var equippedItems: [String: Equipment]?
        var inventory: [Equipment]?
        var savedAt: Date
        // v3 additions (optional for backwards compatibility)
        var appliedSetBonus: ItemRarity?
        var dailyQuestDateString: String?
        var dailyQuestProgress: [String: Int]?
        var dailyQuestClaimed: [String: Bool]?
        // v4 additions (optional for backwards compatibility)
        var activeEffects: [ActiveEffect]?
        var pendingFloorEvent: FloorEvent?
        // v5 additions (optional for backwards compatibility)
        var dailyCompletionBonusClaimed: Bool?
    }

    private static let saveKey = "dungeonSave_v2"

    static func savedCharacterID() -> String? {
        struct Mini: Codable { var characterID: String }
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let mini = try? JSONDecoder().decode(Mini.self, from: data)
        else { return nil }
        return mini.characterID
    }

    static func clearSave() {
        UserDefaults.standard.removeObject(forKey: saveKey)
    }

    func save() {
        let data = SaveData(
            characterID: characterID,
            heroHp: heroHp, heroMaxHp: heroMaxHp, heroAtk: heroAtk,
            heroDef: heroDef, heroRegen: heroRegen,
            gold: gold, currentFloor: currentFloor, deepestFloor: deepestFloor,
            deepestFloorEver: deepestFloorEver, soulShards: soulShards,
            isGameOver: isGameOver,
            monsterHp: monsterHp, monsterMaxHp: monsterMaxHp, monsterAtk: monsterAtk,
            monsterName: monsterName, inCombat: inCombat,
            ticksUntilFight: ticksUntilFight,
            upgradeLevels: upgrades.map { $0.level },
            prestigeUpgradeLevels: prestigeUpgrades.map { $0.level },
            currentEnemyID: currentEnemyType?.id,
            equippedItems: equippedItems,
            inventory: inventory,
            savedAt: Date(),
            appliedSetBonus: appliedSetBonus,
            dailyQuestDateString: dailyQuestDateString,
            dailyQuestProgress: Dictionary(uniqueKeysWithValues: dailyQuests.map { ($0.id, $0.progress) }),
            dailyQuestClaimed:  Dictionary(uniqueKeysWithValues: dailyQuests.map { ($0.id, $0.claimed) }),
            activeEffects: activeEffects,
            pendingFloorEvent: pendingFloorEvent,
            dailyCompletionBonusClaimed: dailyCompletionBonusClaimed
        )
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }

    @discardableResult
    private func load() -> Date? {
        guard let encoded = UserDefaults.standard.data(forKey: Self.saveKey),
              let data    = try? JSONDecoder().decode(SaveData.self, from: encoded)
        else { return nil }

        characterID      = data.characterID
        heroHp           = data.heroHp
        heroMaxHp        = data.heroMaxHp
        heroAtk          = data.heroAtk
        heroDef          = data.heroDef
        heroRegen        = data.heroRegen
        gold             = data.gold
        currentFloor     = data.currentFloor
        deepestFloor     = data.deepestFloor
        deepestFloorEver = data.deepestFloorEver
        soulShards       = data.soulShards
        isGameOver       = data.isGameOver
        monsterHp        = data.monsterHp
        monsterMaxHp     = data.monsterMaxHp
        monsterAtk       = data.monsterAtk
        monsterName      = data.monsterName
        inCombat         = data.inCombat
        ticksUntilFight  = data.ticksUntilFight

        for (i, level) in data.upgradeLevels.enumerated() where i < upgrades.count {
            upgrades[i].level = level
        }
        for (i, level) in data.prestigeUpgradeLevels.enumerated() where i < prestigeUpgrades.count {
            prestigeUpgrades[i].level = level
        }
        if let id = data.currentEnemyID {
            currentEnemyType = EnemyType.all.first { $0.id == id }
        }
        equippedItems = data.equippedItems ?? [:]
        inventory     = data.inventory     ?? []

        appliedSetBonus = data.appliedSetBonus

        // Restore daily quests
        let savedDay = data.dailyQuestDateString ?? ""
        let progress = data.dailyQuestProgress   ?? [:]
        let claimed  = data.dailyQuestClaimed     ?? [:]
        let dayKey   = savedDay.isEmpty ? DungeonGame.todayDateKey() : savedDay
        var quests   = DungeonGame.selectQuestsForDay(dayKey)
        for i in quests.indices {
            quests[i].progress = progress[quests[i].id] ?? 0
            quests[i].claimed  = claimed[quests[i].id]  ?? false
        }
        dailyQuests                  = quests
        dailyQuestDateString         = dayKey
        dailyCompletionBonusClaimed  = data.dailyCompletionBonusClaimed ?? false
        checkAndRefreshDailyQuests()

        activeEffects    = data.activeEffects    ?? []
        pendingFloorEvent = data.pendingFloorEvent

        displayMonsterHp    = inCombat ? max(0, monsterHp) : 0
        displayMonsterMaxHp = inCombat ? monsterMaxHp : 0
        displayMonsterName  = inCombat ? monsterName : ""
        currentFightFloor   = inCombat ? currentFloor : 0

        return data.savedAt
    }

    private func simulateOffline(seconds: TimeInterval) -> OfflineSummary {
        let offlineCap = UserDefaults.standard.bool(forKey: "com.oneMoreFloor.nightWatch") ? 24.0 * 3600 : 4.0 * 3600
        let elapsed    = min(seconds, offlineCap)
        let tickCount = min(Int(elapsed / tickInterval), 50_000)
        var goldEarned = 0; var deaths = 0; var floorsCleared = 0
        let startDeepest = deepestFloor

        if isGameOver {
            guard autoRestartEnabled else {
                return OfflineSummary(goldEarned: 0, deaths: 0, floorsCleared: 0,
                                     deepestFloor: deepestFloor, duration: elapsed)
            }
            isGameOver = false; heroHp = heroMaxHp
            currentFloor = 1; inCombat = false; ticksUntilFight = 3
        }

        for _ in 0..<tickCount {
            if heroHp <= 0 {
                deaths += 1
                if autoRestartEnabled {
                    heroHp = heroMaxHp; currentFloor = 1; inCombat = false; ticksUntilFight = 3
                } else {
                    isGameOver = true; inCombat = false
                    break
                }
            } else if inCombat {
                monsterHp -= max(1, heroAtk)
                if monsterHp <= 0 {
                    let bossBonus = DungeonGame.isBoss(floor: currentFloor) ? 3.0 : 1.0
                    let earned = Int(Double(currentFloor + Int.random(in: 1...3)) * goldMultiplier * bossBonus)
                    gold += earned; goldEarned += earned
                    inCombat = false; ticksUntilFight = 2
                    currentFloor += 1; floorsCleared += 1
                    deepestFloorEver = max(deepestFloorEver, currentFloor)
                    if currentFloor > deepestFloor { deepestFloor = currentFloor }
                } else {
                    heroHp = max(0, heroHp - max(1, monsterAtk - heroDef))
                }
            } else {
                if heroRegen > 0 { heroHp = min(heroMaxHp, heroHp + heroRegen) }
                ticksUntilFight -= 1
                if ticksUntilFight <= 0 {
                    let zoneID = DungeonGame.zones.last(where: { currentFloor >= $0.minFloor })?.id ?? "entrance"
                    let pool   = DungeonGame.zoneEnemyPools[zoneID] ?? [.skeleton]
                    let enemy  = pool.randomElement()!
                    currentEnemyType = enemy
                    monsterName  = enemy.name
                    monsterMaxHp = enemy.hp(floor: currentFloor)
                    monsterHp    = monsterMaxHp
                    monsterAtk   = enemy.atk(floor: currentFloor)
                    inCombat     = true
                }
            }
        }

        displayMonsterHp    = inCombat ? max(0, monsterHp) : 0
        displayMonsterMaxHp = inCombat ? monsterMaxHp : 0
        displayMonsterName  = inCombat ? monsterName : ""
        currentFightFloor   = inCombat ? currentFloor : 0

        return OfflineSummary(goldEarned: goldEarned, deaths: deaths, floorsCleared: floorsCleared,
                              deepestFloor: max(startDeepest, deepestFloor), duration: elapsed)
    }

    func handleForeground() -> OfflineSummary? {
        guard let savedAt = load() else { return nil }
        let elapsed = Date.now.timeIntervalSince(savedAt)
        save()
        guard elapsed > 10 else { return nil }
        let summary = simulateOffline(seconds: elapsed)
        return summary.hasContent ? summary : nil
    }

    // Returns estimated seconds until the hero first dies, capped at 4 hours.
    // Returns nil if the hero is expected to survive the full simulation window.
    func estimatedSecondsUntilFirstDeath() -> Double? {
        guard !isGameOver else { return nil }

        var hp      = heroHp
        var mHp     = monsterHp
        var mAtk    = monsterAtk
        var fighting = inCombat
        var ticks   = ticksUntilFight
        var floor   = currentFloor
        let capHours = UserDefaults.standard.bool(forKey: "com.oneMoreFloor.nightWatch") ? 24.0 : 4.0
        let maxTicks = Int(capHours * 3600 / tickInterval)

        for i in 0..<maxTicks {
            if hp <= 0 { return Double(i) * tickInterval }

            if fighting {
                mHp -= max(1, heroAtk)
                if mHp <= 0 {
                    floor += 1
                    fighting = false
                    ticks = 2
                } else {
                    hp = max(0, hp - max(1, mAtk - heroDef))
                }
            } else {
                if heroRegen > 0 { hp = min(heroMaxHp, hp + heroRegen) }
                ticks -= 1
                if ticks <= 0 {
                    let zoneID = DungeonGame.zones.last(where: { floor >= $0.minFloor })?.id ?? "entrance"
                    let pool   = DungeonGame.zoneEnemyPools[zoneID] ?? [.skeleton]
                    let enemy  = pool[0]
                    let isBoss = DungeonGame.isBoss(floor: floor)
                    mHp  = isBoss ? Int(Double(enemy.hp(floor: floor))  * 2.5) : enemy.hp(floor: floor)
                    mAtk = isBoss ? Int(Double(enemy.atk(floor: floor)) * 1.5) : enemy.atk(floor: floor)
                    fighting = true
                }
            }
        }
        return nil
    }
}
