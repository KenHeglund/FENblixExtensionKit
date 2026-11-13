// Created on 2026-10-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import ExtensionFoundation
import ExtensionKit
import Foundation
import SwiftUI

/// An evaluation provider: a view, shown in each FENblix window, in which the
/// extension draws its own assessment of the position that window shows, and keeps
/// it up to date as its analysis deepens.
///
/// Conform your extension's `@main` type to this and implement `makeEvaluator()`.
/// The framework supplies `configuration`, which declares the scene FENblix hosts and
/// handles the connection to it.
///
/// Bind to FENblix's `evaluation` extension point in two places. Declare the binding
/// in your type, which is the way ExtensionFoundation defines:
///
/// ```swift
/// @main
/// struct MyEngine: EvaluationExtension {
///     @AppExtensionPoint.Bind
///     var extensionPoint: AppExtensionPoint {
///         Identifier(host: "com.orderedbytes.FENblix", name: "evaluation")
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
///     <string>com.orderedbytes.FENblix.evaluation</string>
/// </dict>
/// ```
///
/// With `EX_ENABLE_EXTENSION_POINT_GENERATION` on, Xcode is meant to write that key
/// from the declaration, but as of Xcode 27.2 it writes nothing. Without the key
/// your extension builds cleanly and FENblix never finds it, so write it yourself.
public protocol EvaluationExtension: AppExtension where Configuration == AppExtensionSceneConfiguration {

    // The requirement is `@MainActor`, not the protocol, for the reason given in
    // `ThemeExtension`: a target built with main-actor default isolation conforms
    // to `AppExtension` with a main-actor-isolated conformance, and a conformance
    // to a `@MainActor` protocol cannot rest on one of those.

    /// The object that analyzes one window's positions and draws the result.
    associatedtype Evaluator: PositionEvaluator

    /// Makes the evaluator for one window.
    ///
    /// Called once for each window that uses your extension. Every window has its
    /// own evaluator, but all of them run in one process, on the main actor, so
    /// share an engine between them if you like.
    @MainActor func makeEvaluator() -> Evaluator
}

/// Analyzes the positions one FENblix window shows, and draws what it finds.
///
/// Usually an `@Observable` class whose `body` reads its own state, so that
/// updating that state as the analysis deepens redraws the view.
///
/// ```swift
/// @Observable
/// final class MyEvaluator: PositionEvaluator {
///     private var analysis: Task<Void, Never>?
///     private var line = "Waiting for a position"
///
///     func analyze(fen: String) {
///         analysis?.cancel()
///         analysis = Task {
///             for depth in 1... {
///                 guard let result = await search(fen, depth: depth),
///                       !Task.isCancelled else { return }
///                 line = result.description
///             }
///         }
///     }
///
///     var body: some View {
///         Text(line)
///     }
/// }
/// ```
public protocol PositionEvaluator: AnyObject {

    // `@MainActor` on the requirements, not the protocol, matching
    // `EvaluationExtension`.

    /// The view `body` returns.
    associatedtype Body: View

    /// Starts analyzing `fen`, a six-field FEN record: the position the window now
    /// shows.
    ///
    /// Return at once and do the work in a task of your own. Each call replaces
    /// the last: cancel any analysis still running, and make sure no result from
    /// an earlier position reaches your view after this call. Calls arrive in the
    /// order FENblix made them.
    @MainActor func analyze(fen: String)

    /// The evaluation, drawn however you like.
    ///
    /// It is as wide as the side panel beside the board, and lies at the top of the
    /// space FENblix gives it there, between the FEN and the buttons. That space
    /// depends on the window, not on your view: a view taller than it scrolls
    /// vertically, and the user scrolls it in your extension's process, so a
    /// control in it can be clicked too. Before the first `analyze(fen:)`, draw a
    /// resting state, such as "Waiting for a position", or nothing.
    ///
    /// Make the view navigable with VoiceOver, whatever it draws. FENblix presents
    /// it to VoiceOver as the contents of a group labeled "Evaluation", which the
    /// user steps into, and from there VoiceOver reads only what your accessibility
    /// markup says. Your view may be text, a chart, a gauge, a picture of the
    /// board, or anything else; what matters is that each part the user needs to
    /// know about can be reached and makes sense on its own. In SwiftUI terms:
    /// give such a part an accessibility label, and a value where it has one;
    /// combine parts that belong together into one element, so the user does not
    /// step through fragments; hide what is only decoration; and describe a
    /// graphic in words, since VoiceOver cannot see it. VoiceOver does not announce
    /// a change in the view by itself. To have a change heard, post an
    /// `AccessibilityNotification.Announcement`; each announcement cuts off the one
    /// before, so announce only what matters.
    @MainActor @ViewBuilder var body: Body { get }
}

@MainActor
extension EvaluationExtension {

    /// Starts the extension. `@main` calls this; see `runSceneExtension(_:)` for
    /// why the framework has to supply it.
    public static func main() throws {
        try runSceneExtension(Self.self)
    }

    /// The `evaluation` scene.
    public var configuration: AppExtensionSceneConfiguration {
        // The argument is an autoclosure that ExtensionKit evaluates once per scene
        // session, so every window gets its own evaluator, shared only by that
        // window's view and that window's connection.
        AppExtensionSceneConfiguration(evaluationScene())
    }

    /// The `evaluation` scene: this window's evaluator's view, and a connection
    /// that passes positions to it.
    private func evaluationScene() -> PrimitiveAppExtensionScene {
        let evaluator = makeEvaluator()
        // `onConnection` is `@Sendable`, and the author's evaluator need not be;
        // the box is, being main-actor isolated, like every use of the evaluator.
        let handle = EvaluatorHandle(evaluator)
        return PrimitiveAppExtensionScene(id: SceneID.evaluation) {
            EvaluationSceneContent(evaluator: evaluator)
        } onConnection: { connection in
            connection.exportedInterface = NSXPCInterface.evaluationScene
            connection.exportedObject = EvaluationSceneService { fen in
                handle.evaluator.analyze(fen: fen)
            }
            connection.resume()
            return true
        }
    }
}

/// An evaluator in a box that can cross to the closures ExtensionKit calls on its
/// own queues, for use back on the main actor.
@MainActor
final class EvaluatorHandle<Evaluator: PositionEvaluator> {

    /// The evaluator.
    let evaluator: Evaluator

    /// A box holding `evaluator`.
    init(_ evaluator: Evaluator) {
        self.evaluator = evaluator
    }
}

/// What an `evaluation` scene draws: the evaluator's view, at the top of a vertical
/// scroll view that fills the scene.
///
/// The host sizes the scene to the space it has, whatever the view's height, so a
/// taller view scrolls here, in the extension's process. That is where scroll events
/// over a hosted scene go anyway: the window server hands them to the process that
/// draws it. The scroll view fills the scene from the start, safe area included,
/// for the reasons given on `PieceSceneContent`.
struct EvaluationSceneContent<Evaluator: PositionEvaluator>: View {

    /// The evaluator whose view this shows.
    let evaluator: Evaluator

    /// The evaluator's view, full width, at the top of a scroll view.
    var body: some View {
        ScrollView(.vertical) {
            evaluator.body
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }
}

/// The object an `evaluation` scene exports to the host.
///
/// XPC calls arrive on a background queue, and each hops to the main queue in the
/// order it arrived: `DispatchQueue.main` promises that order, which separate
/// main-actor `Task`s don't, and the evaluator is promised its positions in the
/// order the host sent them.
final class EvaluationSceneService: NSObject, EvaluationSceneXPC, Sendable {

    /// Passes a position to the evaluator.
    private let analyze: @MainActor (String) -> Void

    /// A service that passes each position to `analyze`.
    init(analyze: @escaping @MainActor (String) -> Void) {
        self.analyze = analyze
    }

    /// Replies with the version of the framework the extension was built with.
    func contractVersion(reply: @escaping @Sendable (Int) -> Void) {
        reply(Contract.version)
    }

    /// Hops to the main queue, in arrival order, to pass `fen` on.
    func analyze(fen: String) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.analyze(fen)
            }
        }
    }
}
