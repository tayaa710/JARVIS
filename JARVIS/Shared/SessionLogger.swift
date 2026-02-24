import Foundation

// MARK: - SessionLogging Protocol

protocol SessionLogging: Sendable {
    func logUserMessage(_ text: String)
    func logThinkingRound(_ round: Int, messageCount: Int, toolCount: Int)
    func logToolCall(name: String, inputJSON: String, risk: RiskLevel, decision: PolicyDecision)
    func logToolResult(name: String, isError: Bool, elapsed: TimeInterval, output: String)
    func logToolDenied(name: String)
    func logToolRejected(name: String)
    func logAssistantText(_ text: String)
    func logMetrics(_ metrics: TurnMetrics)
    func logError(_ message: String)
}

// MARK: - NullSessionLogger

struct NullSessionLogger: SessionLogging {
    func logUserMessage(_ text: String) {}
    func logThinkingRound(_ round: Int, messageCount: Int, toolCount: Int) {}
    func logToolCall(name: String, inputJSON: String, risk: RiskLevel, decision: PolicyDecision) {}
    func logToolResult(name: String, isError: Bool, elapsed: TimeInterval, output: String) {}
    func logToolDenied(name: String) {}
    func logToolRejected(name: String) {}
    func logAssistantText(_ text: String) {}
    func logMetrics(_ metrics: TurnMetrics) {}
    func logError(_ message: String) {}
}

// MARK: - FileSessionLogger

/// Writes a human-readable session trace to ~/Library/Logs/JARVIS/session-DATE.txt.
/// Thread-safe: uses separate locks for the date formatter and the file handle.
final class FileSessionLogger: SessionLogging, @unchecked Sendable {

    let filePath: String

    private let fileHandle: FileHandle
    private let writeLock = NSLock()
    private let formatterLock = NSLock()
    private let dateFormatter: DateFormatter

    // MARK: - Init

    /// Returns nil if the log directory or file cannot be created.
    init?() {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/JARVIS")
        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let nameFmt = DateFormatter()
        nameFmt.dateFormat = "yyyy-MM-dd-HHmmss"
        let fileName = "session-\(nameFmt.string(from: Date())).txt"
        let fileURL = logsDir.appendingPathComponent(fileName)

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: fileURL) else { return nil }

        self.fileHandle = handle
        self.filePath = fileURL.path

        let tsFmt = DateFormatter()
        tsFmt.dateFormat = "HH:mm:ss"
        self.dateFormatter = tsFmt

        writeHeader()
        Logger.session.info("Session log started: \(fileURL.path)")
    }

    deinit {
        try? fileHandle.close()
    }

    // MARK: - SessionLogging

    func logUserMessage(_ text: String) {
        let ts = timestamp()
        write("""

        [\(ts)] USER
        \(thinLine())
        \(text)

        """)
    }

    func logThinkingRound(_ round: Int, messageCount: Int, toolCount: Int) {
        let ts = timestamp()
        write("\n[\(ts)] JARVIS THINKING — Round \(round) (\(messageCount) messages, \(toolCount) tools available)\n\(thinLine())\n")
    }

    func logToolCall(name: String, inputJSON: String, risk: RiskLevel, decision: PolicyDecision) {
        let ts = timestamp()
        write("""

          [\(ts)] TOOL CALL — \(name)
            Input:  \(inputJSON)
            Risk:   \(riskLabel(risk))
            Policy: \(decisionLabel(decision))
        """)
    }

    func logToolResult(name: String, isError: Bool, elapsed: TimeInterval, output: String) {
        let ts = timestamp()
        let icon = isError ? "✗" : "✓"
        let elapsedStr = String(format: "%.3fs", elapsed)
        let display = output.count > 600 ? String(output.prefix(600)) + "\n    … (truncated)" : output
        write("""

          [\(ts)] TOOL RESULT — \(name) \(icon) (\(elapsedStr))
            Output: \(display)
        """)
    }

    func logToolDenied(name: String) {
        let ts = timestamp()
        write("\n  [\(ts)] TOOL DENIED — \(name) (blocked by safety policy)\n")
    }

    func logToolRejected(name: String) {
        let ts = timestamp()
        write("\n  [\(ts)] TOOL REJECTED — \(name) (declined by user)\n")
    }

    func logAssistantText(_ text: String) {
        let ts = timestamp()
        write("""

        [\(ts)] JARVIS RESPONSE
        \(thinLine())
        \(text)

        """)
    }

    func logMetrics(_ metrics: TurnMetrics) {
        let ts = timestamp()
        let tools = metrics.toolsUsed.isEmpty ? "(none)" : metrics.toolsUsed.joined(separator: ", ")
        write("""

        [\(ts)] METRICS
          Rounds:     \(metrics.roundCount)
          Tools used: \(tools)
          Errors:     \(metrics.errorsEncountered)
          Tokens:     \(metrics.inputTokens) in / \(metrics.outputTokens) out
          Elapsed:    \(String(format: "%.2f", metrics.elapsedTime))s
        \(separator())

        """)
    }

    func logError(_ message: String) {
        let ts = timestamp()
        write("\n[\(ts)] ERROR — \(message)\n")
    }

    // MARK: - Private

    private func writeHeader() {
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .medium)
        write("""
        \(separator())
        JARVIS Session Log
        Started:  \(now)
        Log file: \(filePath)
        \(separator())

        """)
    }

    private func timestamp() -> String {
        formatterLock.withLock { dateFormatter.string(from: Date()) }
    }

    private func separator() -> String { String(repeating: "=", count: 80) }
    private func thinLine() -> String { String(repeating: "─", count: 80) }

    private func riskLabel(_ risk: RiskLevel) -> String {
        switch risk {
        case .safe:        return "safe"
        case .caution:     return "caution"
        case .dangerous:   return "dangerous"
        case .destructive: return "destructive"
        }
    }

    private func decisionLabel(_ decision: PolicyDecision) -> String {
        switch decision {
        case .allow:                return "allow"
        case .requireConfirmation:  return "require confirmation"
        case .deny:                 return "deny"
        }
    }

    private func write(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        writeLock.withLock {
            try? fileHandle.write(contentsOf: data)
        }
    }
}
