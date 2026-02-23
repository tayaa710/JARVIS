import Foundation
@testable import JARVIS

// MockPolicyEngine is a configurable PolicyEngine for Orchestrator tests.
final class MockPolicyEngine: PolicyEngine, @unchecked Sendable {

    var defaultDecision: PolicyDecision = .allow
    var overrides: [String: PolicyDecision] = [:]

    private let lock = NSLock()
    private(set) var evaluatedCalls: [(ToolUse, RiskLevel)] = []

    func evaluate(call: ToolUse, riskLevel: RiskLevel) -> PolicyDecision {
        lock.withLock {
            evaluatedCalls.append((call, riskLevel))
            return overrides[call.name] ?? defaultDecision
        }
    }
}
