// Created on 2026-10-16
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import FENblixExtensionKit
import SwiftUI

/// One piece: a shape for its kind, filled for its side, with its kind's letter
/// on top.
struct ExamplePiece: View {

    /// The piece to draw.
    let piece: PieceDescription

    /// The shape, its outline and the letter, scaled to fit the scene.
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                shape
                    .fill(fill)
                shape
                    .stroke(ink, lineWidth: side * 0.04)
                Text(letter)
                    .font(.system(size: side * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
            }
            .frame(width: side * extent.width, height: side * extent.height)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    /// The outline for the piece's kind, so kinds differ by more than the letter.
    private var shape: AnyShape {
        switch piece.kind {
        case .king: AnyShape(Decagon(cornerRadius: Self.cornerRadius))
        case .queen: AnyShape(Octagon(cornerRadius: Self.queenCornerRadius))
        case .rook: AnyShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        case .bishop: AnyShape(Hexagon(cornerRadius: Self.cornerRadius))
        case .knight: AnyShape(Diamond(cornerRadius: Self.cornerRadius))
        case .pawn: AnyShape(Circle())
        }
    }

    /// The radius, in points, of the rounded corners of every piece but a pawn and a
    /// queen.
    private static let cornerRadius: CGFloat = 6

    /// The radius, in points, of a queen's rounded corners: smaller than the others',
    /// so its points are sharper.
    private static let queenCornerRadius: CGFloat = 2

    /// How much of the square the shape fills, as fractions of its side. Pawns are
    /// smaller, and a rook is an upright rectangle: 30% narrower and 15% shorter
    /// than the other pieces. A knight is a diamond 10% smaller each way, so a
    /// little taller than a rook. A bishop is a regular hexagon as tall as a rook.
    private var extent: CGSize {
        switch piece.kind {
        case .pawn: CGSize(width: 0.58, height: 0.58)
        case .rook: CGSize(width: 0.78 * 0.7, height: 0.78 * 0.85)
        case .knight: CGSize(width: 0.78 * 0.9, height: 0.78 * 0.9)
        case .bishop: CGSize(width: 0.78 * 0.85 * Hexagon.aspectRatio, height: 0.78 * 0.85)
        case .king, .queen: CGSize(width: 0.78, height: 0.78)
        }
    }

    /// The kind's letter, uppercase for both sides.
    private var letter: String {
        switch piece.kind {
        case .king: "K"
        case .queen: "Q"
        case .rook: "R"
        case .bishop: "B"
        case .knight: "N"
        case .pawn: "P"
        }
    }

    /// Inside the shape: cream for white, a dark plum for black.
    private var fill: Color {
        piece.side == .white ? Color(red: 0.99, green: 0.96, blue: 0.86) : Color(red: 0.16, green: 0.12, blue: 0.22)
    }

    /// The outline and the letter.
    private var ink: Color {
        piece.side == .white ? Color(red: 0.16, green: 0.12, blue: 0.22) : Color(red: 0.99, green: 0.96, blue: 0.86)
    }
}

/// A square standing on one corner, its corners rounded.
private nonisolated struct Diamond: Shape {

    /// The radius, in points, of the arc that rounds each corner.
    let cornerRadius: CGFloat

    /// The diamond that fills `rect`, its corners at the midpoints of the edges.
    func path(in rect: CGRect) -> Path {
        Path(roundedPolygon: [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.midY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.midY)
        ], cornerRadius: cornerRadius)
    }
}

/// A regular hexagon with a vertex at the top and bottom and flat left and right
/// sides, its corners rounded.
private nonisolated struct Hexagon: Shape {

    /// Width over height: √3 / 2, as for any regular hexagon standing on a vertex.
    static let aspectRatio = CGFloat(3).squareRoot() / 2

    /// The radius, in points, of the arc that rounds each corner.
    let cornerRadius: CGFloat

    /// The hexagon that fills `rect`, given `rect` has its proportions: vertices at
    /// the top and bottom middle, and the flat sides along the left and right edges,
    /// from a quarter of the height to three quarters.
    func path(in rect: CGRect) -> Path {
        let upperY = rect.minY + rect.height / 4
        let lowerY = rect.maxY - rect.height / 4
        return Path(roundedPolygon: [
            CGPoint(x: rect.midX, y: rect.minY),
            CGPoint(x: rect.maxX, y: upperY),
            CGPoint(x: rect.maxX, y: lowerY),
            CGPoint(x: rect.midX, y: rect.maxY),
            CGPoint(x: rect.minX, y: lowerY),
            CGPoint(x: rect.minX, y: upperY)
        ], cornerRadius: cornerRadius)
    }
}

/// A regular octagon with vertices at the top, bottom, left and right, its sides
/// bowed slightly inward and its corners rounded.
private nonisolated struct Octagon: Shape {

    /// How far each side bows in at its middle, as a fraction of its length.
    private static let sideDepth: CGFloat = 0.1

    /// How far, in points, each corner's rounding reaches along the sides that meet
    /// there.
    let cornerRadius: CGFloat

    /// The octagon that fills `rect`, its vertices every 45° on the ellipse that
    /// fits `rect`, starting at the right; a square `rect` makes it regular.
    ///
    /// Each side is a quadratic curve whose control point is pulled in toward the
    /// center from the side's midpoint, twice as far as the side bows, since a
    /// quadratic curve passes halfway to its control point. Each side stops short of
    /// its ends, and a curve joins it to the next. That curve's control point is
    /// where the two sides' tangents meet, so the outline has no kink.
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let vertices = (0..<8).map { index in
            let angle = CGFloat(index) * .pi / 4
            return CGPoint(x: rect.midX + rect.width / 2 * cos(angle), y: rect.midY + rect.height / 2 * sin(angle))
        }
        let sides = vertices.indices.map { index in
            BowedSide(from: vertices[index], to: vertices[(index + 1) % vertices.count], toward: center)
                .trimmed(by: cornerRadius)
        }
        return Path { path in
            path.move(to: sides[0].start)
            for (index, side) in sides.enumerated() {
                let next = sides[(index + 1) % sides.count]
                path.addQuadCurve(to: side.end, control: side.control)
                path.addQuadCurve(to: next.start, control: side.tangentsMeet(next))
            }
            path.closeSubpath()
        }
    }

    /// One side of the octagon: a quadratic curve from `start` to `end`.
    private struct BowedSide {

        /// Where the side starts.
        let start: CGPoint

        /// The curve's control point.
        let control: CGPoint

        /// Where the side ends.
        let end: CGPoint

        /// The side from `start` to `end`, bowed toward `center` by `sideDepth` of its
        /// length.
        init(from start: CGPoint, to end: CGPoint, toward center: CGPoint) {
            let middle = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let inward = CGPoint(x: center.x - middle.x, y: center.y - middle.y)
            let inwardLength = hypot(inward.x, inward.y)
            let offset = 2 * Octagon.sideDepth * hypot(end.x - start.x, end.y - start.y)
            self.init(
                start: start,
                control: CGPoint(
                    x: middle.x + inward.x / inwardLength * offset,
                    y: middle.y + inward.y / inwardLength * offset
                ),
                end: end
            )
        }

        /// The side given its three points.
        private init(start: CGPoint, control: CGPoint, end: CGPoint) {
            self.start = start
            self.control = control
            self.end = end
        }

        /// The part of this side that is left once `distance` points, roughly, are
        /// taken off each end, at most a third of it.
        ///
        /// It is cut at parameters t and 1 − t; the part between is again a quadratic
        /// curve, whose control point is the blossom of the two parameters.
        func trimmed(by distance: CGFloat) -> BowedSide {
            let t = min(distance / hypot(end.x - start.x, end.y - start.y), 1.0 / 3)
            return BowedSide(start: point(t, t), control: point(t, 1 - t), end: point(1 - t, 1 - t))
        }

        /// Where the tangent at this side's end meets the tangent at `next`'s start.
        func tangentsMeet(_ next: BowedSide) -> CGPoint {
            let direction = CGPoint(x: end.x - control.x, y: end.y - control.y)
            let nextDirection = CGPoint(x: next.control.x - next.start.x, y: next.control.y - next.start.y)
            let cross = direction.x * nextDirection.y - direction.y * nextDirection.x
            let gap = CGPoint(x: next.start.x - end.x, y: next.start.y - end.y)
            let along = (gap.x * nextDirection.y - gap.y * nextDirection.x) / cross
            return CGPoint(x: end.x + direction.x * along, y: end.y + direction.y * along)
        }

        /// The curve's blossom at `t1` and `t2`: its point at t when both are t.
        private func point(_ t1: CGFloat, _ t2: CGFloat) -> CGPoint {
            let startWeight = (1 - t1) * (1 - t2)
            let controlWeight = (1 - t1) * t2 + t1 * (1 - t2)
            let endWeight = t1 * t2
            return CGPoint(
                x: startWeight * start.x + controlWeight * control.x + endWeight * end.x,
                y: startWeight * start.y + controlWeight * control.y + endWeight * end.y
            )
        }
    }
}

/// A regular decagon with vertices at the left and right and flat sides at the top
/// and bottom, its corners rounded.
private nonisolated struct Decagon: Shape {

    /// The radius, in points, of the arc that rounds each corner.
    let cornerRadius: CGFloat

    /// The decagon whose vertices lie every 36° on the ellipse that fits `rect`,
    /// starting at the right; a square `rect` makes it regular. Its flat top and
    /// bottom then fall a little inside `rect`.
    func path(in rect: CGRect) -> Path {
        let vertices = (0..<10).map { index in
            let angle = CGFloat(index) * .pi / 5
            return CGPoint(x: rect.midX + rect.width / 2 * cos(angle), y: rect.midY + rect.height / 2 * sin(angle))
        }
        return Path(roundedPolygon: vertices, cornerRadius: cornerRadius)
    }
}

private nonisolated extension Path {

    /// A closed polygon through `vertices`, in order, each corner an arc of
    /// `cornerRadius` tangent to the two edges that meet there.
    ///
    /// The outline starts halfway along the last edge, away from any corner, so
    /// that every corner, the first included, is drawn as an arc.
    init(roundedPolygon vertices: [CGPoint], cornerRadius: CGFloat) {
        self.init()
        guard let first = vertices.first, let last = vertices.last else {
            return
        }
        move(to: CGPoint(x: (last.x + first.x) / 2, y: (last.y + first.y) / 2))
        for (index, vertex) in vertices.enumerated() {
            let next = vertices[(index + 1) % vertices.count]
            addArc(tangent1End: vertex, tangent2End: next, radius: cornerRadius)
        }
        closeSubpath()
    }
}
