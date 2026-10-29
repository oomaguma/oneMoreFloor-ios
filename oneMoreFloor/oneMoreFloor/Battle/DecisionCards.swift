// DecisionCards.swift
// Centered decision cards: the Rest / Descend choice and the raid briefing.
// (First-run onboarding now lives in Onboarding/Tutorial.swift as in-game coach bubbles.)

import SwiftUI

// MARK: - Rest Site (push-your-luck decision)

/// The camp after a boss (and the tutorial's scripted first camp): bank the
/// pot and heal, push on with greed climbing, or open the raid briefing.
struct RestSiteCardView: View {
    let game: DungeonGame
    let adManager: AdManager
    @State private var didDouble = false
    /// LAUNCH RAID opens a briefing first, so the gamble is an informed one.
    @State private var showRaidBriefing = false
    /// The tutorial's scripted first camp keeps the choice to Rest vs. Descend.
    @AppStorage(TutorialStep.storageKey) private var tutorialStepRaw = 0
    private var isFirstCamp: Bool { tutorialStepRaw == TutorialStep.firstCamp.rawValue }

    // The three paths, each with its own color so the choice reads instantly:
    // green = safe, flame = greedy, violet = the raid side-gamble.
    private let accentRest    = Theme.Palette.life
    private let accentDescend = Theme.Palette.flame
    private let accentCamp    = Theme.Palette.frost
    private let accentRaid    = Color(red: 0.75, green: 0.35, blue: 1.00)

    var body: some View {
        if showRaidBriefing {
            RaidBriefingView(game: game,
                             onBegin: { game.launchRaid() },
                             onBack: { withAnimation(.spring(response: 0.35)) { showRaidBriefing = false } })
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            restSiteCard
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var restSiteCard: some View {
        VStack(spacing: 14) {
            // Header: campfire + the question the whole game is built on.
            VStack(spacing: 4) {
                Text("⛺")
                    .font(.system(size: 40))
                Text("REST SITE")
                    .font(Theme.Fonts.label(11))
                    .tracking(2)
                    .foregroundStyle(accentCamp)
                Text("Push your luck?")
                    .font(Theme.Fonts.display(26))
                    .foregroundStyle(Theme.Palette.parchment)
                    .gameShadow(3)
            }

            // Tutorial: spell out the one decision this whole game is about.
            if isFirstCamp {
                Text("Your first camp. REST banks the gold and heals you, but greed resets. DESCEND keeps greed climbing, with the gold still at risk.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Palette.parchment.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The pot is the star: it's what you'd lose by pushing on and dying.
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "bag.fill").font(.system(size: 22, weight: .bold))
                    Text("\(game.atRiskGold)")
                        .font(Theme.Fonts.number(40))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Theme.Palette.gold)
                .gameShadow(3)
                Text("GOLD AT RISK")
                    .font(Theme.Fonts.label(10))
                    .tracking(1.5)
                    .foregroundStyle(Theme.Palette.flame)
            }

            // Supporting numbers: what's safe, and the greed you'd forfeit by resting.
            HStack(spacing: 0) {
                rsStat("BANKED", "\(game.gold)", accentRest)
                rsDivider()
                rsStat("GREED", "×\(String(format: "%.1f", game.greedMultiplier))", Theme.greedColor(greedFraction(game)))
            }
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.3)))

            // Optional rewarded bonus: double the at-risk pot before deciding.
            // Opt-in only; Remove Ads buyers simply don't see this ad button.
            if game.atRiskGold > 0 && !StoreManager.shared.hasPurchasedRemoveAds && !isFirstCamp {
                if didDouble {
                    Label("2× POT APPLIED", systemImage: "checkmark.seal.fill")
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(Theme.Palette.gold)
                        .frame(maxWidth: .infinity)
                } else {
                    Button {
                        adManager.showBonusAd {
                            game.atRiskGold *= 2
                            didDouble = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: adManager.isBonusAdReady ? "play.circle.fill" : "hourglass")
                            Text(adManager.isBonusAdReady ? "WATCH AD · DOUBLE THE POT" : "LOADING AD…")
                        }
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(adManager.isBonusAdReady ? Theme.Palette.gold : Theme.Palette.ash)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Theme.Palette.gold.opacity(adManager.isBonusAdReady ? 0.6 : 0.15),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!adManager.isBonusAdReady)
                }
            }

            // The decision.
            HStack(spacing: 10) {
                choiceButton(label: "DESCEND",
                             icon: "arrow.down.to.line",
                             summary: "Greed climbs",
                             accent: accentDescend) { game.descendPastRestSite() }

                choiceButton(label: "REST",
                             icon: "tent.fill",
                             summary: "Bank \(game.atRiskGold) · heal",
                             accent: accentRest) { game.rest() }
            }
            .frame(height: 76)

            // Raid: a lateral gamble — carry in current blessings and fight
            // for soul shards. Losing strips all blessings and forfeits the
            // at-risk pot, so there's real skin in the game.
            if !isFirstCamp {
            choiceButton(label: "RAID…",
                         icon: "flag.2.crossed.fill",
                         summary: "Win +\(game.raidShardReward) ◈ · see the briefing",
                         accent: accentRaid) {
                withAnimation(.spring(response: 0.35)) { showRaidBriefing = true }
            }
                .frame(height: 64)
            }
        }
        .padding(18)
        .gamePanel(tint: accentCamp.opacity(0.7), cornerRadius: 20)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func rsStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Theme.Fonts.label(10))
                .tracking(1)
                .foregroundStyle(Theme.Palette.dust)
            Text(value)
                .font(Theme.Fonts.number(18))
                .foregroundStyle(color)
                .gameShadow(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func rsDivider() -> some View {
        Rectangle().fill(Theme.Palette.stoneEdge.opacity(0.6)).frame(width: 1, height: 28)
    }

    private func choiceButton(label: String, icon: String, summary: String, accent: Color,
                              action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            VStack(spacing: 3) {
                Label(label, systemImage: icon)
                    .font(Theme.Fonts.display(17))
                    .foregroundStyle(.white)
                    .gameShadow()
                Text(summary)
                    .font(Theme.Fonts.label(10))
                    .foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)
            }
        }
        .buttonStyle(ChunkyButtonStyle(face: accent.mix(with: .black, by: 0.3),
                                       lip: accent.mix(with: .black, by: 0.7),
                                       cornerRadius: 14, depth: 5))
    }
}

// MARK: - Raid Briefing

/// Shown before committing to a raid: the prize, the escape payouts, the wave
/// layout, what's at stake, and a danger read — so it's an informed gamble
/// instead of a blind one. BEGIN RAID launches; BACK returns to the rest site.
struct RaidBriefingView: View {
    let game: DungeonGame
    let onBegin: () -> Void
    let onBack: () -> Void

    private let accentRaid = Color(red: 0.75, green: 0.35, blue: 1.00)

    var body: some View {
        let blessings = game.activeEffects.filter { $0.isBlessing }
        let danger    = game.raidDanger

        VStack(spacing: 14) {
            // Header.
            VStack(spacing: 4) {
                Image(systemName: "flag.2.crossed.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(accentRaid)
                    .gameShadow(3)
                Text("RAID BRIEFING")
                    .font(Theme.Fonts.label(11))
                    .tracking(2)
                    .foregroundStyle(accentRaid)
                Text("\(game.currentZone.icon) \(game.currentZone.name)")
                    .font(Theme.Fonts.display(22))
                    .foregroundStyle(Theme.Palette.parchment)
                    .gameShadow(3)
            }

            // The waves: 2, 3, then 4 with the boss.
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { wave in
                    VStack(spacing: 4) {
                        Text("WAVE \(wave)")
                            .font(Theme.Fonts.label(10))
                            .foregroundStyle(Theme.Palette.dust)
                        HStack(spacing: 1) {
                            ForEach(0..<RaidScene.enemyCount(wave: wave), id: \.self) { i in
                                let isBoss = wave == 3 && i == RaidScene.enemyCount(wave: wave) - 1
                                Image(systemName: isBoss ? "crown.fill" : "person.fill")
                                    .font(.system(size: isBoss ? 13 : 11, weight: .bold))
                                    .foregroundStyle(isBoss ? Theme.Palette.blood : Theme.Palette.parchment.opacity(0.8))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.3)))
                }
            }

            // Prize vs. stakes.
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PRIZE").font(Theme.Fonts.label(10)).tracking(1).foregroundStyle(Theme.Palette.dust)
                    Text("+\(game.raidShardReward) ◈")
                        .font(Theme.Fonts.number(24))
                        .foregroundStyle(Theme.Palette.shard)
                        .gameShadow(2)
                    Text("+ boss-tier loot")
                        .font(Theme.Fonts.label(11))
                        .foregroundStyle(Theme.Palette.gold)
                    Text("Escape early: +\(game.raidEscapeReward(wavesCleared: 1)) / +\(game.raidEscapeReward(wavesCleared: 2)) ◈")
                        .font(Theme.Fonts.label(10))
                        .foregroundStyle(Theme.Palette.dust)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 5) {
                    Text("AT STAKE").font(Theme.Fonts.label(10)).tracking(1).foregroundStyle(Theme.Palette.dust)
                    if blessings.isEmpty && game.atRiskGold == 0 {
                        Text("Nothing but pride")
                            .font(Theme.Fonts.label(13))
                            .foregroundStyle(Theme.Palette.parchment)
                    }
                    if !blessings.isEmpty {
                        HStack(spacing: 2) { ForEach(blessings) { Text($0.icon).font(.system(size: 15)) } }
                        Text("\(blessings.count) blessing\(blessings.count == 1 ? "" : "s")")
                            .font(Theme.Fonts.label(11))
                            .foregroundStyle(Theme.Palette.parchment.opacity(0.8))
                    }
                    if game.atRiskGold > 0 {
                        Label("\(game.atRiskGold) gold", systemImage: "bag.fill")
                            .font(Theme.Fonts.label(13))
                            .foregroundStyle(Theme.Palette.gold)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))

            // Danger read (on auto-attack — tapping and blessings improve the odds).
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(dangerColor(danger))
                Text("DANGER")
                    .font(Theme.Fonts.label(11)).tracking(1)
                    .foregroundStyle(Theme.Palette.dust)
                Text(danger.rawValue)
                    .font(Theme.Fonts.display(16))
                    .foregroundStyle(dangerColor(danger))
                    .gameShadow(1)
                Spacer()
                Text(dangerHint(danger))
                    .font(Theme.Fonts.label(10))
                    .foregroundStyle(Theme.Palette.dust)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .gamePanel(tint: dangerColor(danger).opacity(0.7), cornerRadius: 12)

            // Commit or back out.
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Label("BACK", systemImage: "chevron.left")
                        .font(Theme.Fonts.display(16))
                        .foregroundStyle(Theme.Palette.parchment)
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.stoneHi, lip: .black, cornerRadius: 14, depth: 5))
                .frame(width: 110)

                Button {
                    Haptics.impact(.heavy)
                    onBegin()
                } label: {
                    Label("BEGIN RAID", systemImage: "flag.2.crossed.fill")
                        .font(Theme.Fonts.display(18))
                        .foregroundStyle(.white)
                        .gameShadow()
                }
                .buttonStyle(ChunkyButtonStyle(face: accentRaid.mix(with: .black, by: 0.25),
                                               lip: accentRaid.mix(with: .black, by: 0.7),
                                               cornerRadius: 14, depth: 5))
            }
            .frame(height: 64)
        }
        .padding(18)
        .gamePanel(tint: accentRaid.opacity(0.7), cornerRadius: 20)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// The hint beside the rating — must agree with it ("tap fast to beat it"
    /// next to LOW read as a contradiction).
    private func dangerHint(_ danger: DungeonGame.RaidDanger) -> String {
        switch danger {
        case .low:      return "you've got this"
        case .moderate: return "tap to stay safe"
        case .high:     return "tap fast to survive"
        case .deadly:   return "blessings + fast taps"
        }
    }

    private func dangerColor(_ danger: DungeonGame.RaidDanger) -> Color {
        switch danger {
        case .low:      return Theme.Palette.life
        case .moderate: return Theme.Palette.warning
        case .high:     return Theme.Palette.flame
        case .deadly:   return Theme.Palette.blood
        }
    }
}
