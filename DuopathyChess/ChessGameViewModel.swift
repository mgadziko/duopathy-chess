import Foundation

enum StockfishAnalysisTime: String, CaseIterable, Identifiable {
    case halfSecond = "0.5 sec", oneSecond = "1.0 sec", oneAndHalfSeconds = "1.5 sec", twoSeconds = "2.0 sec", fiveSeconds = "5.0 sec", tenSeconds = "10.0 sec", fifteenSeconds = "15.0 sec"
    var id: String { rawValue }
    var milliseconds: Int { switch self { case .halfSecond: 500; case .oneSecond: 1_000; case .oneAndHalfSeconds: 1_500; case .twoSeconds: 2_000; case .fiveSeconds: 5_000; case .tenSeconds: 10_000; case .fifteenSeconds: 15_000 } }
}

@MainActor
final class ChessGameViewModel: ObservableObject {
    @Published var models: [OllamaModel] = []
    @Published var whiteModel = ""
    @Published var blackModel = ""
    @Published var baseURLInput = "http://127.0.0.1:11434"
    @Published var position = ChessPosition()
    @Published var moves: [String] = []
    @Published var status = "Loading local models…"
    @Published var isThinking = false
    @Published var isRunning = false
    @Published var ghostPieces: [GhostPiece] = []
    @Published var streamingText = ""
    @Published var engineSummary = "Stockfish: waiting"
    @Published var stockfishAnalysisTime: StockfishAnalysisTime = .oneAndHalfSeconds
    private var task: Task<Void, Never>?
    private var nextMoveTask: Task<Void, Never>?
    private var service: OllamaService { OllamaService(baseURL: URL(string: baseURLInput) ?? URL(string: "http://127.0.0.1:11434")!) }
    private let stockfish = StockfishService()
    init() { Task { await refreshModels() } }
    func refreshModels() async { status = "Loading local models…"; do { models = try await service.listModels(); whiteModel = whiteModel.isEmpty ? models.first?.name ?? "" : whiteModel; blackModel = blackModel.isEmpty ? models.dropFirst().first?.name ?? whiteModel : blackModel; status = models.isEmpty ? "No Ollama models found" : "Ready to play" } catch { status = "Could not reach Ollama" } }
    func newGame() { pause(); position = ChessPosition(); moves=[]; ghostPieces=[]; streamingText=""; status="Ready to play" }
    func start() { guard !isRunning else { return }; isRunning = true; status = "Match started"; playNext() }
    func pause() { isRunning = false; task?.cancel(); nextMoveTask?.cancel(); task = nil; nextMoveTask = nil; isThinking=false; ghostPieces=[]; status="Paused" }
    func playNext() {
        guard !isThinking, !whiteModel.isEmpty, !blackModel.isEmpty else { return }
        let legal = position.legalMoves()
        guard !legal.isEmpty else { isRunning = false; status = position.isInCheck(position.sideToMove) ? "Checkmate — \(position.sideToMove.opposite.rawValue.capitalized) wins" : "Stalemate"; return }
        isThinking = true; streamingText = ""
        let model = position.sideToMove == .white ? whiteModel : blackModel
        let snapshot = position
        status = "Stockfish analyzing \(snapshot.sideToMove.rawValue)…"
        ghostPieces = Self.previewPieces(for: Array(legal.shuffled().prefix(3)), from: snapshot)
        task = Task { [weak self] in
            guard let self else { return }
            let advice: [StockfishLine]
            do {
                let analysisTime = self.stockfishAnalysisTime
                advice = try await self.stockfish.analyze(fen: snapshot.fen(), timeLimitMilliseconds: analysisTime.milliseconds) { lines in
                    await MainActor.run {
                        self.engineSummary = "Stockfish live: " + lines.map { "\($0.move) (\($0.score))" }.joined(separator: "  •  ")
                        if let principal = lines.first { self.ghostPieces = Self.contemplatedPieces(for: principal.variation, from: snapshot) }
                    }
                }
                self.engineSummary = "Stockfish \(analysisTime.rawValue): " + advice.map { "\($0.move) (\($0.score))" }.joined(separator: "  •  ")
            } catch { advice = []; self.engineSummary = "Stockfish unavailable — using full legal list" }
            guard !Task.isCancelled else { return }
            self.status = "\(snapshot.sideToMove.rawValue.capitalized) / \(model) considering…"
            let choices = advice.compactMap { line in legal.first { $0.uci == line.move } }
            let allowed = choices.isEmpty ? legal : choices
            var reply = ""
            do {
                try await self.service.chatStream(model: model, prompt: Self.prompt(for: snapshot, legal: allowed, advice: advice), onDelta: { piece in
                    await MainActor.run { reply += piece; self.streamingText = reply; let line = Self.contemplatedPieces(in: reply, from: snapshot); if !line.isEmpty { self.ghostPieces = line } }
                })
                guard !Task.isCancelled else { return }
                self.commit(Self.finalMove(in: reply, legal: allowed) ?? Self.move(in: reply, legal: allowed) ?? allowed[0], note: "Played")
            } catch is CancellationError { } catch { guard !Task.isCancelled else { return }; self.commit(allowed[0], note: "Ollama unavailable — Stockfish move played") }
        }
    }
    private func commit(_ move: ChessMove, note: String) { position.apply(move); moves.append(move.uci); ghostPieces=[]; isThinking=false; status="\(note) \(move.uci)"; scheduleNextMove() }
    private func scheduleNextMove() { guard isRunning else { return }; nextMoveTask?.cancel(); nextMoveTask = Task { [weak self] in try? await Task.sleep(for: .milliseconds(650)); guard !Task.isCancelled, let self, self.isRunning else { return }; self.playNext() } }
    private static func prompt(for position: ChessPosition, legal: [ChessMove], advice: [StockfishLine]) -> String { let evaluation = advice.map { "\($0.move) [\($0.score)]: \($0.variation.joined(separator: " "))" }.joined(separator: " | "); return "You are playing chess as \(position.sideToMove.rawValue). Position FEN: \(position.fen()). Stockfish depth-14 analysis: \(evaluation.isEmpty ? "unavailable" : evaluation). Choose strategically from this engine-ranked first-move shortlist only: \(legal.map(\.uci).joined(separator: ", ")). Think at least 8 half-moves deep. Stream one principal variation in this exact form: PV: move1 move2 move3 move4 move5 move6 move7 move8. Every move must be UCI and legal in sequence. Then write FINAL: move1." }
    private static func move(in response: String, legal: [ChessMove]) -> ChessMove? { let lower=response.lowercased(); return legal.first { lower.range(of: $0.uci, options: .regularExpression) != nil } }
    private static func finalMove(in response: String, legal: [ChessMove]) -> ChessMove? { guard let range = response.range(of: "final:", options: .caseInsensitive) else { return nil }; return move(in: String(response[range.upperBound...]), legal: legal) }
    private static func previewPieces(for moves: [ChessMove], from position: ChessPosition) -> [GhostPiece] { moves.enumerated().compactMap { offset, move in guard let piece = position.board[move.from] else { return nil }; return GhostPiece(square: move.to, piece: piece, depth: 1, id: "preview-\(offset)-\(move.uci)") } }
    private static func contemplatedPieces(in response: String, from position: ChessPosition) -> [GhostPiece] { guard let start = response.range(of: "PV:", options: .caseInsensitive) else { return [] }; let text = String(response[start.upperBound...]).components(separatedBy: "FINAL:").first ?? ""; let tokens = text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init); return contemplatedPieces(for: tokens, from: position) }
    private static func contemplatedPieces(for tokens: [String], from position: ChessPosition) -> [GhostPiece] { var simulated = position; var ghosts: [GhostPiece] = []; for token in tokens.prefix(12) { let legal = simulated.legalMoves(); guard let move = legal.first(where: { $0.uci == token }), let piece = simulated.board[move.from] else { break }; let depth = ghosts.count + 1; ghosts.append(GhostPiece(square: move.to, piece: piece, depth: depth, id: "pv-\(depth)-\(move.uci)")); simulated.apply(move) }; return ghosts }
}
