// Created on 2026-10-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

/// The scenes the framework declares for an extension, by the names the host asks
/// for them with.
///
/// An extension author never names a scene. Conforming to `ThemeExtension` or
/// `EvaluationExtension` declares the scenes that role needs.
@_spi(FENblixHost)
public enum SceneID {

    /// One piece of a theme, told which piece to draw over its connection. The
    /// host opens one of these for every piece it shows.
    public static let piece = "piece"

    /// A theme's empty board.
    public static let board = "board"

    /// The background of one side's piece tray, told which side over its
    /// connection. The host opens one for each side.
    public static let tray = "tray"

    /// An evaluation provider's view, which it keeps up to date with its analysis of
    /// the position the host last sent. The host opens one for each window.
    public static let evaluation = "evaluation"
}
