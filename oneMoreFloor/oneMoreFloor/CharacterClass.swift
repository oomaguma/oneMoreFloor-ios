import Foundation

struct AnimationSpec {
    let imageName: String
    let frameCount: Int
}

struct CharacterClass: Identifiable {
    let id: String
    let name: String
    let role: String
    let description: String
    let baseHP: Int
    let baseATK: Int
    let baseDEF: Int
    let baseRegen: Int
    let idle: AnimationSpec
    let attacks: [AnimationSpec]
    let hurt: AnimationSpec
    let death: AnimationSpec
    let block: AnimationSpec?
    let heal: AnimationSpec?
    let projectile: String?
    let critChance: Double
    let blockChance: Double
    let healChance: Double

    init(id: String, name: String, role: String, description: String,
         baseHP: Int, baseATK: Int, baseDEF: Int, baseRegen: Int,
         idle: AnimationSpec, attacks: [AnimationSpec],
         hurt: AnimationSpec, death: AnimationSpec,
         block: AnimationSpec?, heal: AnimationSpec?,
         projectile: String? = nil,
         critChance: Double = 0.08, blockChance: Double = 0.0, healChance: Double = 0.0) {
        self.id = id; self.name = name; self.role = role; self.description = description
        self.baseHP = baseHP; self.baseATK = baseATK; self.baseDEF = baseDEF; self.baseRegen = baseRegen
        self.idle = idle; self.attacks = attacks; self.hurt = hurt; self.death = death
        self.block = block; self.heal = heal; self.projectile = projectile
        self.critChance = critChance; self.blockChance = blockChance; self.healChance = healChance
    }
}

struct EnemyType: Identifiable {
    let id: String
    let name: String
    let hpBase: Int
    let hpPerFloor: Int
    let atkBase: Int
    let atkPerFloor: Int
    let idle: AnimationSpec
    let attacks: [AnimationSpec]
    let hurt: AnimationSpec
    let death: AnimationSpec
    let projectile: String?

    init(id: String, name: String,
         hpBase: Int, hpPerFloor: Int, atkBase: Int, atkPerFloor: Int,
         idle: AnimationSpec, attacks: [AnimationSpec],
         hurt: AnimationSpec, death: AnimationSpec,
         projectile: String? = nil) {
        self.id = id; self.name = name
        self.hpBase = hpBase; self.hpPerFloor = hpPerFloor
        self.atkBase = atkBase; self.atkPerFloor = atkPerFloor
        self.idle = idle; self.attacks = attacks; self.hurt = hurt; self.death = death
        self.projectile = projectile
    }

    func hp(floor: Int) -> Int { max(1, hpBase + floor * hpPerFloor) }
    func atk(floor: Int) -> Int { max(1, atkBase + floor * atkPerFloor) }
}

// MARK: - Characters

extension CharacterClass {
    static let all: [CharacterClass] = [
        soldier, knight, knightTemplar, swordsman, lancer, archer, wizard, priest
    ]

    static let soldier = CharacterClass(
        id: "soldier", name: "Soldier", role: "Warrior",
        description: "Balanced fighter with powerful three-hit combos.",
        baseHP: 120, baseATK: 9, baseDEF: 1, baseRegen: 0,
        idle:    AnimationSpec(imageName: "Soldier-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Soldier-Attack01", frameCount: 6),
                  AnimationSpec(imageName: "Soldier-Attack02", frameCount: 6),
                  AnimationSpec(imageName: "Soldier-Attack03", frameCount: 9)],
        hurt:  AnimationSpec(imageName: "Soldier-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Soldier-Death", frameCount: 4),
        block: nil, heal: nil,
        critChance: 0.10
    )

    static let knight = CharacterClass(
        id: "knight", name: "Knight", role: "Tank",
        description: "High HP and defense. Blocks some incoming strikes.",
        baseHP: 150, baseATK: 7, baseDEF: 3, baseRegen: 0,
        idle:    AnimationSpec(imageName: "Knight-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Knight-Attack01", frameCount: 7),
                  AnimationSpec(imageName: "Knight-Attack02", frameCount: 10),
                  AnimationSpec(imageName: "Knight-Attack03", frameCount: 11)],
        hurt:  AnimationSpec(imageName: "Knight-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Knight-Death", frameCount: 4),
        block: AnimationSpec(imageName: "Knight-Block", frameCount: 4),
        heal: nil,
        critChance: 0.07, blockChance: 0.25
    )

    static let knightTemplar = CharacterClass(
        id: "knightTemplar", name: "Knight Templar", role: "Paladin",
        description: "Holy warrior with innate regeneration.",
        baseHP: 160, baseATK: 7, baseDEF: 4, baseRegen: 1,
        idle:    AnimationSpec(imageName: "Knight Templar-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Knight Templar-Attack01", frameCount: 7),
                  AnimationSpec(imageName: "Knight Templar-Attack02", frameCount: 8),
                  AnimationSpec(imageName: "Knight Templar-Attack03", frameCount: 11)],
        hurt:  AnimationSpec(imageName: "Knight Templar-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Knight Templar-Death", frameCount: 4),
        block: AnimationSpec(imageName: "Knight Templar-Block", frameCount: 4),
        heal: nil,
        critChance: 0.07, blockChance: 0.20
    )

    static let swordsman = CharacterClass(
        id: "swordsman", name: "Swordsman", role: "Duelist",
        description: "Devastatingly fast combos with high burst damage.",
        baseHP: 100, baseATK: 11, baseDEF: 1, baseRegen: 0,
        idle:    AnimationSpec(imageName: "Swordsman-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Swordsman-Attack01", frameCount: 7),
                  AnimationSpec(imageName: "Swordsman-Attack02", frameCount: 15),
                  AnimationSpec(imageName: "Swordsman-Attack3",  frameCount: 12)],
        hurt:  AnimationSpec(imageName: "Swordsman-Hurt",  frameCount: 5),
        death: AnimationSpec(imageName: "Swordsman-Death", frameCount: 4),
        block: nil, heal: nil,
        critChance: 0.18
    )

    static let lancer = CharacterClass(
        id: "lancer", name: "Lancer", role: "Skirmisher",
        description: "Long-reach attacks and aggressive multi-hit combinations.",
        baseHP: 110, baseATK: 10, baseDEF: 1, baseRegen: 0,
        idle:    AnimationSpec(imageName: "Lancer-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Lancer-Attack01", frameCount: 6),
                  AnimationSpec(imageName: "Lancer-Attack02", frameCount: 9),
                  AnimationSpec(imageName: "Lancer-Attack03", frameCount: 8)],
        hurt:  AnimationSpec(imageName: "Lancer-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Lancer-Death", frameCount: 4),
        block: nil, heal: nil,
        critChance: 0.12
    )

    static let archer = CharacterClass(
        id: "archer", name: "Archer", role: "Ranger",
        description: "High attack damage. Fragile but deadly from range.",
        baseHP: 90, baseATK: 12, baseDEF: 0, baseRegen: 0,
        idle:    AnimationSpec(imageName: "Archer-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Archer-Attack01", frameCount: 9),
                  AnimationSpec(imageName: "Archer-Attack02", frameCount: 12)],
        hurt:  AnimationSpec(imageName: "Archer-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Archer-Death", frameCount: 4),
        block: nil, heal: nil, projectile: "Arrow02",
        critChance: 0.15
    )

    static let wizard = CharacterClass(
        id: "wizard", name: "Wizard", role: "Mage",
        description: "Devastating magical damage but extremely fragile.",
        baseHP: 80, baseATK: 14, baseDEF: 0, baseRegen: 0,
        idle:    AnimationSpec(imageName: "Wizard-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Wizard-Attack01", frameCount: 6),
                  AnimationSpec(imageName: "Wizard-Attack02", frameCount: 6)],
        hurt:  AnimationSpec(imageName: "Wizard-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Wizard-DEATH", frameCount: 4),
        block: nil, heal: nil,
        critChance: 0.22
    )

    static let priest = CharacterClass(
        id: "priest", name: "Priest", role: "Healer",
        description: "Powerful regen sustains through prolonged battles.",
        baseHP: 100, baseATK: 7, baseDEF: 1, baseRegen: 2,
        idle:    AnimationSpec(imageName: "Priest-Idle",   frameCount: 6),
        attacks: [AnimationSpec(imageName: "Priest-Attack", frameCount: 9)],
        hurt:  AnimationSpec(imageName: "Priest-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Priest-Death", frameCount: 4),
        block: nil,
        heal:  AnimationSpec(imageName: "Priest-Heal",  frameCount: 6),
        critChance: 0.05, healChance: 0.40
    )
}

// MARK: - Enemies

extension EnemyType {
    static let all: [EnemyType] = [
        slime, skeleton, skeletonArcher, armoredSkeleton,
        orc, orcRider,
        werebear, werewolf,
        eliteOrc, armoredOrc,
        armoredAxeman, greatswordSkeleton
    ]

    // Zone 1: Dungeon Entrance
    static let slime = EnemyType(
        id: "slime", name: "Slime",
        hpBase: 5, hpPerFloor: 3, atkBase: 1, atkPerFloor: 1,
        idle:    AnimationSpec(imageName: "Slime-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Slime-Attack01", frameCount: 6),
                  AnimationSpec(imageName: "Slime-Attack02", frameCount: 12)],
        hurt:  AnimationSpec(imageName: "Slime-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Slime-Death", frameCount: 4)
    )

    static let skeleton = EnemyType(
        id: "skeleton", name: "Skeleton",
        hpBase: 7, hpPerFloor: 4, atkBase: 2, atkPerFloor: 1,
        idle:    AnimationSpec(imageName: "Skeleton-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Skeleton-Attack01", frameCount: 6),
                  AnimationSpec(imageName: "Skeleton-Attack02", frameCount: 7)],
        hurt:  AnimationSpec(imageName: "Skeleton-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Skeleton-Death", frameCount: 4)
    )

    // Zone 2: The Crypts
    static let skeletonArcher = EnemyType(
        id: "skeletonArcher", name: "Skeleton Archer",
        hpBase: 6, hpPerFloor: 3, atkBase: 1, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Skeleton Archer-Idle",    frameCount: 6),
        attacks: [AnimationSpec(imageName: "Skeleton Archer-Attack", frameCount: 9)],
        hurt:  AnimationSpec(imageName: "Skeleton Archer-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Skeleton Archer-Death", frameCount: 4),
        projectile: "Arrow03"
    )

    static let armoredSkeleton = EnemyType(
        id: "armoredSkeleton", name: "Armored Skeleton",
        hpBase: 10, hpPerFloor: 5, atkBase: 2, atkPerFloor: 1,
        idle:    AnimationSpec(imageName: "Armored Skeleton-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Armored Skeleton-Attack01", frameCount: 8),
                  AnimationSpec(imageName: "Armored Skeleton-Attack02", frameCount: 9)],
        hurt:  AnimationSpec(imageName: "Armored Skeleton-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Armored Skeleton-Death", frameCount: 4)
    )

    // Zone 3: Orc Stronghold
    static let orc = EnemyType(
        id: "orc", name: "Orc",
        hpBase: 8, hpPerFloor: 4, atkBase: 2, atkPerFloor: 1,
        idle:    AnimationSpec(imageName: "Orc-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Orc-Attack01", frameCount: 6),
                  AnimationSpec(imageName: "Orc-Attack02", frameCount: 6)],
        hurt:  AnimationSpec(imageName: "Orc-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Orc-Death", frameCount: 4)
    )

    static let orcRider = EnemyType(
        id: "orcRider", name: "Orc Rider",
        hpBase: 15, hpPerFloor: 6, atkBase: 3, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Orc rider-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Orc rider-Attack01", frameCount: 8),
                  AnimationSpec(imageName: "Orc rider-Attack02", frameCount: 9),
                  AnimationSpec(imageName: "Orc rider-Attack03", frameCount: 11)],
        hurt:  AnimationSpec(imageName: "Orc rider-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Orc rider-Death", frameCount: 4)
    )

    // Zone 4: Sunken City
    static let werebear = EnemyType(
        id: "werebear", name: "Werebear",
        hpBase: 20, hpPerFloor: 8, atkBase: 4, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Werebear-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Werebear-Attack01", frameCount: 9),
                  AnimationSpec(imageName: "Werebear-Attack02", frameCount: 13),
                  AnimationSpec(imageName: "Werebear-Attack03", frameCount: 9)],
        hurt:  AnimationSpec(imageName: "Werebear-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Werebear-Death", frameCount: 4)
    )

    static let werewolf = EnemyType(
        id: "werewolf", name: "Werewolf",
        hpBase: 12, hpPerFloor: 5, atkBase: 3, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Werewolf-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Werewolf-Attack01", frameCount: 9),
                  AnimationSpec(imageName: "Werewolf-Attack02", frameCount: 13)],
        hurt:  AnimationSpec(imageName: "Werewolf-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Werewolf-Death", frameCount: 4)
    )

    // Zone 5: The Abyss
    static let eliteOrc = EnemyType(
        id: "eliteOrc", name: "Elite Orc",
        hpBase: 15, hpPerFloor: 7, atkBase: 4, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Elite Orc-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Elite Orc-Attack01", frameCount: 7),
                  AnimationSpec(imageName: "Elite Orc-Attack02", frameCount: 11),
                  AnimationSpec(imageName: "Elite Orc-Attack03", frameCount: 9)],
        hurt:  AnimationSpec(imageName: "Elite Orc-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Elite Orc-Death", frameCount: 4)
    )

    static let armoredOrc = EnemyType(
        id: "armoredOrc", name: "Armored Orc",
        hpBase: 25, hpPerFloor: 9, atkBase: 4, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Armored Orc-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Armored Orc-Attack01", frameCount: 7),
                  AnimationSpec(imageName: "Armored Orc-Attack02", frameCount: 8),
                  AnimationSpec(imageName: "Armored Orc-Attack03", frameCount: 9)],
        hurt:  AnimationSpec(imageName: "Armored Orc-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Armored Orc-Death", frameCount: 4)
    )

    // Zone 6: Iron Citadel
    static let armoredAxeman = EnemyType(
        id: "armoredAxeman", name: "Armored Axeman",
        hpBase: 20, hpPerFloor: 8, atkBase: 5, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Armored Axeman-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Armored Axeman-Attack01", frameCount: 9),
                  AnimationSpec(imageName: "Armored Axeman-Attack02", frameCount: 9),
                  AnimationSpec(imageName: "Armored Axeman-Attack03", frameCount: 12)],
        hurt:  AnimationSpec(imageName: "Armored Axeman-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Armored Axeman-Death", frameCount: 4)
    )

    static let greatswordSkeleton = EnemyType(
        id: "greatswordSkeleton", name: "Greatsword Skeleton",
        hpBase: 18, hpPerFloor: 7, atkBase: 5, atkPerFloor: 2,
        idle:    AnimationSpec(imageName: "Greatsword Skeleton-Idle",      frameCount: 6),
        attacks: [AnimationSpec(imageName: "Greatsword Skeleton-Attack01", frameCount: 9),
                  AnimationSpec(imageName: "Greatsword Skeleton-Attack02", frameCount: 12),
                  AnimationSpec(imageName: "Greatsword Skeleton-Attack03", frameCount: 8)],
        hurt:  AnimationSpec(imageName: "Greatsword Skeleton-Hurt",  frameCount: 4),
        death: AnimationSpec(imageName: "Greatsword Skeleton-Death", frameCount: 4)
    )
}
