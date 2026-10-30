import SwiftUI

private let privacyPolicyURL = URL(string: "https://github.com/oomaguma/oneMoreFloor-ios/blob/main/PRIVACY_POLICY.md")!

// MARK: - Settings View

/// Preferences, Game Center, legal, and credits. Styled like the rest of the
/// game (display-font title, `.gamePanel` cards, palette colors) instead of a
/// stock iOS settings list, so opening it doesn't feel like leaving the game.
struct SettingsView: View {
    @AppStorage("com.oneMoreFloor.soundEnabled")         private var soundEnabled         = true
    @AppStorage("com.oneMoreFloor.hapticsEnabled")       private var hapticsEnabled       = true
    @AppStorage("com.oneMoreFloor.notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("com.oneMoreFloor.autoEquipEnabled")     private var autoEquipEnabled     = true

    @State private var gcManager = GameCenterManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Title, matching the Codex and the other sheets.
                Text("SETTINGS")
                    .font(Theme.Fonts.display(26))
                    .foregroundStyle(Theme.Palette.parchment)
                    .gameShadow(3)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                // MARK: Preferences
                sectionHeader("PREFERENCES")
                VStack(spacing: 0) {
                    toggleRow(icon: "speaker.wave.2.fill", iconColor: Theme.Palette.frost,
                              title: "Sound Effects", isOn: $soundEnabled)
                    rowDivider()
                    toggleRow(icon: "iphone.radiowaves.left.and.right", iconColor: Theme.Palette.shard,
                              title: "Vibration", isOn: $hapticsEnabled)
                    rowDivider()
                    toggleRow(icon: "bell.fill", iconColor: Theme.Palette.flame,
                              title: "Notifications", isOn: $notificationsEnabled)
                    rowDivider()
                    toggleRow(icon: "shield.lefthalf.filled", iconColor: Theme.Palette.life,
                              title: "Auto-Equip Better Gear", isOn: $autoEquipEnabled)
                }
                .gamePanel(cornerRadius: 14)

                // MARK: Game Center
                sectionHeader("GAME CENTER")
                Button { gcManager.showDashboard() } label: {
                    HStack(spacing: 14) {
                        rowIcon("gamecontroller.fill", color: Theme.Palette.frost)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Leaderboards & Achievements")
                                .font(Theme.Fonts.label(14))
                                .foregroundStyle(gcManager.isAuthenticated ? Theme.Palette.parchment : Theme.Palette.ash)
                            if !gcManager.isAuthenticated {
                                Text("Sign in to Game Center to enable")
                                    .font(Theme.Fonts.body(11))
                                    .foregroundStyle(Theme.Palette.ash)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.Palette.ash)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .gamePanel(cornerRadius: 14)
                }
                .buttonStyle(.plain)
                .disabled(!gcManager.isAuthenticated)

                // MARK: Legal
                sectionHeader("LEGAL")
                linkRow(icon: "hand.raised.fill", iconColor: Theme.Palette.life,
                        title: "Privacy Policy", url: privacyPolicyURL)

                // MARK: Credits
                sectionHeader("CREDITS")
                VStack(spacing: 0) {
                    creditRow(label: "Character & Enemy Art", value: "Zerie")
                    rowDivider()
                    creditRow(label: "Sound Effects", value: "Chequered Ink")
                    rowDivider()
                    creditRow(label: "Combat Sounds", value: "Helton Yan")
                    rowDivider()
                    // CC0, so credit isn't required, but it's good manners.
                    creditRow(label: "Interface Sounds", value: "ObsydianX")
                    rowDivider()
                    // SIL Open Font License; the license text ships in the bundle
                    // (Theme/Fonts/PixelifySans-OFL.txt).
                    creditRow(label: "Pixel Font", value: "Pixelify Sans (OFL)")
                    rowDivider()
                    adCreditRow()
                }
                .gamePanel(cornerRadius: 14)

                // MARK: Version footer
                VStack(spacing: 3) {
                    Text("ONE MORE FLOOR")
                        .font(Theme.Fonts.display(13))
                        .tracking(2)
                        .foregroundStyle(Theme.Palette.flame.opacity(0.7))
                    Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                        .font(Theme.Fonts.body(11))
                        .foregroundStyle(Theme.Palette.ash)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.Palette.abyss.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Reusable components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Fonts.label(12))
            .tracking(2)
            .foregroundStyle(Theme.Palette.dust)
            .padding(.bottom, -10)
    }

    /// The colored icon at the start of each row, in a small tinted tile.
    private func rowIcon(_ name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(Theme.Palette.stoneEdge.opacity(0.4))
            .frame(height: 1)
            .padding(.leading, 60)
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            rowIcon(icon, color: iconColor)
            Text(title)
                .font(Theme.Fonts.label(14))
                .foregroundStyle(Theme.Palette.parchment)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(Theme.Palette.gold)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func linkRow(icon: String, iconColor: Color, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                rowIcon(icon, color: iconColor)
                Text(title)
                    .font(Theme.Fonts.label(14))
                    .foregroundStyle(Theme.Palette.parchment)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Palette.ash)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .gamePanel(cornerRadius: 14)
        }
    }

    private func creditRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(Theme.Fonts.label(13))
                .foregroundStyle(Theme.Palette.dust)
            Spacer()
            Text(value)
                .font(Theme.Fonts.label(13))
                .foregroundStyle(Theme.Palette.parchment)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func adCreditRow() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Advertising")
                .font(Theme.Fonts.label(13))
                .foregroundStyle(Theme.Palette.dust)
            Text("Google AdMob + UMP. Ads respect your ATT preference.")
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Palette.ash)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
