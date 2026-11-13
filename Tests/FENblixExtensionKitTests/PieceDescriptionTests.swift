// Created on 2026-10-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Testing
@_spi(FENblixHost) @testable import FENblixExtensionKit

@Suite("Piece descriptions")
struct PieceDescriptionTests {

    @Test("Every piece survives a round trip through its FEN character", arguments: PieceDescription.all)
    func roundTripsThroughFENCharacter(piece: PieceDescription) {
        #expect(PieceDescription(fenCharacter: piece.fenCharacter) == piece)
        #expect(PieceDescription(fenString: String(piece.fenCharacter)) == piece)
    }

    @Test("The twelve pieces use the twelve FEN placement characters")
    func usesStandardCharacters() {
        #expect(String(PieceDescription.all.map(\.fenCharacter)) == "KQRBNPkqrbnp")
    }

    @Test("White is uppercase and black is lowercase")
    func caseGivesSide() {
        #expect(PieceDescription(side: .white, kind: .knight).fenCharacter == "N")
        #expect(PieceDescription(side: .black, kind: .knight).fenCharacter == "n")
    }

    @Test("A character that names no piece is rejected", arguments: [
        "x", "1", "8", "/", " ", "-", "w",
        // Look like piece letters, but aren't the ASCII ones FEN uses.
        "Ｋ", "ｑ", "К"
    ] as [Character])
    func rejectsNonPieceCharacter(character: Character) {
        #expect(PieceDescription(fenCharacter: character) == nil)
    }

    @Test("A string that isn't exactly one piece character is rejected", arguments: [
        "", "KQ", "K ", " K", "k\n", "x"
    ])
    func rejectsNonPieceString(string: String) {
        #expect(PieceDescription(fenString: string) == nil)
    }

    @Test("A side travels as w or b, and back", arguments: PieceDescription.Side.allCases)
    func sideRoundTrips(side: PieceDescription.Side) {
        #expect(PieceDescription.Side(fenString: String(side.fenCharacter)) == side)
        #expect(String(PieceDescription.Side.allCases.map(\.fenCharacter)) == "wb")
    }

    @Test("A string that isn't exactly w or b names no side", arguments: [
        "", "W", "B", "wb", "w ", "white", "K"
    ])
    func rejectsNonSideString(string: String) {
        #expect(PieceDescription.Side(fenString: string) == nil)
    }
}
