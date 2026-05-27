import SpriteKit

// Shared SKView used only to rasterize atlas-backed textures into plain textures,
// which is required because SKTexture(rect:in:) gives wrong dimensions when
// the source texture is backed by a compiled .atlasc file.
private let _sheetBaker = SKView()

private func buildFrames(_ spec: AnimationSpec) -> [SKTexture] {
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

    private let heroClass: CharacterClass
    private var currentEnemy: EnemyType

    init(hero: CharacterClass, initialEnemy: EnemyType, initialZoneID: String = "entrance") {
        heroClass     = hero
        currentEnemy  = initialEnemy
        currentZoneID = initialZoneID
        super.init(size: CGSize(width: 200, height: 200))
        scaleMode       = .aspectFill
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        view.backgroundColor = .clear

        // Zone background — sits behind all sprites. Sized to cover the visible
        // (aspectFill-cropped) area of the 200x200 scene on every phone width.
        bgNode = SKSpriteNode(texture: backgroundTexture(for: currentZoneID))
        bgNode.position  = CGPoint(x: 100, y: 100)
        bgNode.size      = CGSize(width: 360, height: 360 * 270.0 / 480.0) // keep 16:9
        bgNode.zPosition = -10
        // Dim the backdrop so the character sprites stand out against it.
        bgNode.color            = .black
        bgNode.colorBlendFactor = 0.4
        addChild(bgNode)

        loadHeroFrames()
        heroNode = SKSpriteNode(texture: heroIdleFrames.first)
        heroNode.setScale(2.5)
        heroNode.position = CGPoint(x: 50, y: 68)
        addChild(heroNode)

        loadEnemyFrames(currentEnemy)
        enemyNode = SKSpriteNode(texture: enemyIdleFrames.first)
        enemyNode.setScale(2.5)
        enemyNode.position = CGPoint(x: 150, y: 68)
        enemyNode.xScale   = -2.5
        addChild(enemyNode)

        isReady = true
        playHeroIdle()
        playEnemyIdle()
    }

    // MARK: - Frame loading

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
        if let tex = heroProjectileTexture {
            run(.sequence([.wait(forDuration: 0.35),
                           .run { [weak self] in self?.fireProjectile(texture: tex, fromHero: true) }]))
        }
    }

    func playHeroHurt() {
        guard isReady, !isHeroDeathPlaying else { return }
        heroOneShot(heroHurtFrames, fps: 0.12)
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
    }

    func playHeroHeal() {
        guard isReady, !isHeroDeathPlaying, !heroHealFrames.isEmpty else { return }
        heroOneShot(heroHealFrames, fps: 0.12)
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
            }
        ]))
    }

    private func enemyOneShot(_ frames: [SKTexture], fps: TimeInterval) {
        enemyNode.removeAction(forKey: "anim")
        let anim = SKAction.animate(with: frames, timePerFrame: fps)
        let done = SKAction.run { [weak self] in self?.playEnemyIdle() }
        enemyNode.run(.sequence([anim, done]), withKey: "anim")
    }

    private func fireProjectile(texture: SKTexture, fromHero: Bool) {
        let arrow = SKSpriteNode(texture: texture)
        arrow.yScale    = 1.5
        arrow.xScale    = fromHero ? 1.5 : -1.5
        arrow.zPosition = 10
        arrow.position  = fromHero ? CGPoint(x: 65, y: 62) : CGPoint(x: 135, y: 62)
        let destX: CGFloat = fromHero ? 145 : 55
        arrow.run(.sequence([.moveTo(x: destX, duration: 0.28), .removeFromParent()]))
        addChild(arrow)
    }

    // MARK: - Floating combat text

    func showHeroDamage(_ amount: Int) {
        floatText("-\(amount)", at: CGPoint(x: 44, y: 73),
                  color: UIColor(red: 1.0, green: 0.28, blue: 0.28, alpha: 1))
    }

    func showMonsterDamage(_ amount: Int) {
        run(.sequence([
            .wait(forDuration: heroHitDelay),
            .run { [weak self] in
                self?.floatText("-\(amount)", at: CGPoint(x: 156, y: 73),
                                color: UIColor(red: 1.0, green: 0.60, blue: 0.15, alpha: 1))
            }
        ]))
    }

    func showMonsterCritDamage(_ amount: Int) {
        run(.sequence([
            .wait(forDuration: heroHitDelay),
            .run { [weak self] in
                self?.floatText("⚡\(amount)", at: CGPoint(x: 156, y: 73),
                                color: UIColor(red: 1.0, green: 0.88, blue: 0.12, alpha: 1),
                                fontSize: 18)
            }
        ]))
    }

    func showHeroHeal(_ amount: Int) {
        floatText("+\(amount)", at: CGPoint(x: 44, y: 73),
                  color: UIColor(red: 0.20, green: 0.90, blue: 0.38, alpha: 1))
    }

    func showGoldReward(_ amount: Int) {
        let wait  = SKAction.wait(forDuration: heroHitDelay + 0.38)
        let spawn = SKAction.run { [weak self] in
            self?.floatText("+\(amount)g", at: CGPoint(x: 150, y: 53),
                            color: UIColor(red: 0.95, green: 0.82, blue: 0.10, alpha: 1))
        }
        run(.sequence([wait, spawn]))
    }

    private func floatText(_ text: String, at base: CGPoint, color: UIColor, fontSize: CGFloat = 14) {
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text      = text
        label.fontSize  = fontSize
        label.fontColor = color
        label.position  = CGPoint(x: base.x + CGFloat.random(in: -8...8), y: base.y)
        label.zPosition = 20
        addChild(label)

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
