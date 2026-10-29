// DecisionCards.swift
// Centered decision cards: first-run onboarding and the Rest / Descend choice.

import SwiftUI

// MARK: - Rest Site (push-your-luck decision)

// MARK: - First-run Onboarding

/// Shown once on the first run (gated by the `seenIntro` flag). Frames the new
/// push-your-luck loop in three beats, since the combat is no longer a passive
/// idle game and new players need to know to tap, push, and bank.
struct IntroCardView: View {
    let onBegin: () -> Void

    private let gold = Color(red: 1.0, green: 0.82, blue: 0.30)

    var body: some View {
        ZStack {
            Theme.Palette.abyss.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()
                Text("⚔️").font(.system(size: 52))
                Text("HOW TO SURVIVE")
                    .font(Theme.Fonts.display(22))
                    .foregroundStyle(gold)

                VStack(alignment: .leading, spacing: 18) {
                    introRow(icon: "hand.tap.fill", tint: Color(red: 1.0, green: 0.45, blue: 0.35),
                             title: "TAP TO FIGHT",
                             body: "Tap to strike. Stop tapping and your hero auto-battles on its own.")
                    introRow(icon: "flame.fill", tint: Color(red: 0.95, green: 0.45, blue: 0.25),
                             title: "PUSH YOUR LUCK",
                             body: "The deeper you descend without resting, the higher your GREED — more gold and better loot.")
                    introRow(icon: "lock.open.fill", tint: gold,
                             title: "BANK OR LOSE IT",
                             body: "Gold you earn is AT RISK until you bank it at a camp. Die and it's gone. How greedy do you dare to be?")
                }
                .padding(.horizontal, 8)

                Spacer()

                Button(action: onBegin) {
                    Text("DESCEND")
                        .font(Theme.Fonts.label(17))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(RoundedRectangle(cornerRadius: 12).fill(gold))
                }
                .padding(.bottom, 8)
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }

    private func introRow(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Fonts.label(14))
                    .foregroundStyle(.white)
                Text(body)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RestSiteCardView: View {
    let game: DungeonGame
    let adManager: AdManager
    @State private var didDouble = false

    // The three paths, each with its own color so the choice reads instantly:
    // green = safe, flame = greedy, violet = the raid side-gamble.
    private let accentRest    = Theme.Palette.life
    private let accentDescend = Theme.Palette.flame
    private let accentCamp    = Theme.Palette.frost
    private let accentRaid    = Color(red: 0.75, green: 0.35, blue: 1.00)

    var body: some View {
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
            if game.atRiskGold > 0 && !StoreManager.shared.hasPurchasedRemoveAds {
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
            choiceButton(label: "LAUNCH RAID",
                         icon: "flag.2.crossed.fill",
                         summary: "Win ◈ shards · lose blessings + \(game.atRiskGold) gold",
                         accent: accentRaid) { game.launchRaid() }
                .frame(height: 64)
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
