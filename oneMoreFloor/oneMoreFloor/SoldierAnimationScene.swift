import SpriteKit

// Shared SKView used only to rasterize atlas-backed textures into plain textures,
// which is required because SKTexture(rect:in:) gives wrong dimensions when
// the source texture is backed by a compiled .atlasc file.
// Internal (not private) so RaidScene.swift can share the same baker and helper.
let _sheetBaker = SKView()

func buildFrames(_ spec: AnimationSpec) -> [SKTexture] {
    // Compiled .atlasc stores texture names with %20 for spaces; encode before lookup.
    let lookupName = spec.imageName.replacingOccurrences(of: " ", with: "%20")
    let raw = SKTexture(imageNamed: lookupName)
    raw.filteringMode = .nearest

    // Rasterize to a plain (non-atlas) texture so SKTexture(rect:in:) works correctly.
    let node = SKSpriteNode(texture: raw)
    node.position = CGPoint(x: raw.size().width / 2, y: raw.size().height / 2)
    _sheetBaker.frame = CGRect(origin: .zero, size: raw.size())
    let sheet = _sheetBaker.texture(from: node, crop: CGRect(origin: .zero, size: raw.size())) ?? raw
    sheet.filteringMode = .nearest

    let w = 1.0 / CGFloat(spec.frameCount)
    return (0..<spec.frameCount).map { i in
        let t = SKTexture(rect: CGRect(x: CGFloat(i) * w, y: 0, width: w, height: 1), in: sheet)
        t.filteringMode = .nearest
        return t
    }
}

// MARK: - Idle Preview (character select)

class IdlePreviewScene: SKScene {
    private let idleSpec: AnimationSpec

    init(idleSpec: AnimationSpec) {
        self.idleSpec = idleSpec
        super.init(size: CGSize(width: 180, height: 120))
        scaleMode    = .resizeFill
        anchorPoint  = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.backgroundColor = .clear
        let frames = buildFrames(idleSpec)
        guard let first = frames.first else { return }
        let node = SKSpriteNode(texture: first)
        node.setScale(3.0)
        node.position = .zero
        addChild(node)
        node.run(.repeatForever(.animate(with: frames, timePerFrame: 0.15)))
    }
}

// MARK: - Combat Scene

class CombatScene: SKScene {

    // MARK: Layout model
    //
    // The fight is authored in a fixed 200×200 "design space" (hero at x 50,
    // enemy at x 150, feet around y 35). All gameplay nodes — sprites,
    // projectiles, floating numbers — live inside `world`, which is scaled
    // and positioned to fit whatever size the SpriteView gives us. The zone
    // backdrop sits *outside* `world` and simply fills the view.
    //
    // Why: the glow-up made the arena full-bleed and tall. With the old fixed
    // 200×200 scene + `.aspectFill`, a tall view zoomed in until the fighters
    // were cropped off the edges. Now the fighters always fit the width.

    private let world = SKNode()
    private static let designWidth: CGFloat = 200
    private static let designFeetY: CGFloat = 35      // where sprite feet land in design space
    private static let floorBand:   CGFloat = 0.28    // backdrop floor = bottom 28% of each bg image

    private var bgNode: SKSpriteNode!
    private var heroNode: SKSpriteNode!
    private var enemyNode: SKSpriteNode!

    private var currentZoneID: String

    private var isReady             = false
    private var isHeroDeathPlaying  = false
    private var isEnemyDeathPlaying = false

    // Incremented each time a new enemy spawns; delayed closures capture the value
    // at dispatch time and bail out if it no longer matches (stale callback guard).
    private var enemyGeneration = 0

    // Seconds between the hero beginning an attack and the hit visually landing.
    private var heroHitDelay: TimeInterval {
        heroProjectileTexture != nil ? 0.63 : 0.30
    }

    private var heroIdleFrames:      [SKTexture]   = []
    private var heroAttackFrameSets: [[SKTexture]]  = []
    private var heroHurtFrames:      [SKTexture]   = []
    private var heroDeathFrames:     [SKTexture]   = []
    private var heroBlockFrames:     [SKTexture]   = []
    private var heroHealFrames:      [SKTexture]   = []

    private var enemyIdleFrames:      [SKTexture]  = []
    private var enemyAttackFrameSets: [[SKTexture]] = []
    private var enemyHurtFrames:      [SKTexture]  = []
    private var enemyDeathFrames:     [SKTexture]  = []

    private var heroProjectileTexture:  SKTexture?
    private var enemyProjectileTexture: SKTexture?

    private var heroClass: CharacterClass
    private var currentEnemy: EnemyType

    init(hero: CharacterClass, initialEnemy: EnemyType, initialZoneID: String = "entrance") {
        heroClass     = hero
        currentEnemy  = initialEnemy
        currentZoneID = initialZoneID
        super.init(size: CGSize(width: 200, height: 200))
        // resizeFill: the scene's size tracks the view's size in points, and
        // `layoutForSize()` places everything to match.
        scaleMode       = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.backgroundColor = .clear

        // Zone background — fills the whole view behind the fight. Anchored at
        // its bottom edge so the floor stays planted; sized in layoutForSize().
        bgNode = SKSpriteNode(texture: backgroundTexture(for: currentZoneID))
        bgNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        bgNode.zPosition   = -10
        // Dim the backdrop so the character sprites stand out against it.
        bgNode.color            = .black
        bgNode.colorBlendFactor = 0.4
        addChild(bgNode)
        addChild(world)

        loadHeroFrames()
        heroNode = SKSpriteNode(texture: heroIdleFrames.first)
        heroNode.setScale(2.5)
        heroNode.position = CGPoint(x: 50, y: 76)
        world.addChild(heroNode)

        loadEnemyFrames(currentEnemy)
        enemyNode = SKSpriteNode(texture: enemyIdleFrames.first)
        enemyNode.setScale(2.5)
        enemyNode.position = CGPoint(x: 150, y: 76)
        enemyNode.xScale   = -2.5
        world.addChild(enemyNode)

        isReady = true
        layoutForSize()
        playHeroIdle()
        playEnemyIdle()
    }

    // MARK: - Frame loading

    // MARK: - Layout

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutForSize()
    }

    /// Fits the design space to the current view size:
    ///  1. The backdrop aspect-fills the view (16:9 art, anchored at the bottom).
    ///  2. `world` scales so the 200-wide fight spans the screen width — capped
    ///     on short/wide views (iPad, landscape) so sprites never get huge.
    ///  3. `world` shifts vertically so sprite feet stand inside the
    ///     backdrop's floor band instead of floating on the wall.
    private func layoutForSize() {
        guard isReady, size.width > 0, size.height > 0 else { return }

        // 1. Backdrop.
        let bgHeight = max(size.height, size.width * 270.0 / 480.0)
        bgNode.size     = CGSize(width: bgHeight * 480.0 / 270.0, height: bgHeight)
        bgNode.position = CGPoint(x: size.width / 2, y: 0)

        // 2. World scale.
        let k = min(size.width / Self.designWidth, size.height / 170)
        world.setScale(k)

        // 3. Feet a bit under halfway up the floor band.
        let feetY = bgHeight * Self.floorBand * 0.45
        world.position = CGPoint(x: (size.width - Self.designWidth * k) / 2,
                                 y: feetY - Self.designFeetY * k)
    }

    private func frames(_ spec: AnimationSpec) -> [SKTexture] { buildFrames(spec) }

    private func loadHeroFrames() {
        heroIdleFrames         = frames(heroClass.idle)
        heroAttackFrameSets    = heroClass.attacks.map { frames($0) }
        heroHurtFrames         = frames(heroClass.hurt)
        heroDeathFrames        = frames(heroClass.death)
        heroBlockFrames        = heroClass.block.map { frames($0) } ?? []
        heroHealFrames         = heroClass.heal.map  { frames($0) } ?? []
        heroProjectileTexture  = heroClass.projectile.map {
            buildFrames(AnimationSpec(imageName: $0, frameCount: 1)).first!
        }
    }

    private func loadEnemyFrames(_ enemy: EnemyType) {
        enemyIdleFrames         = frames(enemy.idle)
        enemyAttackFrameSets    = enemy.attacks.map { frames($0) }
        enemyHurtFrames         = frames(enemy.hurt)
        enemyDeathFrames        = frames(enemy.death)
        enemyProjectileTexture  = enemy.projectile.map {
            buildFrames(AnimationSpec(imageName: $0, frameCount: 1)).first!
        }
    }

    func updateEnemy(_ enemy: EnemyType) {
        enemyGeneration    += 1
        currentEnemy        = enemy
        isEnemyDeathPlaying = false
        loadEnemyFrames(enemy)
        enemyNode?.removeAllActions()
        enemyNode?.texture = enemyIdleFrames.first
        // Reset scale in case a tap-pop or telegraph pulse was mid-flight.
        enemyNode?.xScale = -2.5
        enemyNode?.yScale = 2.5
    }

    /// Swaps the hero sprite's class — used when the player retires or
    /// changes their hero mid-run without rebuilding the whole scene.
    /// Caller should follow up with `playHeroIdle()` to resume animating.
    func updateHero(_ hero: CharacterClass) {
        heroClass           = hero
        isHeroDeathPlaying  = false
        loadHeroFrames()
        heroNode?.removeAllActions()
        heroNode?.texture = heroIdleFrames.first
        heroNode?.setScale(2.5)
    }

    // MARK: - Zone background

    private func backgroundTexture(for zoneID: String) -> SKTexture {
        let tex = SKTexture(imageNamed: "bg_\(zoneID)")
        tex.filteringMode = .nearest   // keep the pixel art crisp when scaled
        return tex
    }

    /// Swaps the zone backdrop. Safe to call every floor change — it only
    /// touches the texture when the zone actually changes. Call this while the
    /// SpriteView is faded out (during a floor transition) so the swap is hidden.
    func updateZoneBackground(_ zoneID: String) {
        guard zoneID != currentZoneID else { return }
        currentZoneID = zoneID
        bgNode?.texture = backgroundTexture(for: zoneID)
    }

    // MARK: - Hero

    func playHeroIdle() {
        guard isReady else { return }
        isHeroDeathPlaying = false
        heroNode.removeAction(forKey: "anim")
        heroNode.run(
            .repeatForever(.animate(with: heroIdleFrames, timePerFrame: 0.12)),
            withKey: "anim"
        )
    }

    func playHeroAttack() {
        guard isReady, !isHeroDeathPlaying else { return }
        let i = Int.random(in: 0..<heroAttackFrameSets.count)
        heroOneShot(heroAttackFrameSets[i], fps: 0.10)
        SoundManager.shared.play(Bool.random() ? "sword_slice" : "sword_light")
        if let tex = heroProjectileTexture {
            run(.sequence([.wait(forDuration: 0.35),
                           .run { [weak self] in self?.fireProjectile(texture: tex, fromHero: true) }]))
        }
    }

    func playHeroHurt() {
        guard isReady, !isHeroDeathPlaying else { return }
        heroOneShot(heroHurtFrames, fps: 0.12)
        SoundManager.shared.play("punch_2")
    }

    func playHeroDeath() {
        guard isReady else { return }
        isHeroDeathPlaying = true
        heroNode.removeAction(forKey: "anim")
        heroNode.run(.animate(with: heroDeathFrames, timePerFrame: 0.15), withKey: "anim")
    }

    func playHeroBlock() {
        guard isReady, !isHeroDeathPlaying, !heroBlockFrames.isEmpty else { return }
        heroOneShot(heroBlockFrames, fps: 0.10)
        SoundManager.shared.play("sword_clash")
    }

    func playHeroHeal() {
        guard isReady, !isHeroDeathPlaying, !heroHealFrames.isEmpty else { return }
        heroOneShot(heroHealFrames, fps: 0.12)
        SoundManager.shared.play("heart_collect")
    }

    private func heroOneShot(_ frames: [SKTexture], fps: TimeInterval) {
        heroNode.removeAction(forKey: "anim")
        let anim = SKAction.animate(with: frames, timePerFrame: fps)
        let done = SKAction.run { [weak self] in self?.playHeroIdle() }
        heroNode.run(.sequence([anim, done]), withKey: "anim")
    }

    // MARK: - Enemy

    func playEnemyIdle() {
        guard isReady else { return }
        isEnemyDeathPlaying = false
        enemyNode.removeAction(forKey: "anim")
        enemyNode.run(
            .repeatForever(.animate(with: enemyIdleFrames, timePerFrame: 0.12)),
            withKey: "anim"
        )
    }

    func playEnemyAttack() {
        guard isReady, !isEnemyDeathPlaying else { return }
        let i = Int.random(in: 0..<enemyAttackFrameSets.count)
        enemyOneShot(enemyAttackFrameSets[i], fps: 0.10)
        SoundManager.shared.play("punch")
        if let tex = enemyProjectileTexture {
            run(.sequence([.wait(forDuration: 0.35),
                           .run { [weak self] in self?.fireProjectile(texture: tex, fromHero: false) }]))
        }
    }

    func playEnemyHurt() {
        guard isReady, !isEnemyDeathPlaying else { return }
        let gen = enemyGeneration
        run(.sequence([
            .wait(forDuration: heroHitDelay),
            .run { [weak self] in
                guard let self, self.enemyGeneration == gen, !self.isEnemyDeathPlaying else { return }
                self.enemyOneShot(self.enemyHurtFrames, fps: 0.12)
                SoundManager.shared.play("crunch_quick")
            }
        ]))
    }

    func playEnemyDeath() {
        guard isReady else { return }
        isEnemyDeathPlaying = true
        let gen = enemyGeneration
        run(.sequence([
            .wait(forDuration: heroHitDelay),
            .run { [weak self] in
                guard let self, self.enemyGeneration == gen else { return }
                self.enemyNode.removeAction(forKey: "anim")
                self.enemyNode.run(.animate(with: self.enemyDeathFrames, timePerFrame: 0.15), withKey: "anim")
                SoundManager.shared.play("crunch_quick")
            }
        ]))
    }

    private func enemyOneShot(_ frames: [SKTexture], fps: TimeInterval) {
        enemyNode.removeAction(forKey: "anim")
        let anim = SKAction.animate(with: frames, timePerFrame: fps)
        let done = SKAction.run { [weak self] in self?.playEnemyIdle() }
        enemyNode.run(.sequence([anim, done]), withKey: "anim")
    }

    /// Instant squash-and-pop on the enemy when the player taps. The damage
    /// number and hurt animation still arrive on their usual delay; this just
    /// gives the tap an immediate, satisfying response.
    ///
    /// The enemy faces left via a negative xScale (base 2.5), so a uniform
    /// `scale(to:)` would flip the sprite. Instead we snap to a squashed scale
    /// and grow back with a custom action that drives both axes explicitly —
    /// which also stays correct under rapid, overlapping taps.
    func tapFeedback() {
        guard isReady, !isEnemyDeathPlaying else { return }
        enemyNode.removeAction(forKey: "tapPop")
        enemyNode.xScale = -2.25
        enemyNode.yScale = 2.25
        let grow = SKAction.customAction(withDuration: 0.10) { node, elapsed in
            let s = 2.25 + (2.5 - 2.25) * (elapsed / 0.10)
            node.xScale = -s
            node.yScale = s
        }
        enemyNode.run(grow, withKey: "tapPop")
    }

    // MARK: - Hit-stop

    /// Freezes the whole scene for a split second, then resumes. Fighting games
    /// do this on big hits so the impact registers before the action moves on.
    /// It's ~4 frames, short enough to feel like weight rather than lag.
    func hitStop(_ duration: TimeInterval) {
        guard isReady, !isPaused else { return }
        isPaused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.isPaused = false
        }
    }

    // MARK: - Heavy-attack telegraph (Phase 2b)

    /// Signal that the enemy is charging a heavy attack: a few scale pulses plus
    /// a warning glyph, so the player knows a dodge is coming up.
    func showTelegraph() {
        guard isReady, !isEnemyDeathPlaying else { return }
        enemyNode.removeAction(forKey: "tapPop")
        enemyNode.removeAction(forKey: "telegraph")
        // Relative scale keeps the enemy's left-facing (negative xScale) intact.
        let up   = SKAction.scale(by: 1.20, duration: 0.16)
        let down = SKAction.scale(by: 1.0 / 1.20, duration: 0.16)
        enemyNode.run(.repeat(.sequence([up, down]), count: 3), withKey: "telegraph")
        floatText("⚠", at: CGPoint(x: 150, y: 112),
                  color: UIColor(red: 1.0, green: 0.32, blue: 0.18, alpha: 1), fontSize: 24)
    }

    /// Feedback for a successful dodge: a blue "DODGED!" and a quick sidestep.
    func showDodge() {
        guard isReady else { return }
        floatText("DODGED!", at: CGPoint(x: 52, y: 104),
                  color: UIColor(red: 0.40, green: 0.85, blue: 1.0, alpha: 1), fontSize: 15)
        heroNode.run(.sequence([.moveBy(x: -14, y: 0, duration: 0.08),
                                .moveBy(x:  14, y: 0, duration: 0.12)]))
    }

    private func fireProjectile(texture: SKTexture, fromHero: Bool) {
        let arrow = SKSpriteNode(texture: texture)
        arrow.yScale    = 1.5
        arrow.xScale    = fromHero ? 1.5 : -1.5
        arrow.zPosition = 10
        arrow.position  = fromHero ? CGPoint(x: 65, y: 70) : CGPoint(x: 135, y: 70)
        let destX: CGFloat = fromHero ? 145 : 55
        arrow.run(.sequence([.moveTo(x: destX, duration: 0.28), .removeFromParent()]))
        world.addChild(arrow)
    }

    // MARK: - Floating combat text

    func showHeroDamage(_ amount: Int) {
        floatText("-\(amount)", at: CGPoint(x: 44, y: 81),
                  color: UIColor(red: 1.0, green: 0.28, blue: 0.28, alpha: 1))
    }

    func showMonsterDamage(_ amount: Int) {
        run(.sequence([
            .wait(forDuration: heroHitDelay),
            .run { [weak self] in
                self?.floatText("-\(amount)", at: CGPoint(x: 156, y: 81),
                                color: UIColor(red: 1.0, green: 0.60, blue: 0.15, alpha: 1))
            }
        ]))
    }

    func showMonsterCritDamage(_ amount: Int) {
        run(.sequence([
            .wait(forDuration: heroHitDelay),
            .run { [weak self] in
                self?.floatText("\(amount)!", at: CGPoint(x: 156, y: 86),
                                color: UIColor(red: 1.0, green: 0.88, blue: 0.12, alpha: 1),
                                fontSize: 22)
                // Crits freeze the action for a few frames — the impact "lands".
                self?.hitStop(0.07)
            }
        ]))
    }

    func showHeroHeal(_ amount: Int) {
        floatText("+\(amount)", at: CGPoint(x: 44, y: 81),
                  color: UIColor(red: 0.20, green: 0.90, blue: 0.38, alpha: 1))
    }

    func showGoldReward(_ amount: Int) {
        let wait  = SKAction.wait(forDuration: heroHitDelay + 0.38)
        let spawn = SKAction.run { [weak self] in
            self?.floatText("+\(amount)g", at: CGPoint(x: 150, y: 61),
                            color: UIColor(red: 0.95, green: 0.82, blue: 0.10, alpha: 1))
            SoundManager.shared.play("coin_collect")
        }
        run(.sequence([wait, spawn]))
    }

    private func floatText(_ text: String, at base: CGPoint, color: UIColor, fontSize: CGFloat = 14) {
        // Heavy font with a thick black outline, so numbers pop off the busy
        // pixel-art backdrop instead of dissolving into it (the old Courier did).
        let font = UIFont(name: "AvenirNext-Heavy", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
        let label = SKLabelNode()
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
            .strokeColor: UIColor.black,
            .strokeWidth: -5.0          // negative = fill AND stroke
        ])
        label.position  = CGPoint(x: base.x + CGFloat.random(in: -8...8), y: base.y)
        label.zPosition = 20
        world.addChild(label)

        let moveUp = SKAction.moveBy(x: 0, y: 34, duration: 0.80)
        let fade   = SKAction.sequence([
            SKAction.wait(forDuration: 0.28),
            SKAction.fadeOut(withDuration: 0.52)
        ])
        let pop = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.09),
            SKAction.scale(to: 1.0, duration: 0.09)
        ])
        label.run(.sequence([.group([moveUp, fade, pop]), .removeFromParent()]))
    }
}
