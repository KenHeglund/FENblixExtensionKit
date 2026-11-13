# FENblixExtensionKit

The public framework for writing extensions to **FENblix**, a macOS app for viewing
and editing chess positions written in FEN (Forsyth–Edwards Notation), plus two
example apps that each carry one extension. FENblix itself is closed source; this
repo is everything a third party sees.

Extensions are ExtensionKit app extensions in two roles:

- **Themes** (`ThemeExtension`) draw the board, the piece trays and the pieces.
- **Evaluation providers** (`EvaluationExtension`) show an engine's assessment of the
  current position.

The public API is a contract with third parties. Treat any change to its shape, or
to anything an extension would notice over the wire, as a breaking change: propose
it before implementing it.

## Layout

| Path | What it is |
| --- | --- |
| `Package.swift`, `Sources/FENblixExtensionKit/` | The library. One product, linked statically into each extension. |
| `Sources/FENblixExtensionKit/FENblixExtensionKit.docc/` | The DocC landing page and articles. |
| `Tests/FENblixExtensionKitTests/` | The package's tests (Swift Testing). |
| `Examples/Examples.xcodeproj` | The example apps. Depends on the package by relative path (`..`). |
| `Examples/ThemeExample/` | `FENblixThemeExample` app carrying the `ExampleTheme` extension. |
| `Examples/EvaluatorExample/` | `FENblixEvaluatorExample` app carrying the `ExampleEvaluator` extension. |
| `Examples/ExampleEvaluatorTests/` | Tests for the evaluator example's logic. |

## Build and test

Use these wrappers rather than calling `xcodebuild` directly. Raw `xcodebuild` output
includes full `swift-frontend` invocations, thousands of lines per run.

| Command | What it does |
| --- | --- |
| `scripts/build.sh` | Builds the package and both example apps. Prints compiler diagnostics only, then `OK`. |
| `scripts/test.sh` | Runs the package's tests and the example evaluator's. |
| `scripts/test.sh --filter 'Suite/testName()'` | One package test. Swift Testing names a test function with its parentheses; without them nothing runs. |
| `scripts/clean.sh` | Unregisters the example apps and wipes the package's and the examples' DerivedData. |
| `scripts/sync-strings.sh` | Builds, then syncs each example target's `Localizable.xcstrings` and checks each `InfoPlist.xcstrings` against its build settings. |
| `swiftlint` | Lints everything; config in `.swiftlint.yml`. |

`scripts/test.sh` reports from the `.xcresult` bundle, not the console. A run in
which **no tests executed** is a failure. The package's tests run under `xcodebuild
test`, not `swift test`, for the result bundle; they include laying out a SwiftUI
view in a real `NSWindow`, which works without a host app.

None of the tests needs an extension turned on in FENblix.

## Toolchain

- Xcode 27, Swift 6.4 toolchain, macOS 27 SDK; macOS 26.5 deployment target.
- Swift 6 language mode everywhere, so strict concurrency is enforced. Don't reach
  for `@unchecked Sendable` or `nonisolated(unsafe)` without saying why it's safe.
- The library has the default (nonisolated) isolation. The example targets use
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, as Xcode makes new targets, so the
  examples check that the author protocols work for a target built that way.

## The framework

- **An author conforms one type and writes SwiftUI views.** The author protocol's
  default `configuration` declares the scenes (named in `SceneID`) and answers their
  connections. Each view is its own scene: a theme has `board`, `tray` and `piece`
  scenes, an evaluator one `evaluation` scene.
- **Host-only SPI.** The XPC protocols (`XPCProtocols.swift`), `Contract`, `SceneID`
  and the wire format of `PieceDescription` are `@_spi(FENblixHost)`: public so
  FENblix can use them, but outside the API authors are promised. FENblix imports
  the package with `@_spi(FENblixHost) import FENblixExtensionKit`.
- **Author protocols put `@MainActor` on their requirements, not on the protocol**,
  matching `AppExtension`. A target with main-actor default isolation conforms to
  `AppExtension` with a main-actor-isolated conformance, and a conformance to a
  `@MainActor` protocol cannot rest on that.
- **Author protocols supply `static func main()`, and it is not redundant.** Because
  `configuration` comes from a default here, the compiler would otherwise bind
  `@main` to ExtensionFoundation's generic `AppExtension.main()` rather than
  ExtensionKit's, and every scene session fails with ExtensionKit error 14,
  "Extension failed to return scene". Each `main()` forwards through
  `runSceneExtension(_:)`. To check a built extension, disassemble `$main` in its
  `.debug.dylib` (`otool -tV -p <symbol>`, piped through `swift-demangle`): it
  should call `ThemeExtension.main()` or `EvaluationExtension.main()`.
- **ExtensionKit evaluates the scene configuration once per scene session**, though
  all of one extension's scenes run in one process. So an object created in that
  evaluation and captured by both a scene's content and its `onConnection` belongs
  to exactly one session: that is how `ShownPiece` and `ShownSide` link a
  connection to its view.
- **A scene's content fills the scene from the start**, with
  `.frame(maxWidth: .infinity, maxHeight: .infinity)`. A `piece` scene that drew
  nothing until told its piece crashed the extension in AppKit's update-constraints
  pass.
- **Every scene's content ignores the safe area.** A hosted scene gets the host
  window's title-bar safe area where it overlaps the title bar, and a dragged piece
  shrank against it.
- **XPC protocols take `reply:` closures, not `async` requirements.** If the
  extension dies mid-call, an `async` requirement's `await` never returns; with a
  closure the host resumes from whichever of the reply and the proxy's error handler
  fires first. The host only calls; the extension exports one object per scene.
- **Positions reach an evaluator in order, on the main actor**, through
  `DispatchQueue.main` (which keeps order), not separate `Task`s. The evaluator
  schedules and cancels its own work. Nothing comes back to the host but the view.
- `EvaluationSceneContent` puts the evaluator's `body` at the top of a vertical
  `ScrollView`, full width, so a taller view scrolls in the extension's process.
- A `board` scene is told the side it is seen from (`w`/`b`) at once and on every
  flip; a `tray` scene its side once; a `piece` scene its piece (a FEN placement
  character) once. Each draws nothing until told. A string that names nothing is
  logged and ignored.

## The contract and versions

- Every scene connection starts with the host asking for `contractVersion`, and
  refusing an extension outside `Contract.supportedVersions`
  (`minimumSupportedVersion...version`). Any change an extension would notice
  raises `Contract.version`.
- Package versions are semantic, starting at 1.0.0 with contract version 1:
  - **patch**: fixes no extension would notice;
  - **minor**: a contract change that keeps older extensions working (raises
    `version` only);
  - **major**: raising `minimumSupportedVersion`, which drops older extensions.

  For now `minimumSupportedVersion` rises with `version`, so every contract change
  is a major version, until extensions exist outside these repos.
- FENblix depends on this package by version. Tag a release before FENblix depends
  on it; FENblix never pins an unreleased commit.

## Binding and discovery

- The extension point IDs belong to FENblix: `com.orderedbytes.FENblix.theme` and
  `com.orderedbytes.FENblix.evaluation`.
- **An extension binds in two places**: `@AppExtensionPoint.Bind var
  extensionPoint` with `Identifier(host:name:)`, and the Info.plist key
  `EXAppExtensionAttributes` → `EXExtensionPointIdentifier`, which is what discovery
  reads. As of Xcode 27.2, `exutil generate-appextension-plist` writes an empty
  dictionary, so the key is hand-written: `ExampleTheme-Info.plist` and
  `ExampleEvaluator-Info.plist`. Without it, an extension builds and is never found.
- An extension in another app is **off until the user turns it on** in FENblix →
  Settings. Building its app registers it with Launch Services; it need not be
  launched.

## Examples

- Each example is an app carrying one extension, the way a third party ships one.
  Bundle IDs start with `com.example.FENblix.` (`ThemeExample`, `EvaluatorExample`),
  each extension's under its app's. The README tells authors to use their own.
- FENblix's own tests host the real Example Theme: FENblix's repo builds this repo's
  examples from a checkout beside it. Keep `com.example.FENblix.ThemeExample.ExampleTheme`
  stable, or change FENblix's tests with it.
- `ExampleEvaluatorTests` compiles every file of the `ExampleEvaluator` folder except
  `ExampleEvaluator.swift` and the catalogs (membership exceptions), because the
  extension is not a module a test can import.
- The evaluator example counts material and pretends to search deeper. Its
  instructions say it is not chess analysis; keep it that way.

## Conventions

Every source file begins with this two-line header; note the two spaces after
`OrderedBytes.`:

```swift
// Created on YYYY-MM-DD
// Copyright © YYYY OrderedBytes.  Licensed under the MIT License; see LICENSE.
```

`Created on` records the date the file was created and does not change afterward.

**Every property and function has a doc comment** (`///`), whatever its access
level, including `body`, overrides, protocol requirements and private helpers; types
and enum cases too. SwiftLint's `missing_docs` enforces it, except in the test
targets, whose `@Test("…")` names describe each test; their helpers are documented
by hand.

**Spelling is traditional American English**: "analyze", "canceled", "color",
"behavior". Apple's names stay as they are (`Task.isCancelled`).

**Chess sides** are "white" and "black", lowercase in running text, never "light" and
"dark".

**Localization.** Every string the user sees or hears is localizable, through
`String(localized:comment:)` or `Text(_:comment:)`, with a comment for the
translator. One whole sentence per string; no grammar built in code. Interface text
uses typographic punctuation (“ ” ’). The library shows no text and has no catalog.
Each example target that shows text has a `Localizable.xcstrings` in its folder, and
each example target's display name is in an `InfoPlist.xcstrings` whose English must
match the build settings. A command-line build never writes to a catalog, so run
`scripts/sync-strings.sh` after changing user-visible text. Log messages and
identifiers are not localized.

## Testing

- Unit tests use **Swift Testing** (`@Test`, `#expect`, `#require`, `struct`
  suites). Don't add XCTest.
- The package's scene tests run the framework's real services behind an anonymous
  `NSXPCListener` (`SceneLink`), with the same interfaces an extension uses and no
  ExtensionKit.
