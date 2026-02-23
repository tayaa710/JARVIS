import Testing
@testable import JARVIS

// MARK: - Mock

final class MockLogHandler: LogHandler, @unchecked Sendable {
    struct Entry {
        let level: LogLevel
        let message: String
    }
    var entries: [Entry] = []

    func log(level: LogLevel, message: String) {
        entries.append(Entry(level: level, message: message))
    }
}

// MARK: - Tests

@Suite("Logger Tests")
struct LoggerTests {

    @Test func testAllLoggersExist() {
        // Compile-time proof every static logger exists and is the right type.
        let _: JARVISLogger = Logger.orchestrator
        let _: JARVISLogger = Logger.tools
        let _: JARVISLogger = Logger.api
        let _: JARVISLogger = Logger.policy
        let _: JARVISLogger = Logger.voice
        let _: JARVISLogger = Logger.memory
        let _: JARVISLogger = Logger.ui
        let _: JARVISLogger = Logger.keychain
        let _: JARVISLogger = Logger.app
        #expect(true)
    }

    @Test func testSubsystemIsCorrect() {
        let loggers: [JARVISLogger] = [
            Logger.orchestrator, Logger.tools, Logger.api,
            Logger.policy, Logger.voice, Logger.memory,
            Logger.ui, Logger.keychain, Logger.app
        ]
        for logger in loggers {
            #expect(logger.subsystem == "com.aidaemon")
        }
    }

    @Test func testCategoriesAreCorrect() {
        #expect(Logger.orchestrator.category == "orchestrator")
        #expect(Logger.tools.category == "tools")
        #expect(Logger.api.category == "api")
        #expect(Logger.policy.category == "policy")
        #expect(Logger.voice.category == "voice")
        #expect(Logger.memory.category == "memory")
        #expect(Logger.ui.category == "ui")
        #expect(Logger.keychain.category == "keychain")
        #expect(Logger.app.category == "app")
    }

    @Test func testMockHandlerCapturesMessages() {
        let mock = MockLogHandler()
        let logger = JARVISLogger(subsystem: "com.test", category: "test", handler: mock)

        logger.info("hello")
        logger.error("oops")

        #expect(mock.entries.count == 2)
        #expect(mock.entries[0].level == .info)
        #expect(mock.entries[0].message == "hello")
        #expect(mock.entries[1].level == .error)
        #expect(mock.entries[1].message == "oops")
    }

    @Test func testLogLevelsPassThrough() {
        let mock = MockLogHandler()
        let logger = JARVISLogger(subsystem: "com.test", category: "test", handler: mock)

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")

        #expect(mock.entries.count == 4)
        #expect(mock.entries[0].level == .debug)
        #expect(mock.entries[1].level == .info)
        #expect(mock.entries[2].level == .warning)
        #expect(mock.entries[3].level == .error)
    }

    @Test func testLoggerIsSendable() async {
        let mock = MockLogHandler()
        let logger = JARVISLogger(subsystem: "com.test", category: "test", handler: mock)
        // Passing a JARVISLogger across a Task boundary verifies Sendable conformance.
        await Task {
            logger.info("cross-actor")
        }.value
        #expect(mock.entries.count == 1)
    }
}
