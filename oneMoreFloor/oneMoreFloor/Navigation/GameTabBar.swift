// GameTabBar.swift
// The custom bottom tab bar and the GameTab enum it switches between.

import SwiftUI

// MARK: - Tab Navigation

/// Upgrades and Items used to be separate tabs; they're one Hero tab now
/// (see Tabs/HeroTab.swift).
enum GameTab { case hero, battle, prestige, quests }

struct CustomGameTabBar: View {
    @Binding var selectedTab: GameTab
    let hasClaimableQuest: Bool

    private struct TabDef {
        let tab: GameTab
        let label: String
        let icon: String
    }

    private let tabs: [TabDef] = [
        .init(tab: .hero,     label: "HERO",     icon: "figure.fencing"),
        .init(tab: .battle,   label: "BATTLE",   icon: "shield.fill"),
        .init(tab: .prestige, label: "PRESTIGE", icon: "sparkles"),
        .init(tab: .quests,   label: "QUESTS",   icon: "scroll.fill"),
    ]

    // Theme tokens: warm stone bar, gold for the selected tab.
    private let barColor        = Theme.Palette.stone
    private let selectedColor   = Theme.Palette.gold
    private let unselectedColor = Theme.Palette.ash

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.label) { def in
                tabButton(def)
            }
        }
        .frame(height: 56)
        .background(
            LinearGradient(colors: [Theme.Palette.stoneHi, barColor],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            // Carved top edge: a dark groove over a faint highlight.
            VStack(spacing: 0) {
                Rectangle().fill(Color.black.opacity(0.8)).frame(height: 1)
                Rectangle().fill(Theme.Palette.stoneEdge.opacity(0.6)).frame(height: 1)
            }
        }
    }

    private func tabButton(_ def: TabDef) -> some View {
        let isSelected = selectedTab == def.tab
        let isBattle   = def.tab == .battle
        let showBadge  = def.tab == .quests && hasClaimableQuest

        return Button {
            Haptics.impact(.light)
            selectedTab = def.tab
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: def.icon)
                        .font(.system(size: isBattle ? 22 : 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? selectedColor : unselectedColor)
                        .frame(width: 28, height: 24)
                        // Selected icon glows like a lit torch.
                        .shadow(color: isSelected ? selectedColor.opacity(0.7) : .clear, radius: 6)
                        .gameShadow(isSelected ? 2 : 0)

                    if showBadge {
                        Circle()
                            .fill(Theme.Palette.blood)
                            .frame(width: 7, height: 7)
                            .offset(x: 5, y: -2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showBadge)

                Text(def.label)
                    .font(Theme.Fonts.label(10))
                    .foregroundStyle(isSelected ? selectedColor : unselectedColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .overlay(alignment: .top) {
                if isSelected {
                    Capsule()
                        .fill(selectedColor)
                        .frame(width: 20, height: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
