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
                    Text("EQUIPPED GEAR")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.65))
                    Spacer()
                    if !game.inventory.isEmpty {
                        Button(action: { game.optimizeEquipment() }) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                Text("OPTIMIZE")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.18, green: 0.42, blue: 0.22))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
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
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
                            .font(.system(size: 13, design: .monospaced))
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
        .background(Color(red: 0.07, green: 0.07, blue: 0.11))
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
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.40))
                .padding(.bottom, 8)

            if let item {
                ItemIconView(item: item, size: 38)
                    .padding(.bottom, 8)

                Text(item.name)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)

                Text(item.rarity.label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(item.rarity.uiColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(item.rarity.uiColor.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)

                Text(item.statSummary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 10)

                HStack(spacing: 6) {
                    Button(action: onSell) {
                        Text("\(item.sellValue)g")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.yellow)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.30, green: 0.22, blue: 0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)

                    Button(action: onUnequip) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .frame(width: 26)
                            .padding(.vertical, 5)
                            .background(Color(white: 0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: slotSymbol)
                        .font(.system(size: 26))
                        .foregroundStyle(Color.white.opacity(0.12))
                    Text("EMPTY")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.22))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 170)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            item.map { $0.rarity.uiColor.opacity(0.28) } ?? Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }

    private var slotSymbol: String {
        switch slot {
        case .weapon: return "sword"
        case .armor:  return "shield.fill"
        case .ring:   return "seal.fill"
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
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(item.kind == .fullHeal ? "Restore HP to full" : "Auto-triggers on death")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.55))
            }

            Spacer()

            if item.kind == .fullHeal {
                Button(action: onUse) {
                    Text("USE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.18, green: 0.42, blue: 0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            } else {
                Text("AUTO")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.60, green: 0.45, blue: 0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.60, green: 0.45, blue: 0.95).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.09))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(red: 0.55, green: 0.55, blue: 1.0).opacity(0.30), lineWidth: 1))
        )
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
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(item.rarity.label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(item.rarity.uiColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(item.rarity.uiColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(item.statSummary)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                Text("\(DungeonGame.stageLabel(floor: item.floorFound))  •  \(item.slot.label)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.50))
            }

            Spacer()

            VStack(spacing: 5) {
                Button(action: onEquip) {
                    Text("EQUIP")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.15, green: 0.38, blue: 0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button(action: onSell) {
                    Text("SELL \(item.sellValue)g")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(white: 0.09))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(item.rarity.uiColor.opacity(0.18), lineWidth: 1))
        )
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
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(rarity.uiColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(rarity.uiColor.opacity(0.18))
                        .clipShape(Capsule())
                }
                Text(summary)
                    .font(.system(size: 12, design: .monospaced))
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
