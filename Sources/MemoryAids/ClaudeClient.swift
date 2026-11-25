import Foundation

enum ClaudeError: LocalizedError {
    case missingKey
    case http(Int, String)
    case api(String)
    case refused
    case truncated
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add your Claude API key in Settings (Memory Aids menu > Settings) first."
        case .http(let code, let message):
            if code == 401 { return "Claude rejected the API key. Check it in Settings. (\(message))" }
            if code == 429 { return "Too many requests right now. Wait a minute and try again. (\(message))" }
            return "Claude returned an error (\(code)): \(message)"
        case .api(let message):
            return "Claude stopped with an error: \(message)"
        case .refused:
            return "Claude declined to process this material."
        case .truncated:
            return "The answer was too long and got cut off. Try fewer techniques at once or shorter material."
        case .badResponse(let detail):
            return "Couldn't read Claude's answer: \(detail)"
        }
    }
}

/// Minimal Claude Messages API client using URLSession and server-sent events.
/// (There is no official Swift SDK, so this talks to the REST API directly.)
struct ClaudeClient {
    let apiKey: String
    var model = "claude-opus-5-5"

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// Sends one request whose answer must match `schema` (structured outputs),
    /// streams it, and returns the JSON text.
    func structuredRequest(system: String,
                           content: [[String: Any]],
                           schema: [String: Any],
                           maxTokens: Int = 32000,
                           onProgress: @escaping @Sendable (Int) -> Void = { _ in }) async throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": system,
            "messages": [["role": "user", "content": content]],
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": schema],
            ],
            // If a safety check declines, the API retries on a fallback model automatically.
            "fallbacks": "default",
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 900
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.badResponse("no HTTP response")
        }
        if http.statusCode != 200 {
            var data = Data()
            for try await byte in bytes { data.append(byte) }
            throw ClaudeError.http(http.statusCode, Self.errorMessage(from: data))
        }

        var text = ""
        var stopReason: String?
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }
            switch type {
            case "message_start":
                text = "" // a fallback model starts a fresh message
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let piece = delta["text"] as? String {
                    text += piece
                    onProgress(text.count)
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any],
                   let reason = delta["stop_reason"] as? String {
                    stopReason = reason
                }
            case "error":
                let message = (event["error"] as? [String: Any])?["message"] as? String ?? "unknown error"
                throw ClaudeError.api(message)
            default:
                break
            }
        }

        switch stopReason {
        case "refusal": throw ClaudeError.refused
        case "max_tokens": throw ClaudeError.truncated
        default: break
        }
        guard !text.isEmpty else { throw ClaudeError.badResponse("empty answer") }
        return Data(text.utf8)
    }

    private static func errorMessage(from data: Data) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? [String: Any],
           let message = err["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "unknown"
    }
}
