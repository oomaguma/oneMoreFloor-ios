import SwiftUI
import SpriteKit

// MARK: - Raid View

/// Full-screen view that wraps RaidScene for the duration of a raid. Shows the
/// arena SpriteView, a hero HP bar, a wave counter, and a result overlay once
/// the raid resolves. RaidScene drives all the combat logic and fires callbacks;
/// this view just displays state and hands the outcome back to DungeonGame.
struct RaidView: View {

    let game: DungeonGame

    // MARK: - State

    @State private var heroHp:     Int
    @State private var heroMaxHp:  Int
    @State private var currentWave: Int = 0
    /// nil = in progress; true = victory; false = defeat.
    @State private var raidResult: Bool? = nil
    @State private var raidScene:  RaidScene

    // MARK: - Design tokens

    private let bgColor   = Color(red: 0.05, green: 0.05, blue: 0.08)
    private let accentRaid = Color(red: 0.75, green: 0.30, blue: 1.00)

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
            floor:    game.currentFloor
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                raidHeaderBar
                    .padding(.top, 8)

                // Arena — taps trigger immediate hero strikes.
                SpriteView(scene: raidScene, options: [.allowsTransparency])
                    .aspectRatio(300.0 / 160.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(raidResult == nil)
                    .onTapGesture { raidScene.playerTap() }
                    .padding(.top, 8)

                heroHpSection
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                raidStakesReminder
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                Spacer()
            }

            // Result overlay — fades in after the scene resolves.
            if let result = raidResult {
                raidResultOverlay(success: result)
                    .transition(.opacity)
            }
        }
        .onAppear { wireUpScene() }
    }

    // MARK: - Wire-up

    /// Connects RaidScene callbacks to local @State so SwiftUI reflects combat.
    private func wireUpScene() {
        raidScene.onHeroHpChanged = { hp, _ in
            heroHp = hp
        }
        raidScene.onWaveChanged = { wave, _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                currentWave = wave
            }
        }
        raidScene.onRaidCompleted = { success in
            // Keep hero HP in sync for the failure case (scene set it to 0).
            // completeRaid() will then restore it to a wounded-but-alive value.
            withAnimation(.easeInOut(duration: 0.35)) {
                raidResult = success
            }
        }
    }

    // MARK: - Sub-views

    private var raidHeaderBar: some View {
        HStack {
            Label("RAID", systemImage: "shield.lefthalf.filled")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accentRaid)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accentRaid.opacity(0.15))
                .clipShape(Capsule())

            Spacer()

            if currentWave > 0 {
                Text("WAVE  \(currentWave) / 3")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 20)
    }

    private var heroHpSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("HP")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.50))
                Spacer()
                Text("\(heroHp) / \(heroMaxHp)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.10))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(hpBarColor)
                        .frame(width: geo.size.width *
                               max(0, CGFloat(heroHp) / CGFloat(max(1, heroMaxHp))))
                        .animation(.linear(duration: 0.15), value: heroHp)
                }
            }
            .frame(height: 9)
        }
    }

    /// Color of the HP bar — transitions from green → yellow → red as HP drops.
    private var hpBarColor: Color {
        let pct = Double(heroHp) / Double(max(1, heroMaxHp))
        if pct > 0.5 { return Color(red: 0.25, green: 0.85, blue: 0.40) }
        if pct > 0.25 { return Color(red: 0.95, green: 0.75, blue: 0.15) }
        return Color(red: 0.95, green: 0.25, blue: 0.25)
    }

    /// Small reminder of what rides on this raid, so the stakes stay visible.
    private var raidStakesReminder: some View {
        let blessingCount = game.activeEffects.filter { $0.isBlessing }.count
        let atRisk        = game.atRiskGold

        return HStack(spacing: 12) {
            if blessingCount > 0 {
                Label("\(blessingCount) blessing\(blessingCount == 1 ? "" : "s") at risk",
                      systemImage: "sparkles")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.30).opacity(0.75))
            }
            if atRisk > 0 {
                Label("\(atRisk)g at risk", systemImage: "dollarsign.circle")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.25).opacity(0.75))
            }
            Spacer()
        }
    }

    // MARK: - Result overlay

    @ViewBuilder
    private func raidResultOverlay(success: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(success ? "🏆" : "💀")
                    .font(.system(size: 60))

                Text(success ? "RAID COMPLETE" : "RAID FAILED")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        success
                        ? Color(red: 0.95, green: 0.82, blue: 0.10)
                        : Color(red: 0.90, green: 0.25, blue: 0.25)
                    )

                // Summarise what was gained or lost.
                Group {
                    if success {
                        let earned = max(1, game.currentFloor / 5)
                        Text("+\(earned) Soul Shard\(earned == 1 ? "" : "s") earned!")
                            .foregroundStyle(Color.white.opacity(0.85))
                    } else {
                        Text("All blessings lost.\nAt-risk gold forfeit.")
                            .foregroundStyle(Color.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                }
                .font(.system(size: 14, design: .monospaced))

                // Continue — dismisses the raid and returns to the dungeon.
                Button {
                    game.completeRaid(success: success)
                    // isRaidActive → false collapses RaidView from GameView's ZStack
                } label: {
                    Text("CONTINUE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            success ? Color(red: 0.95, green: 0.82, blue: 0.10) : .white
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(success
                                    ? Color(red: 0.55, green: 0.42, blue: 0.08).opacity(0.30)
                                    : Color(white: 0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .strokeBorder(
                                            success
                                            ? Color(red: 0.95, green: 0.78, blue: 0.25).opacity(0.60)
                                            : Color.white.opacity(0.20),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(36)
        }
    }
}
