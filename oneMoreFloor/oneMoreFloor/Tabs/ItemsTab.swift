// ItemsTab.swift
// The Items tab: rarity colors, item icons, equipped gear, inventory, set bonuses.

import SwiftUI

// MARK: - Rarity colors

extension ItemRarity {
    var uiColor: Color {
        switch self {
        case .common:    return .white
        case .uncommon:  return Color(red: 0.22, green: 0.82, blue: 0.35)
        case .rare:      return Color(red: 0.25, green: 0.55, blue: 1.00)
        case .epic:      return Color(red: 0.72, green: 0.30, blue: 1.00)
        case .legendary: return Color(red: 1.00, green: 0.65, blue: 0.10)
        }
    }
}

// MARK: - Item Icon

struct ItemIconView: View {
    let item: Equipment
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(item.rarity.uiColor.opacity(0.18))
            RoundedRectangle(cornerRadius: 6)
                .stroke(item.rarity.uiColor, lineWidth: 1.5)
            Image(item.iconName)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(5)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Items Tab

struct ItemsTabView: View {
    let game: DungeonGame

    var body: some View {
        VStack(spacing: 0) {
            // Fixed equipped section
            VStack(spacing: 14) {
                HStack {
                    Text("GEAR")
                        .font(Theme.Fonts.display(22))
                        .foregroundStyle(Theme.Palette.parchment)
                        .gameShadow()
                    Spacer()
                    if !game.inventory.isEmpty {
                        Button(action: { game.optimizeEquipment() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                Text("OPTIMIZE")
                                    .font(Theme.Fonts.label(11))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                        }
                        .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.life.mix(with: .black, by: 0.3),
                                                       lip: Theme.Palette.lifeDeep.mix(with: .black, by: 0.4),
                                                       cornerRadius: 10, depth: 3))
                        .fixedSize()
                        .frame(height: 34)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                        EquippedGearCard(
                            slot: slot,
                            item: game.equippedItems[slot.rawValue],
                            onUnequip: { game.unequip(slot: slot) },
                            onSell: { game.sellEquipped(slot: slot) }
                        )
                    }
                }
                // Natural height only: without this the cards' spacers soak up
                // all the spare sheet height and balloon to ~340pt tall.
                .fixedSize(horizontal: false, vertical: true)

                if let bonus = game.appliedSetBonus {
                    SetBonusCardView(rarity: bonus, summary: game.setBonusSummary(bonus))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.08))

            // Scrollable inventory
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    let charms = game.usableItems.filter { $0.kind == .revive }
                    if !charms.isEmpty {
                        Text("CONSUMABLES  \(game.usableItems.count)/\(DungeonGame.usableItemLimit)")
                            .font(Theme.Fonts.label(12))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .padding(.horizontal, 4)

                        ForEach(charms) { item in
                            UsableItemView(item: item, onUse: { game.useItem(item) })
                        }

                        if !game.inventory.isEmpty {
                            Divider()
                                .background(Color.white.opacity(0.10))
                                .padding(.vertical, 4)
                        }
                    }

                    if !game.inventory.isEmpty {
                        Text("INVENTORY  \(game.inventory.count)/\(EquipmentDrop.inventoryLimit)")
                            .font(Theme.Fonts.label(12))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .padding(.horizontal, 4)

                        ForEach(game.inventory.reversed()) { item in
                            InventoryItemView(
                                item: item,
                                onEquip: { game.equip(item: item) },
                                onSell:  { game.sellItem(item) }
                            )
                        }
                    } else if game.equippedItems.isEmpty && charms.isEmpty {
                        Text("Items drop from enemies as you fight.\nCheck back after a few battles.")
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Color.white.opacity(0.40))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 24)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.Palette.abyss)
    }
}

// MARK: - Equipped Gear Card

struct EquippedGearCard: View {
    let slot: EquipmentSlot
    let item: Equipment?
    let onUnequip: () -> Void
    let onSell: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(slot.label.uppercased())
                .font(Theme.Fonts.label(8))
                .foregroundStyle(Color.white.opacity(0.40))
                .padding(.bottom, 8)

            if let item {
                ItemIconView(item: item, size: 38)
                    .padding(.bottom, 8)

                Text(item.name)
                    .font(Theme.Fonts.label(11))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                Text(item.rarity.label)
                    .font(Theme.Fonts.label(9))
                    .foregroundStyle(item.rarity.uiColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(item.rarity.uiColor.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)

                Text(item.statSummary)
                    .font(Theme.Fonts.body(10))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    // Sell for gold — a small chunky gold coin button.
                    Button(action: onSell) {
                        Text("\(item.sellValue)g")
                            .font(Theme.Fonts.number(12))
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    .buttonStyle(ChunkyButtonStyle(face: Theme.Palette.gold, lip: Theme.Palette.goldDeep,
                                                   cornerRadius: 7, depth: 3))
                    .frame(height: 28)

                    Button(action: onUnequip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(width: 26)
                            .padding(.vertical, 5)
                            .background(Theme.Palette.stoneHi)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    // A ghosted silhouette of the game's own gear art for this slot.
                    Image(slotArt)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .grayscale(1)
                        .opacity(0.18)
                    Text("EMPTY")
                        .font(Theme.Fonts.label(9))
                        .foregroundStyle(Color.white.opacity(0.22))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 170)
        .gamePanel(tint: item?.rarity.uiColor.opacity(0.7) ?? Theme.Palette.stoneEdge.opacity(0.5),
                   cornerRadius: 12)
    }

    /// Asset name of the starter gear art for each slot, used as the empty-slot ghost.
    /// (The old SF Symbol "sword" doesn't exist, so the weapon slot showed nothing.)
    private var slotArt: String {
        switch slot {
        case .weapon: return "eq_sword"
        case .armor:  return "eq_tunic"
        case .ring:   return "eq_ring"
        }
    }
}

// MARK: - Usable Item Row

struct UsableItemView: View {
    let item: UsableItem
    let onUse: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(item.icon)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(Theme.Fonts.label(13))
                    .foregroundStyle(.white)
                Text(item.kind == .fullHeal ? "Restore HP to full" : "Auto-triggers on death")
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            if item.kind == .fullHeal {
                Button(action: onUse) {
                    Text("USE")
                        .font(Theme.Fonts.label(12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.18, green: 0.42, blue: 0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                Text("AUTO")
                    .font(Theme.Fonts.label(11))
                    .foregroundStyle(Color(red: 0.60, green: 0.45, blue: 0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.60, green: 0.45, blue: 0.95).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .gamePanel(tint: Color(red: 0.55, green: 0.55, blue: 1.0).opacity(0.75), cornerRadius: 10)
    }
}

// MARK: - Inventory Item Row

struct InventoryItemView: View {
    let item: Equipment
    let onEquip: () -> Void
    let onSell: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ItemIconView(item: item, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(.white)
                    Text(item.rarity.label)
                        .font(Theme.Fonts.label(11))
                        .foregroundStyle(item.rarity.uiColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(item.rarity.uiColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(item.statSummary)
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text("\(DungeonGame.stageLabel(floor: item.floorFound))  •  \(item.slot.label)")
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(Color.white.opacity(0.50))
            }

            Spacer()

            VStack(spacing: 5) {
                Button(action: onEquip) {
                    Text("EQUIP")
                        .font(Theme.Fonts.label(12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.15, green: 0.38, blue: 0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: onSell) {
                    Text("SELL \(item.sellValue)g")
                        .font(Theme.Fonts.label(12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.35, green: 0.25, blue: 0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.yellow)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .gamePanel(tint: item.rarity.uiColor.opacity(0.75), cornerRadius: 10)
    }
}

// MARK: - Set Bonus Card

struct SetBonusCardView: View {
    let rarity: ItemRarity
    let summary: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(rarity.uiColor)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(rarity.label) Set Bonus")
                        .font(Theme.Fonts.label(13))
                        .foregroundStyle(.white)
                    Text("ACTIVE")
                        .font(Theme.Fonts.label(9))
                        .foregroundStyle(rarity.uiColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(rarity.uiColor.opacity(0.18))
                        .clipShape(Capsule())
                }
                Text(summary)
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rarity.uiColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(rarity.uiColor.opacity(0.35), lineWidth: 1)
                )
        )
    }
}
