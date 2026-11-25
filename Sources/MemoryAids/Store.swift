import Foundation
import Security

/// Keeps every study set on disk in ~/Library/Application Support/MemoryAids/sets.json.
@MainActor
final class Store: ObservableObject {
    @Published var sets: [StudySet] = []

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MemoryAids", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sets.json")
    }()

    init() { load() }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sets = (try? decoder.decode([StudySet].self, from: data)) ?? []
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sets) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func add(_ set: StudySet) {
        sets.insert(set, at: 0)
        save()
    }

    func delete(_ id: UUID) {
        sets.removeAll { $0.id == id }
        save()
    }

    func binding(for id: UUID) -> StudySet? { sets.first { $0.id == id } }

    func review(setId: UUID, cardId: UUID, grade: Flashcard.Grade) {
        guard let s = sets.firstIndex(where: { $0.id == setId }),
              let c = sets[s].cards.firstIndex(where: { $0.id == cardId }) else { return }
        sets[s].cards[c].review(grade)
        save()
    }

    var totalDue: Int { sets.reduce(0) { $0 + $1.dueCount } }
}

/// Stores the Claude API key in the macOS Keychain.
enum Keychain {
    private static let service = "app.memoryaids.MemoryAids"
    private static let account = "anthropic-api-key"

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func saveKey(_ value: String) {
        SecItemDelete(baseQuery as CFDictionary)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var add = baseQuery
        add[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }

    static func loadKey() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
