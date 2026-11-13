// Created on 2026-11-13
// Copyright © 2026 OrderedBytes.  Licensed under the MIT License; see LICENSE.

/// Checks `condition` every 50 ms for up to 10 s, returning its first non-nil value.
@MainActor
func poll<Value>(_ condition: () -> Value?) async throws -> Value? {
    for _ in 0..<200 {
        if let value = condition() {
            return value
        }
        try await Task.sleep(for: .milliseconds(50))
    }
    return nil
}
