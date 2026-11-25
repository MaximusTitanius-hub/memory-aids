import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct NewSetView: View {
    @EnvironmentObject var store: Store
    @StateObject private var generator = Generator()
    @AppStorage("engine") private var engineRaw = Engine.auto.rawValue

    var onCreated: (UUID) -> Void

    init(onCreated: @escaping (UUID) -> Void) { self.onCreated = onCreated }

    @State private var material = ""
    @State private var pdfData: Data?
    @State private var pdfName: String?
    @State private var chosen: Set<Int> = Techniques.starterPack
    @State private var showImporter = false
    @State private var errorText: String?
    @State private var isDropTarget = false

    private var engine: Engine { Engine(rawValue: engineRaw) ?? .auto }
    private var canGenerate: Bool {
        !chosen.isEmpty && !generator.isRunning &&
        (!material.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || pdfData != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you need to remember?").font(.largeTitle.bold())
                    Text("Paste or type your notes, or drop in a PDF. Then pick the memory techniques you want.")
                        .foregroundStyle(.secondary)
                }

                materialSection
                techniquesSection
                generateSection
            }
            .padding(28)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .plainText]) { result in
            if case .success(let url) = result { importFile(url) }
        }
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("1. Your material").font(.title2.bold())
                Spacer()
                if let pdfName {
                    Label(pdfName, systemImage: "doc.richtext").foregroundStyle(.secondary)
                }
                Button { showImporter = true } label: {
                    Label("Import PDF…", systemImage: "square.and.arrow.down")
                }
                if !material.isEmpty || pdfData != nil {
                    Button("Clear") { material = ""; pdfData = nil; pdfName = nil }
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $material)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                if material.isEmpty {
                    Text(pdfData != nil
                         ? "This PDF has no selectable text (it may be a scan). Claude can still read it if you add an API key in Settings."
                         : "Paste notes here, or drag a PDF onto this box…")
                        .foregroundStyle(.tertiary)
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 220)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isDropTarget ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isDropTarget ? 3 : 1))
            .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { importFile(url) } }
                }
                return true
            }
            if !material.isEmpty {
                Text("\(material.split { $0.isWhitespace }.count) words")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var techniquesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("2. Memory techniques").font(.title2.bold())
                Text("\(chosen.count) chosen").foregroundStyle(.secondary)
                Spacer()
                Button("Starter pack") { chosen = Techniques.starterPack }
                Button("All 20") { chosen = Set(Techniques.all.map(\.id)) }
                Button("None") { chosen = [] }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
                ForEach(Techniques.all) { t in
                    let on = chosen.contains(t.id)
                    Button {
                        if on { chosen.remove(t.id) } else { chosen.insert(t.id) }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: t.symbol)
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(on ? Color.white : Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(t.id). \(t.name)").font(.headline)
                                Text(t.summary).font(.caption)
                                    .foregroundStyle(on ? Color.white.opacity(0.85) : Color.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Color.white : Color.secondary)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(on ? Color.accentColor : Color.secondary.opacity(0.08)))
                        .foregroundStyle(on ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3. Create").font(.title2.bold())
            HStack(spacing: 14) {
                Button {
                    Task { await generate() }
                } label: {
                    Label("Create memory aids", systemImage: "wand.and.stars")
                        .font(.headline)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canGenerate)

                Text("Using: " + (Generator.resolve(engine) == .claude ? "Claude" : "Apple on-device AI"))
                    .font(.callout).foregroundStyle(.secondary)
                SettingsLink { Text("Change…") }
            }
            if generator.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: generator.progress)
                    Text(generator.status).font(.callout).foregroundStyle(.secondary)
                    Text("This can take a minute or two.").font(.caption).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: 500)
            }
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }
        }
    }

    private func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        errorText = nil
        if url.pathExtension.lowercased() == "pdf" {
            guard let data = try? Data(contentsOf: url), let doc = PDFDocument(data: data) else {
                errorText = "Couldn't open that PDF."
                return
            }
            pdfData = data
            pdfName = url.lastPathComponent
            material = (doc.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let text = try? String(contentsOf: url, encoding: .utf8) {
            pdfData = nil
            pdfName = url.lastPathComponent
            material = text
        } else {
            errorText = "That file type isn't supported. Use a PDF or a text file."
        }
    }

    private func generate() async {
        errorText = nil
        do {
            let set = try await generator.run(material: material, pdfData: pdfData,
                                              techniqueIds: Array(chosen), engine: engine)
            store.add(set)
            if !generator.warnings.isEmpty {
                errorText = "Some parts didn't work: " + generator.warnings.joined(separator: " · ")
            }
            material = ""; pdfData = nil; pdfName = nil
            onCreated(set.id)
        } catch {
            errorText = error.localizedDescription
        }
    }
}
