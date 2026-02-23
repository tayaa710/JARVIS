import Testing
@testable import JARVIS

@Suite("PolicyEngineImpl Tests")
struct PolicyEngineTests {

    private func cleanCall() -> ToolUse {
        ToolUse(id: "tu-1", name: "test_tool", input: [:])
    }

    // MARK: - Decision Matrix (12 tests)

    // Level 0 (askAll)
    @Test func level0SafeAllows() {
        let engine = PolicyEngineImpl(autonomyLevel: .askAll)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .safe) == .allow)
    }

    @Test func level0CautionRequiresConfirmation() {
        let engine = PolicyEngineImpl(autonomyLevel: .askAll)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .caution) == .requireConfirmation)
    }

    @Test func level0DangerousRequiresConfirmation() {
        let engine = PolicyEngineImpl(autonomyLevel: .askAll)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .dangerous) == .requireConfirmation)
    }

    @Test func level0DestructiveRequiresConfirmation() {
        let engine = PolicyEngineImpl(autonomyLevel: .askAll)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .destructive) == .requireConfirmation)
    }

    // Level 1 (smartDefault)
    @Test func level1SafeAllows() {
        let engine = PolicyEngineImpl(autonomyLevel: .smartDefault)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .safe) == .allow)
    }

    @Test func level1CautionAllows() {
        let engine = PolicyEngineImpl(autonomyLevel: .smartDefault)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .caution) == .allow)
    }

    @Test func level1DangerousRequiresConfirmation() {
        let engine = PolicyEngineImpl(autonomyLevel: .smartDefault)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .dangerous) == .requireConfirmation)
    }

    @Test func level1DestructiveRequiresConfirmation() {
        let engine = PolicyEngineImpl(autonomyLevel: .smartDefault)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .destructive) == .requireConfirmation)
    }

    // Level 2 (fullAuto)
    @Test func level2SafeAllows() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .safe) == .allow)
    }

    @Test func level2CautionAllows() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .caution) == .allow)
    }

    @Test func level2DangerousAllows() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .dangerous) == .allow)
    }

    @Test func level2DestructiveAlwaysRequiresConfirmation() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        #expect(engine.evaluate(call: cleanCall(), riskLevel: .destructive) == .requireConfirmation)
    }

    // MARK: - Sanitization Integration (5 tests)

    @Test func pathTraversalInInputDenies() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let call = ToolUse(id: "tu-1", name: "test_tool", input: ["path": .string("../secret")])
        #expect(engine.evaluate(call: call, riskLevel: .safe) == .deny)
    }

    @Test func systemPathInInputDenies() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let call = ToolUse(id: "tu-1", name: "test_tool", input: ["path": .string("/System/Library")])
        #expect(engine.evaluate(call: call, riskLevel: .safe) == .deny)
    }

    @Test func controlCharactersInInputDenies() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let call = ToolUse(id: "tu-1", name: "test_tool", input: ["text": .string("hello\u{0000}world")])
        #expect(engine.evaluate(call: call, riskLevel: .safe) == .deny)
    }

    @Test func lengthExceededInInputDenies() {
        let engine = PolicyEngineImpl(autonomyLevel: .fullAuto)
        let longString = String(repeating: "a", count: 10_001)
        let call = ToolUse(id: "tu-1", name: "test_tool", input: ["text": .string(longString)])
        #expect(engine.evaluate(call: call, riskLevel: .safe) == .deny)
    }

    @Test func cleanInputWithSafeRiskAllows() {
        let engine = PolicyEngineImpl(autonomyLevel: .smartDefault)
        let call = ToolUse(id: "tu-1", name: "test_tool", input: ["query": .string("hello world")])
        #expect(engine.evaluate(call: call, riskLevel: .safe) == .allow)
    }

    // MARK: - Autonomy Level Change (1 test)

    @Test func setAutonomyLevelChangesDecisionBehavior() {
        let engine = PolicyEngineImpl(autonomyLevel: .askAll)
        let call = cleanCall()

        // At Level 0: caution → requireConfirmation
        #expect(engine.evaluate(call: call, riskLevel: .caution) == .requireConfirmation)

        // Change to Level 1: caution → allow
        engine.setAutonomyLevel(.smartDefault)
        #expect(engine.evaluate(call: call, riskLevel: .caution) == .allow)
    }
}
