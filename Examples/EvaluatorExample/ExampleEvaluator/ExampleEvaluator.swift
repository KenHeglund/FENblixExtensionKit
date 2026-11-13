// Created on 2026-10-17
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import ExtensionFoundation
import FENblixExtensionKit
import Observation
import SwiftUI

/// An example evaluation provider, shipped in an app of its own the way a third
/// party would ship one.
///
/// Its "evaluation" is a material count: the value of white's pieces minus black's.
/// That is not analysis, which is why this example never ships inside FENblix,
/// where its score could be mistaken for a real one. Like any extension that comes
/// with another app, it is off until the user turns it on in FENblix's Settings.
@main
struct ExampleEvaluator: EvaluationExtension {

    /// Binds this extension to FENblix's `evaluation` extension point.
    @AppExtensionPoint.Bind
    var extensionPoint: AppExtensionPoint {
        Identifier(host: "com.orderedbytes.FENblix", name: "evaluation")
    }

    /// A pretend engine for one window.
    func makeEvaluator() -> MaterialEvaluator {
        MaterialEvaluator()
    }
}

/// One window's evaluator: the material count of the position it was last sent,
/// "searched" to a simulated depth that rises over a couple of seconds.
@Observable
final class MaterialEvaluator: PositionEvaluator {

    /// The pretend search, which the view draws.
    private let analysis = SimulatedAnalysis()

    /// Starts the pretend search of `fen` afresh.
    func analyze(fen: String) {
        analysis.analyze(fen: fen)
    }

    /// A line saying what this is, then a line per depth reached, or why the
    /// position can't be counted.
    var body: some View {
        VStack(spacing: 2) {
            Text(
                "Example evaluator: material count, simulated depth",
                comment: "Caption over the analysis: it counts material and only pretends to search deeper."
            )
                .font(.caption)
                .foregroundStyle(.secondary)

            switch analysis.state {
            case .waiting:
                Text("Waiting for a position", comment: "Shown until FENblix sends the first position to analyze.")
                    .foregroundStyle(.secondary)
            case .analyzing(let depths, let isDeepening):
                ForEach(Array(depths.enumerated()), id: \.offset) { index, balance in
                    let isLatest = index == depths.count - 1
                    HStack(spacing: 4) {
                        Text(
                            "Depth \(index + 1)",
                            comment: "Labels a line of analysis. The argument is how deep the simulated search reached."
                        )
                        Text(SimulatedAnalysis.pawns(balance), format: SimulatedAnalysis.scoreFormat)
                        if isLatest, isDeepening {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                    .foregroundStyle(isLatest ? .primary : .secondary)
                    // One VoiceOver stop per depth, read as "Depth 3, +1.00",
                    // rather than the depth and the score separately.
                    .accessibilityElement(children: .combine)
                }
            case .failed(let reason):
                Text(reason)
                    .foregroundStyle(.red)
            }
        }
        .font(.callout.monospacedDigit())
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
