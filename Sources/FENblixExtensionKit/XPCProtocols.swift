// Created on 2026-10-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Foundation

/// The version of the contract between FENblix and its extensions: these
/// protocols, the scenes in `SceneID`, and the wire format of `PieceDescription`.
///
/// An extension reports the version of the framework it was built with, and the
/// host accepts it if it is in `supportedVersions`: no newer than the host's own,
/// and no older than the oldest the host still supports.
///
/// A newer host stays compatible with older extensions. To change something an
/// extension built against an older version depends on, raise `version` and keep
/// the old behavior working for the versions still supported. Raise
/// `minimumSupportedVersion` only to drop support for older extensions on purpose.
///
/// Version 1 is the first version published.
@_spi(FENblixHost)
public enum Contract {

    /// The version this framework implements.
    public static let version = 1

    /// The oldest version of an extension the host still supports.
    public static let minimumSupportedVersion = 1

    /// The versions of an extension the host accepts.
    public static var supportedVersions: ClosedRange<Int> {
        minimumSupportedVersion...version
    }
}

/// What every FENblix scene answers, whatever its role.
///
/// The extension exports an object conforming to the scene's protocol. The host
/// exports nothing.
@_spi(FENblixHost)
@objc public protocol FENblixSceneXPC {

    /// Replies with the extension's `Contract.version`.
    func contractVersion(reply: @escaping @Sendable (Int) -> Void)
}

/// The connection to a theme's `piece` scene.
@_spi(FENblixHost)
@objc public protocol PieceSceneXPC: FENblixSceneXPC {

    /// Tells the scene which piece to draw, as its FEN placement character. Until
    /// this is called the scene draws nothing. A string that names no piece is
    /// logged and ignored, and the scene goes on drawing what it drew before.
    func show(piece: String)
}

/// The connection to a theme's `board` scene.
@_spi(FENblixHost)
@objc public protocol BoardSceneXPC: FENblixSceneXPC {

    /// Tells the scene which side the board is seen from, as `w` or `b`, and
    /// again whenever that changes. Until this is called the scene draws
    /// nothing. A string that names no side is logged and ignored.
    func show(seenFrom side: String)
}

/// The connection to a theme's `tray` scene.
@_spi(FENblixHost)
@objc public protocol TraySceneXPC: FENblixSceneXPC {

    /// Tells the scene which side's tray it is, as `w` or `b`. Until this is called
    /// the scene draws nothing. A string that names no side is logged and ignored.
    func show(side: String)
}

/// The connection to an evaluation provider's `evaluation` scene.
@_spi(FENblixHost)
@objc public protocol EvaluationSceneXPC: FENblixSceneXPC {

    /// Tells the scene the position its window now shows, a six-field FEN record,
    /// for the evaluator to analyze. There is no reply: the evaluator shows what it
    /// finds in the scene's view.
    func analyze(fen: String)
}

@_spi(FENblixHost)
extension NSXPCInterface {

    /// The interface of a theme's `board` scene.
    public static var boardScene: NSXPCInterface { NSXPCInterface(with: BoardSceneXPC.self) }

    /// The interface of a theme's `piece` scene.
    public static var pieceScene: NSXPCInterface { NSXPCInterface(with: PieceSceneXPC.self) }

    /// The interface of a theme's `tray` scene.
    public static var trayScene: NSXPCInterface { NSXPCInterface(with: TraySceneXPC.self) }

    /// The interface of an evaluation provider's `evaluation` scene.
    public static var evaluationScene: NSXPCInterface { NSXPCInterface(with: EvaluationSceneXPC.self) }
}
