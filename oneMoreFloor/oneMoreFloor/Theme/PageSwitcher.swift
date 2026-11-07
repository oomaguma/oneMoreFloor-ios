// PageSwitcher.swift
// The game's own two-or-more-page switcher, used instead of the stock
// segmented control (which looked like a Settings screen dropped into a
// dungeon). A sunken stone track with a gold plate that slides behind
// whichever page is open. Used by the Hero tab and the Codex.

import SwiftUI

// MARK: - Switcher Page

/// What a page enum needs to appear on a `PageSwitcher`: a label and an icon.
///
/// Why a protocol: the Hero tab's pages (UPGRADES / GEAR) and the Codex's
/// (BESTIARY / GEAR) are different enums. Instead of copying the switcher for
/// each, any enum that "signs this contract" can use the one switcher —
/// the same idea as a base class every subclass can stand in for.
protocol SwitcherPage: Hashable, CaseIterable where AllCases: RandomAccessCollection {
    var title: String { get }
    var icon: String { get }   // an SF Symbol name
}

// MARK: - Page Switcher
//
// `Page` is a *generic* placeholder: "some enum that conforms to
// SwitcherPage". Each screen fills it in with its own enum, and Swift checks
// at compile time that the binding and the cases all match up.
//
// The sliding trick is `matchedGeometryEffect`. Only the selected button
// draws the plate, but because every plate shares one id in one namespace,
// SwiftUI treats them as the *same* view and animates it from the old
// button's frame to the new one, instead of fading one out and another in.

struct PageSwitcher<Page: SwitcherPage>: View {
    @Binding var page: Page
    @Namespace private var plate

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(Page.allCases), id: \.self) { option in
                button(for: option)
            }
        }
        .padding(4)
        .background(
            // The track: darker than a panel, with a shadow along the top
            // edge, so it reads as carved *into* the stone, not sitting on it.
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.Palette.abyss)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Theme.Palette.stoneEdge.opacity(0.7), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            LinearGradient(colors: [.black.opacity(0.6), .clear],
                                           startPoint: .top, endPoint: .center),
                            lineWidth: 3)
                )
        )
    }

    private func button(for option: Page) -> some View {
        let selected = page == option
        return Button {
            guard !selected else { return }
            SoundManager.shared.play("ui_tab")
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { page = option }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 13, weight: .bold))
                Text(option.title)
                    .font(Theme.Fonts.display(15))
            }
            // Dark ink on the gold plate; dim dust on the bare track.
            .foregroundStyle(selected ? Theme.Palette.abyss : Theme.Palette.dust)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Theme.Palette.gold, Theme.Palette.goldDeep],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(
                            // The same glossy top edge as ChunkyButtonStyle.
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    LinearGradient(colors: [.white.opacity(0.5), .clear],
                                                   startPoint: .top, endPoint: .center),
                                    lineWidth: 1.5)
                        )
                        .shadow(color: Theme.Palette.gold.opacity(0.35), radius: 6)
                        .matchedGeometryEffect(id: "plate", in: plate)
                }
            }
            .contentShape(Rectangle())   // the whole half is tappable, not just the text
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
