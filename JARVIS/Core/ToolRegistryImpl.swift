import Foundation

final class ToolRegistryImpl: ToolRegistry, @unchecked Sendable {

    private let lock = NSLock()
    private var executors: [String: any ToolExecutor] = [:]

    // MARK: - ToolRegistry

    func register(_ executor: any ToolExecutor) throws {
        lock.lock()
        defer { lock.unlock() }
        let name = executor.definition.name
        guard executors[name] == nil else {
            throw ToolRegistryError.duplicateToolName(name)
        }
        executors[name] = executor
        Logger.tools.info("Registered tool: \(name)")
    }

    func executor(for toolId: String) -> (any ToolExecutor)? {
        lock.lock()
        defer { lock.unlock() }
        return executors[toolId]
    }

    func allDefinitions() -> [ToolDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return executors.values.map { $0.definition }
    }

    func validate(call: ToolUse) throws {
        lock.lock()
        let executor = executors[call.name]
        lock.unlock()

        guard let executor else {
            throw ToolRegistryError.unknownTool(call.name)
        }

        do {
            try SchemaValidator.validate(input: call.input, against: executor.definition.inputSchema)
        } catch let error as SchemaValidationError {
            throw ToolRegistryError.validationFailed(String(describing: error))
        }
    }

    func dispatch(call: ToolUse) async throws -> ToolResult {
        try validate(call: call)

        lock.lock()
        let executor = executors[call.name]
        lock.unlock()

        guard let executor else {
            throw ToolRegistryError.unknownTool(call.name)
        }

        let start = Date()
        Logger.tools.info("Dispatching tool: \(call.name) id=\(call.id)")

        do {
            let result = try await executor.execute(id: call.id, arguments: call.input)
            let elapsed = Date().timeIntervalSince(start)
            Logger.tools.info("Tool \(call.name) completed in \(String(format: "%.3f", elapsed))s isError=\(result.isError)")
            return result
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            Logger.tools.error("Tool \(call.name) threw error in \(String(format: "%.3f", elapsed))s: \(error)")
            return ToolResult(toolUseId: call.id, content: "Tool execution failed: \(error.localizedDescription)", isError: true)
        }
    }
}
