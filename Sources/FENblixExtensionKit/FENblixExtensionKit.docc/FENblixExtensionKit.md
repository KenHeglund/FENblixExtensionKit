# ``FENblixExtensionKit``

Write themes and evaluation engines for FENblix.

## Overview

FENblix is a macOS app for viewing and editing chess positions written in FEN. It
hosts ExtensionKit app extensions in two roles: a theme draws the board, the piece
trays and the pieces, and an evaluation provider shows its assessment of the
position in the side panel.

An extension conforms its `@main` type to ``ThemeExtension`` or
``EvaluationExtension`` and supplies SwiftUI views. The framework declares the
scenes FENblix hosts, answers their connections, and passes on what each view needs
to know: which piece to draw, which side the board is seen from, or which position
to analyze.

## Topics

### Essentials

- <doc:GettingStarted>

### Themes

- ``ThemeExtension``
- ``PieceDescription``

### Evaluation

- ``EvaluationExtension``
- ``PositionEvaluator``
