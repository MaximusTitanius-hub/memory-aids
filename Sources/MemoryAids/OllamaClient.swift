import Foundation

/// Talks to Ollama (ollama.com), a free app that runs open AI models on this Mac.
/// Bigger models give better aids; a Mac with lots of memory (e.g. M4 Pro) can run big ones.
struct OllamaClient {
    static let baseURL = URL(string: "http://127.0.0.1:11434")!

    struct ModelChoice: Identifiable, Hashable {
        let id: String
        let label: String
        let note: String
    }

    /// Suggested models, smallest first.
    static let suggestions: [ModelChoice] = [
        ModelChoice(id: "gemma3:4b", label: "Gemma 3 4B", note: "About 3 GB. Fine for 8 GB Macs."),
        ModelChoice(id: "gemma3:12b", label: "Gemma 3 12B", note: "About 8 GB. Good for 16 GB+ Macs."),
        ModelChoice(id: "qwen3:14b", label: "Qwen 3 14B", note: "About 9 GB. Good for 24 GB+ Macs like the M4 Pro."),
        ModelChoice(id: "gemma3:27b", label: "Gemma 3 27B", note: "About 17 GB. Best results; needs 32 GB+ memory."),
    ]

    /// A sensible default based on how much memory this Mac has.
    static var recommendedModel: String {
        let gb = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        if gb >= 32 { return "gemma3:27b" }
        if gb >= 24 { return "qwen3:14b" }
        if gb >= 16 { return "gemma3:12b" }
        return "gemma3:4b"
    }

    static var memoryGB: Int { Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded()) }

    let model: String

    struct Status { var running: Bool; var hasModel: Bool }

    static func status(model: String) async -> Status {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
        request.timeoutInterval = 4
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return Status(running: false, hasModel: false)
        }
        let names = (obj["models"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
        let has = names.contains { $0 == model || $0 == model + ":latest" }
        return Status(running: true, hasModel: has)
    }

    /// Downloads a model, reporting progress (0...1, or nil when unknown) and a status line.
    static func pull(model: String, progress: @escaping @Sendable (Double?, String) -> Void) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/pull"))
        request.httpMethod = "POST"
        request.timeoutInterval = 3600
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model, "stream": true])
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw OllamaError.message("Ollama couldn't download \(model).")
        }
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let err = obj["error"] as? String { throw OllamaError.message(err) }
            let status = obj["status"] as? String ?? ""
            if let total = obj["total"] as? Double, total > 0, let done = obj["completed"] as? Double {
                progress(done / total, status)
            } else {
                progress(nil, status)
            }
        }
    }

    /// One structured request: the answer must match `schema`.
    func json(system: String, prompt: String, schema: [String: Any]) async throws -> Data {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 900
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "format": schema,
            "options": ["num_ctx": 16384, "temperature": 0.7],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": prompt],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OllamaError.message("No answer from Ollama.") }
        guard http.statusCode == 200 else {
            throw OllamaError.message("Ollama error (\(http.statusCode)): \(String(data: data, encoding: .utf8)?.prefix(200) ?? "")")
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = obj["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OllamaError.message("Couldn't read Ollama's answer.")
        }
        return Data(content.utf8)
    }
}

enum OllamaError: LocalizedError {
    case notRunning, missingModel(String), message(String)
    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Ollama isn't running. Install it from ollama.com (or open it from Applications), then try again. Settings has step-by-step help."
        case .missingModel(let m):
            return "The AI model \"\(m)\" isn't downloaded yet. Open Settings and click Download."
        case .message(let m):
            return m
        }
    }
}
