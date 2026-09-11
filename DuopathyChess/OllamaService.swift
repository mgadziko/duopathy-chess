import Foundation

struct OllamaModel: Identifiable, Decodable, Hashable {
    let name: String
    var id: String { name }
}

final class OllamaService {
    let baseURL: URL
    init(baseURL: URL) { self.baseURL = baseURL }

    func listModels() async throws -> [OllamaModel] {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent("api/tags"))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        struct Response: Decodable { let models: [OllamaModel] }
        return try JSONDecoder().decode(Response.self, from: data).models.sorted { $0.name < $1.name }
    }

    func chatStream(model: String, prompt: String, onDelta: @escaping @Sendable (String) async -> Void) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        struct Body: Encodable { let model: String; let messages: [[String: String]]; let stream: Bool; let options: [String: Double] }
        request.httpBody = try JSONEncoder().encode(Body(model: model, messages: [["role": "user", "content": prompt]], stream: true, options: ["temperature": 0.25]))
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        struct Chunk: Decodable { struct Message: Decodable { let content: String? }; let message: Message?; let done: Bool?; let error: String? }
        for try await line in bytes.lines {
            if Task.isCancelled { throw CancellationError() }
            guard let chunk = try? JSONDecoder().decode(Chunk.self, from: Data(line.utf8)) else { continue }
            if let error = chunk.error { throw NSError(domain: "Ollama", code: 1, userInfo: [NSLocalizedDescriptionKey: error]) }
            if let text = chunk.message?.content { await onDelta(text) }
            if chunk.done == true { return }
        }
    }
}
