// Created on 2026-11-12
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

import Foundation
import Synchronization
@_spi(FENblixHost) import FENblixExtensionKit

/// A scene's service behind an anonymous XPC listener, exported as the scene's
/// `onConnection` exports it, and an activated connection to it set up as the
/// host sets one up: the same objects and interfaces an extension uses,
/// without ExtensionKit.
@MainActor
final class SceneLink {

    /// The host's end.
    let connection: NSXPCConnection

    /// The listener the service is exported from.
    private let listener: NSXPCListener

    /// Accepts the connection and exports the service on it.
    private let delegate: Delegate

    /// A link to `service`, exported and called through the interface
    /// `interface` makes, such as `.evaluationScene`. A closure, since an
    /// `NSXPCInterface` is not `Sendable` and the listener's delegate is.
    init(exporting service: any NSObject & Sendable, interface: @escaping @Sendable () -> NSXPCInterface) {
        delegate = Delegate(service: service, interface: interface)
        listener = NSXPCListener.anonymous()
        listener.delegate = delegate
        listener.activate()

        connection = NSXPCConnection(listenerEndpoint: listener.endpoint)
        connection.remoteObjectInterface = interface()
        connection.activate()
    }

    /// Closes the connection and the listener.
    func close() {
        connection.invalidate()
        listener.invalidate()
    }

    /// Asks the scene for its contract version, as the host does first on every
    /// connection, and returns it.
    ///
    /// Because the reply comes after every call sent before it on the connection,
    /// waiting for it also waits for those calls to arrive. Throws the proxy's
    /// error if the connection fails first.
    func contractVersion() async throws -> Int {
        let connection = connection
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = OneShot(continuation)
            let proxy = connection.remoteObjectProxyWithErrorHandler { @Sendable error in
                resumer.resume(with: .failure(error))
            }
            guard let scene = proxy as? FENblixSceneXPC else {
                resumer.resume(with: .failure(CocoaError(.featureUnsupported)))
                return
            }
            scene.contractVersion { @Sendable version in
                resumer.resume(with: .success(version))
            }
        }
    }

    /// Resumes a continuation once, from whichever of a reply and an error
    /// handler gets there first.
    private final class OneShot: Sendable {

        /// The continuation, until it has been resumed.
        private let continuation: Mutex<CheckedContinuation<Int, any Error>?>

        /// A resumer for `continuation`.
        init(_ continuation: CheckedContinuation<Int, any Error>) {
            self.continuation = Mutex(continuation)
        }

        /// Resumes the continuation with `result`, unless it has been resumed already.
        func resume(with result: Result<Int, any Error>) {
            continuation.withLock { $0.take() }?.resume(with: result)
        }
    }

    /// Sets up every connection the way a scene's `onConnection` does.
    private final class Delegate: NSObject, NSXPCListenerDelegate, Sendable {

        /// The object exported to the host.
        let service: any NSObject & Sendable

        /// Makes the interface the service is exported through.
        let interface: @Sendable () -> NSXPCInterface

        /// A delegate exporting `service` through `interface`.
        init(service: any NSObject & Sendable, interface: @escaping @Sendable () -> NSXPCInterface) {
            self.service = service
            self.interface = interface
        }

        /// Exports the service and accepts.
        func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
            connection.exportedInterface = interface()
            connection.exportedObject = service
            connection.resume()
            return true
        }
    }
}
