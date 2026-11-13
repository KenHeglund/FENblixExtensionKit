// Created on 2026-11-04
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Foundation
import Observation

/// A pretend engine for one window: it shows the material count of the position at
/// once, then "searches" deeper, one depth every `step`, down to `deepestDepth`.
///
/// Nothing is searched. The score at every depth is the same material count, and
/// only the depth changes. It exists to show how an evaluator refines its view
/// over time: the view grows a line per depth, a new position starts again from
/// depth 1, and nothing about an earlier position reaches the view once a new one
/// has arrived.
@MainActor
@Observable
final class SimulatedAnalysis {

    /// What the analysis has to show.
    enum State: Equatable {
        /// No position yet.
        case waiting
        /// Analyzing a position: the score at each depth reached so far, depth 1
        /// first, and whether deeper ones are still to come.
        case analyzing(depths: [Int], isDeepening: Bool)
        /// The position can't be counted, and why.
        case failed(String)
    }

    /// How deep the pretend search goes.
    static let deepestDepth = 5

    /// How long each depth past the first takes, by default.
    static let defaultStep = Duration.milliseconds(500)

    /// What to show now.
    private(set) var state = State.waiting

    /// Waits out one depth's pretend search. A `var` only so that
    /// `init(pause:)`, for unit tests, can replace it; nothing else changes it.
    @ObservationIgnored private var pause: @Sendable () async throws -> Void

    /// The search for the current position, while it is deepening.
    private var search: Task<Void, Never>?

    /// An analysis that spends `step` on each depth past the first.
    init(step: Duration = SimulatedAnalysis.defaultStep) {
        pause = { try await Task.sleep(for: step) }
    }

    /// Starts again on `fen`: stops the search of the previous position, shows
    /// depth 1 at once, and deepens from there.
    func analyze(fen: String) {
        search?.cancel()
        search = nil

        let balance: Int
        do {
            balance = try MaterialCount(fen: fen).balance
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        state = .analyzing(depths: [balance], isDeepening: true)
        search = Task { [weak self, pause] in
            for depth in 2...Self.deepestDepth {
                do {
                    try await pause()
                } catch {
                    return
                }
                // `analyze(fen:)` cancels this task before it changes `state`, and
                // both run on the main actor, so a canceled search never gets here.
                guard let self, !Task.isCancelled else { return }
                self.state = .analyzing(
                    depths: Array(repeating: balance, count: depth),
                    isDeepening: depth < Self.deepestDepth
                )
            }
        }
    }

    /// How a score in pawns is shown: signed except at zero, with two decimals,
    /// as `+1.00`, `-0.30` or `0.00` in English and `+1,00` in German. It has no
    /// locale of its own, so `Text(_:format:)` gives it the view's.
    static let scoreFormat = Decimal.FormatStyle.number
        .precision(.fractionLength(2))
        .sign(strategy: .always(includingZero: false))

    /// `centipawns` in pawns, exactly, for `scoreFormat`.
    static func pawns(_ centipawns: Int) -> Decimal {
        Decimal(centipawns) / 100
    }
}

// MARK: - Unit testing only

extension SimulatedAnalysis {

    /// An analysis that calls `pause` before each depth past the first. Exists only
    /// for unit tests, which pass a pause of their own to set the pace, and one that
    /// ignores cancellation to check that a stale search never reaches the view.
    convenience init(pause: @escaping @Sendable () async throws -> Void) {
        self.init(step: .zero)
        self.pause = pause
    }
}
