// HeroTab.swift
// One "Hero" tab for everything that makes the hero stronger: gold upgrades
// and gear used to be two separate tabs, even though players think of them
// as one question — "how do I get tougher?" Merging them also frees a slot
// in the tab bar.

import SwiftUI

// MARK: - Hero Tab

struct HeroTabView: View {
    let game: DungeonGame

    /// The two halves of the tab. Remembered between visits, so a player who
    /// lives in the gear screen doesn't have to switch every time.
    enum Page: String, CaseIterable {
        case upgrades = "UPGRADES"
        case gear     = "GEAR"
    }
    @AppStorage("com.oneMoreFloor.heroTabPage") private var page: Page = .upgrades

    var body: some View {
        VStack(spacing: 0) {
            Picker("Page", selection: $page) {
                ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            // The game is always dark; this keeps the unselected label readable.
            .environment(\.colorScheme, .dark)

            // Each page keeps its own header (gold on Upgrades; Codex and
            // Optimize on Gear), so they're shown as-is underneath.
            switch page {
            case .upgrades: UpgradesTabView(game: game)
            case .gear:     ItemsTabView(game: game)
            }
        }
        .background(Theme.Palette.abyss)
    }
}
