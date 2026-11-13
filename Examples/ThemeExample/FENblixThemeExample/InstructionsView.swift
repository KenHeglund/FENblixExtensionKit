// Created on 2026-11-13
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import SwiftUI

/// Explains what the extension does and how to turn it on in FENblix.
struct InstructionsView: View {

    /// The title, then the steps for turning the extension on in FENblix.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example Theme", comment: "Window heading: the name of the extension this app installs.")
                .font(.title2.bold())

            Text("""
                This app installs Example Theme, a theme extension for FENblix. It draws \
                the board, the piece trays and the pieces. It shows how an extension is \
                built and shipped.
                """,
                comment: "Describes the app and its extension. “Example Theme” and “FENblix” are names.")

            Text(
                "FENblix extensions that are provided by other apps are disabled until they are enabled in FENblix:",
                comment: "Introduces three numbered steps."
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("1. Open FENblix.", comment: "First of three steps for enabling the extension.")
                Text(
                    "2. Choose FENblix > Settings.",
                    comment: "Second step. FENblix > Settings is a menu item; match the name FENblix gives it."
                )
                Text(
                    "3. Enable Example Theme.",
                    comment: "Third step, in FENblix's Settings. “Example Theme” is the extension's name."
                )
            }
            .padding(.leading, 8)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 420, alignment: .leading)
        .padding(24)
    }
}
