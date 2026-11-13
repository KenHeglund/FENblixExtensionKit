# FENblixExtensionKit

The framework for writing extensions to **FENblix**, a macOS app for viewing and
editing chess positions written in FEN. An extension is an ExtensionKit app
extension, shipped inside an app of your own, in one of two roles:

- **Theme** (`ThemeExtension`) draws the board, the piece trays and the pieces.
- **Evaluation** (`EvaluationExtension`) shows your engine's assessment of the
  position in the side panel, and updates it as the analysis deepens.

You write SwiftUI views. The framework declares the scenes FENblix hosts and handles
the connections to them.

## Requirements

- macOS 26.5 or later
- Xcode 27 (Swift 6)

## Adding the package

In Xcode, choose File → Add Package Dependencies, enter
`https://github.com/KenHeglund/FENblixExtensionKit.git`, and add the
`FENblixExtensionKit` library to your **extension** target. The app that carries the
extension doesn't need it.

With Swift Package Manager:

```swift
.package(url: "https://github.com/KenHeglund/FENblixExtensionKit.git", from: "1.0.0")
```

The library links statically, so there is no framework to embed.

## Writing an extension

1. In your app's project, add a target from the **Generic Extension** template
   (ExtensionKit), embedded in the app.
2. Conform its `@main` type to `ThemeExtension` or `EvaluationExtension`, and
   implement the views.
3. Bind it to FENblix's extension point **in both places**: the
   `@AppExtensionPoint.Bind` declaration in your type, and the
   `EXAppExtensionAttributes` → `EXExtensionPointIdentifier` key in the extension's
   Info.plist. The identifiers are:

   | Role | Extension point |
   | --- | --- |
   | Theme | `com.orderedbytes.FENblix.theme` |
   | Evaluation | `com.orderedbytes.FENblix.evaluation` |

   Without the Info.plist key, the extension builds cleanly and FENblix never finds
   it. As of Xcode 27.2, Xcode doesn't write the key from the declaration.
4. Build and run the app once, so the system registers the extension.
5. In FENblix, choose FENblix → Settings and turn your extension on. An extension
   provided by another app is off until the user turns it on.

The documentation comments on `ThemeExtension`, `EvaluationExtension` and
`PositionEvaluator` cover the details: what size each view is given, how positions
arrive, and how to make an evaluation view usable with VoiceOver.

## Examples

`Examples/Examples.xcodeproj` holds two complete examples, each an app carrying one
extension, the way you would ship your own:

| Scheme | Extension | What it shows |
| --- | --- | --- |
| `FENblixThemeExample` | Example Theme | A board, trays and pieces drawn in SwiftUI. |
| `FENblixEvaluatorExample` | Example Evaluator | A pretend engine that counts material, deepening over time. It is not chess analysis. |

Build and run a scheme, then turn its extension on in FENblix's Settings. The
examples' bundle identifiers start with `com.example`; use your own in your
extension.

## Compatibility

Every scene connection starts with a check of the contract version the extension was
built with. FENblix accepts extensions built against the versions of this package it
supports, and reports any other as incompatible. Package versions follow semantic
versioning against that contract:

- **Patch**: fixes no extension would notice.
- **Minor**: changes that keep extensions built with earlier versions working.
- **Major**: FENblix stops accepting extensions built with earlier versions.

## License

MIT; see [LICENSE](LICENSE).
