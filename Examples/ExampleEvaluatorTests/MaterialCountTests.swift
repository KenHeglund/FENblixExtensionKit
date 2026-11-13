// Created on 2026-10-17
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Foundation
import Testing

// `MaterialCount` belongs to the ExampleEvaluator extension, which is not a
// module a test can import. This target compiles its source file directly
// instead.
@Suite("Example evaluator material count")
struct MaterialCountTests {

    @Test("The starting position is level")
    func startingPosition() throws {
        let material = try MaterialCount(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

        #expect(material.white == 3900)
        #expect(material.black == 3900)
        #expect(material.balance == 0)
    }

    @Test("The balance is white's material minus black's", arguments: [
        ("rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", 900),
        ("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/1NBQKBNR w Kkq - 0 1", -500),
        ("rnbqkbnr/ppp1pppp/8/8/8/8/PPPPPPPP/RN1QKBNR w KQkq - 0 1", -200),
        ("4k3/8/8/8/8/8/8/2B1KN2 w - - 0 1", 600)
    ])
    func balance(fen: String, expected: Int) throws {
        #expect(try MaterialCount(fen: fen).balance == expected)
    }

    @Test("Kings count for nothing")
    func kings() throws {
        let material = try MaterialCount(fen: "k7/8/8/8/8/8/8/7K w - - 0 1")

        #expect(material.white == 0)
        #expect(material.black == 0)
    }

    @Test("Only the placement field is read")
    func placementOnly() throws {
        #expect(try MaterialCount(fen: "4k3/8/8/8/8/8/8/3QK3").balance == 900)
        #expect(try MaterialCount(fen: "4k3/8/8/8/8/8/8/3QK3 nonsense in the other fields").balance == 900)
    }

    @Test("Malformed placements are reported", arguments: [
        ("", MaterialCountError.noPlacement),
        ("   ", .noPlacement),
        ("8/8/8/8/8/8/8 w - - 0 1", .rankCount(7)),
        ("8/8/8/8/8/8/8/8/8 w - - 0 1", .rankCount(9)),
        ("8/8/8/8/8/8/8/ w - - 0 1", .squareCount(0, rank: 1)),
        ("7/8/8/8/8/8/8/8 w - - 0 1", .squareCount(7, rank: 8)),
        ("ppppppppp/8/8/8/8/8/8/8 w - - 0 1", .squareCount(9, rank: 8)),
        ("9/8/8/8/8/8/8/8 w - - 0 1", .invalidCharacter("9", rank: 8)),
        ("8/8/8/8/0/8/8/8 w - - 0 1", .invalidCharacter("0", rank: 4)),
        ("8/8/8/8/8/8/8/7x w - - 0 1", .invalidCharacter("x", rank: 1))
    ])
    func malformed(fen: String, expected: MaterialCountError) {
        #expect(throws: expected) {
            try MaterialCount(fen: fen)
        }
    }

    @Test("A malformed placement says what is wrong")
    func errorDescription() {
        let error = MaterialCountError.squareCount(7, rank: 8)

        #expect(error.localizedDescription == "Rank 8 covers 7 squares instead of 8.")
    }
}
