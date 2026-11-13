// Created on 2026-10-17
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Foundation

/// The material on the board, counted from the piece-placement field of a FEN
/// record.
///
/// This is the example's own parser, not FENblix's: an extension cannot see the
/// app's model, so it reads what it needs from the FEN string itself. It reads only
/// the first field, and checks only what counting needs — eight ranks of eight
/// squares, each square a piece letter or part of a run of empty squares.
nonisolated struct MaterialCount: Equatable {

    /// Each kind of piece's value in centipawns, by its lowercase FEN letter. The
    /// king is never captured, so it counts for nothing.
    private static let centipawns: [Character: Int] = [
        "p": 100, "n": 300, "b": 300, "r": 500, "q": 900, "k": 0
    ]

    /// White's material, in centipawns.
    let white: Int

    /// Black's material, in centipawns.
    let black: Int

    /// White's material minus black's: positive favors white, negative black.
    var balance: Int { white - black }

    /// Counts the material in `fen`, which needs only its first field.
    ///
    /// Throws if the placement is malformed. FENblix sends canonical FEN, so that
    /// should not happen, but a provider reports bad input rather than guessing.
    init(fen: String) throws(MaterialCountError) {
        guard let placement = fen.split(whereSeparator: \.isWhitespace).first else {
            throw .noPlacement
        }

        let ranks = placement.split(separator: "/", omittingEmptySubsequences: false)
        guard ranks.count == 8 else {
            throw .rankCount(ranks.count)
        }

        var white = 0
        var black = 0
        for (index, rank) in ranks.enumerated() {
            // FEN lists rank 8 first.
            let number = 8 - index
            var squares = 0
            for character in rank {
                if let empty = character.wholeNumberValue, (1...8).contains(empty) {
                    squares += empty
                } else if let value = Self.centipawns[Character(character.lowercased())] {
                    squares += 1
                    if character.isUppercase {
                        white += value
                    } else {
                        black += value
                    }
                } else {
                    throw .invalidCharacter(character, rank: number)
                }
            }
            guard squares == 8 else {
                throw .squareCount(squares, rank: number)
            }
        }

        self.white = white
        self.black = black
    }
}

/// Why a piece placement could not be counted. The description is what FENblix
/// shows the user.
nonisolated enum MaterialCountError: Error, Equatable, LocalizedError {

    /// The record is empty.
    case noPlacement

    /// The placement has this many ranks instead of eight.
    case rankCount(Int)

    /// The rank covers this many squares instead of eight.
    case squareCount(Int, rank: Int)

    /// The rank holds a character that is neither a piece nor a count of empty
    /// squares.
    case invalidCharacter(Character, rank: Int)

    /// The problem in words the user can act on, which FENblix shows in place of a
    /// score.
    var errorDescription: String? {
        switch self {
        case .noPlacement:
            String(
                localized: "The position has no piece placement.",
                comment: "Why the example evaluator can't score a position."
            )
        case .rankCount(let count):
            String(
                localized: "The piece placement has \(count) ranks instead of 8.",
                comment: "Why the example evaluator can't score a position. The argument is a count."
            )
        case .squareCount(let count, let rank):
            String(
                localized: "Rank \(rank) covers \(count) squares instead of 8.",
                comment: "Why the example evaluator can't score a position. Arguments: a rank number, a count."
            )
        case .invalidCharacter(let character, let rank):
            String(
                localized: """
                    Rank \(rank) contains “\(String(character))”, which is not a piece or a count \
                    of empty squares.
                    """,
                comment: "Why the example evaluator can't score a position. Arguments: a rank number, a character."
            )
        }
    }
}
