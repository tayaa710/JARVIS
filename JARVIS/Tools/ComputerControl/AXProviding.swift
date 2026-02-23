import ApplicationServices

// MARK: - AX Service Error

enum AXServiceError: Error, Equatable {
    case permissionDenied
    case noFrontmostApp
    case attributeUnavailable
    case invalidElement
    case elementLimitReached
    case depthLimitReached
}

// MARK: - AX Provider Protocol

/// Abstracts the macOS AXUIElement C API so implementations can be mocked in tests.
/// All methods may be called from any thread; the caller is responsible for thread safety.
protocol AXProviding: Sendable {

    /// Returns true if the process has been granted Accessibility permission.
    func isProcessTrusted() -> Bool

    /// Returns the name, bundle ID, and PID of the frontmost application, or nil if none.
    func frontmostApplicationInfo() -> (name: String, bundleId: String, pid: pid_t)?

    /// Reads a single attribute value from an element. Returns nil if unavailable.
    func copyAttributeValue(_ element: AXUIElement, attribute: String) -> CFTypeRef?

    /// Returns the direct children of an element. Returns [] if the attribute is absent.
    func copyChildren(_ element: AXUIElement) -> [AXUIElement]

    /// Returns the names of all supported attributes, or nil on error.
    func copyAttributeNames(_ element: AXUIElement) -> [String]?

    /// Returns the topmost element at the given screen coordinates within the app element.
    func getElementAtPosition(_ app: AXUIElement, x: Float, y: Float) -> AXUIElement?

    /// Performs a named action (e.g. kAXPressAction) on an element. Returns true on success.
    func performAction(_ element: AXUIElement, action: String) -> Bool

    /// Sets an attribute value on an element. Returns true on success.
    func setAttributeValue(_ element: AXUIElement, attribute: String, value: CFTypeRef) -> Bool

    /// Creates an AXUIElement representing an application with the given PID.
    func createApplicationElement(pid: pid_t) -> AXUIElement

    /// Creates the system-wide AXUIElement.
    func createSystemWideElement() -> AXUIElement
}
