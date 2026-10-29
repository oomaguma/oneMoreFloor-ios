// UpgradesTabs.swift
// The Upgrades and Prestige tabs, plus their row views.

import SwiftUI

// MARK: - Upgrades Tab

struct UpgradesTabView: View {
    let game: DungeonGame

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Spendable (banked) gold — the sheet covers the top status bar,
                // so surface it here so the player can manage purchases.
                HStack(spacing: 8) {
                    Text("UPGRADES")
                        .font(Theme.Fonts.display(22))
                        .foregroundStyle(Theme.Palette.parchment)
                        .gameShadow()
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(game.gold)")
                            .font(Theme.Fonts.number(20))
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: game.gold)
                    }
                    .foregroundStyle(Theme.Palette.gold)
                    .gameShadow()
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .gamePanel(tint: Theme.Palette.gold.opacity(0.5), cornerRadius: 17)
                }
                .padding(.bottom, 4)

                ForEach(game.upgrades) { upgrade in
                    let isLocked = upgrade.unlockFloor > 0 && game.deepestFloorEver < upgrade.unlockFloor
                    let unlockZone = DungeonGame.zones.first(where: { $0.minFloor == upgrade.unlockFloor })?.name
                    let cost = game.effectiveCost(for: upgrade)
                    UpgradeRowView(
                        upgrade: upgrade,
                        displayCost: cost,
                        canAfford: game.gold >= cost,
                        isLocked: isLocked,
                        unlockZoneName: unlockZone
                    ) {
                        game.buyUpgrade(id: upgrade.id)
                        SoundManager.shared.play("weapon_upgrade")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .background(Theme.Palette.abyss)
    }
}

// MARK: - Prestige Tab

struct PrestigeTabView: View {
    let game: DungeonGame
    let combatScene: CombatScene
    let onChangeCharacter: () -> Void
    @State private var showStore = false
    @State private var showDynastySelect = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                PrestigeRowView(game: game, onRetireHero: { showDynastySelect = true })

                Text("PERMANENT UPGRADES")
                    .font(Theme.Fonts.label(10))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.top, 8)

                ForEach(game.prestigeUpgrades) { upgrade in
                    PrestigeUpgradeRowView(
                        upgrade: upgrade,
                        canAfford: game.soulShards >= upgrade.shardCost
                    ) {
                        game.buyPrestigeUpgrade(id: upgrade.id)
                        SoundManager.shared.play("8_bit_chime_positive")
                    }
                }

                if !game.retiredCharacterIDs.isEmpty {
                    LegacyBonusSectionView(retiredIDs: game.retiredCharacterIDs)
                }

                Button(action: onChangeCharacter) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14))
                        Text("CHANGE HERO")
                            .font(Theme.Fonts.label(13))
                    }
                    .foregroundStyle(Color.white.opacity(0.70))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .gamePanel(tint: Theme.Palette.stoneEdge.opacity(0.75), cornerRadius: 10)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)

                Button { showStore = true } label: {
                    HStack {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 14))
                        Text("SUPPORT THE GAME")
                            .font(Theme.Fonts.label(13))
                    }
                    .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.25).opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .gamePanel(tint: Color(red: 1.00, green: 0.75, blue: 0.25).opacity(0.75), cornerRadius: 10)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .background(Theme.Palette.abyss)
        .sheet(isPresented: $showStore) {
            StoreSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationSizing(.page)
        }
        .sheet(isPresented: $showDynastySelect) {
            CharacterSelectView(
                onCancel: { showDynastySelect = false },
                onSelect: { newChar in
                    game.prestige(switchingTo: newChar)
                    combatScene.updateHero(newChar)
                    combatScene.playHeroIdle()
                    showDynastySelect = false
                },
                dynastyContext: DynastySelectContext(
                    retiringCharacterID: game.characterID,
                    retiredCharacterIDs: game.retiredCharacterIDs
                )
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationSizing(.page)
        }
    }
}

// MARK: - Legacy Bonus Section

struct LegacyBonusSectionView: View {
    let retiredIDs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LEGACY BONUSES")
                .font(Theme.Fonts.label(10))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 8)

            VStack(spacing: 0) {
                ForEach(Array(retiredIDs.enumerated()), id: \.element) { i, id in
                    if let char = CharacterClass.all.first(where: { $0.id == id }) {
                        VStack(spacing: 0) {
                            if i > 0 {
                                Divider()
                                    .background(Color.white.opacity(0.08))
                                    .padding(.horizontal, 16)
                            }
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.15))
                                    Text(char.name)
                                        .font(Theme.Fonts.body(13))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                Text(char.legacyBonus.description)
                                    .font(Theme.Fonts.body(12))
                                    .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.15))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
            .gamePanel(tint: Color(red: 1.00, green: 0.75, blue: 0.15).opacity(0.75), cornerRadius: 10)
        }
    }
}

// MARK: - Upgrade Row

struct UpgradeRowView: View {
    let upgrade: Upgrade
    let displayCost: Int
    let canAfford: Bool
    let isLocked: Bool
    let unlockZoneName: String?
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile — each stat gets its own color + symbol so the list can
            // be scanned at a glance instead of read line by line.
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isLocked ? Theme.Palette.abyss : style.color.opacity(0.18))
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isLocked ? Theme.Palette.stoneEdge.opacity(0.4) : style.color.opacity(0.6), lineWidth: 1.5)
                Image(systemName: isLocked ? "lock.fill" : style.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isLocked ? Theme.Palette.ash : style.color)
                    .gameShadow(1)
            }
            .frame(width: 48, height: 48)

            // Name, level, and what it does.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(upgrade.name)
                        .font(Theme.Fonts.label(16))
                        .foregroundStyle(isLocked ? Theme.Palette.ash : Theme.Palette.parchment)
                    if !isLocked && upgrade.level > 0 {
                        Text("LV \(upgrade.level)")
                            .font(Theme.Fonts.label(10))
                            .foregroundStyle(style.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(style.color.opacity(0.16)))
                    }
                }
                Text(isLocked ? "Reach \(unlockZoneName ?? "next zone") to unlock" : upgrade.currentEffect)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(isLocked ? Theme.Palette.ash.opacity(0.8) : Theme.Palette.dust)
            }

            Spacer(minLength: 4)

            // Buy button — a chunky gold coin-button when affordable, a dull
            // stone one when not. It's the only tappable part of the row.
            if !isLocked {
                Button(action: onTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.fill").font(.system(size: 9, weight: .bold))
                        Text("\(displayCost)").font(Theme.Fonts.number(16))
                    }
                    .foregroundStyle(canAfford ? Color.black.opacity(0.8) : Theme.Palette.ash)
                }
                .buttonStyle(ChunkyButtonStyle(face: canAfford ? Theme.Palette.gold : Theme.Palette.stoneHi,
                                               lip: canAfford ? Theme.Palette.goldDeep : .black,
                                               cornerRadius: 10, depth: 4))
                .frame(width: 78, height: 46)
                .disabled(!canAfford)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .gamePanel(tint: canAfford && !isLocked ? Theme.Palette.gold.opacity(0.6) : Theme.Palette.stoneEdge,
                   cornerRadius: 12)
        .opacity(isLocked ? 0.7 : 1)
    }

    /// Icon + color per upgrade id. Unknown ids fall back to a neutral star.
    private var style: (icon: String, color: Color) {
        switch upgrade.id {
        case "atk":      return ("bolt.fill", Theme.Palette.flame)
        case "def":      return ("shield.fill", Theme.Palette.frost)
        case "maxhp":    return ("heart.fill", Theme.Palette.blood)
        case "regen":    return ("leaf.fill", Theme.Palette.life)
        case "goldmult": return ("dollarsign.circle.fill", Theme.Palette.gold)
        case "speed":    return ("hare.fill", Theme.Palette.ember)
        default:         return ("star.fill", Theme.Palette.parchment)
        }
    }
}

// MARK: - Prestige Upgrade Row

struct PrestigeUpgradeRowView: View {
    let upgrade: PrestigeUpgrade
    let canAfford: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(upgrade.name)
                            .font(Theme.Fonts.body(16))
                            .foregroundStyle(Color.white.opacity(upgrade.isMaxed ? 0.4 : 1.0))
                        Text("Lv \(upgrade.level)/\(upgrade.maxLevel)")
                            .font(Theme.Fonts.body(11))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    Text(upgrade.level == 0 ? upgrade.detail : upgrade.currentEffect)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer()
                if upgrade.isMaxed {
                    Text("MAX")
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(Color(red: 0.70, green: 0.50, blue: 1.00))
                } else {
                    Text("\(upgrade.shardCost) ◈")
                        .font(Theme.Fonts.label(18))
                        .foregroundStyle(canAfford ? Color(red: 0.70, green: 0.50, blue: 1.00) : Color.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.Palette.stone)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                upgrade.isMaxed
                                    ? Color(red: 0.50, green: 0.30, blue: 0.80).opacity(0.45)
                                    : canAfford
                                        ? Color(red: 0.50, green: 0.30, blue: 0.80).opacity(0.38)
                                        : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(upgrade.isMaxed)
    }
}

// MARK: - Prestige Row

struct PrestigeRowView: View {
    let game: DungeonGame
    let onRetireHero: () -> Void

    @State private var showRetireConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("PRESTIGE")
                        .font(Theme.Fonts.display(22))
                        .foregroundStyle(game.canPrestige() ? Color(red: 0.72, green: 0.52, blue: 1.00) : Theme.Palette.parchment)
                        .gameShadow()
                    Text(subtitle)
                        .font(Theme.Fonts.body(13))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                Spacer()
            }

            if game.canPrestige() {
                HStack(spacing: 10) {
                    // Prestige: reset the run, cash the climb in for soul shards.
                    Button {
                        game.prestige()
                    } label: {
                        Text("PRESTIGE  +\(game.prestigeShardValue()) ◈")
                            .font(Theme.Fonts.display(15))
                            .foregroundStyle(.white)
                            .gameShadow()
                    }
                    .buttonStyle(ChunkyButtonStyle(face: Color(red: 0.50, green: 0.30, blue: 0.85),
                                                   lip: Color(red: 0.22, green: 0.12, blue: 0.40),
                                                   cornerRadius: 12, depth: 4))

                    Button {
                        showRetireConfirm = true
                    } label: {
                        Label("RETIRE", systemImage: "crown.fill")
                            .font(Theme.Fonts.label(13))
                            .foregroundStyle(Theme.Palette.gold)
                    }
                    .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.stoneHi, lip: .black,
                                                   cornerRadius: 12, depth: 4))
                    .frame(width: 112)
                }
                .frame(height: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .gamePanel(tint: game.canPrestige() ? Color(red: 0.55, green: 0.35, blue: 0.90) : Theme.Palette.stoneEdge,
                   cornerRadius: 16)
        .alert("Retire \(game.character.name)?", isPresented: $showRetireConfirm) {
            Button("Retire", role: .destructive) { onRetireHero() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Pass on your hero's legacy and choose a new champion.")
        }
    }

    private var subtitle: String {
        if game.canPrestige() {
            return "Best floor \(game.deepestFloor) — reset for \(game.prestigeShardValue()) shards"
        }
        let threshold = game.prestigeThreshold
        return game.deepestFloor > 0
            ? "Best: floor \(game.deepestFloor) — need floor \(threshold)"
            : "Reach floor \(threshold) to unlock"
    }
}
