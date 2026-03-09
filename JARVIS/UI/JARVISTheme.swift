import SwiftUI
import AppKit

// MARK: - JARVIS Design System

/// Centralised design system. Single source of truth for all colours,
/// fonts, spacing, and animation constants. Do NOT use raw colours
/// outside of this enum — add a constant here instead.
enum JARVISTheme {

    // MARK: - SwiftUI Colors

    static let background        = Color(.windowBackgroundColor)   // system adaptive
    static let surfacePrimary    = Color(white: 0.12)              // message list bg
    static let surfaceSecondary  = Color(white: 0.17)              // input area bg
    static let userBubble        = Color.accentColor               // system blue
    static let assistantBubble   = Color(white: 0.22)              // dark gray
    static let textPrimary       = Color.primary
    static let textSecondary     = Color.secondary
    static let border            = Color(white: 0.28)
    static let danger            = Color.red

    // Tool call pill background
    static let pillBackground    = Color(white: 0.25)

    // MARK: - AppKit Colors

    static let nsBackground      = NSColor.windowBackgroundColor

    // MARK: - Fonts — all SF Pro

    static let body:     Font = .body
    static let caption:  Font = .caption
    static let headline: Font = .headline

    // Legacy aliases — preserved so callers updated incrementally still compile
    static let jarvisUI          = Font.body
    static let jarvisUISmall     = Font.caption
    static let jarvisOutput      = Font.body
    static let jarvisOutputSmall = Font.caption

    // MARK: - Spacing

    static let messagePadding:     CGFloat = 16
    static let bubbleCornerRadius: CGFloat = 16
}
