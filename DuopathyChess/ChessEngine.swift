import Foundation

enum Side: String { case white, black; var opposite: Side { self == .white ? .black : .white } }
enum PieceKind: String { case king = "K", queen = "Q", rook = "R", bishop = "B", knight = "N", pawn = "P" }
struct Piece: Equatable { let side: Side; let kind: PieceKind; var glyph: String { switch kind { case .king: "♚"; case .queen: "♛"; case .rook: "♜"; case .bishop: "♝"; case .knight: "♞"; case .pawn: "♟" } } }
struct ChessMove: Identifiable, Equatable { let from: Int; let to: Int; let promotion: PieceKind?; var id: String { uci }; var uci: String { square(from) + square(to) + (promotion?.rawValue.lowercased() ?? "") } }
struct GhostPiece: Identifiable, Equatable { let square: Int; let piece: Piece; let depth: Int; let id: String }

func square(_ i: Int) -> String { String(UnicodeScalar(97 + i % 8)!) + String(8 - i / 8) }
func index(_ text: String) -> Int? { guard text.count == 2, let f = text.utf8.first, let r = text.utf8.last, (97...104).contains(f), (49...56).contains(r) else { return nil }; return (8 - Int(r - 48)) * 8 + Int(f - 97) }

struct ChessPosition {
    var board: [Piece?] = Array(repeating: nil, count: 64)
    var sideToMove: Side = .white
    var ply = 0
    init() {
        let back: [PieceKind] = [.rook,.knight,.bishop,.queen,.king,.bishop,.knight,.rook]
        for col in 0..<8 { board[col] = Piece(side: .black, kind: back[col]); board[8 + col] = Piece(side: .black, kind: .pawn); board[48 + col] = Piece(side: .white, kind: .pawn); board[56 + col] = Piece(side: .white, kind: back[col]) }
    }
    func legalMoves() -> [ChessMove] {
        var result: [ChessMove] = []
        for from in 0..<64 where board[from]?.side == sideToMove {
            guard let piece = board[from] else { continue }
            let row = from / 8, col = from % 8
            func add(_ r: Int, _ c: Int) { guard (0..<8).contains(r), (0..<8).contains(c) else { return }; let to = r * 8 + c; if board[to]?.side != sideToMove { result.append(ChessMove(from: from, to: to, promotion: piece.kind == .pawn && (r == 0 || r == 7) ? .queen : nil)) } }
            func slide(_ dirs: [(Int,Int)]) { for (dr,dc) in dirs { var r=row+dr, c=col+dc; while (0..<8).contains(r) && (0..<8).contains(c) { let to=r*8+c; if board[to]?.side == sideToMove { break }; add(r,c); if board[to] != nil { break }; r += dr; c += dc } } }
            switch piece.kind {
            case .pawn:
                let d = piece.side == .white ? -1 : 1; let start = piece.side == .white ? 6 : 1
                if (0..<8).contains(row+d), board[(row+d)*8+col] == nil { add(row+d,col); if row == start && board[(row+2*d)*8+col] == nil { add(row+2*d,col) } }
                for dc in [-1,1] where (0..<8).contains(row+d) && (0..<8).contains(col+dc) { let to=(row+d)*8+col+dc; if let target=board[to], target.side != piece.side { add(row+d,col+dc) } }
            case .knight: for (dr,dc) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] { add(row+dr,col+dc) }
            case .king: for dr in -1...1 { for dc in -1...1 where dr != 0 || dc != 0 { add(row+dr,col+dc) } }
            case .bishop: slide([(-1,-1),(-1,1),(1,-1),(1,1)])
            case .rook: slide([(-1,0),(1,0),(0,-1),(0,1)])
            case .queen: slide([(-1,-1),(-1,1),(1,-1),(1,1),(-1,0),(1,0),(0,-1),(0,1)])
            }
        }
        return result
    }
    mutating func apply(_ move: ChessMove) { var piece = board[move.from]!; if let promotion = move.promotion { piece = Piece(side: piece.side, kind: promotion) }; board[move.to] = piece; board[move.from] = nil; sideToMove = sideToMove.opposite; ply += 1 }
    func fen() -> String { let ranks = (0..<8).map { r -> String in var empty=0, out=""; for c in 0..<8 { guard let p=board[r*8+c] else { empty += 1; continue }; if empty > 0 { out += "\(empty)"; empty=0 }; out += p.side == .white ? p.kind.rawValue : p.kind.rawValue.lowercased() }; return out + (empty > 0 ? "\(empty)" : "") }; return ranks.joined(separator: "/") + " " + (sideToMove == .white ? "w" : "b") + " - - 0 \(ply / 2 + 1)" }
}
