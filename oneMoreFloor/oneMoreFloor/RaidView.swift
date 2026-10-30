import SwiftUI
import SpriteKit

// MARK: - Raid View

/// Full-screen raid: the RaidScene arena running full-bleed (like the battle
/// screen), a floating HUD with wave pips and what's at stake, the cash-out
/// decision between waves, and the result screen.
///
/// RaidScene runs the combat and fires callbacks; this view displays state and
/// hands decisions to DungeonGame. The raid is *resolved* the moment it ends
/// (DungeonGame.raidOutcome) — Continue on the result screen only dismisses it.
struct RaidView: View {

    let game: DungeonGame

    // MARK: - State

    @State private var heroHp:      Int
    @State private var heroMaxHp:   Int
    @State private var currentWave: Int = 0
    @State private var raidScene:   RaidScene

    /// Set when a wave is cleared and the player must choose Escape / Press On.
    @State private var clearedWave: Int?
    /// The big center banner ("WAVE 2" / "BOSS WAVE"); nil hides it.
    @State private var banner: String?
    // Juice triggers, bumped by scene callbacks.
    @State private var shakeTrigger = 0
    @State private var hurtTrigger  = 0
    /// Ability cooldown, 1 = just used … 0 = ready (driven by the scene).
    @State private var abilityCooldown: Double = 0
    /// An enemy is winding up a heavy: the DODGE button lights up.
    @State private var heavyIncoming = false

    private let accentRaid = Color(red: 0.75, green: 0.35, blue: 1.00)

    // MARK: - Init

    init(game: DungeonGame) {
        self.game = game
        let hp    = game.heroHp
        let maxHp = game.heroMaxHp
        _heroHp    = State(initialValue: hp)
        _heroMaxHp = State(initialValue: maxHp)
        _raidScene = State(initialValue: RaidScene(
            hero:     game.character,
            heroHp:   hp,
            heroMaxHp: maxHp,
            heroAtk:  game.heroAtk,
            heroDef:  game.heroDef,
            zoneID:   game.currentZone.id,
            floor:    game.currentFloor,
            critChance:       game.heroCritChance,
            splashFraction:   game.splashFraction,
            thornsFraction:   game.thornsFraction,
            killHealFraction: game.killHealFraction,
            abilityCooldown:  game.character.signatureAbility.cooldown * game.abilityCooldownScale
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.Palette.abyss.ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    // 1. The arena, edge to edge.
                    ArenaSceneView(scene: raidScene, opacity: 1, shakeTrigger: shakeTrigger)

                    // 2. Red edge flash when the hero is hit.
                    HurtFlashOverlay(trigger: hurtTrigger)

                    // 3. Tap catcher — same frame as the SpriteView, so tap
                    //    locations map straight into the scene for targeting.
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea(edges: .top)
                        .gesture(
                            SpatialTapGesture().onEnded { tap in
                                guard isFighting else { return }
                                raidScene.playerTap(atViewPoint: tap.location)
                            }
                        )

                    // 4. Floating HUD.
                    VStack(spacing: 10) {
                        raidHeader
                        stakesRow
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .allowsHitTesting(false)

                    // 5. Wave banner.
                    if let banner {
                        waveBanner(banner)
                            .frame(maxHeight: .infinity)
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 1.6).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                heroPanel
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 14)
            }

            // Between waves: Escape or Press On.
            if let wave = clearedWave, game.raidOutcome == nil {
                decisionOverlay(clearedWave: wave)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // The raid is over — show how it went.
            if let outcome = game.raidOutcome {
                resultOverlay(outcome)
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35), value: clearedWave)
        .animation(.easeInOut(duration: 0.3), value: game.raidOutcome)
        .onAppear { wireUpScene() }
    }

    private var isFighting: Bool { game.isRaidActive && clearedWave == nil }

    // MARK: - Wire-up

    /// Connects RaidScene callbacks to local state and to DungeonGame.
    private func wireUpScene() {
        raidScene.onHeroHpChanged = { hp, _ in heroHp = hp }
        raidScene.onWaveChanged   = { wave, _ in currentWave = wave }
        raidScene.onWaveStarted   = { wave, total, isBoss in
            showBanner(isBoss ? "BOSS WAVE" : "WAVE \(wave) / \(total)")
            if isBoss { shakeTrigger += 1; Haptics.notify(.warning) }
        }
        raidScene.onWaveCleared = { wave, _ in
            Haptics.notify(.success)
            clearedWave = wave
        }
        raidScene.onHeroHurt = { hurtTrigger += 1 }
        raidScene.onHeroCrit = { shakeTrigger += 1; Haptics.impact(.heavy) }
        raidScene.onAbilityCooldown = { fraction in
            // A soft ping the moment the ability comes back.
            if abilityCooldown > 0 && fraction == 0 { SoundManager.shared.play("ability_ready") }
            abilityCooldown = fraction
        }
        raidScene.onHeavyWarning = { incoming in
            withAnimation(.spring(response: 0.25)) { heavyIncoming = incoming }
            if incoming { Haptics.impact(.rigid) }
        }
        raidScene.onDodged = { Haptics.notify(.success) }
        raidScene.onRaidCompleted = { success in
            // Resolve immediately: rewards/penalties land now, not on Continue.
            game.completeRaid(success: success, heroHpAfterRaid: raidScene.heroHp)
            Haptics.notify(success ? .success : .error)
        }
    }

    private func showBanner(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { banner = text }
        Task {
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeIn(duration: 0.25)) { banner = nil }
        }
    }

    // MARK: - HUD

    /// "RAID" + zone on the left, wave pips on the right.
    private var raidHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Label("RAID", systemImage: "flag.2.crossed.fill")
                    .font(Theme.Fonts.display(20))
                    .foregroundStyle(accentRaid)
                    .gameShadow(2)
                Text("\(Image(systemName: game.currentZone.icon)) \(game.currentZone.shortName) · floor \(game.currentFloor)")
                    .font(Theme.Fonts.label(12))
                    .foregroundStyle(Theme.Palette.dust)
                    .gameShadow(1)
            }
            Spacer()
            // Wave pips: done = green, current = violet, upcoming = dim. The last is the boss.
            HStack(spacing: 6) {
                ForEach(1...3, id: \.self) { wave in
                    let done    = wave < currentWave || (wave == currentWave && clearedWave == wave)
                    let current = wave == currentWave && !done
                    Image(systemName: wave == 3 ? "crown.fill" : "circle.fill")
                        .font(.system(size: wave == 3 ? 14 : 11, weight: .bold))
                        .foregroundStyle(done ? Theme.Palette.life : current ? accentRaid : Theme.Palette.ash)
                        .gameShadow(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .gamePanel(tint: accentRaid.opacity(0.6), cornerRadius: 16, translucent: true)
        }
    }

    /// What rides on this raid, always visible: blessings + pot vs. the prize.
    private var stakesRow: some View {
        HStack(spacing: 8) {
            let blessings = game.activeEffects.filter { $0.isBlessing }
            if !blessings.isEmpty {
                chip {
                    HStack(spacing: 2) { ForEach(blessings) { Text($0.icon).font(.system(size: 12)) } }
                }
            }
            if game.atRiskGold > 0 {
                chip {
                    Label("\(game.atRiskGold)", systemImage: "bag.fill")
                        .font(Theme.Fonts.number(13))
                        .foregroundStyle(Theme.Palette.gold)
                }
            }
            Spacer()
            chip {
                Text("WIN +\(game.raidShardReward) ◈")
                    .font(Theme.Fonts.label(12))
                    .foregroundStyle(Theme.Palette.shard)
            }
        }
    }

    private func chip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 10)
            .frame(height: 28)
            .gamePanel(cornerRadius: 14, translucent: true)
    }

    private func waveBanner(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.display(text == "BOSS WAVE" ? 40 : 34))
            .foregroundStyle(text == "BOSS WAVE" ? Theme.Palette.blood : Theme.Palette.parchment)
            .gameShadow(4)
    }

    /// Hero name, HP bar, and a one-line control hint, under the arena.
    private var heroPanel: some View {
        let pct = Double(max(0, heroHp)) / Double(max(1, heroMaxHp))
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(game.character.name.uppercased())
                    .font(Theme.Fonts.display(15))
                    .foregroundStyle(Theme.Palette.parchment)
                    .gameShadow()
                Spacer()
                Text("\(max(0, heroHp)) / \(heroMaxHp)")
                    .font(Theme.Fonts.number(13))
                    .foregroundStyle(Theme.Palette.parchment.opacity(0.8))
            }
            GameBar(fraction: pct,
                    color: pct > 0.5 ? Theme.Palette.life : pct > 0.25 ? Theme.Palette.warning : Theme.Palette.blood,
                    height: 14)
            Label("Tap an enemy to focus it · tap anywhere to strike", systemImage: "hand.tap.fill")
                .font(Theme.Fonts.label(11))
                .foregroundStyle(Theme.Palette.dust)
            raidActions
                .padding(.top, 4)
        }
        .padding(14)
        .gamePanel(cornerRadius: 16)
    }

    // MARK: - Ability + Dodge

    /// The class ability (left) and DODGE (right). DODGE glows red and
    /// pulses while an enemy is winding up a heavy — that's the cue to press it.
    private var raidActions: some View {
        let ability = game.character.signatureAbility
        let ready   = abilityCooldown <= 0
        return HStack(spacing: 10) {
            Button {
                if raidScene.useAbility() { Haptics.impact(.heavy) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: ability.icon)
                        .font(.system(size: 18, weight: .bold))
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ability.name.uppercased())
                            .font(Theme.Fonts.display(13))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(ready ? "READY" : "COOLING")
                            .font(Theme.Fonts.label(9))
                            .opacity(0.75)
                    }
                }
                .foregroundStyle(ready ? Color.black.opacity(0.8) : Theme.Palette.ash)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(face: ready ? Theme.Palette.flame : Theme.Palette.stoneHi,
                                           lip: ready ? Theme.Palette.flame.mix(with: .black, by: 0.5) : .black,
                                           cornerRadius: 12, depth: 4))
            // The cooldown drains away left-to-right over the button.
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: geo.size.width * abilityCooldown)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)
            }
            .disabled(!ready || !isFighting)

            Button {
                raidScene.playerDodge()
                Haptics.impact(.light)
            } label: {
                Label("DODGE", systemImage: "figure.run")
                    .font(Theme.Fonts.display(16))
                    .foregroundStyle(heavyIncoming ? .white : Theme.Palette.parchment)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChunkyButtonStyle(face: heavyIncoming ? Theme.Palette.blood : Theme.Palette.stoneHi,
                                           lip: heavyIncoming ? Theme.Palette.blood.mix(with: .black, by: 0.5) : .black,
                                           cornerRadius: 12, depth: 4))
            .scaleEffect(heavyIncoming ? 1.06 : 1)
            .shadow(color: heavyIncoming ? Theme.Palette.blood.opacity(0.7) : .clear, radius: 10)
            .disabled(!isFighting)
        }
        .frame(height: 52)
    }

    // MARK: - Between-wave decision

    /// The raid's push-your-luck beat: bank a share of the shards now, or risk
    /// your blessings and pot for the full prize.
    private func decisionOverlay(clearedWave wave: Int) -> some View {
        let escape     = game.raidEscapeReward(wavesCleared: wave)
        let nextCount  = RaidScene.enemyCount(wave: wave + 1)
        let bossNext   = wave + 1 == 3
        let heal       = RaidScene.raidScaled(heroMaxHp, by: RaidScene.breatherHealFraction)
        let blessings  = game.activeEffects.filter { $0.isBlessing }.count

        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text("WAVE \(wave) CLEARED")
                        .font(Theme.Fonts.display(26))
                        .foregroundStyle(Theme.Palette.life)
                        .gameShadow(3)
                    Text("+\(heal) HP · catch your breath")
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(Theme.Palette.dust)
                }

                // What's next.
                Label("Next: \(nextCount) enemies\(bossNext ? ", including the boss" : "")",
                      systemImage: bossNext ? "crown.fill" : "person.3.fill")
                    .font(Theme.Fonts.label(14))
                    .foregroundStyle(bossNext ? Theme.Palette.blood : Theme.Palette.parchment)

                // What pressing on risks.
                if blessings > 0 || game.atRiskGold > 0 {
                    Text("Fall and you lose " + lossParts(blessings: blessings, gold: game.atRiskGold) + ".")
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Theme.Palette.flame)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Button {
                        raidScene.endForEscape()
                        game.escapeRaid(wavesCleared: wave, heroHpAfterRaid: raidScene.heroHp)
                        Haptics.impact(.medium)
                    } label: {
                        choiceLabel(title: "ESCAPE", icon: "figure.walk.departure",
                                    subtitle: "+\(escape) ◈ · keep it all")
                    }
                    .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.life.mix(with: .black, by: 0.3),
                                                   lip: Theme.Palette.lifeDeep.mix(with: .black, by: 0.5)))

                    Button {
                        clearedWave = nil
                        raidScene.continueToNextWave()
                        Haptics.impact(.heavy)
                    } label: {
                        choiceLabel(title: "PRESS ON", icon: "flame.fill",
                                    subtitle: "full clear: +\(game.raidShardReward) ◈ + loot")
                    }
                    .buttonStyle(ChunkyButtonStyle(face: accentRaid.mix(with: .black, by: 0.25),
                                                   lip: accentRaid.mix(with: .black, by: 0.7)))
                }
                .frame(height: 76)
            }
            .padding(20)
            .gamePanel(tint: Theme.Palette.life.opacity(0.7), cornerRadius: 20)
            .padding(.horizontal, 18)
        }
    }

    private func choiceLabel(title: String, icon: String, subtitle: String) -> some View {
        VStack(spacing: 3) {
            Label(title, systemImage: icon)
                .font(Theme.Fonts.display(17))
                .foregroundStyle(.white)
                .gameShadow()
            Text(subtitle)
                .font(Theme.Fonts.label(10))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
        }
    }

    // MARK: - Result

    private func resultOverlay(_ outcome: DungeonGame.RaidOutcome) -> some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                switch outcome.kind {
                case .cleared:
                    resultHeader(icon: "trophy.fill", title: "RAID CLEARED", color: Theme.Palette.gold)
                    shardsEarned(outcome.shards)
                    if let loot = outcome.loot { lootCard(loot) }
                case .escaped(let wave):
                    resultHeader(icon: "figure.walk.departure", title: "ESCAPED", color: Theme.Palette.frost)
                    Text("after wave \(wave) · blessings and gold kept")
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(Theme.Palette.dust)
                    shardsEarned(outcome.shards)
                case .lost:
                    resultHeader(icon: "xmark.shield.fill", title: "RAID FAILED", color: Theme.Palette.blood)
                    Text(outcome.blessingsLost > 0 || outcome.goldLost > 0
                         ? "You lost " + lossParts(blessings: outcome.blessingsLost, gold: outcome.goldLost) + "."
                         : "You escape, badly wounded.")
                        .font(Theme.Fonts.body(15))
                        .foregroundStyle(Theme.Palette.parchment.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Button {
                    game.dismissRaidOutcome()
                } label: {
                    Text("CONTINUE")
                        .font(Theme.Fonts.display(18))
                        .foregroundStyle(Theme.Palette.parchment)
                        .gameShadow()
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.stoneHi, lip: .black, cornerRadius: 14, depth: 5))
                .frame(height: 58)
                .padding(.top, 4)
            }
            .padding(24)
            .gamePanel(tint: resultTint(outcome.kind).opacity(0.75), cornerRadius: 22)
            .padding(.horizontal, 28)
        }
    }

    private func resultHeader(icon: String, title: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(color)
                .gameShadow(3)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text(title)
                .font(Theme.Fonts.display(32))
                .foregroundStyle(color)
                .gameShadow(4)
        }
    }

    private func shardsEarned(_ shards: Int) -> some View {
        Text("+\(shards) ◈")
            .font(Theme.Fonts.number(40))
            .foregroundStyle(Theme.Palette.shard)
            .gameShadow(3)
    }

    /// The boss-tier drop from a full clear, framed in its rarity color.
    private func lootCard(_ item: Equipment) -> some View {
        HStack(spacing: 12) {
            ItemIconView(item: item, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(Theme.Fonts.label(15))
                    .foregroundStyle(Theme.Palette.parchment)
                Text(item.rarity.label.uppercased())
                    .font(Theme.Fonts.label(11))
                    .foregroundStyle(item.rarity.uiColor)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .gamePanel(tint: item.rarity.uiColor.opacity(0.8), cornerRadius: 14)
        .shadow(color: item.rarity.uiColor.opacity(0.45), radius: 14)
    }

    private func resultTint(_ kind: DungeonGame.RaidOutcome.Kind) -> Color {
        switch kind {
        case .cleared: return Theme.Palette.gold
        case .escaped: return Theme.Palette.frost
        case .lost:    return Theme.Palette.blood
        }
    }

    /// "3 blessings and 100 gold", skipping whatever is zero.
    private func lossParts(blessings: Int, gold: Int) -> String {
        var parts: [String] = []
        if blessings > 0 { parts.append("\(blessings) blessing\(blessings == 1 ? "" : "s")") }
        if gold > 0      { parts.append("\(gold) gold") }
        return parts.joined(separator: " and ")
    }
}
