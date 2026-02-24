@testable import JARVIS

// MARK: - MockCDPDiscovery

/// Configurable mock implementation of CDPDiscovering for tests.
final class MockCDPDiscovery: CDPDiscovering, @unchecked Sendable {

    // MARK: - Configurable Outputs

    var targets: [CDPTarget] = []
    var shouldThrow: CDPError?

    // MARK: - Call Recording

    var discoverCallCount: Int = 0
    var lastPort: Int?

    // MARK: - CDPDiscovering

    func discoverTargets(port: Int) async throws -> [CDPTarget] {
        discoverCallCount += 1
        lastPort = port
        if let error = shouldThrow {
            throw error
        }
        return targets
    }

    func findPageTarget(port: Int) async throws -> CDPTarget {
        let all = try await discoverTargets(port: port)
        guard let page = all.first(where: { $0.type == "page" }) else {
            throw CDPError.noTargetsFound
        }
        return page
    }
}
