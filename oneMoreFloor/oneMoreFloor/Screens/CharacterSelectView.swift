// CharacterSelectView.swift
// Character select: picking a class (and a dynasty heir) for a new run.

import SwiftUI
import SpriteKit

// MARK: - Character Select

struct DynastySelectContext {
    let retiringCharacterID: String
    let retiredCharacterIDs: [String]

    var retiringCharacterName: String {
        CharacterClass.all.first { $0.id == retiringCharacterID }?.name ?? "Hero"
    }
    // nil when the legacy for this character has already been claimed
    var pendingLegacyBonus: LegacyBonus? {
        guard !retiredCharacterIDs.contains(retiringCharacterID) else { return nil }
        return CharacterClass.all.first { $0.id == retiringCharacterID }?.legacyBonus
    }
}

struct CharacterSelectView: View {
    let onCancel: (() -> Void)?
    let onSelect: (CharacterClass) -> Void
    var dynastyContext: DynastySelectContext? = nil
    // True only for the title screen's "New Hero" flow, which really does wipe
    // the save. Mid-run hero swaps (Change Hero) keep every soul shard,
    // prestige upgrade, and deepest-floor record, so they get a reassuring
    // message instead of the data-loss warning.
    var isDestructiveReset: Bool = true

    init(onCancel: (() -> Void)? = nil,
         onSelect: @escaping (CharacterClass) -> Void,
         dynastyContext: DynastySelectContext? = nil,
         isDestructiveReset: Bool = true) {
        self.onCancel = onCancel
        self.onSelect = onSelect
        self.dynastyContext = dynastyContext
        self.isDestructiveReset = isDestructiveReset
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            // Atmosphere: the entrance art, dimmed way down behind the grid.
            Theme.Palette.abyss.ignoresSafeArea()
            // Wrapped in an overlay on a Color so the fill-scaled image can't
            // widen the ZStack (a scaledToFill image sizes its parent otherwise).
            Color.clear
                .overlay(
                    Image("bg_entrance")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFill()
                )
                .clipped()
                .ignoresSafeArea()
                .opacity(0.25)
            LinearGradient(colors: [Theme.Palette.abyss.opacity(0.3), Theme.Palette.abyss],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(dynastyContext != nil ? "CHOOSE NEW CHAMPION" : "CHOOSE YOUR HERO")
                    .font(Theme.Fonts.display(26))
                    .foregroundStyle(Theme.Palette.parchment)
                    .gameShadow(3)
                    .padding(.top, 52)
                    .padding(.bottom, 12)

                if let ctx = dynastyContext {
                    if let bonus = ctx.pendingLegacyBonus {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
                            Text("Retiring \(ctx.retiringCharacterName): \(bonus.description)")
                                .font(Theme.Fonts.label(12))
                        }
                        .foregroundStyle(Color(red: 1.00, green: 0.80, blue: 0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    } else {
                        Text("\(ctx.retiringCharacterName)'s legacy already claimed.")
                            .font(Theme.Fonts.label(12))
                            .foregroundStyle(Color.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                } else if onCancel != nil && isDestructiveReset {
                    Text("Warning: starting a new hero resets all progress.")
                        .font(Theme.Fonts.label(12))
                        .foregroundStyle(Color(red: 1.00, green: 0.45, blue: 0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                } else if onCancel != nil {
                    Text("Your soul shards and prestige upgrades carry over.")
                        .font(Theme.Fonts.label(12))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                } else {
                    Spacer().frame(height: 8)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CharacterClass.all) { character in
                            CharacterCardView(
                                character: character,
                                legacyBonusLabel: dynastyContext != nil ? character.legacyBonus.description : nil
                            ) {
                                onSelect(character)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }

            if let onCancel {
                VStack {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.60))
                                .padding(16)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CharacterCardView: View {
    let character: CharacterClass
    let onTap: () -> Void
    var legacyBonusLabel: String? = nil

    @State private var previewScene: IdlePreviewScene

    init(character: CharacterClass, legacyBonusLabel: String? = nil, onTap: @escaping () -> Void) {
        self.character = character
        self.legacyBonusLabel = legacyBonusLabel
        self.onTap = onTap
        _previewScene = State(initialValue: IdlePreviewScene(idleSpec: character.idle))
    }

    private var roleColor: Color {
        switch character.role {
        case "Tank", "Paladin": return Color(red: 0.35, green: 0.60, blue: 1.00)
        case "Warrior", "Duelist", "Skirmisher": return Color(red: 1.00, green: 0.45, blue: 0.25)
        case "Ranger": return Color(red: 0.30, green: 0.85, blue: 0.45)
        case "Mage": return Color(red: 0.80, green: 0.40, blue: 1.00)
        case "Healer": return Color(red: 0.95, green: 0.82, blue: 0.30)
        default: return .white
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // The hero on a glowing pedestal in its role color.
                ZStack {
                    RadialGradient(colors: [roleColor.opacity(0.35), .clear],
                                   center: .center, startRadius: 4, endRadius: 80)
                    Ellipse()
                        .fill(Color.black.opacity(0.45))
                        .frame(width: 90, height: 14)
                        .offset(y: 26)
                    SpriteView(scene: previewScene, options: [.allowsTransparency])
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipped()

                HStack(alignment: .firstTextBaseline) {
                    Text(character.name)
                        .font(Theme.Fonts.label(15))
                        .foregroundStyle(Theme.Palette.parchment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer()
                    Text(character.role)
                        .font(Theme.Fonts.label(10))
                        .foregroundStyle(roleColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(roleColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                // Fixed to three lines so every card in the grid is the same height.
                Text(character.description)
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .lineLimit(3, reservesSpace: true)

                Divider().background(Color.white.opacity(0.10))

                HStack(spacing: 0) {
                    statPill("HP", "\(character.baseHP)", Theme.Palette.life)
                    statPill("ATK", "\(character.baseATK)", Theme.Palette.flame)
                    statPill("DEF", "\(character.baseDEF)", Theme.Palette.frost)
                    if character.baseRegen > 0 {
                        statPill("RGN", "\(character.baseRegen)", Color(red: 0.95, green: 0.82, blue: 0.30))
                    }
                }

                if let bonus = legacyBonusLabel {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9))
                        Text(bonus)
                            .font(Theme.Fonts.label(10))
                    }
                    .foregroundStyle(Color(red: 1.00, green: 0.75, blue: 0.15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .gamePanel(tint: roleColor.opacity(0.55), cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private func statPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(Theme.Fonts.label(8))
                .foregroundStyle(Color.white.opacity(0.50))
            Text(value)
                .font(Theme.Fonts.label(12))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}
