import Testing
import CoreGraphics
@testable import JARVIS

@Suite("UISnapshotFormatter Tests")
struct UISnapshotFormatterTests {

    // MARK: - Helpers

    private func makeSnapshot(
        appName: String = "Safari",
        bundleId: String = "com.apple.Safari",
        pid: pid_t = 1000,
        root: UIElementSnapshot,
        elementCount: Int = 1,
        truncated: Bool = false
    ) -> UITreeSnapshot {
        UITreeSnapshot(appName: appName, bundleId: bundleId, pid: pid,
                       root: root, elementCount: elementCount, truncated: truncated)
    }

    private func element(
        ref: String = "@e1",
        role: String = "AXApplication",
        title: String? = nil,
        value: String? = nil,
        isEnabled: Bool = true,
        children: [UIElementSnapshot] = []
    ) -> UIElementSnapshot {
        UIElementSnapshot(ref: ref, role: role, title: title, value: value,
                          isEnabled: isEnabled, frame: .zero, children: children)
    }

    // MARK: - Tests

    @Test("Header contains app name and bundle ID")
    func headerContainsAppInfo() {
        let root = element()
        let snapshot = makeSnapshot(appName: "Safari", bundleId: "com.apple.Safari", root: root)
        let output = UISnapshotFormatter.format(snapshot)
        #expect(output.contains("App: Safari (com.apple.Safari)"))
    }

    @Test("Simple tree with one element shows ref and role")
    func simpleOneElement() {
        let root = element(ref: "@e1", role: "AXApplication", title: "My App")
        let snapshot = makeSnapshot(root: root, elementCount: 1)
        let output = UISnapshotFormatter.format(snapshot)
        #expect(output.contains("@e1"))
        #expect(output.contains("AXApplication"))
        #expect(output.contains("\"My App\""))
    }

    @Test("Nested tree shows indentation")
    func nestedIndentation() {
        let child = element(ref: "@e2", role: "AXButton", title: "OK")
        let root = element(ref: "@e1", role: "AXWindow", title: "Window", children: [child])
        let snapshot = makeSnapshot(root: root, elementCount: 2)
        let output = UISnapshotFormatter.format(snapshot)
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        // Child line should be more indented than root line
        let rootLine = lines.first { $0.contains("@e1") }
        let childLine = lines.first { $0.contains("@e2") }
        #expect(rootLine != nil)
        #expect(childLine != nil)
        let rootIndent = rootLine!.prefix(while: { $0 == " " }).count
        let childIndent = childLine!.prefix(while: { $0 == " " }).count
        #expect(childIndent > rootIndent)
    }

    @Test("Disabled element shows [disabled]")
    func disabledElement() {
        let root = element(ref: "@e1", role: "AXButton", title: "Submit", isEnabled: false)
        let snapshot = makeSnapshot(root: root)
        let output = UISnapshotFormatter.format(snapshot)
        #expect(output.contains("[disabled]"))
    }

    @Test("Element with value shows value")
    func elementWithValue() {
        let root = element(ref: "@e1", role: "AXTextField", value: "hello world")
        let snapshot = makeSnapshot(root: root)
        let output = UISnapshotFormatter.format(snapshot)
        #expect(output.contains("\"hello world\""))
    }

    @Test("Truncated tree shows truncation notice")
    func truncatedTree() {
        let root = element()
        let snapshot = makeSnapshot(root: root, elementCount: 300, truncated: true)
        let output = UISnapshotFormatter.format(snapshot)
        #expect(output.contains("truncated"))
    }

    @Test("Non-truncated tree shows element count summary")
    func elementCountSummary() {
        let root = element()
        let snapshot = makeSnapshot(root: root, elementCount: 42, truncated: false)
        let output = UISnapshotFormatter.format(snapshot)
        #expect(output.contains("42 element"))
    }
}
