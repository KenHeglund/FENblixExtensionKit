// Created on 2026-11-04
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Foundation
import Synchronization
import Testing

// `SimulatedAnalysis` belongs to the ExampleEvaluator extension, which is not a
// module a test can import. This target compiles its source file directly
// instead.
@Suite("Example evaluator simulated analysis", .timeLimit(.minutes(1)))
@MainActor
struct SimulatedAnalysisTests {

    /// The starting position, which is level.
    private static let level = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    /// The starting position without black's queen: white is up 9.
    private static let whiteUp = "rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    /// The state of a search of `whiteUp` that has finished.
    private static let whiteUpFinished = SimulatedAnalysis.State.analyzing(
        depths: Array(repeating: 900, count: SimulatedAnalysis.deepestDepth),
        isDeepening: false
    )

    @Test("Before any position it is waiting")
    func waiting() {
        #expect(SimulatedAnalysis(pause: {}).state == .waiting)
    }

    @Test("Depth 1 is shown as soon as a position arrives")
    func depthOneAtOnce() {
        let gate = Gate()
        let analysis = SimulatedAnalysis(pause: gate.wait)

        analysis.analyze(fen: Self.whiteUp)

        #expect(analysis.state == .analyzing(depths: [900], isDeepening: true))
        gate.open()
    }

    @Test("The search deepens a depth at a time, then stops")
    func deepens() async throws {
        let steps = Gate.Stepper()
        let analysis = SimulatedAnalysis(pause: steps.wait)
        analysis.analyze(fen: Self.whiteUp)

        for depth in 2...SimulatedAnalysis.deepestDepth {
            steps.release()
            let expected = SimulatedAnalysis.State.analyzing(
                depths: Array(repeating: 900, count: depth),
                isDeepening: depth < SimulatedAnalysis.deepestDepth
            )
            let reached = try await poll { analysis.state == expected ? true : nil }
            #expect(reached == true, "depth \(depth)")
        }
        #expect(analysis.state == Self.whiteUpFinished)
    }

    @Test("A new position starts again from depth 1, and the old search never reaches the view")
    func newPositionRestarts() async throws {
        let gate = Gate()
        let analysis = SimulatedAnalysis(pause: gate.wait)

        analysis.analyze(fen: Self.level)
        analysis.analyze(fen: Self.whiteUp)
        #expect(analysis.state == .analyzing(depths: [900], isDeepening: true))

        // Lets both searches go. The first was waiting on its first step and
        // resumes no later than the second's first, so by the time the second has
        // finished, the first has had every chance to write.
        gate.open()
        _ = try await poll { analysis.state == Self.whiteUpFinished ? true : nil }
        await Task.yield()

        #expect(analysis.state == Self.whiteUpFinished)
    }

    @Test("A position that can't be counted shows why, and stops the previous search")
    func failure() async throws {
        let gate = Gate()
        let analysis = SimulatedAnalysis(pause: gate.wait)
        analysis.analyze(fen: Self.whiteUp)

        analysis.analyze(fen: "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1")
        gate.open()
        for _ in 0..<10 {
            await Task.yield()
        }

        #expect(analysis.state == .failed(MaterialCountError.rankCount(7).localizedDescription))
    }

    @Test("A score is shown in pawns, with a sign and two decimals", arguments: [
        (0, "0.00"),
        (900, "+9.00"),
        (-30, "-0.30"),
        (125, "+1.25"),
        (-1, "-0.01")
    ])
    func pawns(centipawns: Int, expected: String) {
        #expect(Self.score(centipawns, in: "en_US") == expected)
    }

    @Test("A score follows the locale's decimal separator", arguments: [
        ("en_US", "+1.25"),
        ("de_DE", "+1,25"),
        ("fr_FR", "+1,25")
    ])
    func pawnsInLocale(identifier: String, expected: String) {
        #expect(Self.score(125, in: identifier) == expected)
    }

    /// `centipawns` as the evaluator's view shows it in the locale `identifier`.
    private static func score(_ centipawns: Int, in identifier: String) -> String {
        SimulatedAnalysis.pawns(centipawns)
            .formatted(SimulatedAnalysis.scoreFormat.locale(Locale(identifier: identifier)))
    }
}

/// A pause that holds every caller until it is opened, and lets later ones straight
/// through. It ignores cancellation, as a careless engine might, so the analysis
/// has to check for that itself.
private final class Gate: Sendable {

    /// Whether the gate is open, and the callers waiting while it isn't.
    private let state = Mutex<(isOpen: Bool, waiting: [CheckedContinuation<Void, Never>])>((false, []))

    /// Returns once the gate is open.
    @Sendable func wait() async {
        await withCheckedContinuation { continuation in
            let isOpen = state.withLock { state in
                if !state.isOpen {
                    state.waiting.append(continuation)
                }
                return state.isOpen
            }
            if isOpen {
                continuation.resume()
            }
        }
    }

    /// Opens the gate, letting every caller through.
    func open() {
        let waiting = state.withLock { state in
            state.isOpen = true
            defer { state.waiting = [] }
            return state.waiting
        }
        waiting.forEach { $0.resume() }
    }

    /// A pause that lets one caller through for each `release()`, whichever comes
    /// first.
    final class Stepper: Sendable {

        /// Releases not yet used, and the callers waiting for one.
        private let state = Mutex<(released: Int, waiting: [CheckedContinuation<Void, Never>])>((0, []))

        /// Returns once there is a release for this call.
        @Sendable func wait() async {
            await withCheckedContinuation { continuation in
                let proceeds = state.withLock { state in
                    if state.released > 0 {
                        state.released -= 1
                        return true
                    }
                    state.waiting.append(continuation)
                    return false
                }
                if proceeds {
                    continuation.resume()
                }
            }
        }

        /// Lets one waiting caller through, or the next one to call.
        func release() {
            let next = state.withLock { state -> CheckedContinuation<Void, Never>? in
                if state.waiting.isEmpty {
                    state.released += 1
                    return nil
                }
                return state.waiting.removeFirst()
            }
            next?.resume()
        }
    }
}
