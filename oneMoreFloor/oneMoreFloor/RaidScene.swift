import SpriteKit

// MARK: - Raid Enemy

/// Tracks one enemy in the raid: live state, timers, sprite node, and HP bar.
/// The HP bar lives at scene level (not as a child of the sprite) so it never
/// inherits the sprite's negative xScale and stays correctly oriented.
final class RaidEnemy {

    let node: SKSpriteNode

    var hp: Int
    let maxHp: Int
    let atk: Int
    var isDead: Bool { hp <= 0 }

    // True once the walk-in action completes and the enemy is ready to attack.
    var hasArrived: Bool = false

    // Counts down; when it hits 0 the enemy attacks and resets.
    var attackTimer: TimeInterval
    let attackInterval: TimeInterval

    // Bumped each time a new damage hit is queued, so stale delayed closures bail out.
    var generation: Int = 0

    // Animation frames loaded from the sprite atlas
    let idleFrames:   [SKTexture]
    let attackFrames: [[SKTexture]]
    let hurtFrames:   [SKTexture]
    let deathFrames:  [SKTexture]

    // HP bar nodes — owned here, added as children of the scene, not the sprite.
    let hpBarBg:   SKSpriteNode
    let hpBarFill: SKSpriteNode

    static let barWidth:  CGFloat = 26
    static let barHeight: CGFloat = 3
    // How far above the enemy center the bar floats (in scene units).
    static let barYOffset: CGFloat = 24

    init(name: String, hp: Int, atk: Int, isBoss: Bool,
         idleFrames: [SKTexture], attackFrames: [[SKTexture]],
         hurtFrames: [SKTexture], deathFrames: [SKTexture]) {
        self.maxHp        = hp
        self.hp           = hp
        self.atk          = atk
        self.idleFrames   = idleFrames
        self.attackFrames = attackFrames
        self.hurtFrames   = hurtFrames
        self.deathFrames  = deathFrames
        // Bosses swing harder but slower; minions attack faster.
        self.attackInterval = isBoss ? 2.2 : 1.6
        // Stagger first attacks so enemies don't all swing at once.
        self.attackTimer = Double.random(in: 0.6...1.5)

        // Sprite node — negative xScale flips it left to face the hero.
        let sprite = SKSpriteNode(texture: idleFrames.first)
        sprite.setScale(2.0)
        sprite.xScale = -2.0
        self.node = sprite

        // HP bar background (dark gray pill at scene level).
        let bg = SKSpriteNode(
            color: UIColor(white: 0.25, alpha: 0.85),
            size: CGSize(width: RaidEnemy.barWidth, height: RaidEnemy.barHeight)
        )
        bg.zPosition = 15
        self.hpBarBg = bg

        // HP fill — anchored left so it shrinks from the right as HP drops.
        let fill = SKSpriteNode(
            color: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0),
            size: CGSize(width: RaidEnemy.barWidth, height: RaidEnemy.barHeight)
        )
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position    = CGPoint(x: -RaidEnemy.barWidth / 2, y: 0)
        fill.zPosition   = 1
        bg.addChild(fill)
        self.hpBarFill = fill
    }

    /// Reposition the HP bar to float above the enemy and update its fill width.
    func syncHpBar() {
        let pct = max(0, CGFloat(hp) / CGFloat(maxHp))
        hpBarFill.size.width    = RaidEnemy.barWidth * pct
        hpBarBg.position        = CGPoint(x: node.position.x,
                                           y: node.position.y + RaidEnemy.barYOffset)
    }
}

// MARK: - Raid Scene

/// Side-scrolling arena. Enemies walk in from the right; the hero auto-attacks
/// the nearest one. Three waves of enemies — clear all three to win the raid.
///
/// All combat logic lives here; RaidView only reads the callbacks to update its
/// SwiftUI overlays. The pattern mirrors CombatScene: no direct game-state
/// references, everything flows through closures set before didMove fires.
class RaidScene: SKScene {

    // MARK: - Callbacks

    /// Fired whenever hero HP changes — (current, max).
    var onHeroHpChanged: ((Int, Int) -> Void)?
    /// Fired when a new wave begins — (wave number, total waves).
    var onWaveChanged: ((Int, Int) -> Void)?
    /// Fired when all waves are cleared (true) or the hero falls (false).
    var onRaidCompleted: ((Bool) -> Void)?

    // MARK: - Immutable hero config

    private let heroClass: CharacterClass
    private let heroAtk:   Int
    private let heroDef:   Int
    private(set) var heroHp: Int
    let heroMaxHp: Int

    private let zoneID: String
    private let floor:  Int

    // MARK: - Mutable raid state

    private var wave       = 0
    private let totalWaves = 3

    /// All enemies created for the current wave (alive or dead).
    private var raidEnemies: [RaidEnemy] = []
    /// True while we're between waves — prevents the wave-clear check from
    /// re-firing on the previous wave's dead bodies during the breather pause.
    private var isSpawningWave = false
    /// Latched true once the final outcome is decided (all waves or hero dead).
    private var isRaidOver = false

    // MARK: - Sprite nodes

    private var bgNode:   SKSpriteNode!
    private var heroNode: SKSpriteNode!
    private var heroIsDeathPlaying = false

    private var heroIdleFrames:      [SKTexture]   = []
    private var heroAttackFrameSets: [[SKTexture]]  = []
    private var heroHurtFrames:      [SKTexture]   = []
    private var heroDeathFrames:     [SKTexture]   = []

    // MARK: - Timing

    /// Countdown to the hero's next auto-attack.
    private var heroAttackTimer:    TimeInterval = 0.8
    private let heroAttackInterval: TimeInterval = 0.9

    /// Maximum x position (scene units) that an enemy must reach before the hero
    /// can strike it. Enemies spawning at x=290 walk left — the hero can only hit
    /// them once they cross this threshold. Gives the player a tense "wait for it"
    /// window while enemies approach. All enemy arrival positions are set to land
    /// inside this boundary so the fight always kicks off once they arrive.
    private let heroHitRange: CGFloat = 170

    /// Set each call to update() — used to compute dt.
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Init

    init(hero: CharacterClass,
         heroHp: Int, heroMaxHp: Int, heroAtk: Int, heroDef: Int,
         zoneID: String, floor: Int) {
        self.heroClass = hero
        self.heroHp    = heroHp
        self.heroMaxHp = heroMaxHp
        self.heroAtk   = heroAtk
        self.heroDef   = heroDef
        self.zoneID    = zoneID
        self.floor     = floor
        // Wider aspect ratio than the 1v1 CombatScene — we need horizontal room
        // for enemies walking in from the right side.
        super.init(size: CGSize(width: 300, height: 160))
        scaleMode       = .aspectFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Scene lifecycle

    override func didMove(to view: SKView) {
        view.backgroundColor = .clear

        // Zone background — same texture key and dimming as CombatScene.
        let bgTex = SKTexture(imageNamed: "bg_\(zoneID)")
        bgTex.filteringMode = .nearest
        bgNode = SKSpriteNode(texture: bgTex)
        bgNode.position         = CGPoint(x: 150, y: 80)
        bgNode.size             = CGSize(width: 400, height: 400 * 160.0 / 300.0)
        bgNode.zPosition        = -10
        bgNode.color            = .black
        bgNode.colorBlendFactor = 0.45
        addChild(bgNode)

        // Hero — planted on the left side, facing right (positive xScale).
        loadHeroFrames()
        heroNode = SKSpriteNode(texture: heroIdleFrames.first)
        heroNode.setScale(2.2)
        heroNode.position = CGPoint(x: 45, y: 62)
        addChild(heroNode)
        heroNode.run(
            .repeatForever(.animate(with: heroIdleFrames, timePerFrame: 0.12)),
            withKey: "anim"
        )

        // Faint range-indicator line — shows the hit boundary so the player
        // can see at a glance why their taps aren't landing on far enemies.
        // Very low alpha keeps it from cluttering the pixel-art look.
        let rangePath = CGMutablePath()
        rangePath.move(to: CGPoint(x: heroHitRange, y: 22))
        rangePath.addLine(to: CGPoint(x: heroHitRange, y: 106))
        let rangeLine = SKShapeNode(path: rangePath)
        rangeLine.strokeColor   = UIColor(white: 1.0, alpha: 0.10)
        rangeLine.lineWidth     = 1
        rangeLine.zPosition     = 5
        rangeLine.isAntialiased = false
        addChild(rangeLine)

        // Brief dramatic pause before enemies charge in.
        run(.sequence([
            .wait(forDuration: 0.7),
            .run { [weak self] in self?.startNextWave() }
        ]))
    }

    // MARK: - Frame loading

    private func loadHeroFrames() {
        heroIdleFrames      = buildFrames(heroClass.idle)
        heroAttackFrameSets = heroClass.attacks.map { buildFrames($0) }
        heroHurtFrames      = buildFrames(heroClass.hurt)
        heroDeathFrames     = buildFrames(heroClass.death)
    }

    // MARK: - Wave management

    private func startNextWave() {
        wave += 1
        // Tear down any leftover HP bars from the previous wave.
        raidEnemies.forEach { $0.hpBarBg.removeFromParent() }
        raidEnemies = []
        onWaveChanged?(wave, totalWaves)

        floatText("WAVE \(wave)",
                  at: CGPoint(x: 150, y: 105),
                  color: UIColor(red: 0.95, green: 0.78, blue: 0.15, alpha: 1),
                  fontSize: 20)

        let pool     = DungeonGame.zoneEnemyPools[zoneID] ?? [EnemyType.skeleton]
        let bossType = DungeonGame.zoneBossEnemies[zoneID]
        let count    = wave + 2   // wave 1 → 3 enemies, wave 2 → 4, wave 3 → 5

        // Y offsets create a loose cluster so enemies don't all stack on top of each other.
        let yOffsets: [CGFloat] = [0, -10, 10, -5, 5]

        for i in 0..<count {
            // The last enemy of the final wave is the boss type for this zone.
            let isBossEnemy = (wave == totalWaves && i == count - 1)
            let eType: EnemyType = isBossEnemy
                ? (bossType ?? pool.randomElement()!)
                : (pool.randomElement()!)

            let hp  = eType.scaledHp(floor: floor, isBoss: isBossEnemy)
            let atk = eType.scaledAtk(floor: floor, isBoss: isBossEnemy)

            let enemy = RaidEnemy(
                name: eType.name, hp: hp, atk: atk, isBoss: isBossEnemy,
                idleFrames:   buildFrames(eType.idle),
                attackFrames: eType.attacks.map { buildFrames($0) },
                hurtFrames:   buildFrames(eType.hurt),
                deathFrames:  buildFrames(eType.death)
            )

            let yPos: CGFloat = 62 + yOffsets[i % yOffsets.count]
            enemy.node.position = CGPoint(x: 290, y: yPos)
            addChild(enemy.node)
            addChild(enemy.hpBarBg)
            enemy.syncHpBar()

            enemy.node.run(
                .repeatForever(.animate(with: enemy.idleFrames, timePerFrame: 0.12)),
                withKey: "anim"
            )

            // Stagger walk-in so enemies arrive at different times, front-to-back.
            // All target positions land to the LEFT of heroHitRange (170) so every
            // enemy is attackable by the time it finishes walking. The extended
            // 1.8s walk gives the player a tense "they're coming" window before
            // combat starts.
            let delay:   Double  = Double(i) * 0.8
            let targetX: CGFloat = max(95, 155 - CGFloat(i) * 20)

            run(.sequence([
                .wait(forDuration: 0.35 + delay),
                .run { [weak enemy] in
                    guard let enemy else { return }
                    enemy.node.run(
                        .sequence([
                            .moveTo(x: targetX, duration: 1.8),
                            .run { enemy.hasArrived = true }
                        ]),
                        withKey: "walk"
                    )
                }
            ]))

            raidEnemies.append(enemy)
        }

        // All enemies are now in the array (alive), so the wave-clear guard can lift.
        isSpawningWave = false
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard !isRaidOver else { return }

        // Track enemy positions with their HP bars.
        for enemy in raidEnemies where !enemy.isDead {
            enemy.syncHpBar()
        }

        // Hero auto-attack countdown.
        // We only reset the timer (and swing) when an in-range target exists.
        // If nothing is reachable yet, the timer stays at ≤ 0 so the hero fires
        // immediately on the first frame an enemy crosses the hit-range boundary —
        // no dead time between "enemy enters range" and "hero attacks".
        heroAttackTimer -= dt
        if heroAttackTimer <= 0 {
            let hasInRange = raidEnemies.contains(where: {
                !$0.isDead && $0.node.position.x <= heroHitRange
            })
            if hasInRange {
                heroAttackTimer = heroAttackInterval
                heroAttackNearest()
            }
        }

        // Enemy attack countdowns — only for enemies that have walked into range.
        for enemy in raidEnemies where !enemy.isDead && enemy.hasArrived {
            enemy.attackTimer -= dt
            if enemy.attackTimer <= 0 {
                enemy.attackTimer = enemy.attackInterval
                enemyAttacks(enemy)
            }
        }

        checkWaveCompletion()
    }

    // MARK: - Player tap (immediate hero strike)

    /// Called by RaidView when the player taps the arena.
    /// If an enemy is within hit range, the hero attacks immediately and the
    /// auto-attack timer resets. If nothing is in range yet, the hero plays
    /// the swing animation but shows "TOO FAR" — clear feedback that the player
    /// needs to wait for enemies to advance before they can be struck.
    func playerTap() {
        guard !isRaidOver, !heroIsDeathPlaying else { return }
        let hasInRange = raidEnemies.contains(where: {
            !$0.isDead && $0.node.position.x <= heroHitRange
        })
        if hasInRange {
            heroAttackTimer = heroAttackInterval
            heroAttackNearest()
        }
        // If nothing is in range, do nothing — the tap silently fails and the
        // player quickly learns to wait for enemies to cross the range line.
    }

    // MARK: - Hero combat

    private func heroAttackNearest() {
        guard !isRaidOver, !heroIsDeathPlaying else { return }
        // Only target enemies that have crossed into hit range (x ≤ heroHitRange).
        // Enemies still walking in from x=290 are silently skipped — the hero
        // physically can't reach them yet. Of those in range, pick the leftmost
        // (closest to the hero) to prioritise the most immediate threat.
        guard let target = raidEnemies
            .filter({ !$0.isDead && $0.node.position.x <= heroHitRange })
            .min(by: { $0.node.position.x < $1.node.position.x })
        else { return }

        playHeroAttack()

        // Bump generation so the delayed hit lambda bails if the enemy dies first.
        target.generation += 1
        let gen = target.generation

        run(.sequence([
            .wait(forDuration: 0.28),
            .run { [weak self, weak target] in
                guard let self, let target,
                      target.generation == gen, !target.isDead else { return }
                self.applyHeroDamageTo(target)
            }
        ]))
    }

    private func applyHeroDamageTo(_ enemy: RaidEnemy) {
        let isCrit = Double.random(in: 0...1) < heroClass.critChance
        let dmg    = max(1, isCrit ? heroAtk * 2 : heroAtk)
        enemy.hp  -= dmg
        SoundManager.shared.play(Bool.random() ? "sword_slice" : "sword_light")

        let hitPos = CGPoint(x: enemy.node.position.x + 6, y: enemy.node.position.y + 20)

        if isCrit {
            floatText("⚡\(dmg)", at: hitPos,
                      color: UIColor(red: 1.0, green: 0.88, blue: 0.12, alpha: 1), fontSize: 15)
        } else {
            floatText("-\(dmg)", at: hitPos,
                      color: UIColor(red: 1.0, green: 0.60, blue: 0.15, alpha: 1))
        }

        if enemy.isDead {
            playEnemyDeath(enemy)
        } else {
            enemy.syncHpBar()
            playEnemyHurt(enemy)
        }
    }

    // MARK: - Enemy combat

    private func enemyAttacks(_ enemy: RaidEnemy) {
        guard !isRaidOver, !heroIsDeathPlaying else { return }

        // Enemy plays its attack animation.
        let i    = Int.random(in: 0..<enemy.attackFrames.count)
        let anim = SKAction.animate(with: enemy.attackFrames[i], timePerFrame: 0.10)
        let idle = SKAction.run { [weak enemy] in
            guard let enemy, !enemy.isDead else { return }
            enemy.node.run(
                .repeatForever(.animate(with: enemy.idleFrames, timePerFrame: 0.12)),
                withKey: "anim"
            )
        }
        enemy.node.run(.sequence([anim, idle]), withKey: "anim")
        SoundManager.shared.play("punch")

        // Calculate and apply damage to the hero.
        let dmg = max(1, enemy.atk - heroDef)
        heroHp  = max(0, heroHp - dmg)
        onHeroHpChanged?(heroHp, heroMaxHp)

        floatText("-\(dmg)", at: CGPoint(x: 44, y: 78),
                  color: UIColor(red: 1.0, green: 0.28, blue: 0.28, alpha: 1))
        playHeroHurt()

        if heroHp <= 0 {
            endRaid(success: false)
        }
    }

    // MARK: - Wave completion check

    private func checkWaveCompletion() {
        guard !isSpawningWave, !isRaidOver, !raidEnemies.isEmpty else { return }
        guard raidEnemies.allSatisfy({ $0.isDead }) else { return }

        // Block re-entry until the next wave is running.
        isSpawningWave = true

        if wave >= totalWaves {
            endRaid(success: true)
        } else {
            floatText("WAVE CLEAR!", at: CGPoint(x: 150, y: 95),
                      color: UIColor(red: 0.30, green: 0.90, blue: 0.40, alpha: 1), fontSize: 16)
            run(.sequence([
                .wait(forDuration: 1.8),
                .run { [weak self] in self?.startNextWave() }
            ]))
        }
    }

    // MARK: - Raid resolution

    private func endRaid(success: Bool) {
        guard !isRaidOver else { return }
        isRaidOver = true

        if success {
            floatText("RAID COMPLETE!", at: CGPoint(x: 150, y: 100),
                      color: UIColor(red: 0.95, green: 0.82, blue: 0.10, alpha: 1), fontSize: 18)
            SoundManager.shared.play("8_bit_positive_long")
        } else {
            playHeroDeath()
            SoundManager.shared.play("8_bit_defeated")
        }

        // Give the player a beat to absorb the result before the overlay fires.
        run(.sequence([
            .wait(forDuration: 1.8),
            .run { [weak self] in self?.onRaidCompleted?(success) }
        ]))
    }

    // MARK: - Hero animations

    private func playHeroAttack() {
        guard !heroIsDeathPlaying, !heroAttackFrameSets.isEmpty else { return }
        let i    = Int.random(in: 0..<heroAttackFrameSets.count)
        let anim = SKAction.animate(with: heroAttackFrameSets[i], timePerFrame: 0.10)
        let idle = SKAction.run { [weak self] in
            guard let self, !self.heroIsDeathPlaying else { return }
            self.heroNode.run(
                .repeatForever(.animate(with: self.heroIdleFrames, timePerFrame: 0.12)),
                withKey: "anim"
            )
        }
        heroNode.run(.sequence([anim, idle]), withKey: "anim")
    }

    private func playHeroHurt() {
        guard !heroIsDeathPlaying, !heroHurtFrames.isEmpty else { return }
        let anim = SKAction.animate(with: heroHurtFrames, timePerFrame: 0.12)
        let idle = SKAction.run { [weak self] in
            guard let self, !self.heroIsDeathPlaying else { return }
            self.heroNode.run(
                .repeatForever(.animate(with: self.heroIdleFrames, timePerFrame: 0.12)),
                withKey: "anim"
            )
        }
        heroNode.run(.sequence([anim, idle]), withKey: "anim")
        SoundManager.shared.play("punch_2")
    }

    private func playHeroDeath() {
        guard !heroIsDeathPlaying else { return }
        heroIsDeathPlaying = true
        heroNode.removeAllActions()
        heroNode.run(
            .animate(with: heroDeathFrames, timePerFrame: 0.15),
            withKey: "anim"
        )
    }

    // MARK: - Enemy animations

    private func playEnemyHurt(_ enemy: RaidEnemy) {
        let gen = enemy.generation
        run(.sequence([
            .wait(forDuration: 0.20),
            .run { [weak enemy] in
                guard let enemy, enemy.generation == gen, !enemy.isDead else { return }
                let anim = SKAction.animate(with: enemy.hurtFrames, timePerFrame: 0.12)
                let idle = SKAction.run { [weak enemy] in
                    guard let enemy, !enemy.isDead else { return }
                    enemy.node.run(
                        .repeatForever(.animate(with: enemy.idleFrames, timePerFrame: 0.12)),
                        withKey: "anim"
                    )
                }
                enemy.node.run(.sequence([anim, idle]), withKey: "anim")
                SoundManager.shared.play("crunch_quick")
            }
        ]))
    }

    private func playEnemyDeath(_ enemy: RaidEnemy) {
        // Stop the walk action so the enemy doesn't keep advancing after dying.
        enemy.node.removeAction(forKey: "walk")
        enemy.hpBarBg.removeFromParent()

        let gen = enemy.generation
        run(.sequence([
            .wait(forDuration: 0.20),
            .run { [weak enemy] in
                guard let enemy, enemy.generation == gen else { return }
                enemy.node.removeAllActions()
                enemy.node.run(
                    .animate(with: enemy.deathFrames, timePerFrame: 0.15),
                    withKey: "anim"
                )
                SoundManager.shared.play("crunch_quick")
                // Clean up the sprite after the death animation finishes.
                let totalDuration = TimeInterval(enemy.deathFrames.count) * 0.15 + 0.4
                enemy.node.run(.sequence([
                    .wait(forDuration: totalDuration),
                    .removeFromParent()
                ]))
            }
        ]))
    }

    // MARK: - Floating combat text

    private func floatText(_ text: String, at base: CGPoint,
                            color: UIColor, fontSize: CGFloat = 13) {
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text      = text
        label.fontSize  = fontSize
        label.fontColor = color
        label.position  = base
        label.zPosition = 20
        addChild(label)

        let up   = SKAction.moveBy(x: 0, y: 32, duration: 0.80)
        let fade = SKAction.sequence([.wait(forDuration: 0.22), .fadeOut(withDuration: 0.58)])
        let pop  = SKAction.sequence([.scale(to: 1.3, duration: 0.08), .scale(to: 1.0, duration: 0.08)])
        label.run(.sequence([.group([up, fade, pop]), .removeFromParent()]))
    }
}
