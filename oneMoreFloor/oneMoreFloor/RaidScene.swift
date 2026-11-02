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

    /// Bosses telegraph heavy attacks more often (same split as the dungeon).
    let isBoss: Bool
    /// True while this enemy is winding up a heavy attack (the red "!" is up).
    var isWindingUp = false
    /// The "!" floating over a winding-up enemy; nil the rest of the time.
    var warningNode: SKLabelNode?

    // Animation frames loaded from the sprite atlas
    let idleFrames:   [SKTexture]
    let attackFrames: [[SKTexture]]
    let hurtFrames:   [SKTexture]
    let deathFrames:  [SKTexture]

    // HP bar nodes — owned here, added as children of the scene, not the sprite.
    let hpBarBg:   SKSpriteNode
    let hpBarFill: SKSpriteNode

    static let barWidth:  CGFloat = 30
    static let barHeight: CGFloat = 4
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
        self.isBoss       = isBoss
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
    /// Fired when a wave's enemies start walking in — (wave, total, is it the boss wave).
    var onWaveStarted: ((Int, Int, Bool) -> Void)?
    /// Fired when a non-final wave is cleared. The scene then waits for
    /// `continueToNextWave()` (press on) — or the view escapes the raid.
    var onWaveCleared: ((Int, Int) -> Void)?
    /// Fired each time the hero takes a hit (drives the red edge flash).
    var onHeroHurt: (() -> Void)?
    /// Fired on a critical strike (drives the screen shake).
    var onHeroCrit: (() -> Void)?
    /// Ability cooldown as a fraction of its full length (1 = just used, 0 = ready).
    var onAbilityCooldown: ((Double) -> Void)?
    /// True while at least one enemy is winding up a heavy — light up DODGE.
    var onHeavyWarning: ((Bool) -> Void)?
    /// A heavy (or any hit) was dodged.
    var onDodged: (() -> Void)?

    // MARK: - Immutable hero config

    private let heroClass: CharacterClass
    private let heroAtk:   Int
    private let heroDef:   Int
    private(set) var heroHp: Int
    let heroMaxHp: Int

    private let zoneID: String
    private let floor:  Int

    // Carried-in modifiers. Crit uses the game's full crit chance (class +
    // legacy bonus), and blessing special effects work here like they do in
    // the dungeon — before, raids only honored flat stat blessings.
    private let critChance:       Double
    private let splashFraction:   Double   // War Surge: share of each strike that hits a second enemy
    private let thornsFraction:   Double   // Thorn Mantle: share of incoming damage reflected
    private let killHealFraction: Double   // Blood Rush: share of max HP restored per kill

    // The class's signature ability works in raids too (Phase 3 raid glow-up).
    // Its cooldown arrives already scaled by Adrenaline.
    let ability: Ability
    private let abilityCooldown: TimeInterval

    // MARK: - Layout model
    //
    // Same approach as CombatScene: the fight is authored in a fixed design
    // space (250 wide — enemies spawn at x 290, just off the right edge, and
    // walk in), and every gameplay node lives in `world`, which is scaled to
    // the view's width. The zone backdrop fills the view outside `world`, with
    // its floor band under the fighters' feet. This is what lets the raid run
    // full-bleed instead of in a 300×160 letterbox.

    private let world = SKNode()
    private static let designWidth: CGFloat = 250
    private static let designFeetY: CGFloat = 26      // sprite feet in design space (y ≈ 62 centers)
    private static let floorBand:   CGFloat = 0.28    // backdrop floor = bottom 28% of each bg image

    // MARK: - Focus target (tap an enemy to attack it first)

    private weak var focusTarget: RaidEnemy?
    private let focusRing: SKShapeNode = {
        let ring = SKShapeNode(ellipseOf: CGSize(width: 30, height: 9))
        ring.strokeColor = UIColor(red: 1.0, green: 0.80, blue: 0.28, alpha: 0.95)
        ring.lineWidth   = 1.5
        ring.fillColor   = UIColor(red: 1.0, green: 0.80, blue: 0.28, alpha: 0.18)
        ring.zPosition   = -1
        ring.isHidden    = true
        return ring
    }()

    /// True between a cleared wave and the player's Escape / Press On choice.
    private(set) var isAwaitingDecision = false

    // MARK: - Tuning knobs (first draft, 2026-10-29 — tune in playtest)
    //
    // Raid enemies used full single-fight stats but arrive several at a time,
    // so the first raid (floor 11, right after the floor-10 boss) was
    // unwinnable however you played. A Monte Carlo of this scene's timings
    // (hero entering at 60% HP, fresh Soldier, floor 11) with these values:
    //   AUTO only: lose · casual tapping (~2/s): ~50% · engaged tapping: win ·
    //   blessings without tapping: ~55%.
    // So idling loses, skill matters, and staking blessings pays off.

    /// Share of a normal floor enemy's HP a raid enemy gets.
    static let enemyHpScale:  Double = 0.45
    /// Share of a normal floor enemy's ATK a raid enemy gets.
    static let enemyAtkScale: Double = 0.55
    /// HP restored during the breather between waves, as a share of max HP.
    static let breatherHealFraction: Double = 0.15

    /// Heavy attacks in raids (2026-10-30). Enemies sometimes wind up a heavy:
    /// a red "!" for `heavyWindup` seconds, then a hit for `heavyMultiplier`×.
    /// DODGE in time and it whiffs. Chances match the dungeon. The multiplier is
    /// lower than the dungeon's 2× because raids are real-time and several
    /// enemies can wind up at once — the sim showed 2× made raids harder for
    /// players who stake blessings but don't tap, while 1.5× left that path
    /// unchanged and still rewards dodging.
    static let heavyChanceNormal = DungeonGame.heavyChanceNormal
    static let heavyChanceBoss   = DungeonGame.heavyChanceBoss
    static let heavyMultiplier: Double = 1.5
    static let heavyWindup: TimeInterval = 0.9
    /// How long one DODGE keeps the hero untouchable, and how soon it can be used again.
    static let dodgeWindow:   TimeInterval = 0.5
    static let dodgeCooldown: TimeInterval = 1.2
    /// Gap between the strikes of a burst ability (Power Strike, Fireball…).
    static let burstHitGap: TimeInterval = 0.13

    /// Damage one enemy hit deals to the hero: heavy hits are multiplied, DEF
    /// is subtracted, then an active guard (Shield Wall) cuts what's left.
    /// Static so tests can check the formula without building a scene.
    static func incomingDamage(atk: Int, def: Int, heavy: Bool, guardReduction: Double) -> Int {
        let raw = heavy ? Int(Double(atk) * heavyMultiplier) : atk
        var dmg = max(1, raw - def)
        if guardReduction > 0 { dmg = max(1, Int(Double(dmg) * (1 - guardReduction))) }
        return dmg
    }

    /// Enemies per wave: 2, 3, 4 (was 3, 4, 5).
    static func enemyCount(wave: Int) -> Int { wave + 1 }

    /// A stat scaled for raid use. Never drops below 1.
    static func raidScaled(_ stat: Int, by scale: Double) -> Int {
        max(1, Int(Double(stat) * scale))
    }

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

    // Ability, guard, and dodge timers (seconds, counting down in update()).
    private var abilityCooldownRemaining: TimeInterval = 0   // ready from the start
    private var lastReportedCooldown: Double = -1
    private var guardRemaining: TimeInterval = 0
    private var guardReduction: Double = 0
    private var dodgeRemaining: TimeInterval = 0
    private var dodgeCooldownRemaining: TimeInterval = 0
    private var wasHeavyIncoming = false

    var isAbilityReady: Bool { abilityCooldownRemaining <= 0 }
    var canDodge: Bool { dodgeCooldownRemaining <= 0 }

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
         zoneID: String, floor: Int,
         critChance: Double, splashFraction: Double = 0,
         thornsFraction: Double = 0, killHealFraction: Double = 0,
         abilityCooldown: TimeInterval? = nil) {
        self.heroClass = hero
        self.heroHp    = heroHp
        self.heroMaxHp = heroMaxHp
        self.heroAtk   = heroAtk
        self.heroDef   = heroDef
        self.zoneID    = zoneID
        self.floor     = floor
        self.critChance       = critChance
        self.splashFraction   = splashFraction
        self.thornsFraction   = thornsFraction
        self.killHealFraction = killHealFraction
        self.ability          = hero.signatureAbility
        self.abilityCooldown  = abilityCooldown ?? hero.signatureAbility.cooldown
        // Wider aspect ratio than the 1v1 CombatScene — we need horizontal room
        // for enemies walking in from the right side.
        super.init(size: CGSize(width: 300, height: 160))
        // resizeFill: the scene tracks the view's size; layoutForSize() fits it.
        scaleMode       = .resizeFill
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
        bgNode.anchorPoint      = CGPoint(x: 0.5, y: 0)   // sized in layoutForSize()
        bgNode.zPosition        = -10
        bgNode.color            = .black
        bgNode.colorBlendFactor = 0.45
        addChild(bgNode)
        addChild(world)
        world.addChild(focusRing)

        // Hero — planted on the left side, facing right (positive xScale).
        loadHeroFrames()
        heroNode = SKSpriteNode(texture: heroIdleFrames.first)
        heroNode.setScale(2.2)
        heroNode.position = CGPoint(x: 45, y: 62)
        world.addChild(heroNode)
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
        world.addChild(rangeLine)
        layoutForSize()

        // Brief dramatic pause before enemies charge in.
        run(.sequence([
            .wait(forDuration: 0.7),
            .run { [weak self] in self?.startNextWave() }
        ]))
    }

    // MARK: - Layout

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutForSize()
    }

    /// Fit the design space to the view: backdrop aspect-fills (anchored at the
    /// bottom), `world` spans the width (capped on short/wide views), and the
    /// fighters' feet stand inside the backdrop's floor band.
    private func layoutForSize() {
        guard let bgNode, size.width > 0, size.height > 0 else { return }
        let bgHeight = max(size.height, size.width * 270.0 / 480.0)
        bgNode.size     = CGSize(width: bgHeight * 480.0 / 270.0, height: bgHeight)
        bgNode.position = CGPoint(x: size.width / 2, y: 0)

        let k = min(size.width / Self.designWidth, size.height / 130)
        world.setScale(k)
        let feetY = bgHeight * Self.floorBand * 0.45
        world.position = CGPoint(x: (size.width - Self.designWidth * k) / 2,
                                 y: feetY - Self.designFeetY * k)
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
        // The SwiftUI layer shows the big "WAVE 2" / "BOSS WAVE" banner.
        onWaveStarted?(wave, totalWaves, wave == totalWaves)
        if wave == totalWaves { SoundManager.shared.play("boss_arrives") }

        let pool     = DungeonGame.zoneEnemyPools[zoneID] ?? [EnemyType.skeleton]
        let bossType = DungeonGame.zoneBossEnemies[zoneID]
        let count    = Self.enemyCount(wave: wave)   // 2, 3, 4

        // Y offsets create a loose cluster so enemies don't all stack on top of each other.
        let yOffsets: [CGFloat] = [0, -10, 10, -5, 5]

        for i in 0..<count {
            // The last enemy of the final wave is the boss type for this zone.
            let isBossEnemy = (wave == totalWaves && i == count - 1)
            let eType: EnemyType = isBossEnemy
                ? (bossType ?? pool.randomElement()!)
                : (pool.randomElement()!)

            // Raid enemies are a scaled-down version of the floor's enemy,
            // because they come in groups (see the tuning knobs above).
            let hp  = Self.raidScaled(eType.scaledHp(floor: floor, isBoss: isBossEnemy),  by: Self.enemyHpScale)
            let atk = Self.raidScaled(eType.scaledAtk(floor: floor, isBoss: isBossEnemy), by: Self.enemyAtkScale)

            let enemy = RaidEnemy(
                name: eType.name, hp: hp, atk: atk, isBoss: isBossEnemy,
                idleFrames:   buildFrames(eType.idle),
                attackFrames: eType.attacks.map { buildFrames($0) },
                hurtFrames:   buildFrames(eType.hurt),
                deathFrames:  buildFrames(eType.death)
            )

            let yPos: CGFloat = 62 + yOffsets[i % yOffsets.count]
            enemy.node.position = CGPoint(x: 290, y: yPos)
            world.addChild(enemy.node)
            world.addChild(enemy.hpBarBg)
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

        tickTimers(dt)

        // Track enemy positions with their HP bars.
        for enemy in raidEnemies where !enemy.isDead {
            enemy.syncHpBar()
        }
        // The focus ring follows its enemy and disappears when it dies.
        if let target = focusTarget, !target.isDead {
            focusRing.isHidden = false
            focusRing.position = CGPoint(x: target.node.position.x, y: target.node.position.y - 24)
        } else {
            focusTarget = nil
            focusRing.isHidden = true
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
    /// `viewPoint` is where the finger landed in the SpriteView (SwiftUI's
    /// top-left origin). Tapping on or near an enemy focuses it: the hero hits
    /// that one first (when it's in range) until it dies or you pick another.
    func playerTap(atViewPoint viewPoint: CGPoint? = nil) {
        guard !isRaidOver, !heroIsDeathPlaying else { return }
        if let viewPoint {
            // Flip to SpriteKit's bottom-left origin, then into world space.
            let scenePoint = CGPoint(x: viewPoint.x, y: size.height - viewPoint.y)
            let worldPoint = world.convert(scenePoint, from: self)
            if let tapped = raidEnemies
                .filter({ !$0.isDead && hypot($0.node.position.x - worldPoint.x,
                                               $0.node.position.y - worldPoint.y) < 36 })
                .min(by: { abs($0.node.position.x - worldPoint.x) < abs($1.node.position.x - worldPoint.x) }) {
                focusTarget = tapped
            }
        }
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
        let inRange = raidEnemies.filter { !$0.isDead && $0.node.position.x <= heroHitRange }
        let focused = focusTarget.flatMap { f in inRange.first { $0 === f } }
        guard let target = focused ?? inRange.min(by: { $0.node.position.x < $1.node.position.x })
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
        let isCrit = Double.random(in: 0...1) < critChance
        let dmg    = max(1, isCrit ? heroAtk * 2 : heroAtk)
        enemy.hp  -= dmg
        SoundManager.shared.play("swing")

        let hitPos = CGPoint(x: enemy.node.position.x + 6, y: enemy.node.position.y + 20)

        if isCrit {
            floatText("\(dmg)!", at: hitPos,
                      color: UIColor(red: 1.0, green: 0.88, blue: 0.12, alpha: 1), fontSize: 16)
            hitStop(0.07)
            SoundManager.shared.play("crit")
            onHeroCrit?()
        } else {
            floatText("-\(dmg)", at: hitPos,
                      color: UIColor(red: 1.0, green: 0.60, blue: 0.15, alpha: 1))
        }

        if enemy.isDead {
            playEnemyDeath(enemy)
            healOnKill()
        } else {
            enemy.syncHpBar()
            playEnemyHurt(enemy)
        }

        // War Surge: splash part of the strike onto the next-closest enemy in range.
        let splash = BlessingCombat.splashDamage(strike: dmg, fraction: splashFraction)
        if splash > 0,
           let neighbor = Self.splashTarget(after: enemy, among: raidEnemies, hitRange: heroHitRange) {
            neighbor.hp -= splash
            floatText("-\(splash)",
                      at: CGPoint(x: neighbor.node.position.x + 6, y: neighbor.node.position.y + 20),
                      color: UIColor(red: 1.0, green: 0.75, blue: 0.40, alpha: 1), fontSize: 10)
            if neighbor.isDead {
                playEnemyDeath(neighbor)
                healOnKill()
            } else {
                neighbor.syncHpBar()
                playEnemyHurt(neighbor)
            }
        }
    }

    /// War Surge's second target: the closest living enemy in range that isn't
    /// the one just struck. Static and state-free so unit tests can drive it.
    static func splashTarget(after struck: RaidEnemy, among enemies: [RaidEnemy],
                             hitRange: CGFloat) -> RaidEnemy? {
        enemies
            .filter { $0 !== struck && !$0.isDead && $0.node.position.x <= hitRange }
            .min { $0.node.position.x < $1.node.position.x }
    }

    /// Blood Rush: each kill restores a share of max HP (same formula as the dungeon).
    private func healOnKill() {
        let heal = BlessingCombat.killHeal(maxHp: heroMaxHp, fraction: killHealFraction)
        guard heal > 0, heroHp > 0 else { return }
        heroHp = min(heroMaxHp, heroHp + heal)
        onHeroHpChanged?(heroHp, heroMaxHp)
        floatText("+\(heal)", at: CGPoint(x: 44, y: 84),
                  color: UIColor(red: 0.20, green: 0.90, blue: 0.38, alpha: 1))
    }

    // MARK: - Enemy combat

    private func enemyAttacks(_ enemy: RaidEnemy) {
        guard !isRaidOver, !heroIsDeathPlaying, !enemy.isWindingUp else { return }

        // Sometimes the swing is a telegraphed heavy instead (see knobs above).
        let heavyChance = enemy.isBoss ? Self.heavyChanceBoss : Self.heavyChanceNormal
        if Double.random(in: 0...1) < heavyChance {
            startHeavyWindup(enemy)
            return
        }

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

        hurtHero(by: enemy, heavy: false)
    }

    /// One enemy hit landing on the hero: DODGE negates it; otherwise DEF,
    /// guard, Thorn Mantle and death all happen here, for normal and heavy hits.
    private func hurtHero(by enemy: RaidEnemy, heavy: Bool) {
        if dodgeRemaining > 0 {
            floatText(heavy ? "DODGED!" : "MISS", at: CGPoint(x: 44, y: 86),
                      color: UIColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 1), fontSize: heavy ? 15 : 12)
            if heavy { SoundManager.shared.play("dodged") }
            onDodged?()
            return
        }

        let dmg = Self.incomingDamage(atk: enemy.atk, def: heroDef, heavy: heavy,
                                      guardReduction: guardRemaining > 0 ? guardReduction : 0)
        heroHp  = max(0, heroHp - dmg)
        onHeroHpChanged?(heroHp, heroMaxHp)

        floatText(heavy ? "-\(dmg)!" : "-\(dmg)", at: CGPoint(x: 44, y: 78),
                  color: UIColor(red: 1.0, green: 0.28, blue: 0.28, alpha: 1), fontSize: heavy ? 17 : 13)
        playHeroHurt()
        onHeroHurt?()
        if heavy { hitStop(0.08) }

        // Thorn Mantle: reflect part of the hit back. Like the dungeon version it
        // can't land the killing blow — it stops at 1 HP.
        let reflected = BlessingCombat.thornsReflect(incoming: dmg, fraction: thornsFraction,
                                                     attackerHp: enemy.hp)
        if reflected > 0 {
            enemy.hp -= reflected
            enemy.syncHpBar()
        }

        if heroHp <= 0 {
            endRaid(success: false)
        }
    }

    // MARK: - Heavy attacks + dodge

    /// The enemy rears back: a pulsing red "!" over its head and a red tint for
    /// `heavyWindup` seconds, then the heavy lands (or whiffs, if you dodged).
    private func startHeavyWindup(_ enemy: RaidEnemy) {
        enemy.isWindingUp = true
        // The wind-up eats into its next swing, so heavies don't stack on normals.
        enemy.attackTimer += Self.heavyWindup

        let mark = SKLabelNode(text: "!")
        mark.fontName  = "AvenirNext-Heavy"
        mark.fontSize  = 20
        mark.fontColor = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
        mark.position  = CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 30)
        mark.zPosition = 25
        mark.run(.repeatForever(.sequence([.scale(to: 1.35, duration: 0.15), .scale(to: 1.0, duration: 0.15)])))
        world.addChild(mark)
        enemy.warningNode = mark

        enemy.node.color = .red
        enemy.node.run(.repeatForever(.sequence([
            .colorize(withColorBlendFactor: 0.55, duration: 0.15),
            .colorize(withColorBlendFactor: 0.0,  duration: 0.15)
        ])), withKey: "windup")
        SoundManager.shared.play("heavy_windup")

        run(.sequence([
            .wait(forDuration: Self.heavyWindup),
            .run { [weak self, weak enemy] in
                guard let self, let enemy else { return }
                self.resolveHeavy(enemy)
            }
        ]))
    }

    private func resolveHeavy(_ enemy: RaidEnemy) {
        clearWindup(enemy)
        guard !enemy.isDead, !isRaidOver, !heroIsDeathPlaying else { return }
        // The swing itself.
        if !enemy.attackFrames.isEmpty {
            let anim = SKAction.animate(with: enemy.attackFrames[0], timePerFrame: 0.08)
            let idle = SKAction.run { [weak enemy] in
                guard let enemy, !enemy.isDead else { return }
                enemy.node.run(.repeatForever(.animate(with: enemy.idleFrames, timePerFrame: 0.12)), withKey: "anim")
            }
            enemy.node.run(.sequence([anim, idle]), withKey: "anim")
        }
        hurtHero(by: enemy, heavy: true)
    }

    /// Removes the "!" and red tint (also used when the enemy dies mid-wind-up).
    private func clearWindup(_ enemy: RaidEnemy) {
        enemy.isWindingUp = false
        enemy.warningNode?.removeFromParent()
        enemy.warningNode = nil
        enemy.node.removeAction(forKey: "windup")
        enemy.node.colorBlendFactor = 0
    }

    /// Called by RaidView's DODGE button: a short window where nothing lands.
    /// The cooldown stops it being held down as permanent invincibility.
    func playerDodge() {
        guard canDodge, !isRaidOver, !heroIsDeathPlaying else { return }
        dodgeRemaining         = Self.dodgeWindow
        dodgeCooldownRemaining = Self.dodgeCooldown
        // A quick hop back, half-transparent while untouchable.
        heroNode.run(.sequence([
            .group([.moveBy(x: -14, y: 4, duration: 0.10), .fadeAlpha(to: 0.55, duration: 0.10)]),
            .wait(forDuration: Self.dodgeWindow - 0.1),
            .group([.moveBy(x: 14, y: -4, duration: 0.15), .fadeAlpha(to: 1.0, duration: 0.15)])
        ]), withKey: "dodge")
        SoundManager.shared.play("dodge")
    }

    // MARK: - Class ability

    /// Called by RaidView's ability button. Same three effects as the dungeon:
    /// a burst of rapid strikes, a heal, or a guard that cuts incoming damage.
    /// Returns false (and keeps the cooldown) when it can't do anything useful,
    /// e.g. a burst with no enemy in range.
    @discardableResult
    func useAbility() -> Bool {
        guard isAbilityReady, !isRaidOver, !heroIsDeathPlaying, !isAwaitingDecision else { return false }
        switch ability.effect {
        case .burst(let hits):
            guard raidEnemies.contains(where: { !$0.isDead && $0.node.position.x <= heroHitRange }) else { return false }
            floatText(ability.name.uppercased(), at: CGPoint(x: 70, y: 104),
                      color: UIColor(red: 1.0, green: 0.80, blue: 0.28, alpha: 1), fontSize: 13)
            for i in 0..<hits {
                run(.sequence([
                    .wait(forDuration: Double(i) * Self.burstHitGap),
                    .run { [weak self] in self?.burstStrike() }
                ]))
            }
        case .heal(let fraction):
            let heal = max(1, Int(Double(heroMaxHp) * fraction))
            heroHp = min(heroMaxHp, heroHp + heal)
            onHeroHpChanged?(heroHp, heroMaxHp)
            floatText("+\(heal)", at: CGPoint(x: 44, y: 86),
                      color: UIColor(red: 0.20, green: 0.90, blue: 0.38, alpha: 1), fontSize: 16)
            SoundManager.shared.play("heal")
        case .guardUp(let seconds, let reduction):
            guardRemaining = seconds
            guardReduction = reduction
            floatText(ability.name.uppercased(), at: CGPoint(x: 70, y: 104),
                      color: UIColor(red: 0.45, green: 0.85, blue: 1.0, alpha: 1), fontSize: 13)
            // A blue tint on the hero while the guard is up.
            heroNode.color = UIColor(red: 0.45, green: 0.75, blue: 1.0, alpha: 1)
            heroNode.colorBlendFactor = 0.45
        }
        abilityCooldownRemaining = abilityCooldown
        return true
    }

    /// One hit of a burst ability: an immediate strike on the focused (or
    /// nearest) enemy in range. Each hit can crit, splash, and kill.
    private func burstStrike() {
        guard !isRaidOver, !heroIsDeathPlaying else { return }
        let inRange = raidEnemies.filter { !$0.isDead && $0.node.position.x <= heroHitRange }
        let focused = focusTarget.flatMap { f in inRange.first { $0 === f } }
        guard let target = focused ?? inRange.min(by: { $0.node.position.x < $1.node.position.x }) else { return }
        playHeroAttack()
        applyHeroDamageTo(target)
    }

    /// Counts down the ability, guard, and dodge timers, and tells the view
    /// about cooldown progress and incoming heavies.
    private func tickTimers(_ dt: TimeInterval) {
        if abilityCooldownRemaining > 0 { abilityCooldownRemaining = max(0, abilityCooldownRemaining - dt) }
        if dodgeRemaining > 0           { dodgeRemaining = max(0, dodgeRemaining - dt) }
        if dodgeCooldownRemaining > 0   { dodgeCooldownRemaining = max(0, dodgeCooldownRemaining - dt) }
        if guardRemaining > 0 {
            guardRemaining = max(0, guardRemaining - dt)
            if guardRemaining == 0 { heroNode.colorBlendFactor = 0 }
        }

        // Report cooldown in 2% steps, so SwiftUI isn't redrawn 60 times a second.
        let fraction = abilityCooldown > 0 ? abilityCooldownRemaining / abilityCooldown : 0
        let stepped  = (fraction * 50).rounded(.up) / 50
        if stepped != lastReportedCooldown {
            lastReportedCooldown = stepped
            onAbilityCooldown?(stepped)
        }

        let heavyIncoming = raidEnemies.contains { $0.isWindingUp && !$0.isDead }
        if heavyIncoming != wasHeavyIncoming {
            wasHeavyIncoming = heavyIncoming
            onHeavyWarning?(heavyIncoming)
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

            // Breather: catch your breath before the next wave.
            let heal = Self.raidScaled(heroMaxHp, by: Self.breatherHealFraction)
            heroHp = min(heroMaxHp, heroHp + heal)
            onHeroHpChanged?(heroHp, heroMaxHp)
            floatText("+\(heal)", at: CGPoint(x: 44, y: 84),
                      color: UIColor(red: 0.20, green: 0.90, blue: 0.38, alpha: 1))
            // Push-your-luck beat: pause and let the player escape with a share
            // of the reward, or press on (see continueToNextWave()).
            isAwaitingDecision = true
            let cleared = wave
            run(.sequence([
                .wait(forDuration: 0.9),
                .run { [weak self] in self?.onWaveCleared?(cleared, self?.totalWaves ?? 3) }
            ]))
        }
    }

    // MARK: - Between-wave decision

    /// Press on: start the next wave after a short beat.
    func continueToNextWave() {
        guard isAwaitingDecision, !isRaidOver else { return }
        isAwaitingDecision = false
        run(.sequence([
            .wait(forDuration: 0.5),
            .run { [weak self] in self?.startNextWave() }
        ]))
    }

    /// Escape: stop the raid here. DungeonGame.escapeRaid() pays out; this just
    /// freezes the scene so nothing else happens behind the result screen.
    func endForEscape() {
        guard isAwaitingDecision else { return }
        isAwaitingDecision = false
        isRaidOver = true
    }

    // MARK: - Hit-stop

    /// Freeze the scene for a few frames on a big hit (same trick as CombatScene).
    private func hitStop(_ duration: TimeInterval) {
        guard !isPaused else { return }
        isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isPaused = false
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
        SoundManager.shared.play("hero_hurt")
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
                SoundManager.shared.play("enemy_hit")
            }
        ]))
    }

    private func playEnemyDeath(_ enemy: RaidEnemy) {
        // Killing an enemy mid-wind-up cancels its heavy.
        clearWindup(enemy)
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
                SoundManager.shared.play("enemy_death")
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
        // Heavy outlined numbers so they read over the busy pixel backdrop.
        let font  = UIFont(name: "AvenirNext-Heavy", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color,
            .strokeColor: UIColor.black, .strokeWidth: -5.0
        ])
        label.position  = base
        label.zPosition = 20
        world.addChild(label)

        let up   = SKAction.moveBy(x: 0, y: 32, duration: 0.80)
        let fade = SKAction.sequence([.wait(forDuration: 0.22), .fadeOut(withDuration: 0.58)])
        let pop  = SKAction.sequence([.scale(to: 1.3, duration: 0.08), .scale(to: 1.0, duration: 0.08)])
        label.run(.sequence([.group([up, fade, pop]), .removeFromParent()]))
    }
}
