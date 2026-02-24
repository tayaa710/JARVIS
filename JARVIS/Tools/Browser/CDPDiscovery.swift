import Foundation

// MARK: - CDPDiscovering Protocol

/// Discovers Chrome DevTools Protocol debug targets from a running browser's debug port.
public protocol CDPDiscovering: Sendable {
    /// Returns all debug targets available at the given port.
    func discoverTargets(port: Int) async throws -> [CDPTarget]

    /// Returns the first "page" type target, or throws `CDPError.noTargetsFound`.
    func findPageTarget(port: Int) async throws -> CDPTarget
}

// MARK: - CDPDiscoveryImpl

/// HTTP-based implementation that queries Chrome's /json endpoint.
public struct CDPDiscoveryImpl: CDPDiscovering {

    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func discoverTargets(port: Int) async throws -> [CDPTarget] {
        guard let url = URL(string: "http://localhost:\(port)/json") else {
            throw CDPError.discoveryFailed("Invalid URL for port \(port)")
        }
        do {
            let (data, _) = try await urlSession.data(from: url)
            let targets = try JSONDecoder().decode([CDPTarget].self, from: data)
            return targets
        } catch let error as CDPError {
            throw error
        } catch {
            throw CDPError.discoveryFailed(error.localizedDescription)
        }
    }

    public func findPageTarget(port: Int) async throws -> CDPTarget {
        let targets = try await discoverTargets(port: port)
        guard let page = targets.first(where: { $0.type == "page" }) else {
            throw CDPError.noTargetsFound
        }
        return page
    }
}
