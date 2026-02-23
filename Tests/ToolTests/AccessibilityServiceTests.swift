import Testing
import CoreGraphics
import ApplicationServices
@testable import JARVIS

// MARK: - Helpers

private func makeService(mock: MockAXProvider) -> AccessibilityServiceImpl {
    AccessibilityServiceImpl(axProvider: mock)
}

private func makeDeepNode(levels: Int) -> MockAXProvider.MockAXNode {
    guard levels > 1 else {
        return MockAXProvider.MockAXNode(role: "AXButton")
    }
    return MockAXProvider.MockAXNode(role: "AXGroup", children: [makeDeepNode(levels: levels - 1)])
}

// MARK: - Tests

@Suite("AccessibilityService Tests")
struct AccessibilityServiceTests {

    // MARK: - Permission Tests

    @Test func checkPermissionReturnsTrueWhenGranted() {
        let mock = MockAXProvider()
        mock.isProcessTrustedResult = true
        let service = makeService(mock: mock)
        #expect(service.checkPermission() == true)
    }

    @Test func checkPermissionReturnsFalseWhenNotGranted() {
        let mock = MockAXProvider()
        mock.isProcessTrustedResult = false
        let service = makeService(mock: mock)
        #expect(service.checkPermission() == false)
    }

    // MARK: - Tree Walking Tests

    @Test func walkReturnsSnapshotOfFrontmostApp() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(
            name: "TestApp",
            bundleId: "com.test.app",
            pid: 12345,
            rootNode: .init(role: "AXWindow", children: [
                .init(role: "AXButton", title: "OK"),
                .init(role: "AXTextField", title: "Input")
            ])
        )
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.appName == "TestApp")
        #expect(snapshot.bundleId == "com.test.app")
        #expect(snapshot.pid == 12345)
        #expect(snapshot.elementCount == 3)
        #expect(snapshot.truncated == false)
    }

    @Test func walkAssignsSequentialRefs() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(
            name: "App", bundleId: "com.app", pid: 1001,
            rootNode: .init(role: "AXWindow", children: [
                .init(role: "AXButton", title: "A"),
                .init(role: "AXButton", title: "B")
            ])
        )
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.root.ref == "@e1")
        #expect(snapshot.root.children[0].ref == "@e2")
        #expect(snapshot.root.children[1].ref == "@e3")
    }

    @Test func walkCapturesRole() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1002,
                             rootNode: .init(role: "AXScrollArea"))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        #expect(snapshot.root.role == "AXScrollArea")
    }

    @Test func walkCapturesTitle() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1003,
                             rootNode: .init(role: "AXButton", title: "Submit"))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        #expect(snapshot.root.title == "Submit")
    }

    @Test func walkCapturesValue() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1004,
                             rootNode: .init(role: "AXTextField", value: "hello"))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        #expect(snapshot.root.value == "hello")
    }

    @Test func walkCapturesEnabledState() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1005,
                             rootNode: .init(role: "AXButton", enabled: false))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        #expect(snapshot.root.isEnabled == false)
    }

    @Test func walkCapturesFrame() async throws {
        let expectedFrame = CGRect(x: 10, y: 20, width: 200, height: 50)
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1006,
                             rootNode: .init(role: "AXButton", frame: expectedFrame))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        #expect(snapshot.root.frame.origin.x == expectedFrame.origin.x)
        #expect(snapshot.root.frame.origin.y == expectedFrame.origin.y)
        #expect(snapshot.root.frame.size.width == expectedFrame.size.width)
        #expect(snapshot.root.frame.size.height == expectedFrame.size.height)
    }

    @Test func walkCapturesChildren() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(
            name: "App", bundleId: "com.app", pid: 1007,
            rootNode: .init(role: "AXWindow", children: [
                .init(role: "AXGroup", children: [
                    .init(role: "AXButton", title: "Nested")
                ])
            ])
        )
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.root.children.count == 1)
        #expect(snapshot.root.children[0].role == "AXGroup")
        #expect(snapshot.root.children[0].children.count == 1)
        #expect(snapshot.root.children[0].children[0].role == "AXButton")
    }

    // MARK: - Ref Assignment Tests

    @Test func refsResetBetweenWalks() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1008,
                             rootNode: .init(role: "AXWindow"))
        let service = makeService(mock: mock)

        let snap1 = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        let snap2 = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snap1.root.ref == "@e1")
        #expect(snap2.root.ref == "@e1")
    }

    @Test func elementForRefReturnsCorrectElement() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1009,
                             rootNode: .init(role: "AXWindow"))
        let service = makeService(mock: mock)

        _ = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        let element = service.elementForRef("@e1")
        #expect(element != nil)
    }

    @Test func elementForRefReturnsNilForInvalidRef() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1010,
                             rootNode: .init(role: "AXWindow"))
        let service = makeService(mock: mock)

        _ = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        #expect(service.elementForRef("@e99") == nil)
    }

    @Test func invalidateRefMapClearsRefs() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1011,
                             rootNode: .init(role: "AXWindow"))
        let service = makeService(mock: mock)

        _ = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        #expect(service.elementForRef("@e1") != nil)

        service.invalidateRefMap()
        #expect(service.elementForRef("@e1") == nil)
    }

    // MARK: - Depth Limit Tests

    @Test func walkStopsAtMaxDepth() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1012,
                             rootNode: makeDeepNode(levels: 8))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.truncated == true)
        #expect(snapshot.elementCount == 5)
    }

    @Test func walkDefaultMaxDepthIs5() async throws {
        // A tree exactly 5 deep should not be truncated with maxDepth: 5.
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1013,
                             rootNode: makeDeepNode(levels: 5))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.truncated == false)
        #expect(snapshot.elementCount == 5)
    }

    @Test func walkRespectsCustomMaxDepth() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1014,
                             rootNode: makeDeepNode(levels: 6))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 3, maxElements: 300)

        #expect(snapshot.truncated == true)
        #expect(snapshot.elementCount == 3)
    }

    // MARK: - Element Count Limit Tests

    @Test func walkStopsAtMaxElements() async throws {
        // Wide tree: root + 499 children (500 elements total)
        let children = (0..<499).map { _ in MockAXProvider.MockAXNode(role: "AXButton") }
        let root = MockAXProvider.MockAXNode(role: "AXWindow", children: children)
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1015, rootNode: root)
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.truncated == true)
        #expect(snapshot.elementCount == 300)
    }

    @Test func walkDefaultMaxElementsIs300() async throws {
        // Small tree: 10 elements — should not be truncated with maxElements: 300.
        let children = (0..<9).map { _ in MockAXProvider.MockAXNode(role: "AXButton") }
        let root = MockAXProvider.MockAXNode(role: "AXWindow", children: children)
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1016, rootNode: root)
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.truncated == false)
        #expect(snapshot.elementCount == 10)
    }

    // MARK: - Edge Case Tests

    @Test func walkWithNoFrontmostAppThrowsError() async {
        let mock = MockAXProvider()
        // Don't call setFrontmostApp — configuredPID stays 0, so frontmostApplicationInfo() returns nil
        let service = makeService(mock: mock)

        await #expect(throws: AXServiceError.noFrontmostApp) {
            try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
        }
    }

    @Test func walkHandlesEmptyTree() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1017,
                             rootNode: .init(role: "AXWindow"))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.elementCount == 1)
        #expect(snapshot.root.children.isEmpty)
        #expect(snapshot.truncated == false)
    }

    @Test func walkTruncatesLongValues() async throws {
        let longValue = String(repeating: "x", count: 250)
        let mock = MockAXProvider()
        mock.setFrontmostApp(name: "App", bundleId: "com.app", pid: 1018,
                             rootNode: .init(role: "AXTextField", value: longValue))
        let service = makeService(mock: mock)
        let snapshot = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)

        #expect(snapshot.root.value?.count == 200)
    }

    // MARK: - Thread Safety Test

    @Test func concurrentWalkCallsDoNotCrash() async throws {
        let mock = MockAXProvider()
        mock.setFrontmostApp(
            name: "App", bundleId: "com.app", pid: 1019,
            rootNode: .init(role: "AXWindow", children: [
                .init(role: "AXButton", title: "A"),
                .init(role: "AXButton", title: "B")
            ])
        )
        let service = makeService(mock: mock)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        _ = try await service.walkFrontmostApp(maxDepth: 5, maxElements: 300)
                    } catch {}
                }
            }
        }
        // Test passes if no crash occurred
    }
}
