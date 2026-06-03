import SwiftUI

private let privacyPolicyURL = URL(string: "https://github.com/oomaguma/oneMoreFloor-ios/blob/main/PRIVACY_POLICY.md")!

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("com.oneMoreFloor.soundEnabled")         private var soundEnabled         = true
    @AppStorage("com.oneMoreFloor.hapticsEnabled")       private var hapticsEnabled       = true
    @AppStorage("com.oneMoreFloor.notificationsEnabled") private var notificationsEnabled = true

    private let bgColor   = Color(red: 0.07, green: 0.07, blue: 0.11)
    private let cardColor = Color(red: 0.10, green: 0.10, blue: 0.16)
    private let gold      = Color(red: 0.90, green: 0.70, blue: 0.28)

    @State private var gcManager = GameCenterManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // MARK: Preferences
                    sectionHeader("PREFERENCES")

                    VStack(spacing: 0) {
                        toggleRow(
                            icon: "speaker.wave.2.fill",
                            iconColor: Color(red: 0.45, green: 0.72, blue: 1.00),
                            title: "Sound Effects",
                            isOn: $soundEnabled
                        )
                        rowDivider()
                        toggleRow(
                            icon: "iphone.radiowaves.left.and.right",
                            iconColor: Color(red: 0.65, green: 0.45, blue: 1.00),
                            title: "Vibration",
                            isOn: $hapticsEnabled
                        )
                        rowDivider()
                        toggleRow(
                            icon: "bell.fill",
                            iconColor: Color(red: 1.00, green: 0.65, blue: 0.20),
                            title: "Notifications",
                            isOn: $notificationsEnabled
                        )
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardColor))

                    // MARK: Game Center
                    sectionHeader("GAME CENTER")

                    Button { gcManager.showDashboard() } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(red: 0.45, green: 0.72, blue: 1.00))
                                .frame(width: 26)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Leaderboards & Achievements")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundStyle(gcManager.isAuthenticated ? .white : Color.white.opacity(0.35))
                                if !gcManager.isAuthenticated {
                                    Text("Sign in to Game Center to enable")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.30))
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(cardColor))
                    }
                    .buttonStyle(.plain)
                    .disabled(!gcManager.isAuthenticated)

                    // MARK: Legal
                    sectionHeader("LEGAL")

                    linkRow(
                        icon: "hand.raised.fill",
                        iconColor: Color(red: 0.30, green: 0.85, blue: 0.45),
                        title: "Privacy Policy",
                        url: privacyPolicyURL
                    )

                    // MARK: Credits
                    sectionHeader("CREDITS")

                    VStack(spacing: 0) {
                        creditRow(label: "Character & Enemy Art", value: "Zerie")
                        rowDivider()
                        creditRow(label: "Sound Effects", value: "Chequered Ink")
                        rowDivider()
                        adCreditRow()
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(cardColor))

                    // MARK: Version footer
                    HStack {
                        Spacer()
                        VStack(spacing: 3) {
                            Text("One More Floor")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.30))
                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.20))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .scrollContentBackground(.hidden)
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.09, green: 0.09, blue: 0.14), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Reusable components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(gold.opacity(0.80))
            .padding(.bottom, -8)
    }

    private func rowDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 56)
    }

    private func toggleRow(icon: String, iconColor: Color, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(iconColor)
                .frame(width: 26)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(gold)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func linkRow(icon: String, iconColor: Color, title: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(iconColor)
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardColor))
        }
    }

    private func creditRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.50))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func adCreditRow() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Advertising")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.50))
            Text("Google AdMob + UMP. Ads respect your ATT preference.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.30))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
