import SwiftUI

struct SettingsView: View {
    @AppStorage("engine") private var engineRaw = Engine.auto.rawValue
    @State private var key = Keychain.loadKey() ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("Which AI creates your memory aids") {
                Picker("Engine", selection: $engineRaw) {
                    ForEach(Engine.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.radioGroup)
                Text("Automatic uses Claude if you've added a key below, otherwise Apple's free on-device AI (needs an Apple chip Mac on macOS 26 with Apple Intelligence turned on).")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Claude API key (optional)") {
                SecureField("sk-ant-…", text: $key)
                HStack {
                    Button("Save key") {
                        Keychain.saveKey(key)
                        saved = true
                    }
                    Button("Remove key") {
                        key = ""
                        Keychain.saveKey("")
                        saved = true
                    }
                    if saved { Text("Saved").foregroundStyle(.green) }
                }
                Text("Claude gives richer aids, draws a picture for each one and can read scanned PDFs. Get a key at console.anthropic.com (pay-as-you-go, usually a few pence per study set). It's stored in your Mac's Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Open console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 460)
        .onChange(of: key) { _ in saved = false }
    }
}
