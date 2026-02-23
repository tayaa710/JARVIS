import Testing
import Foundation
import CoreGraphics
@testable import JARVIS

@Suite("MouseMoveTool Tests")
struct MouseMoveToolTests {

    @Test("Risk level is safe")
    func riskLevel() {
        let tool = MouseMoveTool(inputService: MockInputService(), postActionDelay: 0)
        #expect(tool.riskLevel == .safe)
    }

    @Test("Definition has correct name")
    func definitionName() {
        let tool = MouseMoveTool(inputService: MockInputService(), postActionDelay: 0)
        #expect(tool.definition.name == "mouse_move")
    }

    @Test("Valid move to coordinates succeeds")
    func validMove() async throws {
        let mockInput = MockInputService()
        let tool = MouseMoveTool(inputService: mockInput, postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["x": .number(300), "y": .number(400)])
        #expect(!result.isError)
        #expect(mockInput.moves.count == 1)
        #expect(mockInput.moves[0] == CGPoint(x: 300, y: 400))
    }

    @Test("Missing x or y returns error")
    func missingCoordinates() async throws {
        let tool = MouseMoveTool(inputService: MockInputService(), postActionDelay: 0)
        let result1 = try await tool.execute(id: "t1", arguments: ["x": .number(100)])
        #expect(result1.isError)
        let result2 = try await tool.execute(id: "t2", arguments: ["y": .number(100)])
        #expect(result2.isError)
    }

    @Test("InputService error is returned as tool error")
    func inputServiceError() async throws {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Move failure" }
        }
        let mockInput = MockInputService()
        mockInput.shouldThrow = TestError()
        let tool = MouseMoveTool(inputService: mockInput, postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["x": .number(100), "y": .number(100)])
        #expect(result.isError)
    }

    @Test("Move is recorded in MockInputService")
    func moveRecorded() async throws {
        let mockInput = MockInputService()
        let tool = MouseMoveTool(inputService: mockInput, postActionDelay: 0)
        _ = try await tool.execute(id: "t1", arguments: ["x": .number(100), "y": .number(200)])
        _ = try await tool.execute(id: "t2", arguments: ["x": .number(300), "y": .number(400)])
        #expect(mockInput.moves.count == 2)
    }

    @Test("No context lock check required")
    func noContextLockRequired() async throws {
        // MouseMoveTool works without a context lock set
        let mockInput = MockInputService()
        let tool = MouseMoveTool(inputService: mockInput, postActionDelay: 0)
        let result = try await tool.execute(id: "t1", arguments: ["x": .number(100), "y": .number(100)])
        #expect(!result.isError)
    }
}
