protocol PolicyEngine: Sendable {
    func evaluate(call: ToolCall, riskLevel: RiskLevel) -> PolicyDecision
}
