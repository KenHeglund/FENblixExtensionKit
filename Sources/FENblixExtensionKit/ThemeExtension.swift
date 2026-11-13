// Created on 2026-10-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import ExtensionFoundation
import ExtensionKit
import Foundation
import Observation
import os
import SwiftUI

/// A theme provider: it draws the board, the pieces and the piece trays FENblix
/// shows.
///
/// Conform your extension's `@main` type to this and implement the three view
/// builders. The framework supplies `configuration`, which declares the scenes
/// FENblix hosts and handles the connections to them.
///
/// Bind to FENblix's `theme` extension point in two places. Declare the binding
/// in your type, which is the way ExtensionFoundation defines:
///
/// ```swift
/// @main
/// struct MyTheme: ThemeExtension {
///     @AppExtensionPoint.Bind
///     var extensionPoint: AppExtensionPoint {
///         Identifier(host: "com.orderedbytes.FENblix", name: "theme")
///     }
///     …
/// }
/// ```
///
/// And add the key the system reads to find your extension to its Info.plist:
///
/// ```xml
/// <key>EXAppExtensionAttributes</key>
/// <dict>
///     <key>EXExtensionPointIdentifier</key>
///     <string>com.orderedbytes.FENblix.theme</string>
/// </dict>
/// ```
///
/// With `EX_ENABLE_EXTENSION_POINT_GENERATION` on, Xcode is meant to write that key
/// from the declaration, but as of Xcode 27.2 it writes nothing. Without the key
/// your extension builds cleanly and FENblix never finds it, so write it yourself.
///
/// Each view runs in its own scene, and FENblix sizes the scene to fit. Several of
/// your scenes are on screen at once, all in one process.
public protocol ThemeExtension: AppExtension where Configuration == AppExtensionSceneConfiguration {

    // The requirements are `@MainActor`, not the protocol, matching `AppExtension`.
    // A target built with main-actor default isolation, which is how Xcode makes
    // new ones, conforms to `AppExtension` with a main-actor-isolated conformance,
    // and a conformance to a `@MainActor` protocol cannot rest on one of those.

    /// The view `piece(_:)` returns.
    associatedtype PieceBody: View
    /// The view `board(seenFrom:)` returns.
    associatedtype BoardBody: View
    /// The view `tray(for:)` returns.
    associatedtype TrayBody: View

    /// One piece, filling the square-sized frame it is given. Called again, in the
    /// same scene, whenever the host says the piece has changed.
    @MainActor @ViewBuilder func piece(_ piece: PieceDescription) -> PieceBody

    /// The 8×8 board with no pieces, as seen from `side`: from white's side,
    /// rank 1 at the bottom and file a at the left; from black's, rank 8 at the
    /// bottom and file h at the left. a1 is a black square either way. Called
    /// again, in the same scene, whenever the user flips the board.
    @MainActor @ViewBuilder func board(seenFrom side: PieceDescription.Side) -> BoardBody

    /// The background of one side's piece tray, drawn behind the pieces it offers.
    ///
    /// The tray is 6 squares wide and 1 tall, and FENblix draws the pieces over it,
    /// one per square, pawn to king outward from the board: the pawn's square is
    /// the one nearest the board, on whichever side the user puts the tray. The
    /// order across the view therefore depends on that side, which the view is not
    /// told, so draw a background that suits every square alike. Where the view
    /// draws nothing, the window shows through, so it may round its corners or
    /// leave a margin.
    @MainActor @ViewBuilder func tray(for side: PieceDescription.Side) -> TrayBody
}

@MainActor
extension ThemeExtension {

    /// Starts the extension. `@main` calls this; see `runSceneExtension(_:)` for
    /// why the framework has to supply it.
    public static func main() throws {
        try runSceneExtension(Self.self)
    }

    /// The `piece`, `board` and `tray` scenes.
    ///
    /// Until the host names a piece, a `piece` scene draws nothing, and likewise a
    /// `board` scene until the host names the side it is seen from, and a `tray`
    /// scene until the host names its side.
    public var configuration: AppExtensionSceneConfiguration {
        // The argument is an autoclosure that ExtensionKit evaluates once per scene
        // session, so every session gets its own `ShownPiece`, shared only by that
        // session's view and that session's connection. The same goes for each
        // `ShownSide`.
        AppExtensionSceneConfiguration(themeScenes())
    }

    /// The three scenes, a `piece` scene sharing one `ShownPiece` between its view
    /// and its connection, and a `board` scene and a `tray` scene one `ShownSide`
    /// each.
    private func themeScenes() -> [PrimitiveAppExtensionScene] {
        let shown = ShownPiece()
        let viewpoint = ShownSide()
        let shownSide = ShownSide()
        return [
            PrimitiveAppExtensionScene(id: SceneID.piece) {
                PieceSceneContent(theme: self, shown: shown)
            } onConnection: { connection in
                connection.exportedInterface = NSXPCInterface.pieceScene
                connection.exportedObject = PieceSceneService(shown: shown)
                connection.resume()
                return true
            },
            PrimitiveAppExtensionScene(id: SceneID.board) {
                BoardSceneContent(theme: self, viewpoint: viewpoint)
            } onConnection: { connection in
                connection.exportedInterface = NSXPCInterface.boardScene
                connection.exportedObject = BoardSceneService(viewpoint: viewpoint)
                connection.resume()
                return true
            },
            PrimitiveAppExtensionScene(id: SceneID.tray) {
                TraySceneContent(theme: self, shown: shownSide)
            } onConnection: { connection in
                connection.exportedInterface = NSXPCInterface.trayScene
                connection.exportedObject = TraySceneService(shown: shownSide)
                connection.resume()
                return true
            }
        ]
    }
}

/// The piece one `piece` scene is showing, if the host has named one yet.
@MainActor
@Observable
final class ShownPiece {
    /// The piece, or `nil` until the host names one.
    var piece: PieceDescription?
}

/// What a `piece` scene draws: the theme's view of whatever piece it was last told
/// to show.
///
/// It fills the scene whether or not there is a piece yet. Drawing nothing at
/// all would size the scene's hosting view to zero until the piece arrived, and
/// a scene whose content changes size during layout can send AppKit into a
/// constraint-update loop that it ends by throwing, which crashes the extension.
///
/// It also ignores the safe area. A scene whose view overlaps the host window's
/// title bar is given a top safe-area inset as large as the overlap, and content
/// laid out inside it shrinks: a piece dragged up into the title bar shrank to
/// about half its size, and ignoring the safe area here fixed it (Ken,
/// 2026-11-06). Pieces are the only scenes that cross the window's edge today.
/// The board, tray and evaluation scenes ignore it too, for consistency and in
/// case a layout change puts one under a title bar or toolbar, or a future iOS
/// host gives one a status bar, home indicator or keyboard inset. So every
/// scene's content fills its scene wherever the host puts it.
struct PieceSceneContent<Theme: ThemeExtension>: View {

    /// The theme that draws the piece.
    let theme: Theme
    /// The piece this scene was told to draw.
    let shown: ShownPiece

    /// The theme's piece once the host has named one, in a frame that fills the scene
    /// either way, safe area included.
    var body: some View {
        ZStack {
            if let piece = shown.piece {
                theme.piece(piece)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// The object a `piece` scene exports to the host.
///
/// XPC calls arrive on a background queue. Each hops to the main queue to update
/// `ShownPiece`, in order: `DispatchQueue.main` runs blocks in the order they were
/// queued, which separate main-actor `Task`s don't promise, and a piece that is
/// told to change twice in quick succession has to end up as the second.
final class PieceSceneService: NSObject, PieceSceneXPC, Sendable {

    /// Where a scene logs a piece string it could not read.
    private static let logger = Logger(subsystem: "com.orderedbytes.FENblixExtensionKit", category: "PieceScene")

    /// The piece this scene's view draws, which `show(piece:)` sets.
    private let shown: ShownPiece

    /// A service that sets `shown`.
    init(shown: ShownPiece) {
        self.shown = shown
    }

    /// Replies with the version of the framework the extension was built with.
    func contractVersion(reply: @escaping @Sendable (Int) -> Void) {
        reply(Contract.version)
    }

    /// Parses `piece` and, on the main queue, sets it as the piece to draw.
    func show(piece: String) {
        guard let description = PieceDescription(fenString: piece) else {
            Self.logger.error("Asked to show “\(piece, privacy: .public)”, which names no piece.")
            return
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.shown.piece = description
            }
        }
    }
}

/// What a `board` scene draws: the theme's board seen from the side it was
/// last told, filling the scene whether or not it has been told yet, for the
/// reason given on `PieceSceneContent`.
struct BoardSceneContent<Theme: ThemeExtension>: View {

    /// The theme that draws the board.
    let theme: Theme
    /// The side this scene was told the board is seen from.
    let viewpoint: ShownSide

    /// The theme's board once the host has named the side it is seen from, in a
    /// frame that fills the scene either way, safe area included; see
    /// `PieceSceneContent`.
    var body: some View {
        ZStack {
            if let side = viewpoint.side {
                theme.board(seenFrom: side)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// The object a `board` scene exports to the host. Calls hop to the main queue
/// in order, as `PieceSceneService` explains: a board flipped twice in quick
/// succession has to end up seen from the second side.
final class BoardSceneService: NSObject, BoardSceneXPC, Sendable {

    /// Where a scene logs a side string it could not read.
    private static let logger = Logger(subsystem: "com.orderedbytes.FENblixExtensionKit", category: "BoardScene")

    /// The side this scene's board is seen from, which `show(seenFrom:)` sets.
    private let viewpoint: ShownSide

    /// A service that sets `viewpoint`.
    init(viewpoint: ShownSide) {
        self.viewpoint = viewpoint
    }

    /// Replies with the version of the framework the extension was built with.
    func contractVersion(reply: @escaping @Sendable (Int) -> Void) {
        reply(Contract.version)
    }

    /// Parses `side` and, on the main queue, sets it as the side the board is
    /// seen from.
    func show(seenFrom side: String) {
        guard let parsed = PieceDescription.Side(fenString: side) else {
            Self.logger.error("Asked to show the board seen from “\(side, privacy: .public)”, which names no side.")
            return
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.viewpoint.side = parsed
            }
        }
    }
}

/// A side the host names to a scene, if it has yet: the side a `tray` scene
/// belongs to, or the side a `board` scene's board is seen from.
@MainActor
@Observable
final class ShownSide {
    /// The side, or `nil` until the host names one.
    var side: PieceDescription.Side?
}

/// What a `tray` scene draws: the theme's tray for the side it was told, filling
/// the scene whether or not it has been told yet, for the reason given on
/// `PieceSceneContent`.
struct TraySceneContent<Theme: ThemeExtension>: View {

    /// The theme that draws the tray.
    let theme: Theme
    /// The side this scene was told it belongs to.
    let shown: ShownSide

    /// The theme's tray once the host has named its side, in a frame that fills the
    /// scene either way, safe area included; see `PieceSceneContent`.
    var body: some View {
        ZStack {
            if let side = shown.side {
                theme.tray(for: side)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

/// The object a `tray` scene exports to the host. Calls hop to the main queue in
/// order, as `PieceSceneService` explains.
final class TraySceneService: NSObject, TraySceneXPC, Sendable {

    /// Where a scene logs a side string it could not read.
    private static let logger = Logger(subsystem: "com.orderedbytes.FENblixExtensionKit", category: "TrayScene")

    /// The side this scene's view draws, which `show(side:)` sets.
    private let shown: ShownSide

    /// A service that sets `shown`.
    init(shown: ShownSide) {
        self.shown = shown
    }

    /// Replies with the version of the framework the extension was built with.
    func contractVersion(reply: @escaping @Sendable (Int) -> Void) {
        reply(Contract.version)
    }

    /// Parses `side` and, on the main queue, sets it as the side to draw.
    func show(side: String) {
        guard let parsed = PieceDescription.Side(fenString: side) else {
            Self.logger.error("Asked to show the tray for “\(side, privacy: .public)”, which names no side.")
            return
        }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.shown.side = parsed
            }
        }
    }
}
