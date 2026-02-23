import CoreGraphics

// MARK: - UIElementSnapshot

/// A snapshot of a single UI element in the accessibility tree.
struct UIElementSnapshot: Sendable, Equatable {

    /// The element reference assigned during the walk, e.g. "@e1", "@e2".
    let ref: String

    /// The accessibility role, e.g. "AXButton", "AXTextField", "AXWindow".
    let role: String

    /// The element's title or label, if any.
    let title: String?

    /// The element's current value (text content, slider position, etc.), if any.
    /// Truncated to 200 characters when captured.
    let value: String?

    /// Whether the element is currently enabled for user interaction.
    let isEnabled: Bool

    /// The element's position and size in screen coordinates.
    let frame: CGRect

    /// The element's direct children, in order.
    let children: [UIElementSnapshot]
}

// MARK: - UITreeSnapshot

/// A complete snapshot of a frontmost application's accessibility tree.
struct UITreeSnapshot: Sendable {

    /// The localized display name of the app (e.g. "Safari").
    let appName: String

    /// The bundle identifier (e.g. "com.apple.Safari").
    let bundleId: String

    /// The process identifier of the app.
    let pid: pid_t

    /// The root element of the snapshot (the application element).
    let root: UIElementSnapshot

    /// Total number of elements captured in the snapshot.
    let elementCount: Int

    /// True if the snapshot was cut short by a depth or element count limit.
    let truncated: Bool
}
