import Foundation
import ApplicationServices
@testable import JARVIS

/// Configurable mock for AccessibilityServiceProtocol. Used in tool tests.
final class MockAccessibilityService: AccessibilityServiceProtocol, @unchecked Sendable {

    // MARK: - Configuration

    var checkPermissionResult: Bool = true
    var walkResult: UITreeSnapshot? = nil
    var walkError: Error? = nil
    var walkCallCount: Int = 0

    // ref map
    private let lock = NSLock()
    private var _refMap: [String: AXUIElement] = [:]

    // MARK: - Helpers

    func setRefMap(_ map: [String: AXUIElement]) {
        lock.lock()
        defer { lock.unlock() }
        _refMap = map
    }

    func setDefaultSnapshot() {
        let root = UIElementSnapshot(
            ref: "@e1",
            role: "AXApplication",
            title: "TestApp",
            value: nil,
            isEnabled: true,
            frame: .zero,
            children: [
                UIElementSnapshot(ref: "@e2", role: "AXButton", title: "OK",
                                  value: nil, isEnabled: true, frame: .zero, children: [])
            ]
        )
        walkResult = UITreeSnapshot(
            appName: "TestApp",
            bundleId: "com.test.app",
            pid: 1234,
            root: root,
            elementCount: 2,
            truncated: false
        )
    }

    // MARK: - AccessibilityServiceProtocol

    func checkPermission() -> Bool { checkPermissionResult }

    func requestPermission() {}

    func walkFrontmostApp(maxDepth: Int, maxElements: Int) async throws -> UITreeSnapshot {
        lock.lock()
        walkCallCount += 1
        lock.unlock()
        if let error = walkError { throw error }
        guard let result = walkResult else {
            throw AXServiceError.noFrontmostApp
        }
        // Populate the ref map from the snapshot so performAction/setValue/setFocused can find refs.
        // Use a fake AXUIElement for each ref (same PID-based approach as MockAXProvider).
        lock.lock()
        var newRefMap: [String: AXUIElement] = [:]
        var counter: pid_t = 5000
        populateRefMap(element: result.root, map: &newRefMap, counter: &counter)
        _refMap = newRefMap
        lock.unlock()
        return result
    }

    private func populateRefMap(element: UIElementSnapshot,
                                map: inout [String: AXUIElement],
                                counter: inout pid_t) {
        counter += 1
        map[element.ref] = AXUIElementCreateApplication(counter)
        for child in element.children {
            populateRefMap(element: child, map: &map, counter: &counter)
        }
    }

    func elementForRef(_ ref: String) -> AXUIElement? {
        lock.lock()
        defer { lock.unlock() }
        return _refMap[ref]
    }

    func invalidateRefMap() {
        lock.lock()
        defer { lock.unlock() }
        _refMap = [:]
    }

    func performAction(ref: String, action: String) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _refMap[ref] != nil else { throw AXServiceError.invalidElement }
        return true
    }

    func setValue(ref: String, attribute: String, value: String) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _refMap[ref] != nil else { throw AXServiceError.invalidElement }
        return true
    }

    func setFocused(ref: String) async throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard _refMap[ref] != nil else { throw AXServiceError.invalidElement }
        return true
    }
}
