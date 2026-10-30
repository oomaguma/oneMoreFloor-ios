// RunOverlays.swift
// Full-screen moments that interrupt a run: offline summary, game over,
// boss victory, blessing/item banners, and zone unlocks.

import SwiftUI

// MARK: - Offline Summary Overlay

struct OfflineSummaryView: View {
    let summary: OfflineSummary
    let adManager: AdManager
    /// Offer the notification soft ask (hero died while away, and iOS hasn't asked yet).
    var offerNotifications = false
    var onEnableNotifications: () -> Void = {}
    let onDoubleGold: () -> Void
    let onDismiss: () -> Void

    @State private var didDoubleGold = false
    @State private var didAskNotifications = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("WHILE YOU WERE AWAY")
                    .font(Theme.Fonts.label(13))
                    .foregroundStyle(Color.white.opacity(0.75))

                Text(summary.durationString)
                    .font(Theme.Fonts.display(32))
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

                // The notification ask, at the moment it obviously helps: the hero
                // just died while the player was away. Our own soft ask first —
                // the real iOS dialog only appears if they tap NOTIFY ME.
                if offerNotifications && summary.deaths > 0 {
                    if didAskNotifications {
                        Label("We'll give you a heads-up next time.", systemImage: "bell.fill")
                            .font(Theme.Fonts.label(13))
                            .foregroundStyle(Theme.Palette.gold)
                    } else {
                        // Big and obvious: the question on top, a full-width gold
                        // button under it — same weight as the game's main actions.
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(Theme.Palette.gold)
                                    .symbolEffect(.bounce, options: .repeat(.periodic(delay: 1.5)))
                                Text("Want a heads-up next time your hero falls?")
                                    .font(Theme.Fonts.label(15))
                                    .foregroundStyle(Theme.Palette.parchment)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            Button {
                                didAskNotifications = true
                                onEnableNotifications()
                            } label: {
                                Label("NOTIFY ME", systemImage: "bell.fill")
                                    .font(Theme.Fonts.display(18))
                                    .foregroundStyle(Color.black.opacity(0.8))
                            }
                            .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.gold, lip: Theme.Palette.goldDeep,
                                                           cornerRadius: 12, depth: 4))
                            .frame(height: 54)
                        }
                        .padding(14)
                        .gamePanel(tint: Theme.Palette.gold.opacity(0.8), cornerRadius: 14)
                        .shadow(color: Theme.Palette.gold.opacity(0.25), radius: 10)
                    }
                }

                if summary.stoppedByDeath {
                    Text("Unlock Undying Will to keep earning gold after death")
                        .font(Theme.Fonts.body(11))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }

                if summary.goldEarned > 0 {
                    if didDoubleGold {
                        Text("2× GOLD APPLIED!")
                            .font(Theme.Fonts.label(13))
                            .foregroundStyle(Theme.Palette.gold)
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
                            .font(Theme.Fonts.label(15))
                            .foregroundStyle(adManager.isOfflineAdReady ? Color.black.opacity(0.8) : Theme.Palette.ash)
                        }
                        .buttonStyle(ChunkyButtonStyle(face: adManager.isOfflineAdReady ? Theme.Palette.gold : Theme.Palette.stoneHi,
                                                       lip: adManager.isOfflineAdReady ? Theme.Palette.goldDeep : .black,
                                                       cornerRadius: 12, depth: 4))
                        .frame(height: 52)
                        .disabled(!adManager.isOfflineAdReady)
                    }
                }

                Button(action: onDismiss) {
                    Text("CONTINUE")
                        .font(Theme.Fonts.display(18))
                        .foregroundStyle(Theme.Palette.parchment)
                        .gameShadow()
                }
                .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.stoneHi, lip: .black, cornerRadius: 12, depth: 4))
                .frame(height: 52)
                .padding(.top, 4)
            }
            .padding(28)
            .gamePanel(tint: Theme.Palette.stoneEdge.opacity(0.75), cornerRadius: 16)
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
                .font(Theme.Fonts.body(14))
                .foregroundStyle(Color.white.opacity(0.75))
            Spacer()
            Text(value)
                .font(Theme.Fonts.label(14))
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
                    // Where this run ranks in the Hall of the Fallen.
                    if let best = game.fallenHeroes.map(\.floor).max(), game.currentFloor > best {
                        Label("Your deepest fall yet", systemImage: "crown.fill")
                            .font(Theme.Fonts.label(12))
                            .foregroundStyle(Theme.Palette.gold)
                    }
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

                    // Share the tombstone — the run becomes a story worth telling.
                    if let fall = game.currentFall {
                        FallenShareButton(fall: fall, source: "game_over") {
                            Label("SHARE YOUR FALL", systemImage: "square.and.arrow.up")
                                .font(Theme.Fonts.label(14))
                                .foregroundStyle(Theme.Palette.parchment)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
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
                    .foregroundStyle(Theme.Palette.gold)
                    .padding(.bottom, 14)

                Text("ZONE CLEARED!")
                    .font(Theme.Fonts.display(30))
                    .foregroundStyle(Theme.Palette.gold)
                    .gameShadow(3)

                Text("Stage \(victory.stageLabel)")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.top, 4)
                    .padding(.bottom, 18)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.bottom, 16)

                Text(victory.zoneIcon + "  " + victory.zoneName.uppercased())
                    .font(Theme.Fonts.label(15))
                    .foregroundStyle(.white)

                Text("\(victory.bossName) Defeated")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.top, 4)
                    .padding(.bottom, 20)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.bottom, 18)

                HStack(spacing: 36) {
                    VStack(spacing: 4) {
                        Text("GOLD")
                            .font(Theme.Fonts.label(9))
                            .foregroundStyle(Color.white.opacity(0.50))
                        Text("+\(victory.goldEarned)g")
                            .font(Theme.Fonts.display(22))
                            .foregroundStyle(Theme.Palette.gold)
                            .gameShadow()
                    }

                    VStack(spacing: 4) {
                        Text("REWARD")
                            .font(Theme.Fonts.label(9))
                            .foregroundStyle(Color.white.opacity(0.50))
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                            Text("Item Drop!")
                                .font(Theme.Fonts.label(14))
                        }
                        .foregroundStyle(Color(red: 0.72, green: 0.45, blue: 1.00))
                    }
                }
            }
            .padding(28)
            .gamePanel(tint: Theme.Palette.gold.opacity(0.75), cornerRadius: 18)
            .shadow(color: Theme.Palette.flame.opacity(0.15), radius: 24)
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
                    .font(Theme.Fonts.label(10))
                    .foregroundStyle(Color(red: 0.40, green: 0.95, blue: 0.55))
                Text(template.title)
                    .font(Theme.Fonts.label(15))
                    .foregroundStyle(.white)
                Text(template.primaryEffectSummary)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .gamePanel(tint: Theme.Palette.life.opacity(0.75), cornerRadius: 14)
        .padding(.horizontal, 16)
        .task {
            try? await Task.sleep(for: .seconds(3))
            onDismiss()
        }
    }
}

// MARK: - Loot Reveal Banner

/// Every drop gets a little "reveal" moment instead of a plain notice: the icon
/// pops out of a burst of its rarity color, a shine sweeps across the card, and
/// the rarer the item, the bigger the show (Epic and Legendary get spinning
/// rays and stay up longer). It's still a banner, never a blocking popup —
/// drops are frequent in an idle game, so the fight keeps going underneath.
struct ItemDropBanner: View {
    let item: Equipment
    /// True when the drop went straight onto the hero (an empty slot, or an
    /// auto-equip upgrade). False means it went to the bag.
    let wasEquipped: Bool
    let onDismiss: () -> Void

    /// Drives the reveal: false = the first frame (icon tiny, no shine),
    /// true = revealed. Flipped in `.task`, so SwiftUI animates between them.
    @State private var revealed = false
    @State private var shinePhase: CGFloat = -1
    @State private var raysSpin = false

    // MARK: Rarity drama
    // One place that decides how loud each rarity is.

    /// Epic and Legendary are "big moments": rays, a bigger icon, longer on screen.
    private var isBigMoment: Bool { item.rarity == .epic || item.rarity == .legendary }
    private var color: Color { item.rarity.uiColor }
    private var iconSize: CGFloat { isBigMoment ? 54 : 46 }
    private var secondsOnScreen: Double { isBigMoment ? 6 : 4 }

    /// The headline over the item name. Common gear doesn't need shouting.
    private var headline: String {
        switch item.rarity {
        case .common:    return "ITEM FOUND"
        case .uncommon:  return "UNCOMMON DROP"
        case .rare:      return "RARE DROP!"
        case .epic:      return "EPIC DROP!"
        case .legendary: return "LEGENDARY!!"
        }
    }

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: 12) {
                revealIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(Theme.Fonts.label(isBigMoment ? 12 : 10))
                        .tracking(1)
                        .foregroundStyle(color)
                        .gameShadow(1)
                    Text(item.name)
                        .font(Theme.Fonts.label(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.statSummary)
                        .font(Theme.Fonts.body(12))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                // The text slides in a beat after the icon pops.
                .opacity(revealed ? 1 : 0)
                .offset(x: revealed ? 0 : -8)

                Spacer(minLength: 4)

                destinationTag
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .gamePanel(tint: color.opacity(0.75), cornerRadius: 14)
            .overlay(shine)
            .shadow(color: color.opacity(isBigMoment ? 0.45 : 0.20), radius: isBigMoment ? 18 : 12)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .task {
            // Beat 1: pop the icon and text in.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { revealed = true }
            // Beat 2: the shine sweeps across once the card has landed.
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeInOut(duration: 0.7)) { shinePhase = 1 }
            if isBigMoment {
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { raysSpin = true }
            }
            try? await Task.sleep(for: .seconds(secondsOnScreen))
            onDismiss()
        }
    }

    // MARK: Pieces

    /// The item icon bursting out of a glow of its rarity color.
    private var revealIcon: some View {
        ZStack {
            // Epic+: slow-spinning light rays behind the icon.
            if isBigMoment {
                ForEach(0..<8, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(0.55))
                        .frame(width: 4, height: iconSize * 1.5)
                        .rotationEffect(.degrees(Double(i) * 22.5))
                }
                .rotationEffect(.degrees(raysSpin ? 360 : 0))
                .blur(radius: 1.5)
            }
            // The burst: a soft glow that blooms out as the icon arrives.
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.7), .clear],
                                     center: .center, startRadius: 2, endRadius: iconSize * 0.8))
                .frame(width: iconSize * 1.6, height: iconSize * 1.6)
                .scaleEffect(revealed ? 1 : 0.2)
                .opacity(item.rarity == .common ? 0.35 : 1)

            ItemIconView(item: item, size: iconSize)
                .scaleEffect(revealed ? 1 : 0.3)
                .rotationEffect(.degrees(revealed ? 0 : -25))
        }
        .frame(width: iconSize, height: iconSize)
    }

    /// Where the drop went: worn right now, or waiting in the bag.
    private var destinationTag: some View {
        VStack(spacing: 2) {
            Image(systemName: wasEquipped ? "checkmark.shield.fill" : "bag.fill")
                .font(.system(size: 15, weight: .bold))
            Text(wasEquipped ? "EQUIPPED" : "TO BAG")
                .font(Theme.Fonts.label(9))
        }
        .foregroundStyle(wasEquipped ? Theme.Palette.life : Theme.Palette.dust)
        .opacity(revealed ? 1 : 0)
    }

    /// A diagonal band of light that sweeps across the card once.
    private var shine: some View {
        GeometryReader { geo in
            LinearGradient(colors: [.clear, .white.opacity(isBigMoment ? 0.35 : 0.18), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: geo.size.width * 0.35)
                .rotationEffect(.degrees(20))
                .offset(x: shinePhase * geo.size.width * 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
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
                    .font(Theme.Fonts.label(11))
                    .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 0.45))
                    .padding(.bottom, 14)

                Image(systemName: zone.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.Palette.life)
                    .symbolEffect(.bounce, value: zone.id)
                    .padding(.bottom, 10)

                Text(zone.name.uppercased())
                    .font(Theme.Fonts.display(22))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Floor \(zone.minFloor)\(zone.maxFloor.map { "–\($0)" } ?? "+")")
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Color.white.opacity(0.50))
                    .padding(.top, 6)
            }
            .padding(36)
            .gamePanel(tint: Theme.Palette.life.opacity(0.75), cornerRadius: 18)
            .shadow(color: Theme.Palette.life.opacity(0.18), radius: 24)
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
