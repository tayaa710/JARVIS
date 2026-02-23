import Foundation

final class PolicyEngineImpl: PolicyEngine, @unchecked Sendable {

    private let lock = NSLock()
    private var _autonomyLevel: AutonomyLevel

    init(autonomyLevel: AutonomyLevel = .smartDefault) {
        self._autonomyLevel = autonomyLevel
    }

    func setAutonomyLevel(_ level: AutonomyLevel) {
        lock.lock()
        defer { lock.unlock() }
        _autonomyLevel = level
    }

    // MARK: - PolicyEngine

    func evaluate(call: ToolUse, riskLevel: RiskLevel) -> PolicyDecision {
        // Step 1: Input sanitization — any violation results in deny
        let violations = InputSanitizer.check(call: call)
        if !violations.isEmpty {
            Logger.policy.warning("Tool '\(call.name)' denied: \(violations.count) sanitization violation(s)")
            return .deny
        }

        // Step 2: Apply the decision matrix
        lock.lock()
        let autonomy = _autonomyLevel
        lock.unlock()

        let decision = decisionMatrix(riskLevel: riskLevel, autonomyLevel: autonomy)
        Logger.policy.info("Tool '\(call.name)' risk=\(String(describing: riskLevel)) autonomy=\(autonomy.rawValue) → \(String(describing: decision))")
        return decision
    }

    // MARK: - Private

    private func decisionMatrix(riskLevel: RiskLevel, autonomyLevel: AutonomyLevel) -> PolicyDecision {
        // Destructive ALWAYS requires confirmation at any autonomy level
        if riskLevel == .destructive {
            return .requireConfirmation
        }

        switch autonomyLevel {
        case .askAll:
            // Level 0: safe auto-allowed; caution/dangerous require confirmation
            return riskLevel == .safe ? .allow : .requireConfirmation

        case .smartDefault:
            // Level 1: safe + caution auto-allowed; dangerous requires confirmation
            switch riskLevel {
            case .safe, .caution:
                return .allow
            case .dangerous, .destructive:
                return .requireConfirmation
            }

        case .fullAuto:
            // Level 2: safe + caution + dangerous auto-allowed (destructive handled above)
            return .allow
        }
    }
}
