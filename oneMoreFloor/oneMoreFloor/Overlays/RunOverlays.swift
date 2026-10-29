// RunOverlays.swift
// Full-screen moments that interrupt a run: offline summary, game over,
// boss victory, blessing/item banners, and zone unlocks.

import SwiftUI

// MARK: - Offline Summary Overlay

struct OfflineSummaryView: View {
    let summary: OfflineSummary
    let adManager: AdManager
    let onDoubleGold: () -> Void
    let onDismiss: () -> Void

    @State private var didDoubleGold = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("WHILE YOU WERE AWAY")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))

                Text(summary.durationString)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    if summary.goldEarned > 0 {
                        summaryRow("Gold Earned",
                                   didDoubleGold ? "+\(summary.goldEarned * 2)g" : "+\(summary.goldEarned)g",
                                   .yellow)
                    }
                    if summary.floorsCleared > 0 {
                        summaryRow("Floors Cleared", "\(summary.floorsCleared)", .white)
                    }
                    summaryRow("Deepest Floor", DungeonGame.stageLabel(floor: summary.deepestFloor),
                               Color(red: 0.45, green: 0.72, blue: 1.00))
                    if summary.deaths > 0 {
                        summaryRow("Deaths", "\(summary.deaths)",
                                   Color(red: 1.0, green: 0.38, blue: 0.38))
                    }
                }

                if summary.stoppedByDeath {
                    Text("Unlock Undying Will to keep earning gold after death")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }

                if summary.goldEarned > 0 {
                    if didDoubleGold {
                        Text("2× GOLD APPLIED!")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.yellow.opacity(0.85))
                    } else {
                        Button {
                            adManager.showOfflineAd {
                                onDoubleGold()
                                didDoubleGold = true
                                Analytics.offlineGoldDoubled(goldEarned: summary.goldEarned)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if adManager.isOfflineAdReady {
                                    Image(systemName: "play.circle.fill")
                                } else {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(Color.white.opacity(0.50))
                                        .scaleEffect(0.8)
                                }
                                Text(adManager.isOfflineAdReady ? "WATCH AD — 2× GOLD" : "LOADING AD...")
                            }
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(adManager.isOfflineAdReady
                                ? Color(red: 0.55, green: 0.42, blue: 0.08)
                                : Color(white: 0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(adManager.isOfflineAdReady ? .white : Color.white.opacity(0.35))
                        }
                        .disabled(!adManager.isOfflineAdReady)
                    }
                }

                Button(action: onDismiss) {
                    Text("CONTINUE")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color(red: 0.15, green: 0.38, blue: 0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
            .padding(.horizontal, 32)
            .onAppear {
                let autoDoubled = StoreManager.shared.hasPurchasedRemoveAds && summary.goldEarned > 0 && !didDoubleGold
                if autoDoubled {
                    onDoubleGold()
                    didDoubleGold = true
                }
                Analytics.offlineSummaryShown(
                    goldEarned: summary.goldEarned,
                    floorsCleared: summary.floorsCleared,
                    deaths: summary.deaths,
                    durationSeconds: summary.duration,
                    goldDoubled: autoDoubled
                )
            }
        }
    }

    private func summaryRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Game Over Overlay

struct GameOverOverlay: View {
    let game: DungeonGame
    let adManager: AdManager
    let onRevive: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            // Blood-red vignette over a dark wash: the run just ended.
            Color.black.opacity(0.7).ignoresSafeArea()
            RadialGradient(colors: [.clear, Theme.Palette.blood.opacity(0.35)],
                           center: .center, startRadius: 120, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                // Headline + where it happened.
                VStack(spacing: 4) {
                    Text("YOU FELL")
                        .font(Theme.Fonts.display(40))
                        .foregroundStyle(Theme.Palette.blood)
                        .gameShadow(4)
                    Text("on floor \(game.currentFloor)")
                        .font(Theme.Fonts.label(15))
                        .foregroundStyle(Theme.Palette.dust)
                }

                if game.atRiskGold > 0 {
                    // Surface the pot the player is about to lose — this is what
                    // makes the "second wind" revive ad genuinely tempting.
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "bag.fill").font(.system(size: 22, weight: .bold))
                            Text("\(game.atRiskGold)").font(Theme.Fonts.number(38))
                            Text("×\(String(format: "%.1f", game.greedMultiplier))")
                                .font(Theme.Fonts.number(20))
                                .foregroundStyle(Theme.greedColor(greedFraction(game)))
                        }
                        .foregroundStyle(Theme.Palette.gold)
                        .gameShadow(3)
                        Text("Revive to keep it, or restart and lose it.")
                            .font(Theme.Fonts.body(14))
                            .foregroundStyle(Theme.Palette.parchment.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("Banked gold, upgrades, and shards carry over.")
                        .font(Theme.Fonts.body(14))
                        .foregroundStyle(Theme.Palette.parchment.opacity(0.75))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    // Second Wind: free for Remove Ads buyers, a rewarded ad otherwise.
                    if StoreManager.shared.hasPurchasedRemoveAds {
                        Button(action: onRevive) {
                            Label("SECOND WIND", systemImage: "heart.fill")
                                .font(Theme.Fonts.display(18))
                                .foregroundStyle(Color.black.opacity(0.8))
                        }
                        .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.gold, lip: Theme.Palette.goldDeep))
                        .frame(height: 60)
                    } else {
                        Button {
                            adManager.showReviveAd(onReward: onRevive)
                        } label: {
                            HStack(spacing: 8) {
                                if adManager.isReviveAdReady {
                                    Image(systemName: "play.circle.fill")
                                } else {
                                    ProgressView().tint(Theme.Palette.ash)
                                }
                                Text(adManager.isReviveAdReady ? "SECOND WIND" : "LOADING AD…")
                            }
                            .font(Theme.Fonts.display(18))
                            .foregroundStyle(adManager.isReviveAdReady ? Color.black.opacity(0.8) : Theme.Palette.ash)
                        }
                        .buttonStyle(ChunkyButtonStyle(face: adManager.isReviveAdReady ? Theme.Palette.gold : Theme.Palette.stoneHi,
                                                       lip: adManager.isReviveAdReady ? Theme.Palette.goldDeep : .black))
                        .frame(height: 60)
                        .disabled(!adManager.isReviveAdReady)
                        if adManager.isReviveAdReady {
                            Text("Watch an ad to revive")
                                .font(Theme.Fonts.label(11))
                                .foregroundStyle(Theme.Palette.dust)
                        }
                    }

                    Button(action: onRestart) {
                        Label("RESTART", systemImage: "arrow.counterclockwise")
                            .font(Theme.Fonts.display(18))
                            .foregroundStyle(Theme.Palette.parchment)
                            .gameShadow()
                    }
                    .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.stoneHi, lip: .black))
                    .frame(height: 60)
                }
            }
            .padding(24)
            .gamePanel(tint: Theme.Palette.blood.opacity(0.7), cornerRadius: 22)
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Boss Victory Overlay

struct BossVictoryOverlay: View {
    let victory: BossVictory
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 0) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.15))
                    .padding(.bottom, 14)

                Text("ZONE CLEARED!")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.20))

                Text("Stage \(victory.stageLabel)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.top, 4)
                    .padding(.bottom, 18)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.bottom, 16)

                Text(victory.zoneIcon + "  " + victory.zoneName.uppercased())
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                Text("\(victory.bossName) Defeated")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.bottom, 18)

                HStack(spacing: 36) {
                    VStack(spacing: 4) {
                        Text("GOLD")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.50))
                        Text("+\(victory.goldEarned)g")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.yellow)
                    }

                    VStack(spacing: 4) {
                        Text("REWARD")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.50))
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                            Text("Item Drop!")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(Color(red: 0.72, green: 0.45, blue: 1.00))
                    }
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 1.0, green: 0.82, blue: 0.20).opacity(0.35), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.75, blue: 0.10).opacity(0.15), radius: 24)
            )
            .padding(.horizontal, 28)
        }
        .onTapGesture { onDismiss() }
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.4), value: victory.stageLabel)
    }
}

// MARK: - Blessing Banner

/// Brief, non-blocking banner for an auto-applied free blessing. It slides in at
/// the top and dismisses itself — it never pauses the fight the way a decision
/// modal does, which is what keeps the tapping flow intact.
struct BlessingBanner: View {
    let template: FloorEventTemplate
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(template.icon)
                .font(.system(size: 26))
            VStack(alignment: .leading, spacing: 3) {
                Text("BLESSING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.40, green: 0.95, blue: 0.55))
                Text(template.title)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(template.primaryEffectSummary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.13, blue: 0.10))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color(red: 0.30, green: 0.70, blue: 0.40).opacity(0.55), lineWidth: 1.5))
        )
        .padding(.horizontal, 16)
        .task {
            try? await Task.sleep(for: .seconds(3))
            onDismiss()
        }
    }
}

// MARK: - Item Drop Banner

struct ItemDropBanner: View {
    let item: Equipment
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 12) {
                ItemIconView(item: item, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text("ITEM FOUND!")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.rarity.uiColor)
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(item.statSummary)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(item.rarity.uiColor.opacity(0.45), lineWidth: 1.5))
                    .shadow(color: item.rarity.uiColor.opacity(0.20), radius: 12)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
    }
}

// MARK: - Zone Unlock Overlay

struct ZoneUnlockOverlay: View {
    let zone: Zone
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 0) {
                Text("NEW ZONE UNLOCKED")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.45))
                    .padding(.bottom, 14)

                Text(zone.icon)
                    .font(.system(size: 52))
                    .padding(.bottom, 10)

                Text(zone.name.uppercased())
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Floor \(zone.minFloor)\(zone.maxFloor.map { "–\($0)" } ?? "+")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.top, 6)
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.07, green: 0.13, blue: 0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(red: 0.30, green: 0.72, blue: 0.42).opacity(0.45), lineWidth: 1.5)
                    )
                    .shadow(color: Color(red: 0.25, green: 0.80, blue: 0.40).opacity(0.18), radius: 24)
            )
            .padding(.horizontal, 36)
        }
        .onTapGesture { onDismiss() }
        .task {
            try? await Task.sleep(for: .seconds(3))
            onDismiss()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .animation(.spring(response: 0.45), value: zone.id)
    }
}
