import SwiftUI

private let privacyPolicyURL = URL(string: "https://github.com/oomaguma/oneMoreFloor-ios/blob/main/PRIVACY_POLICY.md")!

private let bgColor   = Color(red: 0.07, green: 0.07, blue: 0.11)
private let rowColor  = Color(white: 0.10)
private let navColor  = Color(red: 0.09, green: 0.09, blue: 0.14)

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
                    .listRowBackground(rowColor)
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Vibration", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .listRowBackground(rowColor)
                }

                Section("Legal") {
                    Link(destination: privacyPolicyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    .listRowBackground(rowColor)
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
                    .listRowBackground(rowColor)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sound Effects")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("by Chequered Ink")
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(rowColor)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Advertising")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("This app uses Google AdMob for advertising and Google UMP for consent management. Ads respect your ATT preference.")
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(rowColor)
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
                    .listRowBackground(rowColor)
                }
            }
            .scrollContentBackground(.hidden)
            .background(bgColor.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(navColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }
}
