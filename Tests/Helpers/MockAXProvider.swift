import Foundation
import ApplicationServices
@testable import JARVIS

// MARK: - AX Element Key

/// Hashable wrapper for AXUIElement using CF identity semantics.
struct AXElementKey: Hashable, @unchecked Sendable {
    let element: AXUIElement

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }

    static func == (lhs: AXElementKey, rhs: AXElementKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }
}

// MARK: - Mock AX Provider

/// Configurable mock for AXProviding. Lets tests set up fake UI trees without
/// needing Accessibility permission or real apps.
final class MockAXProvider: AXProviding, @unchecked Sendable {

    // MARK: - Mock Node Type

    struct MockAXNode {
        var role: String
        var title: String?
        var value: String?
        var enabled: Bool = true
        var frame: CGRect = .zero
        var children: [MockAXNode] = []

        init(role: String, title: String? = nil, value: String? = nil,
             enabled: Bool = true, frame: CGRect = .zero,
             children: [MockAXNode] = []) {
            self.role = role
            self.title = title
            self.value = value
            self.enabled = enabled
            self.frame = frame
            self.children = children
        }
    }

    // MARK: - Configuration

    var isProcessTrustedResult: Bool = true

    // Set to nil to simulate "no frontmost app"
    private var configuredPID: pid_t = 0
    private var configuredName: String = ""
    private var configuredBundleId: String = ""

    // MARK: - Internal Tree State

    private var nodeMap: [AXElementKey: MockAXNode] = [:]
    private var childrenMap: [AXElementKey: [AXUIElement]] = [:]
    private var appElement: AXUIElement?
    private var pidCounter: pid_t = 9000

    // MARK: - Setup

    /// Configures a fake app and UI tree. Call this before exercising the service.
    func setFrontmostApp(name: String, bundleId: String, pid: pid_t, rootNode: MockAXNode) {
        configuredName = name
        configuredBundleId = bundleId
        configuredPID = pid
        nodeMap = [:]
        childrenMap = [:]
        pidCounter = 9000

        let rootElement = AXUIElementCreateApplication(pid)
        appElement = rootElement
        buildTree(node: rootNode, element: rootElement)
    }

    private func buildTree(node: MockAXNode, element: AXUIElement) {
        let key = AXElementKey(element: element)
        nodeMap[key] = node

        var childElements: [AXUIElement] = []
        for childNode in node.children {
            pidCounter += 1
            let childElement = AXUIElementCreateApplication(pidCounter)
            buildTree(node: childNode, element: childElement)
            childElements.append(childElement)
        }
        childrenMap[key] = childElements
    }

    // MARK: - AXProviding

    func isProcessTrusted() -> Bool { isProcessTrustedResult }

    func frontmostApplicationInfo() -> (name: String, bundleId: String, pid: pid_t)? {
        guard configuredPID != 0 else { return nil }
        return (name: configuredName, bundleId: configuredBundleId, pid: configuredPID)
    }

    func copyAttributeValue(_ element: AXUIElement, attribute: String) -> CFTypeRef? {
        let key = AXElementKey(element: element)
        guard let node = nodeMap[key] else { return nil }

        switch attribute {
        case kAXRoleAttribute as String:
            return node.role as AnyObject

        case kAXTitleAttribute as String:
            guard let title = node.title else { return nil }
            return title as AnyObject

        case kAXValueAttribute as String:
            guard let value = node.value else { return nil }
            return value as AnyObject

        case kAXEnabledAttribute as String:
            return node.enabled as AnyObject

        case kAXPositionAttribute as String:
            var point = node.frame.origin
            return AXValueCreate(.cgPoint, &point) as AnyObject

        case kAXSizeAttribute as String:
            var size = node.frame.size
            return AXValueCreate(.cgSize, &size) as AnyObject

        default:
            return nil
        }
    }

    func copyChildren(_ element: AXUIElement) -> [AXUIElement] {
        childrenMap[AXElementKey(element: element)] ?? []
    }

    func copyAttributeNames(_ element: AXUIElement) -> [String]? {
        guard nodeMap[AXElementKey(element: element)] != nil else { return nil }
        return [kAXRoleAttribute, kAXTitleAttribute, kAXValueAttribute,
                kAXEnabledAttribute, kAXChildrenAttribute]
    }

    func getElementAtPosition(_ app: AXUIElement, x: Float, y: Float) -> AXUIElement? { nil }

    func performAction(_ element: AXUIElement, action: String) -> Bool { false }

    func createApplicationElement(pid: pid_t) -> AXUIElement {
        // Return the cached root element when the configured PID is requested,
        // so the service's lookups into nodeMap/childrenMap succeed.
        if pid == configuredPID, let element = appElement {
            return element
        }
        return AXUIElementCreateApplication(pid)
    }

    func createSystemWideElement() -> AXUIElement {
        AXUIElementCreateSystemWide()
    }
}
