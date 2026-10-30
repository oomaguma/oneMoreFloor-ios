// CodexViews.swift
// The codex on screen: a bestiary (every monster and every zone boss —
// silhouettes until slain) and a gear codex (every piece of gear, with a pip
// per rarity you've found). Opened from the CODEX button on the Items tab.

import SwiftUI

// MARK: - Codex Screen

struct CodexView: View {
    let codex: Codex

    private enum Page: String, CaseIterable { case bestiary = "BESTIARY", gear = "GEAR" }
    @State private var page: Page = .bestiary

    var body: some View {
        VStack(spacing: 14) {
            // Title + overall progress for the page you're on.
            VStack(spacing: 4) {
                Text("CODEX")
                    .font(Theme.Fonts.display(26))
                    .foregroundStyle(Theme.Palette.parchment)
                    .gameShadow(3)
                let progress = page == .bestiary ? codex.bestiaryProgress : codex.gearProgress
                Text("\(progress.found) / \(progress.total) discovered")
                    .font(Theme.Fonts.label(12))
                    .foregroundStyle(Theme.Palette.dust)
                    .contentTransition(.numericText())
            }
            .padding(.top, 20)

            Picker("Page", selection: $page) {
                ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            ScrollView {
                switch page {
                case .bestiary: BestiaryPage(codex: codex)
                case .gear:     GearCodexPage(codex: codex)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.abyss)
        // The game is always dark; without this the segmented picker draws its
        // unselected label in light-mode black, invisible on the abyss background.
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Bestiary

private struct BestiaryPage: View {
    let codex: Codex

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Zone bosses first: the biggest trophies, one per zone, in order.
            sectionTitle("BOSSES")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(DungeonGame.zones, id: \.id) { zone in
                    if let boss = DungeonGame.zoneBossEnemies[zone.id] {
                        let kills = codex.bossKillCount(zone: zone.id)
                        MonsterCard(enemy: boss, kills: kills, isBoss: true,
                                    title: kills > 0 ? boss.name : "???",
                                    // Undiscovered bosses say *where* to look, not who.
                                    subtitle: kills > 0
                                        ? "Boss of \(zone.shortName) · \(DungeonGame.bossGimmick(forZone: zone.id).teaser)"
                                        : "Waits on floor \(zone.maxFloor ?? zone.minFloor + 9)")
                    }
                }
            }

            sectionTitle("MONSTERS")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(EnemyType.all) { enemy in
                    let kills = codex.killCount(enemy.id)
                    MonsterCard(enemy: enemy, kills: kills, isBoss: false,
                                title: kills > 0 ? enemy.name : "???",
                                subtitle: habitat(of: enemy))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }

    /// Where a monster lives, e.g. "Crypts · Hell Gate" — a hint for hunting
    /// the ones you haven't met yet.
    private func habitat(of enemy: EnemyType) -> String {
        let zones = DungeonGame.zones.filter { zone in
            DungeonGame.zoneEnemyPools[zone.id]?.contains { $0.id == enemy.id } ?? false
        }
        return zones.isEmpty ? "Only as a boss" : zones.map(\.shortName).joined(separator: " · ")
    }
}

/// One bestiary entry: the monster in full color once slain, a black
/// silhouette (like the next-boss preview) until then.
private struct MonsterCard: View {
    let enemy: EnemyType
    let kills: Int
    let isBoss: Bool
    let title: String
    let subtitle: String

    private var discovered: Bool { kills > 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let frame = SpriteFrames.firstFrame(of: enemy.idle) {
                    if discovered {
                        Image(uiImage: frame)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(uiImage: frame)
                            .renderingMode(.template)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.black)
                            .shadow(color: Theme.Palette.ash.opacity(0.8), radius: 1.5)
                    }
                }
            }
            .frame(height: 64)
            .padding(.top, 6)

            Text(title)
                .font(Theme.Fonts.label(14))
                .foregroundStyle(discovered ? (isBoss ? Theme.Palette.flame : Theme.Palette.parchment)
                                            : Theme.Palette.ash)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Palette.dust)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(discovered ? "\(kills) slain" : "Not yet slain")
                .font(Theme.Fonts.number(11))
                .foregroundStyle(discovered ? Theme.Palette.blood : Theme.Palette.ash)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .gamePanel(tint: discovered && isBoss ? Theme.Palette.flame.opacity(0.7) : Theme.Palette.stoneEdge,
                   cornerRadius: 14)
    }
}

// MARK: - Gear Codex

private struct GearCodexPage: View {
    let codex: Codex

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(EquipmentSlot.allCases, id: \.self) { slot in
                sectionTitle(slot.label.uppercased() + "S")
                ForEach(EquipmentDrop.codexEntries.filter { $0.slot == slot }, id: \.baseName) { entry in
                    GearCodexRow(codex: codex, baseName: entry.baseName, iconName: entry.iconName)
                }
            }
            Text("Each pip is a rarity: Common, Uncommon, Rare, Epic, Legendary.")
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Palette.ash)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

/// One gear piece: its icon (ghosted until found), its name, and five
/// rarity pips — filled in that rarity's color once you've found it.
private struct GearCodexRow: View {
    let codex: Codex
    let baseName: String
    let iconName: String

    private var foundAny: Bool { ItemRarity.allCases.contains { codex.hasFound(baseName, rarity: $0) } }
    /// The rarest version found, which colors the icon frame.
    private var best: ItemRarity? { ItemRarity.allCases.last { codex.hasFound(baseName, rarity: $0) } }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill((best?.uiColor ?? Theme.Palette.ash).opacity(0.15))
                RoundedRectangle(cornerRadius: 6)
                    .stroke(best?.uiColor ?? Theme.Palette.ash.opacity(0.5), lineWidth: 1.5)
                Image(iconName)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(5)
                    .opacity(foundAny ? 1 : 0.15)
                    .saturation(foundAny ? 1 : 0)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(foundAny ? baseName : "???")
                    .font(Theme.Fonts.label(14))
                    .foregroundStyle(foundAny ? Theme.Palette.parchment : Theme.Palette.ash)
                HStack(spacing: 6) {
                    ForEach(ItemRarity.allCases, id: \.self) { rarity in
                        let found = codex.hasFound(baseName, rarity: rarity)
                        Circle()
                            .fill(found ? rarity.uiColor : .clear)
                            .overlay(Circle().stroke(found ? rarity.uiColor : Theme.Palette.ash.opacity(0.6),
                                                     lineWidth: 1.5))
                            .frame(width: 12, height: 12)
                            .shadow(color: found ? rarity.uiColor.opacity(0.6) : .clear, radius: 3)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .gamePanel(cornerRadius: 12)
    }
}

// MARK: - Shared

private func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(Theme.Fonts.label(12))
        .tracking(2)
        .foregroundStyle(Theme.Palette.dust)
        .padding(.top, 6)
}
