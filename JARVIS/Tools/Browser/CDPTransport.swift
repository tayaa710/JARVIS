import Foundation

// MARK: - CDPTransport

/// Protocol abstracting WebSocket send/receive operations.
/// Enables mock injection for testing without a real WebSocket server.
public protocol CDPTransport: Sendable {
    func connect(to url: URL) async throws
    func send(_ data: Data) async throws
    func receive() async throws -> Data
    func disconnect()
}
