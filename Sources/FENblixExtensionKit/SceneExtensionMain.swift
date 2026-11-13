// Created on 2026-10-17
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import ExtensionFoundation
import ExtensionKit

/// Runs an extension through ExtensionKit's entry point for scene configurations.
///
/// The author protocols' `main()` calls this, and must, because of how `@main`
/// resolves. An author's type gets `configuration` from a default in the
/// framework, and with that default the compiler binds `@main` to
/// ExtensionFoundation's `AppExtension.main()`, not to ExtensionKit's
/// `main()` for `Configuration == AppExtensionSceneConfiguration`. The extension
/// still launches, but it never builds a scene: every session fails with
/// ExtensionKit error 14, "Extension failed to return scene".
///
/// A protocol's own `main()` cannot call `main()` itself without calling itself.
/// This function knows only that its argument is an `AppExtension` with a scene
/// configuration, so the one `main()` it can see is ExtensionKit's.
@MainActor
func runSceneExtension<Extension: AppExtension>(_: Extension.Type) throws
where Extension.Configuration == AppExtensionSceneConfiguration {
    try Extension.main()
}
