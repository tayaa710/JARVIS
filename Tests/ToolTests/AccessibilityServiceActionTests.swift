import Testing
import ApplicationServices
@testable import JARVIS

@Suite("AccessibilityServiceAction Tests")
struct AccessibilityServiceActionTests {

    // MARK: - Helpers

    private func makeService(
        appName: String = "TestApp",
        bundleId: String = "com.test.app",
        pid: pid_t = 1234
    ) -> (AccessibilityServiceImpl, MockAXProvider) {
        let provider = MockAXProvider()
        let root = MockAXProvider.MockAXNode(
            role: "AXApplication",
            title: appName,
            children: [
                MockAXProvider.MockAXNode(role: "AXButton", title: "OK"),
                MockAXProvider.MockAXNode(role: "AXTextField", value: "hello")
            ]
        )
        provider.setFrontmostApp(name: appName, bundleId: bundleId, pid: pid, rootNode: root)
        let service = AccessibilityServiceImpl(axProvider: provider)
        return (service, provider)
    }

    // Walk the tree so refs are populated
    private func walkAndGetRefs(service: AccessibilityServiceImpl) async throws -> UITreeSnapshot {
        return try await service.walkFrontmostApp()
    }

    // MARK: - performAction tests

    @Test("performAction with valid ref returns true")
    func performActionValidRef() async throws {
        let (service, provider) = makeService()
        provider.performActionResult = true
        let snapshot = try await walkAndGetRefs(service: service)
        // @e1 is the root, @e2 and @e3 are children
        let result = try await service.performAction(ref: snapshot.root.ref, action: "AXPress")
        #expect(result == true)
    }

    @Test("performAction with unknown ref throws invalidElement")
    func performActionUnknownRef() async throws {
        let (service, _) = makeService()
        _ = try await walkAndGetRefs(service: service)
        await #expect(throws: AXServiceError.invalidElement) {
            _ = try await service.performAction(ref: "@e999", action: "AXPress")
        }
    }

    @Test("performAction delegates to axProvider with correct action string")
    func performActionDelegates() async throws {
        let (service, provider) = makeService()
        provider.performActionResult = true
        let snapshot = try await walkAndGetRefs(service: service)
        _ = try await service.performAction(ref: snapshot.root.ref, action: "AXPress")
        #expect(provider.performedActions.count == 1)
        #expect(provider.performedActions[0].action == "AXPress")
    }

    @Test("performAction returns false when provider returns false")
    func performActionFalse() async throws {
        let (service, provider) = makeService()
        provider.performActionResult = false
        let snapshot = try await walkAndGetRefs(service: service)
        let result = try await service.performAction(ref: snapshot.root.ref, action: "AXPress")
        #expect(result == false)
    }

    // MARK: - setValue tests

    @Test("setValue with valid ref returns true")
    func setValueValidRef() async throws {
        let (service, provider) = makeService()
        provider.performActionResult = true
        let snapshot = try await walkAndGetRefs(service: service)
        let result = try await service.setValue(ref: snapshot.root.ref, attribute: "AXValue", value: "new text")
        #expect(result == true)
    }

    @Test("setValue with unknown ref throws invalidElement")
    func setValueUnknownRef() async throws {
        let (service, _) = makeService()
        _ = try await walkAndGetRefs(service: service)
        await #expect(throws: AXServiceError.invalidElement) {
            _ = try await service.setValue(ref: "@e999", attribute: "AXValue", value: "text")
        }
    }

    @Test("setValue delegates to axProvider with correct attribute")
    func setValueDelegates() async throws {
        let (service, provider) = makeService()
        provider.performActionResult = true
        let snapshot = try await walkAndGetRefs(service: service)
        _ = try await service.setValue(ref: snapshot.root.ref, attribute: "AXValue", value: "hello")
        #expect(provider.setValueCalls.count == 1)
        #expect(provider.setValueCalls[0].attribute == "AXValue")
    }

    // MARK: - setFocused tests

    @Test("setFocused with valid ref delegates focused attribute")
    func setFocusedDelegates() async throws {
        let (service, provider) = makeService()
        provider.performActionResult = true
        let snapshot = try await walkAndGetRefs(service: service)
        let result = try await service.setFocused(ref: snapshot.root.ref)
        #expect(result == true)
        #expect(provider.setValueCalls.count == 1)
        #expect(provider.setValueCalls[0].attribute == "AXFocused")
    }

    @Test("setFocused with unknown ref throws invalidElement")
    func setFocusedUnknownRef() async throws {
        let (service, _) = makeService()
        _ = try await walkAndGetRefs(service: service)
        await #expect(throws: AXServiceError.invalidElement) {
            _ = try await service.setFocused(ref: "@e999")
        }
    }

    @Test("Thread safety: concurrent performAction doesn't crash")
    func concurrentPerformAction() async throws {
        let (service, provider) = makeService()
        provider.performActionResult = true
        let snapshot = try await walkAndGetRefs(service: service)
        let ref = snapshot.root.ref

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    _ = try? await service.performAction(ref: ref, action: "AXPress")
                }
            }
        }
        // No crash = success
        #expect(provider.performedActions.count == 10)
    }
}
