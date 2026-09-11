import Foundation

enum Side: String { case white, black; var opposite: Side { self == .white ? .black : .white } }
enum PieceKind: String { case king = "K", queen = "Q", rook = "R", bishop = "B", knight = "N", pawn = "P" }
struct Piece: Equatable { let side: Side; let kind: PieceKind; var glyph: String { switch kind { case .king: "♚"; case .queen: "♛"; case .rook: "♜"; case .bishop: "♝"; case .knight: "♞"; case .pawn: "♟" } } }
struct ChessMove: Identifiable, Equatable { let from: Int; let to: Int; let promotion: PieceKind?; var id: String { uci }; var uci: String { square(from) + square(to) + (promotion?.rawValue.lowercased() ?? "") } }
struct GhostPiece: Identifiable, Equatable { let square: Int; let piece: Piece; let depth: Int; let id: String }

func square(_ i: Int) -> String { String(UnicodeScalar(97 + i % 8)!) + String(8 - i / 8) }
func index(_ text: String) -> Int? { guard text.count == 2, let f = text.utf8.first, let r = text.utf8.last, (97...104).contains(f), (49...56).contains(r) else { return nil }; return (8 - Int(r - 48)) * 8 + Int(f - 97) }

struct CastlingRights: Equatable { var whiteKing = true; var whiteQueen = true; var blackKing = true; var blackQueen = true }

struct ChessPosition {
    var board: [Piece?] = Array(repeating: nil, count: 64)
    var sideToMove: Side = .white
    var ply = 0
    var castling = CastlingRights()
    var enPassantSquare: Int?
    init() {
        let back: [PieceKind] = [.rook,.knight,.bishop,.queen,.king,.bishop,.knight,.rook]
        for col in 0..<8 { board[col] = Piece(side: .black, kind: back[col]); board[8 + col] = Piece(side: .black, kind: .pawn); board[48 + col] = Piece(side: .white, kind: .pawn); board[56 + col] = Piece(side: .white, kind: back[col]) }
    }
    func legalMoves() -> [ChessMove] {
        pseudoMoves().filter { move in var next = self; next.apply(move); return !next.isInCheck(sideToMove) }
    }
    private func pseudoMoves() -> [ChessMove] {
        var result: [ChessMove] = []
        for from in 0..<64 where board[from]?.side == sideToMove {
            guard let piece = board[from] else { continue }
            let row = from / 8, col = from % 8
            func add(_ r: Int, _ c: Int) { guard (0..<8).contains(r), (0..<8).contains(c) else { return }; let to = r * 8 + c; guard board[to]?.side != sideToMove, board[to]?.kind != .king else { return }; if piece.kind == .pawn && (r == 0 || r == 7) { for promotion in [PieceKind.queen, .rook, .bishop, .knight] { result.append(ChessMove(from: from, to: to, promotion: promotion)) } } else { result.append(ChessMove(from: from, to: to, promotion: nil)) } }
            func slide(_ dirs: [(Int,Int)]) { for (dr,dc) in dirs { var r=row+dr, c=col+dc; while (0..<8).contains(r) && (0..<8).contains(c) { let to=r*8+c; if board[to]?.side == sideToMove { break }; add(r,c); if board[to] != nil { break }; r += dr; c += dc } } }
            switch piece.kind {
            case .pawn:
                let d = piece.side == .white ? -1 : 1; let start = piece.side == .white ? 6 : 1
                if (0..<8).contains(row+d), board[(row+d)*8+col] == nil { add(row+d,col); if row == start && board[(row+2*d)*8+col] == nil { add(row+2*d,col) } }
                for dc in [-1,1] where (0..<8).contains(row+d) && (0..<8).contains(col+dc) { let to=(row+d)*8+col+dc; if let target=board[to], target.side != piece.side { add(row+d,col+dc) } else if enPassantSquare == to { add(row+d,col+dc) } }
            case .knight: for (dr,dc) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] { add(row+dr,col+dc) }
            case .king:
                for dr in -1...1 { for dc in -1...1 where dr != 0 || dc != 0 { add(row+dr,col+dc) } }
                addCastlingMoves(for: piece, from: from, into: &result)
            case .bishop: slide([(-1,-1),(-1,1),(1,-1),(1,1)])
            case .rook: slide([(-1,0),(1,0),(0,-1),(0,1)])
            case .queen: slide([(-1,-1),(-1,1),(1,-1),(1,1),(-1,0),(1,0),(0,-1),(0,1)])
            }
        }
        return result
    }
    private func addCastlingMoves(for king: Piece, from: Int, into result: inout [ChessMove]) {
        let home = king.side == .white ? 56 : 0
        guard from == home + 4, !isInCheck(king.side) else { return }
        let enemy = king.side.opposite
        let kingSide = king.side == .white ? castling.whiteKing : castling.blackKing
        let queenSide = king.side == .white ? castling.whiteQueen : castling.blackQueen
        if kingSide, board[home + 5] == nil, board[home + 6] == nil, board[home + 7] == Piece(side: king.side, kind: .rook), !isSquareAttacked(home + 5, by: enemy), !isSquareAttacked(home + 6, by: enemy) { result.append(ChessMove(from: from, to: home + 6, promotion: nil)) }
        if queenSide, board[home + 1] == nil, board[home + 2] == nil, board[home + 3] == nil, board[home] == Piece(side: king.side, kind: .rook), !isSquareAttacked(home + 3, by: enemy), !isSquareAttacked(home + 2, by: enemy) { result.append(ChessMove(from: from, to: home + 2, promotion: nil)) }
    }
    func isInCheck(_ side: Side) -> Bool { guard let king = board.firstIndex(where: { $0 == Piece(side: side, kind: .king) }) else { return true }; return isSquareAttacked(king, by: side.opposite) }
    func isSquareAttacked(_ square: Int, by attacker: Side) -> Bool {
        let row = square / 8, col = square % 8
        let pawnRow = row + (attacker == .white ? 1 : -1)
        for dc in [-1, 1] where (0..<8).contains(pawnRow) && (0..<8).contains(col + dc) { if board[pawnRow * 8 + col + dc] == Piece(side: attacker, kind: .pawn) { return true } }
        for (dr, dc) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] where (0..<8).contains(row + dr) && (0..<8).contains(col + dc) { if board[(row + dr) * 8 + col + dc] == Piece(side: attacker, kind: .knight) { return true } }
        for dr in -1...1 { for dc in -1...1 where (dr != 0 || dc != 0) && (0..<8).contains(row + dr) && (0..<8).contains(col + dc) { if board[(row + dr) * 8 + col + dc] == Piece(side: attacker, kind: .king) { return true } } }
        func attackedOnRay(_ directions: [(Int, Int)], _ kinds: Set<PieceKind>) -> Bool { for (dr, dc) in directions { var r = row + dr, c = col + dc; while (0..<8).contains(r) && (0..<8).contains(c) { guard let piece = board[r * 8 + c] else { r += dr; c += dc; continue }; if piece.side == attacker && kinds.contains(piece.kind) { return true }; break } }; return false }
        return attackedOnRay([(-1,-1),(-1,1),(1,-1),(1,1)], [.bishop, .queen]) || attackedOnRay([(-1,0),(1,0),(0,-1),(0,1)], [.rook, .queen])
    }
    mutating func apply(_ move: ChessMove) {
        guard var piece = board[move.from] else { return }
        let captured = board[move.to]
        let direction = piece.side == .white ? -1 : 1
        if piece.kind == .pawn, move.to == enPassantSquare, board[move.to] == nil { board[move.to - direction * 8] = nil }
        board[move.from] = nil
        if piece.kind == .king && abs(move.to - move.from) == 2 { let rookFrom = move.to > move.from ? (move.from / 8) * 8 + 7 : (move.from / 8) * 8; let rookTo = move.to > move.from ? move.to - 1 : move.to + 1; board[rookTo] = board[rookFrom]; board[rookFrom] = nil }
        if let promotion = move.promotion { piece = Piece(side: piece.side, kind: promotion) }
        board[move.to] = piece
        revokeRights(for: piece.side, kind: piece.kind, square: move.from)
        if let captured, captured.kind == .rook { revokeRights(for: captured.side, kind: .rook, square: move.to) }
        enPassantSquare = piece.kind == .pawn && abs(move.to - move.from) == 16 ? (move.to + move.from) / 2 : nil
        sideToMove = sideToMove.opposite; ply += 1
    }
    private mutating func revokeRights(for side: Side, kind: PieceKind, square: Int) { if kind == .king { if side == .white { castling.whiteKing = false; castling.whiteQueen = false } else { castling.blackKing = false; castling.blackQueen = false } }; if kind == .rook { switch square { case 56: castling.whiteQueen = false; case 63: castling.whiteKing = false; case 0: castling.blackQueen = false; case 7: castling.blackKing = false; default: break } } }
    func fen() -> String { let ranks = (0..<8).map { r -> String in var empty=0, out=""; for c in 0..<8 { guard let p=board[r*8+c] else { empty += 1; continue }; if empty > 0 { out += "\(empty)"; empty=0 }; out += p.side == .white ? p.kind.rawValue : p.kind.rawValue.lowercased() }; return out + (empty > 0 ? "\(empty)" : "") }; var rights = ""; if castling.whiteKing { rights += "K" }; if castling.whiteQueen { rights += "Q" }; if castling.blackKing { rights += "k" }; if castling.blackQueen { rights += "q" }; return ranks.joined(separator: "/") + " " + (sideToMove == .white ? "w" : "b") + " " + (rights.isEmpty ? "-" : rights) + " " + (enPassantSquare.map(square) ?? "-") + " 0 \(ply / 2 + 1)" }
}
