// Created on 2026-10-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

/// A chess piece, as a theme extension is asked to draw it: a side and a kind.
///
/// This is the framework's own type, not the app's. An extension cannot see how
/// FENblix represents a position, and doesn't need to.
public struct PieceDescription: Sendable, Hashable {

    /// Which side a piece belongs to.
    public enum Side: Sendable, CaseIterable {
        /// The side that moves first.
        case white
        /// The side that moves second.
        case black
    }

    /// The kind of piece, independent of side.
    public enum Kind: Sendable, CaseIterable {
        /// The king.
        case king
        /// The queen.
        case queen
        /// A rook.
        case rook
        /// A bishop.
        case bishop
        /// A knight.
        case knight
        /// A pawn.
        case pawn
    }

    /// The side the piece belongs to.
    public var side: Side
    /// What kind of piece it is.
    public var kind: Kind

    /// A piece of `kind` belonging to `side`.
    public init(side: Side, kind: Kind) {
        self.side = side
        self.kind = kind
    }

    /// All twelve pieces: every kind of each side.
    static let all = Side.allCases.flatMap { side in
        Kind.allCases.map { kind in PieceDescription(side: side, kind: kind) }
    }
}

// MARK: - FEN character

/// A piece travels over XPC as its FEN placement character — `K` for a white
/// king, `q` for a black queen — rather than as an archived object, so the wire
/// format is one that both sides already agree on.
@_spi(FENblixHost)
extension PieceDescription {

    /// The FEN placement character: uppercase for white, lowercase for black.
    public var fenCharacter: Character {
        switch (side, kind) {
        case (.white, .king): "K"
        case (.white, .queen): "Q"
        case (.white, .rook): "R"
        case (.white, .bishop): "B"
        case (.white, .knight): "N"
        case (.white, .pawn): "P"
        case (.black, .king): "k"
        case (.black, .queen): "q"
        case (.black, .rook): "r"
        case (.black, .bishop): "b"
        case (.black, .knight): "n"
        case (.black, .pawn): "p"
        }
    }

    /// Parses a FEN placement character. Returns `nil` for anything that is not
    /// one of the twelve piece characters.
    ///
    /// The twelve are spelled out rather than found by changing case, because
    /// this reads whatever arrives over XPC, and case mapping has surprises
    /// outside ASCII.
    public init?(fenCharacter: Character) {
        guard let piece = PieceDescription.all.first(where: { $0.fenCharacter == fenCharacter }) else {
            return nil
        }
        self = piece
    }

    /// Parses the string a `PieceSceneXPC.show(piece:)` call carries, which has
    /// to be exactly one FEN placement character.
    public init?(fenString: String) {
        guard fenString.count == 1, let character = fenString.first else {
            return nil
        }
        self.init(fenCharacter: character)
    }
}

// MARK: - Side character

/// A side travels over XPC as its FEN side-to-move character, `w` or `b`, for the
/// same reason a piece travels as its placement character.
@_spi(FENblixHost)
extension PieceDescription.Side {

    /// The FEN side-to-move character: `w` for white, `b` for black.
    public var fenCharacter: Character {
        self == .white ? "w" : "b"
    }

    /// Parses the string a `TraySceneXPC.show(side:)` or
    /// `BoardSceneXPC.show(seenFrom:)` call carries, which has to be exactly `w`
    /// or `b`.
    public init?(fenString: String) {
        switch fenString {
        case "w": self = .white
        case "b": self = .black
        default: return nil
        }
    }
}
