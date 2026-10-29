// BattleViews.swift
// Everything on the battle tab: the full-bleed arena, floating HUD (header,
// greed gauge, versus bars), the strike/ability thumb zone, active effects,
// consumables, and floor event cards.

import SwiftUI
import SpriteKit

// MARK: - Battle Tab
//
// The glow-up layout. The old screen stacked five equal-weight bordered cards
// with the art squeezed into a 230pt letterbox in the middle — it read like a
// settings page. Now the dungeon *is* the screen:
//
//   ┌──────────────────────────────┐
//   │ header (floor, best, gold)   │  ← floats over the art
//   │ greed gauge + REST           │  ← top of screen, far from the thumb
//   │ hero HP  ⚔  enemy HP         │  ← fighting-game style, over the sprites
//   │                              │
//   │     full-bleed dungeon       │  ← tap anywhere here to strike
//   │                              │
//   ├──────────────────────────────┤
//   │ effects / consumables        │
//   │ [ability] [   STRIKE     ]   │  ← thumb zone: intended actions only
//   └──────────────────────────────┘
//
// Tap-zone rule (from OVERHAUL.md) still holds: REST lives at the top, so a
// player mashing STRIKE at the bottom can never bank by accident.

struct BattleTabView: View {
    let game: DungeonGame
    let combatScene: CombatScene
    let spriteOpacity: Double
    @Binding var autoBattle: Bool
    let onSettings: () -> Void
    let onStore: () -> Void
    // Bumped by GameView's combat callbacks; each bump plays one shake / flash.
    let shakeTrigger: Int
    let hurtTrigger: Int

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 1. The dungeon itself, edge to edge (shakes on big hits).
                ArenaSceneView(combatScene: combatScene, opacity: spriteOpacity, shakeTrigger: shakeTrigger)

                // 2. Greed heat — the screen literally heats up as greed climbs.
                GreedHeatOverlay(fraction: greedFraction(game))

                // 3. Red edge flash when the hero takes a hit.
                HurtFlashOverlay(trigger: hurtTrigger)

                // 4. Tap catcher: the open dungeon is a giant strike button.
                //    Disabled during a heavy telegraph so mashing can't
                //    accidentally "strike through" — that choice must be deliberate.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !autoBattle, !game.incomingHeavy else { return }
                        performStrike(game: game, combatScene: combatScene)
                    }

                // 5. The HUD, floating over the art.
                VStack(spacing: 10) {
                    BattleHeaderView(game: game, autoBattle: $autoBattle,
                                     onSettings: onSettings, onStore: onStore)
                    GreedGaugeView(game: game, onRest: { game.rest() })
                    VersusBarsView(game: game)
                        .allowsHitTesting(false)   // taps fall through to the strike catcher
                    if game.incomingHeavy {
                        HeavyWarningView()
                            .allowsHitTesting(false)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .animation(.spring(response: 0.3), value: game.incomingHeavy)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Secondary status — run buffs + consumables, kept out of the tap zone.
            ActiveEffectsBarView(game: game)
            ConsumablesBarView(game: game)

            // The thumb zone: ability + strike, side by side.
            ActionRowView(game: game, combatScene: combatScene, autoBattle: autoBattle)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .background(Theme.Palette.abyss)
    }
}

/// One hero strike plus its feedback. Shared by the STRIKE button and the
/// tap-anywhere dungeon so both feel identical.
func performStrike(game: DungeonGame, combatScene: CombatScene) {
    guard game.canTap else { return }
    game.playerStrike()
    combatScene.tapFeedback()
    Haptics.impact(.light)
}

/// How far greed is from ×1.0 toward its cap, as 0…1. Drives every greed visual.
func greedFraction(_ game: DungeonGame) -> Double {
    let span = game.effectiveGreedCap - 1.0
    guard span > 0 else { return 0 }
    return min(1.0, max(0, (game.greedMultiplier - 1.0) / span))
}

// MARK: - Arena Scene (full-bleed)

/// The SpriteKit fight, stretched edge to edge and under the status bar. The
/// bottom fades into the page so there's no hard "box" edge, and a dark wash
/// at the top keeps the floating HUD readable.
struct ArenaSceneView: View {
    let combatScene: CombatScene
    let opacity: Double
    let shakeTrigger: Int

    var body: some View {
        SpriteView(scene: combatScene, options: [.allowsTransparency])
            .opacity(opacity)
            // Screen shake: a quick, decaying side-to-side jolt per trigger bump.
            .keyframeAnimator(initialValue: CGFloat(0), trigger: shakeTrigger) { content, x in
                content.offset(x: x)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(7, duration: 0.035)
                    LinearKeyframe(-6, duration: 0.05)
                    LinearKeyframe(4, duration: 0.05)
                    LinearKeyframe(-2, duration: 0.05)
                    LinearKeyframe(0, duration: 0.05)
                }
            }
            // Melt the bottom edge into the page background.
            .mask(
                LinearGradient(stops: [.init(color: .black, location: 0),
                                       .init(color: .black, location: 0.90),
                                       .init(color: .clear, location: 1)],
                               startPoint: .top, endPoint: .bottom)
            )
            // Darken the top so the HUD text sits on calm ground.
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.75), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Greed Heat Overlay

/// The deeper (greedier) you go, the hotter the screen gets: an ember-red
/// vignette creeps in from the edges and embers start rising. At ×1.0 it's
/// invisible; near the cap the whole dungeon is glowing. You *feel* the risk
/// without reading a number.
struct GreedHeatOverlay: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(colors: [.clear, Theme.greedColor(fraction).opacity(0.55)],
                               center: .center,
                               startRadius: geo.size.width * 0.35,
                               endRadius: geo.size.height * 0.75)
                    .opacity(fraction)
                // Reuse the title screen's embers; they fade in with greed.
                EmberFieldView(size: geo.size)
                    .opacity(min(1, fraction * 1.5))
            }
            .animation(.easeInOut(duration: 0.6), value: fraction)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

// MARK: - Hurt Flash Overlay

/// A brief red pulse around the screen edges when the hero is hit.
struct HurtFlashOverlay: View {
    let trigger: Int

    var body: some View {
        GeometryReader { geo in
            RadialGradient(colors: [.clear, Theme.Palette.blood.opacity(0.5)],
                           center: .center,
                           startRadius: geo.size.width * 0.45,
                           endRadius: geo.size.height * 0.70)
        }
        .keyframeAnimator(initialValue: 0.0, trigger: trigger) { content, opacity in
            content.opacity(opacity)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(1.0, duration: 0.05)
                LinearKeyframe(0.0, duration: 0.35)
            }
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

// MARK: - Battle Header

/// Floor + zone on the left (with your personal-best marker), currencies and
/// quick controls on the right. Floats over the dungeon art.
struct BattleHeaderView: View {
    let game: DungeonGame
    @Binding var autoBattle: Bool
    let onSettings: () -> Void
    let onStore: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            // Floor block.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("FLOOR")
                        .font(Theme.Fonts.label(11))
                        .tracking(2)
                        .foregroundStyle(Theme.Palette.dust)
                    Text("\(game.currentFloor)")
                        .font(Theme.Fonts.number(34))
                        .foregroundStyle(Theme.Palette.parchment)
                        .gameShadow(3)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: game.currentFloor)
                }
                Text("\(game.currentZone.icon) \(game.currentZone.shortName)")
                    .font(Theme.Fonts.label(12))
                    .foregroundStyle(Theme.Palette.dust)
                    .gameShadow(1)
                bestMarker
            }

            Spacer()

            // Controls + currencies.
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Button { autoBattle.toggle() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: autoBattle ? "play.fill" : "hand.tap.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("AUTO").font(Theme.Fonts.label(11))
                        }
                        .foregroundStyle(autoBattle ? Theme.Palette.life : Theme.Palette.dust)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .gamePanel(tint: autoBattle ? Theme.Palette.life : Theme.Palette.stoneEdge,
                                   cornerRadius: 10, translucent: true)
                    }
                    .buttonStyle(.plain)
                    iconButton("gearshape.fill", tint: Theme.Palette.dust, action: onSettings)
                    iconButton("cart.fill", tint: Theme.Palette.gold, action: onStore)
                }
                HStack(spacing: 8) {
                    currencyPill(icon: "circle.fill", value: game.gold, color: Theme.Palette.gold)
                    currencyPill(icon: "diamond.fill", value: game.soulShards, color: Theme.Palette.shard)
                }
            }
        }
    }

    /// "Goal gradient" nudge: how close you are to your deepest floor ever.
    /// Being 2 floors from a record is the most "one more floor" moment there is.
    /// Hidden until the record means something (floor 5+), so a brand-new
    /// player isn't shown "NEW BEST" on every single floor.
    @ViewBuilder private var bestMarker: some View {
        let best = game.deepestFloorEver
        if best >= 5 {
            if game.currentFloor >= best {
                Label("NEW BEST", systemImage: "crown.fill")
                    .font(Theme.Fonts.label(11))
                    .foregroundStyle(Theme.Palette.gold)
                    .gameShadow(1)
            } else {
                Label("BEST \(best) · \(best - game.currentFloor) to go", systemImage: "flag.fill")
                    .font(Theme.Fonts.label(11))
                    .foregroundStyle(Theme.Palette.dust.opacity(0.85))
                    .gameShadow(1)
            }
        }
    }

    private func iconButton(_ name: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .gamePanel(cornerRadius: 10, translucent: true)
        }
        .buttonStyle(.plain)
    }

    private func currencyPill(icon: String, value: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text("\(value)")
                .font(Theme.Fonts.number(14))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: value)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .gamePanel(cornerRadius: 13, translucent: true)
    }
}

// MARK: - Greed Gauge

/// The push-your-luck dashboard, promoted from a thin bar to the star of the
/// HUD. Flame + multiplier (color heats up with greed), the at-risk pot (bounces
/// when it grows), and REST — the cash-out — up here, away from the thumb.
struct GreedGaugeView: View {
    let game: DungeonGame
    var onRest: () -> Void

    var body: some View {
        let f = greedFraction(game)
        let heat = Theme.greedColor(f)

        HStack(spacing: 12) {
            // Flame grows and starts pulsing as greed climbs.
            Image(systemName: "flame.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Theme.Palette.ember, heat],
                                                startPoint: .top, endPoint: .bottom))
                .scaleEffect(0.85 + 0.35 * f)
                .symbolEffect(.pulse, isActive: f >= 0.5)
                .frame(width: 32)
                .gameShadow()

            // Multiplier + heat bar.
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text("GREED")
                        .font(Theme.Fonts.label(11))
                        .tracking(1.5)
                        .foregroundStyle(Theme.Palette.dust)
                    Spacer(minLength: 4)
                    Text("×" + String(format: "%.1f", game.greedMultiplier))
                        .font(Theme.Fonts.number(24))
                        .foregroundStyle(heat)
                        .gameShadow()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35), value: game.greedMultiplier)
                }
                GameBar(fraction: f, color: heat, height: 9, showsGhost: false)
                    .animation(.easeOut(duration: 0.3), value: f)
            }

            // The pot: what you stand to lose.
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("\(game.atRiskGold)")
                        .font(Theme.Fonts.number(18))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Theme.Palette.gold)
                .gameShadow()
                Text("AT RISK")
                    .font(Theme.Fonts.label(9))
                    .tracking(1)
                    .foregroundStyle(Theme.Palette.flame.opacity(0.9))
            }
            .frame(minWidth: 58)
            // Bounce each time the pot grows — coins landing in the sack.
            .keyframeAnimator(initialValue: 1.0, trigger: game.atRiskGold) { content, s in
                content.scaleEffect(s)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(1.25, duration: 0.10)
                    SpringKeyframe(1.0, duration: 0.25)
                }
            }

            // REST — bank the pot, heal, reset greed.
            Button(action: onRest) {
                VStack(spacing: 1) {
                    Image(systemName: "tent.fill").font(.system(size: 15, weight: .bold))
                    Text("REST").font(Theme.Fonts.label(10))
                }
                .foregroundStyle(restEnabled ? .white : Theme.Palette.ash)
            }
            .buttonStyle(ChunkyButtonStyle(face: restEnabled ? Theme.Palette.life.mix(with: .black, by: 0.25) : Theme.Palette.stoneHi,
                                           lip: restEnabled ? Theme.Palette.lifeDeep.mix(with: .black, by: 0.4) : .black,
                                           cornerRadius: 11, depth: 3))
            .frame(width: 56, height: 50)
            .disabled(!restEnabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .gamePanel(tint: heat.opacity(0.35 + 0.65 * f), translucent: true)
        // Swallow stray taps on the panel so they don't fall through as strikes.
        .contentShape(Rectangle())
        .onTapGesture { }
    }

    // Nothing to gain from resting at full HP with an empty pot, so dim it then.
    private var restEnabled: Bool {
        !game.isGameOver && (game.atRiskGold > 0 || game.heroHp < game.heroMaxHp)
    }
}

// MARK: - Versus Bars

/// Fighting-game health bars: hero on the left, enemy on the right, both
/// draining toward the middle. Names sit above the bars with a hard shadow.
struct VersusBarsView: View {
    let game: DungeonGame

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            fighterPlate(name: game.character.name.uppercased(),
                         hp: game.heroHp, maxHp: game.heroMaxHp,
                         color: heroColor, nameColor: Theme.Palette.parchment,
                         badge: nil, mirrored: false)

            Text("VS")
                .font(Theme.Fonts.display(13))
                .foregroundStyle(Theme.Palette.dust)
                .gameShadow()
                .padding(.top, 14)

            // Between spawns there's no enemy yet (max HP 0) — the plate shows
            // "…" and an empty bar instead of a confusing "— 0 / 0".
            fighterPlate(name: game.displayMonsterMaxHp > 0 ? game.displayMonsterName.uppercased() : "…",
                         hp: game.displayMonsterHp, maxHp: game.displayMonsterMaxHp,
                         color: Theme.Palette.blood,
                         nameColor: game.displayIsBoss ? Theme.Palette.flame : Theme.Palette.parchment,
                         badge: game.displayIsBoss ? (game.bossStatusText ?? "BOSS") : nil,
                         mirrored: true)
        }
    }

    private func fighterPlate(name: String, hp: Int, maxHp: Int, color: Color, nameColor: Color,
                              badge: String?, mirrored: Bool) -> some View {
        let pct = maxHp > 0 ? Double(max(0, hp)) / Double(maxHp) : 0
        return VStack(alignment: mirrored ? .trailing : .leading, spacing: 4) {
            HStack(spacing: 6) {
                if mirrored, let badge { badgeView(badge) }
                Text(name)
                    .font(Theme.Fonts.display(14))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .gameShadow()
                if !mirrored, let badge { badgeView(badge) }
            }
            // Mirroring the enemy bar makes it drain right-to-left, toward the hero.
            GameBar(fraction: pct, color: color, height: 13)
                .scaleEffect(x: mirrored ? -1 : 1)
            Text(maxHp > 0 ? "\(max(0, hp)) / \(maxHp)" : " ")
                .font(Theme.Fonts.number(11))
                .foregroundStyle(Theme.Palette.parchment.opacity(0.75))
                .gameShadow(1)
        }
        .frame(maxWidth: .infinity, alignment: mirrored ? .trailing : .leading)
    }

    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.label(9))
            .foregroundStyle(text == "SHIELDED" ? Theme.Palette.frost : .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(text == "SHIELDED" ? Theme.Palette.frost.opacity(0.2)
                                                          : Theme.Palette.inferno.opacity(0.85)))
    }

    private var heroColor: Color {
        let pct = game.heroMaxHp > 0 ? Double(game.heroHp) / Double(game.heroMaxHp) : 0
        if pct > 0.5  { return Theme.Palette.life }
        if pct > 0.25 { return Theme.Palette.warning }
        return Theme.Palette.blood
    }
}

// MARK: - Heavy Warning

/// A loud, pulsing call-out when the enemy winds up a heavy attack, so the
/// Dodge / Strike-through choice below never sneaks up on the player.
struct HeavyWarningView: View {
    var body: some View {
        Label("HEAVY ATTACK INCOMING", systemImage: "exclamationmark.triangle.fill")
            .font(Theme.Fonts.display(15))
            .foregroundStyle(Theme.Palette.warning)
            .gameShadow()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .overlay(Capsule().strokeBorder(Theme.Palette.blood, lineWidth: 1.5))
            .phaseAnimator([1.0, 1.08]) { content, s in
                content.scaleEffect(s)
            } animation: { _ in .easeInOut(duration: 0.35) }
    }
}

// MARK: - Action Row (thumb zone)

/// The two things your thumb should ever press in a fight: your class ability
/// and STRIKE. During a heavy telegraph, STRIKE splits into the Dodge /
/// Strike-through choice; in auto-battle it becomes a status readout.
struct ActionRowView: View {
    let game: DungeonGame
    let combatScene: CombatScene
    let autoBattle: Bool

    var body: some View {
        HStack(spacing: 12) {
            AbilityButtonView(game: game)
                .frame(width: 84)

            if autoBattle {
                Button { } label: {
                    actionLabel(icon: "play.fill", title: "AUTO", subtitle: "battling on its own")
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.lifeDeep, lip: .black.opacity(0.8)))
                .disabled(true)
            } else if game.incomingHeavy {
                Button {
                    game.playerDodge()
                    Haptics.impact(.medium)
                } label: {
                    actionLabel(icon: "figure.run", title: "DODGE", subtitle: "safe, no attack")
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.frost.mix(with: .black, by: 0.35),
                                               lip: Theme.Palette.frost.mix(with: .black, by: 0.75)))

                Button {
                    game.playerStrike()
                    combatScene.tapFeedback()
                    Haptics.impact(.heavy)
                } label: {
                    actionLabel(icon: "bolt.fill", title: "STRIKE", subtitle: "take the hit")
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.blood, lip: Theme.Palette.blood.mix(with: .black, by: 0.6)))
            } else {
                Button {
                    performStrike(game: game, combatScene: combatScene)
                } label: {
                    actionLabel(icon: "bolt.fill", title: "STRIKE", subtitle: "or tap the dungeon")
                }
                .buttonStyle(ChunkyButtonStyle(face: game.canTap ? Theme.Palette.blood : Theme.Palette.stoneHi,
                                               lip: game.canTap ? Theme.Palette.blood.mix(with: .black, by: 0.6) : .black))
                .disabled(!game.canTap)
            }
        }
        .frame(height: 84)
        .animation(.spring(response: 0.25), value: game.incomingHeavy)
    }

    private func actionLabel(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .black))
                Text(title).font(Theme.Fonts.display(22))
            }
            .foregroundStyle(.white)
            .gameShadow()
            Text(subtitle)
                .font(Theme.Fonts.label(10))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Ability Button

/// The class's signature ability as a square chunky button. While cooling
/// down, a dark shade drains away from the top (like a refilling vial) with
/// a countdown on top; when ready, it lights up in flame orange.
struct AbilityButtonView: View {
    let game: DungeonGame

    var body: some View {
        let ability = game.ability
        let ready   = game.canUseAbility
        let cd      = game.abilityCooldownRemaining
        let frac    = ability.cooldown > 0 ? 1 - min(1, cd / ability.cooldown) : 1

        Button {
            game.activateAbility()
            Haptics.impact(.medium)
        } label: {
            ZStack {
                VStack(spacing: 3) {
                    Image(systemName: ability.icon)
                        .font(.system(size: 26, weight: .bold))
                        .symbolEffect(.bounce, value: ready)
                    Text(ability.name.uppercased())
                        .font(Theme.Fonts.label(9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 4)
                }
                .foregroundStyle(ready ? .white : Theme.Palette.ash)
                .gameShadow()

                if !ready {
                    // Cooldown shade shrinks toward the top as the ability recharges.
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.black.opacity(0.55))
                            .frame(height: geo.size.height * (1 - frac))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .animation(.linear(duration: 0.2), value: frac)

                    Text("\(Int(ceil(cd)))")
                        .font(Theme.Fonts.number(26))
                        .foregroundStyle(.white)
                        .gameShadow()
                }
            }
        }
        .buttonStyle(ChunkyButtonStyle(face: ready ? Theme.Palette.flame : Theme.Palette.stoneHi,
                                       lip: ready ? Theme.Palette.flame.mix(with: .black, by: 0.6) : .black))
        .disabled(!ready)
    }
}

// MARK: - Active Effects Bar

struct ActiveEffectsBarView: View {
    let game: DungeonGame
    @State private var selectedEffect: ActiveEffect?
    @State private var isExpanded = false

    var body: some View {
        if !game.activeEffects.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                // The header is always visible — one compact row showing a preview of
                // the effect icons and a count, with a chevron to signal it's tappable.
                // Collapsed by default so it never steals vertical space from the action buttons.
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        // Peek at the first few icons so the player knows what's in there
                        // even when the list is collapsed.
                        HStack(spacing: 2) {
                            ForEach(game.activeEffects.prefix(5)) { effect in
                                Text(effect.icon).font(.system(size: 13))
                            }
                            if game.activeEffects.count > 5 {
                                Text("+\(game.activeEffects.count - 5)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.40))
                            }
                        }
                        Text("\(game.activeEffects.count) EFFECTS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.40))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.30))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                // Full pill grid — only visible when the player taps the header.
                // Rows of 3 so wide pill names don't get clipped.
                if isExpanded {
                    let rows = stride(from: 0, to: game.activeEffects.count, by: 3).map {
                        Array(game.activeEffects[$0..<min($0 + 3, game.activeEffects.count)])
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 8) {
                                ForEach(row) { effect in
                                    effectPill(effect)
                                        .onTapGesture { selectedEffect = effect }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .sheet(item: $selectedEffect) { effect in
                EffectDetailView(effect: effect)
                    .presentationDetents([.height(260)])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(red: 0.07, green: 0.07, blue: 0.11))
            }
        }
    }

    private func effectPill(_ effect: ActiveEffect) -> some View {
        HStack(spacing: 5) {
            Text(effect.icon)
                .font(.system(size: 13))
            Text(effect.name)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(effect.isBlessing ? Color(red: 0.4, green: 0.95, blue: 0.55)
                                                   : Color(red: 1.0, green: 0.5, blue: 0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(effect.isBlessing ? Color(red: 0.05, green: 0.18, blue: 0.08)
                                        : Color(red: 0.20, green: 0.05, blue: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(effect.isBlessing ? Color(red: 0.25, green: 0.65, blue: 0.3)
                                                        : Color(red: 0.65, green: 0.25, blue: 0.25),
                                      lineWidth: 1)
                )
        )
    }
}

// MARK: - Consumables Bar

struct ConsumablesBarView: View {
    let game: DungeonGame

    var body: some View {
        let vials = game.usableItems.filter { $0.kind == .fullHeal }
        if !vials.isEmpty {
            HStack(spacing: 8) {
                ForEach(vials) { vial in
                    Button { game.useItem(vial) } label: {
                        HStack(spacing: 5) {
                            Text(vial.icon)
                                .font(.system(size: 13))
                            Text(vial.name)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("USE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(red: 0.4, green: 0.95, blue: 0.55))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(red: 0.05, green: 0.18, blue: 0.08))
                                .overlay(RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color(red: 0.25, green: 0.65, blue: 0.3), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(game.isGameOver ? 0.35 : 1.0)
                    .disabled(game.isGameOver)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

struct EffectDetailView: View {
    let effect: ActiveEffect

    private var accentColor: Color {
        effect.isBlessing ? Color(red: 0.3, green: 0.85, blue: 0.45) : Color(red: 0.95, green: 0.35, blue: 0.35)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(effect.icon)
                    .font(.system(size: 44))
                Text(effect.name)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor)
                Text(effect.isBlessing ? "BLESSING" : "CURSE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(accentColor.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(spacing: 10) {
                // Flat stat modifiers
                if effect.atkMod != 0 {
                    effectRow(label: "Attack", value: effect.atkMod)
                }
                if effect.defMod != 0 {
                    effectRow(label: "Defense", value: effect.defMod)
                }
                if effect.maxHpMod != 0 {
                    effectRow(label: "Max HP", value: effect.maxHpMod)
                }
                if effect.regenMod != 0 {
                    effectRow(label: "HP Regen", value: effect.regenMod)
                }
                // Triggered effects — shown as descriptive strings since they
                // aren't simple +/- numbers.
                if effect.onKillHealPercent > 0 {
                    effectRowText(label: "On Kill", value: "Heal \(Int(effect.onKillHealPercent * 100))% max HP")
                }
                if effect.thornsDamagePercent > 0 {
                    effectRowText(label: "On Hit Taken", value: "Reflect \(Int(effect.thornsDamagePercent * 100))% back")
                }
                if effect.splashDamagePercent > 0 {
                    effectRowText(label: "On Strike", value: "Splash \(Int(effect.splashDamagePercent * 100))% to nearby")
                }
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }

    private func effectRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.6))
            Spacer()
            Text(value > 0 ? "+\(value)" : "\(value)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(value > 0 ? Color(red: 0.3, green: 0.85, blue: 0.45)
                                           : Color(red: 0.95, green: 0.35, blue: 0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func effectRowText(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.6))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.3, green: 0.85, blue: 0.45))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Floor Event Card

struct FloorEventCardView: View {
    let game: DungeonGame
    let event: FloorEvent

    var body: some View {
        let t = event.template
        let canAfford = t.primaryGoldCost == 0 || game.gold >= t.primaryGoldCost

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(t.icon)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 4) {
                    Text(categoryLabel(t.category))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(categoryColor(t.category))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(categoryColor(t.category).opacity(0.15))
                        )
                    Text(t.title)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                Spacer()
            }

            Text(t.flavorText)
                .font(.system(size: 12, design: .monospaced).italic())
                .foregroundStyle(Color.white.opacity(0.50))
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .background(Color.white.opacity(0.10))

            HStack(spacing: 10) {
                eventButton(
                    label: t.primaryLabel,
                    summary: t.primaryEffectSummary,
                    active: canAfford,
                    accent: canAfford ? categoryColor(t.category) : Color.white.opacity(0.3)
                ) { game.resolveFloorEvent(primary: true) }

                eventButton(
                    label: t.secondaryLabel,
                    summary: t.secondaryEffectSummary,
                    active: true,
                    accent: Color(red: 0.40, green: 0.65, blue: 0.95)
                ) { game.resolveFloorEvent(primary: false) }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(categoryColor(t.category).opacity(0.6), lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func eventButton(label: String, summary: String, active: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(active ? accent : Color.white.opacity(0.25))
                Text(summary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(active ? accent.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(active ? accent.opacity(0.4) : Color.white.opacity(0.10),
                                          lineWidth: 1)
                    )
            )
        }
        .disabled(!active)
        .buttonStyle(.plain)
    }

    private func categoryLabel(_ cat: FloorEventTemplate.Category) -> String {
        switch cat {
        case .blessing: return "BLESSING"
        case .shrine:   return "SHRINE"
        case .curse:    return "CURSE"
        case .mystery:  return "MYSTERY"
        }
    }

    private func categoryColor(_ cat: FloorEventTemplate.Category) -> Color {
        switch cat {
        case .blessing: return Color(red: 0.30, green: 0.85, blue: 0.45)
        case .shrine:   return Color(red: 0.95, green: 0.78, blue: 0.25)
        case .curse:    return Color(red: 0.95, green: 0.35, blue: 0.35)
        case .mystery:  return Color(red: 0.65, green: 0.35, blue: 0.95)
        }
    }
}
