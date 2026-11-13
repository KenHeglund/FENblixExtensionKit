// Created on 2026-10-28
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import AppKit
import Foundation
@_spi(FENblixHost) @testable import FENblixExtensionKit
import SwiftUI
import Testing

/// The framework's side of an `evaluation` scene: the service the host sends
/// positions to, run over an in-process XPC connection — the same objects and
/// interfaces an extension uses, without ExtensionKit — and the content that lays
/// out the evaluator's view. These need no extension turned on.
@Suite("Evaluation scene", .timeLimit(.minutes(1)))
@MainActor
struct EvaluationSceneTests {

    /// The starting position.
    private static let first = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    /// The position after 1. e4.
    private static let second = "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
    /// The position after 1. e4 e5.
    private static let third = "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"

    @Test("The scene reports this framework's contract version")
    func contractVersion() async throws {
        let link = SceneLink(exporting: EvaluationSceneService(analyze: { _ in }), interface: { .evaluationScene })
        defer { link.close() }

        #expect(try await link.contractVersion() == Contract.version)
    }

    @Test("Positions reach the evaluator in the order the host sent them")
    func positionsInOrder() async throws {
        var received: [String] = []
        let link = SceneLink(
            exporting: EvaluationSceneService(analyze: { received.append($0) }),
            interface: { .evaluationScene }
        )
        defer { link.close() }

        let scene = try #require(link.connection.remoteObjectProxy as? EvaluationSceneXPC)
        for fen in [Self.first, Self.second, Self.third] {
            scene.analyze(fen: fen)
        }

        _ = try await poll { received.count == 3 ? true : nil }
        #expect(received == [Self.first, Self.second, Self.third])
    }

    @Test("A short view lies at the top of the scene, as wide as it")
    func shortViewAtTop() async throws {
        let evaluator = StandInEvaluator()
        let window = SceneWindow(showing: evaluator)
        defer { window.close() }

        let frame = try #require(try await poll { evaluator.frame })
        #expect(isClose(frame.minY, 0))
        #expect(isClose(frame.width, SceneWindow.size.width))
        #expect(isClose(frame.height, StandInEvaluator.lineHeight))
    }

    @Test("A view taller than the scene keeps its height, to be scrolled")
    func tallViewScrolls() async throws {
        let evaluator = StandInEvaluator()
        evaluator.lines = 40
        let window = SceneWindow(showing: evaluator)
        defer { window.close() }

        let frame = try #require(try await poll { evaluator.frame })
        #expect(isClose(frame.minY, 0))
        #expect(isClose(frame.height, 40 * StandInEvaluator.lineHeight))
        #expect(frame.height > SceneWindow.size.height)
    }

    /// Whether two lengths are within half a point, which layout's rounding allows.
    private func isClose(_ length: CGFloat, _ expected: CGFloat) -> Bool {
        abs(length - expected) < 0.5
    }
}

/// An evaluator whose view is a column of fixed-height lines, and which records
/// where its view was laid out.
@MainActor
@Observable
private final class StandInEvaluator: PositionEvaluator {

    /// The height of each line, in points.
    static let lineHeight = 20.0

    /// How many lines the view shows.
    var lines = 1

    /// Where the view was last laid out, in the window's coordinates.
    var frame: CGRect?

    /// Does nothing; these tests drive the view directly.
    func analyze(fen: String) {}

    /// `lines` lines, each `lineHeight` tall, with no spacing.
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<lines, id: \.self) { _ in
                Color.clear.frame(height: Self.lineHeight)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
            self.frame = frame
        }
    }
}

/// A window showing an `evaluation` scene's content for an evaluator, as the scene
/// would.
@MainActor
private final class SceneWindow {

    /// The size of the scene.
    static let size = CGSize(width: 300, height: 200)

    /// The window.
    private let window: NSWindow

    /// A window showing `evaluator`'s view in the scene's content, at `size`.
    init(showing evaluator: StandInEvaluator) {
        let view = NSHostingView(rootView: EvaluationSceneContent(evaluator: evaluator))
        view.frame = NSRect(origin: .zero, size: Self.size)
        window = NSWindow(contentRect: view.frame, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
    }

    /// Closes the window.
    func close() {
        window.close()
    }
}
