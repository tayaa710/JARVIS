protocol PolicyEngine: Sendable {
    func evaluate(call: ToolUse, riskLevel: RiskLevel) -> PolicyDecision
}
