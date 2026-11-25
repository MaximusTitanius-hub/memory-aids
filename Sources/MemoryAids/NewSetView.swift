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
                hero

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

    private var hero: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's make it stick ✨").font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("Drop in your notes and turn them into mind maps, memory palaces, superhero cards and more.")
                    .font(.rounded(.title3, weight: .medium))
                    .opacity(0.9)
            }
            Spacer()
            ZStack {
                Circle().fill(.white.opacity(0.15)).frame(width: 110, height: 110)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 54, weight: .semibold))
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .offset(x: 40, y: -38)
            }
        }
        .foregroundStyle(.white)
        .padding(26)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.brand))
        .shadow(color: Theme.brandColor.opacity(0.3), radius: 12, y: 6)
    }

    private func stepTitle(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.brand))
            Text(text).font(.rounded(.title2, weight: .bold))
        }
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                stepTitle(1, "Your material")
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
                stepTitle(2, "Pick your techniques")
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
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .foregroundStyle(on ? t.tint : Color.white)
                                .background(Circle().fill(on ? Color.white : t.tint))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name).font(.rounded(.headline))
                                Text(t.summary).font(.caption)
                                    .foregroundStyle(on ? Color.white.opacity(0.85) : Color.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? Color.white : Color.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(on ? AnyShapeStyle(LinearGradient(colors: [t.tint, t.tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                     : AnyShapeStyle(Color(nsColor: .controlBackgroundColor))))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? Color.clear : Color.primary.opacity(0.08)))
                        .scaleEffect(on ? 1.0 : 0.98)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: on)
                        .foregroundStyle(on ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var generateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle(3, "Create")
            HStack(spacing: 14) {
                Button {
                    Task { await generate() }
                } label: {
                    Label("Create memory aids", systemImage: "wand.and.stars")
                        .font(.rounded(.title3, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.brand))
                        .shadow(color: Theme.brandColor.opacity(0.35), radius: 8, y: 4)
                        .opacity(canGenerate ? 1 : 0.45)
                }
                .buttonStyle(.plain)
                .disabled(!canGenerate)

                Text("Using: " + Generator.resolve(engine).shortName)
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
