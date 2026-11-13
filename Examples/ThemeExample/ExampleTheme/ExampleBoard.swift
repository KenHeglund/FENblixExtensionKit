// Created on 2026-10-16
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import FENblixExtensionKit
import SwiftUI

/// The empty board in blues, seen from either side, with a1 a black square:
/// the rank numbers down the left edge, each in its square's upper left
/// corner, and the file letters along the bottom, each in its square's lower
/// right corner, all in the color of the opposite squares.
struct ExampleBoard: View {

    /// The color of the white squares, which white's `ExampleTray` uses too.
    static let whiteSquare = Color(red: 0.86, green: 0.91, blue: 0.96)
    /// The color of the black squares, which black's `ExampleTray` uses too.
    static let blackSquare = Color(red: 0.33, green: 0.47, blue: 0.64)

    /// How tall a rank number or a capital letter stands, as a fraction of a
    /// square's height.
    private static let coordinateHeight: CGFloat = 0.12

    /// A system font's cap height, which digits share, as a fraction of its
    /// point size: about 0.7. Dividing by it turns a glyph height into a font
    /// size.
    private static let capHeightRatio: CGFloat = 0.7

    /// The space between a coordinate and the two edges of its square's corner,
    /// in points, the same across and up or down.
    private static let coordinateInset: CGFloat = 4

    /// The side the board is seen from: white puts rank 1 at the bottom and
    /// file a at the left, black rank 8 and file h.
    let side: PieceDescription.Side

    /// The 64 squares and the coordinates, drawn in one canvas.
    var body: some View {
        Canvas { context, size in
            let squareWidth = size.width / 8
            let squareHeight = size.height / 8
            let fontSize = squareHeight * Self.coordinateHeight / Self.capHeightRatio
            let font = Font.system(size: fontSize)

            for row in 0..<8 {
                for column in 0..<8 {
                    let square = CGRect(
                        x: CGFloat(column) * squareWidth,
                        y: CGFloat(row) * squareHeight,
                        width: squareWidth,
                        height: squareHeight
                    )
                    let isBlack = isBlackSquare(row: row, column: column)
                    context.fill(Path(square), with: .color(isBlack ? Self.blackSquare : Self.whiteSquare))

                    // The opposite color, so a coordinate stands out on either.
                    let ink = isBlack ? Self.whiteSquare : Self.blackSquare
                    // A text's frame has room above its digits and below its
                    // baseline, so it is placed by the glyphs instead: a rank's
                    // top is its cap height above the baseline, and a file
                    // letter sits on the baseline, which a "g" hangs below.
                    if column == 0 {
                        let rank = context.resolve(
                            Text(verbatim: rankName(row: row)).font(font).foregroundStyle(ink)
                        )
                        let baseline = rank.firstBaseline(in: square.size)
                        let top = square.minY + Self.coordinateInset + fontSize * Self.capHeightRatio
                        context.draw(
                            rank,
                            at: CGPoint(x: square.minX + Self.coordinateInset, y: top - baseline),
                            anchor: .topLeading
                        )
                    }
                    if row == 7 {
                        let file = context.resolve(
                            Text(verbatim: fileName(column: column)).font(font).foregroundStyle(ink)
                        )
                        let width = file.measure(in: square.size).width
                        let baseline = file.firstBaseline(in: square.size)
                        context.draw(
                            file,
                            at: CGPoint(
                                x: square.maxX - Self.coordinateInset - width,
                                y: square.maxY - Self.coordinateInset - baseline
                            ),
                            anchor: .topLeading
                        )
                    }
                }
            }
        }
    }

    /// The file drawn in `column`, counting from 0 at the left: a for column 0
    /// seen from white's side, h seen from black's.
    private func file(column: Int) -> Int {
        side == .white ? column : 7 - column
    }

    /// The rank drawn in `row`, counting from 0 at the top and from 0 for rank
    /// 1: rank 8 in row 0 seen from white's side, rank 1 seen from black's.
    private func rank(row: Int) -> Int {
        side == .white ? 7 - row : row
    }

    /// Whether the square drawn at `row` and `column` is black: a1, where both
    /// count 0, is black, and so is every square of the same parity.
    private func isBlackSquare(row: Int, column: Int) -> Bool {
        (rank(row: row) + file(column: column)).isMultiple(of: 2)
    }

    /// The number of the rank drawn in `row`, "1" to "8". Chess notation, the
    /// same in every language.
    private func rankName(row: Int) -> String {
        String(rank(row: row) + 1)
    }

    /// The letter of the file drawn in `column`, "a" to "h". Chess notation, the
    /// same in every language.
    private func fileName(column: Int) -> String {
        String(Character(UnicodeScalar(UInt8(ascii: "a") + UInt8(file(column: column)))))
    }
}
