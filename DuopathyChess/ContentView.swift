import SwiftUI

struct ContentView: View {
    @ObservedObject var game: ChessGameViewModel
    private let files = Array("abcdefgh").map(String.init)

    var body: some View {
        HStack(spacing: 28) {
            VStack(spacing: 14) {
                HStack { VStack(alignment: .leading) { Text("Duopathy Chess").font(.largeTitle.weight(.bold)); Text("Two local Ollama models, one visible train of thought.").foregroundStyle(.secondary) }; Spacer(); Text(game.status).font(.caption).padding(8).background(.quaternary, in: Capsule()) }
                board
                HStack { Text("White to move: \(game.position.sideToMove == .white ? game.whiteModel : game.blackModel)").font(.caption).foregroundStyle(.secondary); Spacer(); Text("Move \(game.position.ply / 2 + 1)").font(.caption.monospaced()).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            inspector.frame(width: 310)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var board: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                VStack(spacing: 0) { ForEach(0..<8, id: \.self) { row in HStack(spacing: 0) { ForEach(0..<8, id: \.self) { col in square(row, col, size: size) } } } }
                ForEach(game.ghostPieces) { preview in ghost(preview, size: size) }
            }
            .frame(width: size, height: size)
            .overlay(alignment: .bottomLeading) { Text("Numbered ghosts = live Stockfish / LLM principal variation").font(.caption2.weight(.medium)).padding(7).background(.black.opacity(0.58), in: Capsule()).foregroundStyle(.white).padding(8) }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 7)
    }

    @ViewBuilder private func square(_ row: Int, _ col: Int, size: CGFloat) -> some View {
        let i = row * 8 + col
        ZStack(alignment: .topLeading) {
            ((row + col).isMultiple(of: 2) ? Color(red: 0.93, green: 0.82, blue: 0.63) : Color(red: 0.48, green: 0.30, blue: 0.18))
            if let piece = game.position.board[i] { Text(piece.glyph).font(.system(size: size * 0.102)).foregroundStyle(piece.side == .white ? Color.white : Color.black).shadow(color: piece.side == .white ? .black.opacity(0.38) : .white.opacity(0.18), radius: 1, y: 1).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) }
            if col == 0 { Text("\(8-row)").font(.caption2.weight(.bold)).foregroundStyle((row + col).isMultiple(of: 2) ? .brown : .white.opacity(0.8)).padding(3) }
            if row == 7 { Text(files[col]).font(.caption2.weight(.bold)).foregroundStyle((row + col).isMultiple(of: 2) ? .brown : .white.opacity(0.8)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(3) }
        }.frame(width: size / 8, height: size / 8)
    }

    private func ghost(_ ghost: GhostPiece, size: CGFloat) -> some View {
        let row = ghost.square / 8, col = ghost.square % 8
        return ZStack {
            Circle().fill(.cyan.opacity(0.3)).frame(width: size / 8 * 0.72).overlay(Circle().stroke(.cyan.opacity(0.85), lineWidth: 2))
            Text(ghost.piece.glyph).font(.system(size: size * 0.102)).foregroundStyle(ghost.piece.side == .white ? Color.white : Color.black).opacity(max(0.36, 0.70 - Double(ghost.depth) * 0.035))
            Text("\(ghost.depth)").font(.caption2.bold()).foregroundStyle(.white).padding(3).background(.indigo.opacity(0.9), in: Circle()).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: size / 8, height: size / 8)
        .position(x: size / 16 + CGFloat(col) * size / 8, y: size / 16 + CGFloat(row) * size / 8)
        .transition(.scale.combined(with: .opacity))
        .animation(.easeInOut(duration: 0.45), value: game.ghostPieces.map(\.id))
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox("Players") { VStack(alignment: .leading, spacing: 12) {
                modelPicker("White", selection: $game.whiteModel, tint: .blue)
                modelPicker("Black", selection: $game.blackModel, tint: .orange)
                HStack { Button("Refresh Models") { Task { await game.refreshModels() } }; Spacer(); Button("New Game") { game.newGame() } }
            }.padding(.top, 4) }
            GroupBox("Ollama") { VStack(alignment: .leading, spacing: 8) { TextField("Server", text: $game.baseURLInput).textFieldStyle(.roundedBorder); Text("Choose any installed local model for each side.").font(.caption).foregroundStyle(.secondary) }.padding(.top, 4) }
            GroupBox("Stockfish") { VStack(alignment: .leading, spacing: 8) { Picker("Analysis Time", selection: $game.stockfishAnalysisTime) { ForEach(StockfishAnalysisTime.allCases) { Text($0.rawValue).tag($0) } }.disabled(game.isThinking); Text(game.engineSummary).font(.caption.monospaced()).lineLimit(3).textSelection(.enabled) }.padding(.top, 4) }
            GroupBox("Thinking") { VStack(alignment: .leading, spacing: 8) { if game.isThinking { HStack { ProgressView().controlSize(.small); Text("Showing \(game.ghostPieces.count)-ply principal variation") }.font(.caption); Text(game.streamingText.isEmpty ? "Waiting for the model…" : game.streamingText).font(.caption.monospaced()).lineLimit(5).textSelection(.enabled) } else { Text("Numbered ghosts show the model's contemplated line, one ply at a time.").font(.caption).foregroundStyle(.secondary) } }.padding(.top, 4) }
            GroupBox("Move List") { ScrollView { LazyVGrid(columns: [GridItem(.fixed(34)), GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) { ForEach(Array(stride(from: 0, to: game.moves.count, by: 2)), id: \.self) { i in Text("\(i / 2 + 1).").foregroundStyle(.secondary); Text(game.moves[i]); Text(i + 1 < game.moves.count ? game.moves[i + 1] : "") } }.font(.caption.monospaced()) }.frame(minHeight: 95, maxHeight: .infinity) }
            HStack { Button("Start") { game.start() }.buttonStyle(.borderedProminent).tint(.indigo).keyboardShortcut(.return).disabled(game.isRunning); Button("Pause") { game.pause() }.buttonStyle(.bordered).disabled(!game.isRunning); Spacer(); if game.isThinking { ProgressView().controlSize(.small) } }
        }
    }
    private func modelPicker(_ label: String, selection: Binding<String>, tint: Color) -> some View { VStack(alignment: .leading, spacing: 4) { Text(label).font(.caption.weight(.bold)).foregroundStyle(tint); Picker(label, selection: selection) { Text("Select a model").tag(""); ForEach(game.models) { Text($0.name).tag($0.name) } }.labelsHidden().frame(maxWidth: .infinity) } }
}
