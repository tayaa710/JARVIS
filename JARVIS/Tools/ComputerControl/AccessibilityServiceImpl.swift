import AppKit
import ApplicationServices

// MARK: - Accessibility Service Implementation

/// Walks the macOS AX tree of the frontmost application and assigns element refs.
///
/// Thread safety: all AX API calls and ref map mutations happen on a dedicated
/// serial `axQueue`. External callers can call `elementForRef` and `invalidateRefMap`
/// from any thread — both dispatch to `axQueue` internally.
final class AccessibilityServiceImpl: AccessibilityServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies

    private let axProvider: any AXProviding

    // MARK: - Serial Queue

    private let axQueue = DispatchQueue(label: "com.aidaemon.accessibility", qos: .userInitiated)

    // MARK: - State (axQueue-protected)

    private var _refMap: [String: AXUIElement] = [:]
    private var _refCounter: Int = 0

    // MARK: - Init

    init(axProvider: any AXProviding = SystemAXProvider()) {
        self.axProvider = axProvider
    }

    // MARK: - AccessibilityServiceProtocol

    func checkPermission() -> Bool {
        axProvider.isProcessTrusted()
    }

    func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options: NSDictionary = [key: NSNumber(booleanLiteral: true)]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func walkFrontmostApp(maxDepth: Int = 5, maxElements: Int = 300) async throws -> UITreeSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            axQueue.async {
                do {
                    let snapshot = try self.performWalk(maxDepth: maxDepth, maxElements: maxElements)
                    continuation.resume(returning: snapshot)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func elementForRef(_ ref: String) -> AXUIElement? {
        axQueue.sync { _refMap[ref] }
    }

    func invalidateRefMap() {
        axQueue.sync {
            _refMap = [:]
            _refCounter = 0
        }
    }

    // MARK: - Private Walk

    private func performWalk(maxDepth: Int, maxElements: Int) throws -> UITreeSnapshot {
        guard let appInfo = axProvider.frontmostApplicationInfo() else {
            Logger.accessibility.error("walkFrontmostApp: no frontmost application")
            throw AXServiceError.noFrontmostApp
        }

        Logger.accessibility.info("Walking AX tree: \(appInfo.name) pid=\(appInfo.pid)")

        let appElement = axProvider.createApplicationElement(pid: appInfo.pid)

        // Reset ref state for this walk
        _refMap = [:]
        _refCounter = 0

        var state = WalkState()
        guard let rootSnapshot = walkElement(appElement, depth: 1,
                                             maxDepth: maxDepth,
                                             maxElements: maxElements,
                                             state: &state) else {
            throw AXServiceError.invalidElement
        }

        // Commit ref map
        _refMap = state.refMap
        _refCounter = state.counter

        Logger.accessibility.info(
            "Walk complete: \(state.counter) elements, truncated=\(state.truncated)"
        )

        return UITreeSnapshot(
            appName: appInfo.name,
            bundleId: appInfo.bundleId,
            pid: appInfo.pid,
            root: rootSnapshot,
            elementCount: state.counter,
            truncated: state.truncated
        )
    }

    // MARK: - Walk State

    private struct WalkState {
        var counter: Int = 0
        var refMap: [String: AXUIElement] = [:]
        var truncated: Bool = false
    }

    // MARK: - Recursive Element Walk

    private func walkElement(
        _ axElement: AXUIElement,
        depth: Int,
        maxDepth: Int,
        maxElements: Int,
        state: inout WalkState
    ) -> UIElementSnapshot? {
        guard depth <= maxDepth else {
            state.truncated = true
            return nil
        }
        guard state.counter < maxElements else {
            state.truncated = true
            return nil
        }

        // Role (required — fall back to AXUnknown if absent)
        let role = axProvider.copyAttributeValue(axElement, attribute: kAXRoleAttribute as String)
            as? String ?? "AXUnknown"

        // Title
        let title = axProvider.copyAttributeValue(axElement, attribute: kAXTitleAttribute as String)
            as? String

        // Value — truncate to 200 chars
        var value: String? = axProvider.copyAttributeValue(axElement, attribute: kAXValueAttribute as String)
            as? String
        if let v = value, v.count > 200 {
            value = String(v.prefix(200))
        }

        // Enabled state
        let isEnabled: Bool
        if let ref = axProvider.copyAttributeValue(axElement, attribute: kAXEnabledAttribute as String) {
            isEnabled = (ref as? Bool) ?? (ref as? NSNumber)?.boolValue ?? true
        } else {
            isEnabled = true
        }

        // Position
        var position = CGPoint.zero
        if let posRef = axProvider.copyAttributeValue(axElement, attribute: kAXPositionAttribute as String),
           CFGetTypeID(posRef) == AXValueGetTypeID() {
            let axVal: AXValue = unsafeBitCast(posRef, to: AXValue.self)
            AXValueGetValue(axVal, .cgPoint, &position)
        }

        // Size
        var size = CGSize.zero
        if let sizeRef = axProvider.copyAttributeValue(axElement, attribute: kAXSizeAttribute as String),
           CFGetTypeID(sizeRef) == AXValueGetTypeID() {
            let axVal: AXValue = unsafeBitCast(sizeRef, to: AXValue.self)
            AXValueGetValue(axVal, .cgSize, &size)
        }

        let frame = CGRect(origin: position, size: size)

        // Assign ref (1-based: @e1, @e2, ...)
        state.counter += 1
        let ref = "@e\(state.counter)"
        state.refMap[ref] = axElement

        // Recurse into children
        let axChildren = axProvider.copyChildren(axElement)
        var childSnapshots: [UIElementSnapshot] = []
        for child in axChildren {
            if let childSnapshot = walkElement(child, depth: depth + 1,
                                               maxDepth: maxDepth,
                                               maxElements: maxElements,
                                               state: &state) {
                childSnapshots.append(childSnapshot)
            }
        }

        return UIElementSnapshot(
            ref: ref,
            role: role,
            title: title,
            value: value,
            isEnabled: isEnabled,
            frame: frame,
            children: childSnapshots
        )
    }
}
