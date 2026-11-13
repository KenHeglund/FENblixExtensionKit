// Created on 2026-11-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Foundation
@_spi(FENblixHost) @testable import FENblixExtensionKit
import Testing

/// The framework's side of a theme's `board` scene: the service the host tells
/// which side the board is seen from, run over an in-process XPC connection.
/// These need no extension turned on.
@Suite("Board scene", .timeLimit(.minutes(1)))
@MainActor
struct BoardSceneTests {

    @Test("The scene reports this framework's contract version")
    func contractVersion() async throws {
        let link = SceneLink(exporting: BoardSceneService(viewpoint: ShownSide()), interface: { .boardScene })
        defer { link.close() }

        #expect(try await link.contractVersion() == Contract.version)
    }

    @Test("The board is seen from the side the host named last, and a string naming no side is ignored")
    func lastSideNamed() async throws {
        let viewpoint = ShownSide()
        let link = SceneLink(exporting: BoardSceneService(viewpoint: viewpoint), interface: { .boardScene })
        defer { link.close() }
        #expect(viewpoint.side == nil)

        let scene = try #require(link.connection.remoteObjectProxy as? BoardSceneXPC)
        for side in ["w", "b", "w", "b", "x"] {
            scene.show(seenFrom: side)
        }

        // The reply comes after every call before it on the connection, and each
        // call queued its change on the main queue before the reply, so they
        // have all run by the time this resumes on the main actor.
        _ = try await link.contractVersion()
        #expect(viewpoint.side == .black)
    }
}
