// Created on 2026-10-29
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import SwiftUI

/// The app that carries the Example Theme extension.
///
/// It exists to install the extension, the way a third party's app would. All it
/// shows is how to turn the extension on, since that happens in FENblix, not here.
@main
struct FENblixThemeExampleApp: App {

    /// One window, sized to its instructions.
    var body: some Scene {
        Window(
            Text("FENblix Theme Example", comment: "Window title: the name of the app carrying Example Theme."),
            id: "instructions"
        ) {
            InstructionsView()
        }
        .windowResizability(.contentSize)
    }
}
