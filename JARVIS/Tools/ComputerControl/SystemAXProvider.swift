import AppKit
import ApplicationServices

/// Production implementation of AXProviding that calls real macOS AX C functions.
/// Not unit-tested — tested manually on a real Mac with Accessibility permission granted.
struct SystemAXProvider: AXProviding {

    func isProcessTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    func frontmostApplicationInfo() -> (name: String, bundleId: String, pid: pid_t)? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let name = app.localizedName else { return nil }
        let bundleId = app.bundleIdentifier ?? ""
        return (name: name, bundleId: bundleId, pid: app.processIdentifier)
    }

    func copyAttributeValue(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        return error == .success ? value : nil
    }

    func copyChildren(_ element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let ref = value,
              CFGetTypeID(ref) == CFArrayGetTypeID() else {
            return []
        }
        let cfArray: CFArray = unsafeBitCast(ref, to: CFArray.self)
        let count = CFArrayGetCount(cfArray)
        var children: [AXUIElement] = []
        for i in 0..<count {
            guard let rawPtr = CFArrayGetValueAtIndex(cfArray, i) else { continue }
            let child: AXUIElement = Unmanaged<AXUIElement>.fromOpaque(rawPtr).takeUnretainedValue()
            children.append(child)
        }
        return children
    }

    func copyAttributeNames(_ element: AXUIElement) -> [String]? {
        var names: CFArray?
        guard AXUIElementCopyAttributeNames(element, &names) == .success,
              let array = names else { return nil }
        return (array as NSArray).compactMap { $0 as? String }
    }

    func getElementAtPosition(_ app: AXUIElement, x: Float, y: Float) -> AXUIElement? {
        var element: AXUIElement?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyElementAtPosition(systemWide, x, y, &element) == .success else {
            return nil
        }
        return element
    }

    func performAction(_ element: AXUIElement, action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    func createApplicationElement(pid: pid_t) -> AXUIElement {
        AXUIElementCreateApplication(pid)
    }

    func createSystemWideElement() -> AXUIElement {
        AXUIElementCreateSystemWide()
    }
}
