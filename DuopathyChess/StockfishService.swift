import Foundation

struct StockfishLine: Identifiable, Equatable {
    let move: String
    let score: String
    let variation: [String]
    var id: String { move }
}

enum StockfishError: LocalizedError {
    case unavailable(String)
    case noAnalysis
    var errorDescription: String? { switch self { case .unavailable(let path): "Stockfish was not found at \(path)."; case .noAnalysis: "Stockfish returned no principal variation." } }
}

final class StockfishService {
    let executablePath: String
    init(executablePath: String = "/opt/homebrew/bin/stockfish") { self.executablePath = executablePath }

    func analyze(fen: String, timeLimitMilliseconds: Int = 1_500, onUpdate: @escaping @Sendable ([StockfishLine]) async -> Void) async throws -> [StockfishLine] {
        try await Task.detached(priority: .userInitiated) { [executablePath] in
            guard FileManager.default.isExecutableFile(atPath: executablePath) else { throw StockfishError.unavailable(executablePath) }
            let process = Process(), input = Pipe(), output = Pipe()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.standardInput = input; process.standardOutput = output; process.standardError = output
            try process.run()
            defer { if process.isRunning { process.terminate() } }
            let commands = "uci\nsetoption name MultiPV value 3\nisready\nposition fen \(fen)\ngo movetime \(timeLimitMilliseconds)\n"
            input.fileHandleForWriting.write(Data(commands.utf8))
            var lines: [Int: StockfishLine] = [:]
            let handle = output.fileHandleForReading
            var buffer = Data()
            while true {
                let data = handle.availableData
                if data.isEmpty { break }
                buffer.append(data)
                while let newline = buffer.firstIndex(of: 10) {
                    let line = String(decoding: buffer[..<newline], as: UTF8.self)
                    buffer.removeSubrange(...newline)
                    if line == "bestmove" || line.hasPrefix("bestmove ") { process.terminate(); return lines.keys.sorted().compactMap { lines[$0] } }
                    guard line.hasPrefix("info "), line.contains(" pv "), let pvRange = line.range(of: " pv ") else { continue }
                    let parts = line.split(separator: " ").map(String.init)
                    guard let multiIndex = parts.firstIndex(of: "multipv"), multiIndex + 1 < parts.count, let multi = Int(parts[multiIndex + 1]) else { continue }
                    let variation = line[pvRange.upperBound...].split(separator: " ").map(String.init)
                    guard let move = variation.first else { continue }
                    let score: String
                    if let scoreIndex = parts.firstIndex(of: "score"), scoreIndex + 2 < parts.count { score = parts[scoreIndex + 1] == "cp" ? "\(parts[scoreIndex + 2]) cp" : "mate \(parts[scoreIndex + 2])" } else { score = "—" }
                    lines[multi] = StockfishLine(move: move, score: score, variation: variation)
                    await onUpdate(lines.keys.sorted().compactMap { lines[$0] })
                }
            }
            throw StockfishError.noAnalysis
        }.value
    }
}
