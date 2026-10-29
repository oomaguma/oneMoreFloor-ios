// HallViews.swift
// The Hall of the Fallen on screen: the memorial card (also the shareable
// image), a compact row for the list, and the Hall section in the Prestige tab.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Memorial Card

/// A tombstone for one fallen hero. Fixed size, because it doubles as the
/// image players share (rendered with ImageRenderer in `FallenShareButton`).
struct FallenCardView: View {
    let fall: FallenHero

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "staroflife.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.Palette.ash)
                .rotationEffect(.degrees(45))
            Text("HERE LIES")
                .font(Theme.Fonts.label(12))
                .tracking(3)
                .foregroundStyle(Theme.Palette.dust)
            Text(fall.heroName.uppercased())
                .font(Theme.Fonts.display(30))
                .foregroundStyle(Theme.Palette.parchment)
                .gameShadow(3)

            // The headline number: how deep they got.
            VStack(spacing: 0) {
                Text("FLOOR")
                    .font(Theme.Fonts.label(11))
                    .tracking(2)
                    .foregroundStyle(Theme.Palette.dust)
                Text("\(fall.floor)")
                    .font(Theme.Fonts.number(56))
                    .foregroundStyle(Theme.Palette.blood)
                    .gameShadow(4)
            }

            Text(fall.causeLine)
                .font(Theme.Fonts.body(15).italic())
                .foregroundStyle(Theme.Palette.parchment.opacity(0.8))

            // What the greed cost them.
            if fall.goldLost > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "bag.fill")
                    Text("\(fall.goldLost) gold lost at ×\(String(format: "%.1f", fall.greed)) greed")
                }
                .font(Theme.Fonts.label(13))
                .foregroundStyle(Theme.Palette.gold)
            }

            Text(fall.date.formatted(date: .abbreviated, time: .omitted))
                .font(Theme.Fonts.label(11))
                .foregroundStyle(Theme.Palette.ash)

            Text("ONE MORE FLOOR")
                .font(Theme.Fonts.display(13))
                .tracking(2)
                .foregroundStyle(Theme.Palette.flame)
                .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 320)
        .gamePanel(tint: Theme.Palette.stoneEdge, cornerRadius: 24)
        .padding(16)
        .background(Theme.Palette.abyss)
    }
}

// MARK: - Share Button

/// The memorial card as something shareable. Rendering to PNG happens only
/// when the share sheet actually asks for the data — not on every redraw of
/// the screen (rendering inside `body` made the button take seconds to open).
struct FallenCardImage: Transferable {
    let fall: FallenHero

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            try await MainActor.run {
                let renderer = ImageRenderer(content: FallenCardView(fall: card.fall)
                    .environment(\.colorScheme, .dark))
                renderer.scale = 3
                guard let data = renderer.uiImage?.pngData() else { throw CocoaError(.fileWriteUnknown) }
                return data
            }
        }
    }
}

/// Shares the memorial card as an image through the system share sheet.
struct FallenShareButton<Label: View>: View {
    let fall: FallenHero
    @ViewBuilder let label: () -> Label

    var body: some View {
        ShareLink(item: FallenCardImage(fall: fall),
                  preview: SharePreview("\(fall.heroName) fell on floor \(fall.floor)")) {
            label()
        }
    }
}

// MARK: - Hall Section (Prestige tab)

/// The memorial list: deepest fall up top, then every fallen hero, newest first.
struct HallOfTheFallenSection: View {
    let fallen: [FallenHero]
    @State private var selected: FallenHero?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("HALL OF THE FALLEN")
                    .font(Theme.Fonts.display(18))
                    .foregroundStyle(Theme.Palette.parchment)
                    .gameShadow()
                Spacer()
                Text("\(fallen.count) fallen")
                    .font(Theme.Fonts.label(12))
                    .foregroundStyle(Theme.Palette.dust)
            }

            if fallen.isEmpty {
                Text("No hero has fallen yet. Every run that ends in death is remembered here.")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Palette.dust)
            } else {
                ForEach(fallen) { fall in
                    Button { selected = fall } label: {
                        row(fall, isDeepest: fall.id == deepest?.id)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .gamePanel(cornerRadius: 16)
        .sheet(item: $selected) { fall in
            VStack(spacing: 18) {
                FallenCardView(fall: fall)
                FallenShareButton(fall: fall) {
                    Label("SHARE", systemImage: "square.and.arrow.up")
                        .font(Theme.Fonts.display(17))
                        .foregroundStyle(Color.black.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.Palette.gold))
                }
                .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Palette.abyss)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    /// The deepest fall gets a crown in the list.
    private var deepest: FallenHero? { fallen.max { $0.floor < $1.floor } }

    private func row(_ fall: FallenHero, isDeepest: Bool) -> some View {
        HStack(spacing: 12) {
            Text("\(fall.floor)")
                .font(Theme.Fonts.number(20))
                .foregroundStyle(isDeepest ? Theme.Palette.gold : Theme.Palette.blood)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(fall.heroName)
                        .font(Theme.Fonts.label(15))
                        .foregroundStyle(Theme.Palette.parchment)
                    if isDeepest {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Palette.gold)
                    }
                }
                Text(fall.causeLine + (fall.goldLost > 0 ? " · \(fall.goldLost) gold lost" : ""))
                    .font(Theme.Fonts.body(12))
                    .foregroundStyle(Theme.Palette.dust)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.Palette.ash)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
