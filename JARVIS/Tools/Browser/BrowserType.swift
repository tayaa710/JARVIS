import Foundation

// MARK: - BrowserType

/// The family/engine of a browser.
public enum BrowserType: String, Sendable, Equatable {
    case chromium
    case safari
    case firefox
    case unknown
}

// MARK: - BrowserInfo

/// Information about a detected browser.
public struct BrowserInfo: Sendable, Equatable {
    public let name: String
    public let bundleId: String
    public let type: BrowserType
    public let pid: pid_t

    public init(name: String, bundleId: String, type: BrowserType, pid: pid_t) {
        self.name = name
        self.bundleId = bundleId
        self.type = type
        self.pid = pid
    }
}
