// Created on 2026-10-16
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import ExtensionFoundation
import FENblixExtensionKit
import SwiftUI

/// An example theme, shipped inside FENblix to show what a theme provider can do.
///
/// It is meant to look plainly unlike the built-in theme, so it is obvious at a
/// glance which one is drawing: pieces are shapes marked with a letter rather than
/// glyphs, and the board and trays are blue rather than brown.
@main
struct ExampleTheme: ThemeExtension {

    /// Binds this extension to FENblix's `theme` extension point.
    @AppExtensionPoint.Bind
    var extensionPoint: AppExtensionPoint {
        Identifier(host: "com.orderedbytes.FENblix", name: "theme")
    }

    /// Draws `piece` as an `ExamplePiece`.
    func piece(_ piece: PieceDescription) -> some View {
        ExamplePiece(piece: piece)
    }

    /// Draws the board seen from `side` as an `ExampleBoard`.
    func board(seenFrom side: PieceDescription.Side) -> some View {
        ExampleBoard(side: side)
    }

    /// Draws `side`'s tray as an `ExampleTray`.
    func tray(for side: PieceDescription.Side) -> some View {
        ExampleTray(side: side)
    }
}
