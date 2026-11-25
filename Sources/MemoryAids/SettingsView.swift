import SwiftUI

struct SettingsView: View {
    @AppStorage("engine") private var engineRaw = Engine.auto.rawValue
    @AppStorage("ollamaModel") private var ollamaModel = OllamaClient.recommendedModel
    @State private var key = Keychain.loadKey() ?? ""
    @State private var saved = false
    @State private var ollamaState: OllamaClient.Status?
    @State private var pulling = false
    @State private var pullProgress: Double?
    @State private var pullStatus = ""
    @State private var customModel = ""

    var body: some View {
        TabView {
            engineTab.tabItem { Label("AI", systemImage: "sparkles") }
            ollamaTab.tabItem { Label("Ollama", systemImage: "cpu") }
            claudeTab.tabItem { Label("Claude", systemImage: "key.fill") }
        }
        .frame(width: 600, height: 520)
        .task { await refreshOllama() }
    }

    // MARK: Which AI

    private var engineTab: some View {
        Form {
            Section("Which AI creates your memory aids") {
                ForEach(Engine.allCases) { engine in
                    Button {
                        engineRaw = engine.rawValue
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: engineRaw == engine.rawValue ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(engineRaw == engine.rawValue ? Theme.brandColor : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(engine.label).font(.rounded(.headline))
                                Text(engine.detail).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                Text("Right now this Mac will use: **\(Generator.resolve(Engine(rawValue: engineRaw) ?? .auto).shortName)**")
                if !Generator.appleAvailable {
                    Text("Apple's built-in AI isn't available on this Mac (it needs Apple Intelligence turned on in System Settings).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: Ollama

    private var ollamaTab: some View {
        Form {
            Section("Status") {
                HStack {
                    if let s = ollamaState {
                        if !s.running {
                            Label("Ollama isn't running or isn't installed yet", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                        } else if s.hasModel {
                            Label("Ready. \(ollamaModel) is downloaded", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Label("Ollama is running. Now download the model below", systemImage: "arrow.down.circle.fill").foregroundStyle(.orange)
                        }
                    } else {
                        ProgressView().controlSize(.small)
                        Text("Checking…")
                    }
                    Spacer()
                    Button("Check again") { Task { await refreshOllama() } }
                }
            }
            Section("Set up (one time)") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Download and install Ollama from ollama.com, then open it once.")
                    Text("2. Pick a model below and click Download.")
                    Text("3. Choose Ollama on the AI tab (or leave it on Automatic).")
                }
                Link("Open ollama.com/download", destination: URL(string: "https://ollama.com/download/mac")!)
            }
            Section("Model (bigger = better aids, but slower and needs more memory)") {
                Text("This Mac has \(OllamaClient.memoryGB) GB of memory. Suggested: **\(OllamaClient.recommendedModel)**")
                    .font(.callout)
                Picker("Model", selection: $ollamaModel) {
                    ForEach(OllamaClient.suggestions) { m in
                        Text("\(m.label): \(m.note)").tag(m.id)
                    }
                    if !OllamaClient.suggestions.contains(where: { $0.id == ollamaModel }) {
                        Text(ollamaModel).tag(ollamaModel)
                    }
                }
                .onChange(of: ollamaModel) { _ in Task { await refreshOllama() } }
                HStack {
                    TextField("Or type any Ollama model name", text: $customModel)
                    Button("Use") {
                        let m = customModel.trimmingCharacters(in: .whitespaces)
                        if !m.isEmpty { ollamaModel = m; customModel = "" }
                    }
                }
                HStack {
                    Button {
                        Task { await pull() }
                    } label: { Label("Download \(ollamaModel)", systemImage: "arrow.down.circle") }
                        .disabled(pulling || ollamaState?.running != true)
                    if pulling, let p = pullProgress {
                        ProgressView(value: p).frame(width: 140)
                    }
                    Text(pullStatus).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func refreshOllama() async {
        ollamaState = nil
        ollamaState = await OllamaClient.status(model: ollamaModel)
    }

    private func pull() async {
        pulling = true
        pullStatus = "Starting download…"
        defer { pulling = false }
        do {
            try await OllamaClient.pull(model: ollamaModel) { p, s in
                Task { @MainActor in
                    pullProgress = p
                    pullStatus = p.map { "\(s) \(Int($0 * 100))%" } ?? s
                }
            }
            pullStatus = "Downloaded. You're ready to go! 🎉"
        } catch {
            pullStatus = error.localizedDescription
        }
        await refreshOllama()
    }

    // MARK: Claude

    private var claudeTab: some View {
        Form {
            Section("Claude API key (optional)") {
                SecureField("sk-ant-…", text: $key)
                HStack {
                    Button("Save key") { Keychain.saveKey(key); saved = true }
                    Button("Remove key") { key = ""; Keychain.saveKey(""); saved = true }
                    if saved { Text("Saved").foregroundStyle(.green) }
                }
                Text("Claude gives the richest aids, draws a picture for each one and can read scanned PDFs. Get a key at console.anthropic.com (pay as you go, usually a few pence per study set). It's stored in your Mac's Keychain.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Link("Open console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
            }
        }
        .formStyle(.grouped)
        .onChange(of: key) { _ in saved = false }
    }
}
