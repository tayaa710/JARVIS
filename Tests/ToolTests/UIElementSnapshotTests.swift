import Testing
import CoreGraphics
@testable import JARVIS

@Suite("UIElementSnapshot Tests")
struct UIElementSnapshotTests {

    @Test func snapshotStoresAllProperties() {
        let frame = CGRect(x: 10, y: 20, width: 100, height: 40)
        let snapshot = UIElementSnapshot(
            ref: "@e1",
            role: "AXButton",
            title: "OK",
            value: nil,
            isEnabled: true,
            frame: frame,
            children: []
        )
        #expect(snapshot.ref == "@e1")
        #expect(snapshot.role == "AXButton")
        #expect(snapshot.title == "OK")
        #expect(snapshot.value == nil)
        #expect(snapshot.isEnabled == true)
        #expect(snapshot.frame == frame)
        #expect(snapshot.children.isEmpty)
    }

    @Test func snapshotEquatableConsidersAllFields() {
        let a = UIElementSnapshot(ref: "@e1", role: "AXButton", title: "OK", value: nil,
                                  isEnabled: true, frame: .zero, children: [])
        let b = UIElementSnapshot(ref: "@e1", role: "AXButton", title: "OK", value: nil,
                                  isEnabled: true, frame: .zero, children: [])
        let c = UIElementSnapshot(ref: "@e2", role: "AXButton", title: "OK", value: nil,
                                  isEnabled: true, frame: .zero, children: [])
        #expect(a == b)
        #expect(a != c)
    }

    @Test func snapshotPreservesNestedChildren() {
        let child = UIElementSnapshot(ref: "@e2", role: "AXStaticText", title: "Hello",
                                      value: nil, isEnabled: true, frame: .zero, children: [])
        let parent = UIElementSnapshot(ref: "@e1", role: "AXGroup", title: nil,
                                       value: nil, isEnabled: true, frame: .zero, children: [child])
        #expect(parent.children.count == 1)
        #expect(parent.children[0].ref == "@e2")
        #expect(parent.children[0].role == "AXStaticText")
    }

    @Test func treeSnapshotStoresMetadata() {
        let root = UIElementSnapshot(ref: "@e1", role: "AXWindow", title: "Main",
                                     value: nil, isEnabled: true, frame: .zero, children: [])
        let tree = UITreeSnapshot(appName: "Safari", bundleId: "com.apple.Safari",
                                  pid: 42, root: root, elementCount: 1, truncated: false)
        #expect(tree.appName == "Safari")
        #expect(tree.bundleId == "com.apple.Safari")
        #expect(tree.pid == 42)
        #expect(tree.elementCount == 1)
        #expect(tree.truncated == false)
    }
}
