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
    /// lives in the gear screen doesn't have to switch every time. The raw
    /// values are what @AppStorage saves, so don't rename them.
    enum Page: String, SwitcherPage {
        case upgrades = "UPGRADES"
        case gear     = "GEAR"

        var title: String { rawValue }
        var icon: String {
            switch self {
            case .upgrades: return "arrow.up.circle.fill"
            case .gear:     return "shield.lefthalf.filled"
            }
        }
    }
    @AppStorage("com.oneMoreFloor.heroTabPage") private var page: Page = .upgrades

    var body: some View {
        VStack(spacing: 0) {
            // The game's own switcher (Theme/PageSwitcher.swift), not the
            // stock segmented control.
            PageSwitcher(page: $page)
                .padding(.horizontal, 16)
                .padding(.top, 18)

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
