// Created on 2026-10-28
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import FENblixExtensionKit
import SwiftUI

/// A piece tray's background: a rounded rectangle in the color of the board's
/// white squares for white's tray, and of its black squares for black's, to show
/// that the two trays can differ.
struct ExampleTray: View {

    /// The side whose pieces the tray offers.
    let side: PieceDescription.Side

    /// The rounded rectangle, filling the scene, its corners rounded in proportion
    /// to a square.
    var body: some View {
        GeometryReader { geometry in
            // The tray is 6 squares wide and 1 tall.
            let squareSide = min(geometry.size.width / 6, geometry.size.height)
            RoundedRectangle(cornerRadius: squareSide * 0.12, style: .continuous)
                .fill(side == .white ? ExampleBoard.whiteSquare : ExampleBoard.blackSquare)
        }
    }
}
