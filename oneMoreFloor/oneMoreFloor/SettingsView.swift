import SwiftUI

// Replace this URL once your privacy policy page is live.
private let privacyPolicyURL = URL(string: "https://github.com/oomaguma/oneMoreFloor-ios/blob/main/PRIVACY_POLICY.md")!

struct SettingsView: View {
    @AppStorage("com.oneMoreFloor.soundEnabled")   private var soundEnabled   = true
    @AppStorage("com.oneMoreFloor.hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        NavigationStack {
            List {
                Section("Preferences") {
                    Toggle(isOn: $soundEnabled) {
                        Label("Sound Effects", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }

                Section("Legal") {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                }

                Section("Acknowledgments") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Character & Enemy Art")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("by Zerie")
                            .font(.caption)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sound Effects")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("by Chequered Ink")
                            .font(.caption)
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Advertising")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("This app uses Google AdMob for advertising and Google UMP for consent management. Ads respect your ATT preference.")
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Text("One More Floor")
                                .font(.caption.weight(.semibold))
                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
