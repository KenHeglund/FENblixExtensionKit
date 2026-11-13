# Getting Started

Create an extension, bind it to FENblix, and turn it on.

## Overview

A FENblix extension is an ExtensionKit app extension carried by an app of your own.
FENblix finds it once the system has registered the app, and uses it once the user
has turned it on.

### Create the extension

In your app's project, add a target from Xcode's Generic Extension template, embedded
in the app, and add the `FENblixExtensionKit` library to that target. The library
links statically, so there is no framework to embed, and the app itself doesn't need
it.

Conform the extension's `@main` type to ``ThemeExtension`` or
``EvaluationExtension``, and implement its views.

### Bind it to FENblix

Bind the extension to FENblix's extension point in two places. Declare the binding
in your type:

```swift
@main
struct MyEngine: EvaluationExtension {
    @AppExtensionPoint.Bind
    var extensionPoint: AppExtensionPoint {
        Identifier(host: "com.orderedbytes.FENblix", name: "evaluation")
    }

    func makeEvaluator() -> MyEvaluator {
        MyEvaluator()
    }
}
```

And add the key the system reads to find it to the extension's Info.plist:

```xml
<key>EXAppExtensionAttributes</key>
<dict>
    <key>EXExtensionPointIdentifier</key>
    <string>com.orderedbytes.FENblix.evaluation</string>
</dict>
```

For a theme, the name is `theme` and the identifier
`com.orderedbytes.FENblix.theme`.

Without the Info.plist key, the extension builds cleanly and FENblix never finds it.
With `EX_ENABLE_EXTENSION_POINT_GENERATION` on, Xcode is meant to write the key from
the declaration, but as of Xcode 27.2 it writes nothing.

### Turn it on

Build and run your app once, so the system registers the extension. Then, in
FENblix, choose FENblix → Settings and turn the extension on. An extension that
another app provides is off until the user turns it on, and Settings is the only
place to do it, so tell your users how.

### Learn from the examples

The package's repository holds an Xcode project, `Examples/Examples.xcodeproj`,
with one example app for each role: `FENblixThemeExample` carries a theme, and
`FENblixEvaluatorExample` an evaluator that counts material.
