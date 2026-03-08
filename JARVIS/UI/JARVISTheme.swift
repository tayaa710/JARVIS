import SwiftUI
import AppKit

// MARK: - JARVIS Design System

/// Centralised design system. Single source of truth for all colours,
/// fonts, spacing, and animation constants. Do NOT use raw colours
/// outside of this enum — add a constant here instead.
enum JARVISTheme {

    // MARK: - SwiftUI Colors

    static let jarvisBlack  = Color(red: 0.031, green: 0.047, blue: 0.078) // #080C14
    static let jarvisBlue   = Color(red: 0.0,   green: 0.667, blue: 1.0)   // #00AAFF
    static let jarvisCyan   = Color(red: 0.0,   green: 1.0,   blue: 1.0)   // #00FFFF
    static let jarvisPurple = Color(red: 0.482, green: 0.184, blue: 0.745) // #7B2FBE
    static let jarvisDanger = Color(red: 1.0,   green: 0.271, blue: 0.271) // #FF4545

    // Opacity variants — computed on demand so no static init ordering issues
    static var jarvisBlueDim: Color { jarvisBlue.opacity(0.30) }
    static var jarvisBlue10:  Color { jarvisBlue.opacity(0.10) }
    static var jarvisBlue15:  Color { jarvisBlue.opacity(0.15) }
    static var jarvisBlue40:  Color { jarvisBlue.opacity(0.40) }
    static var jarvisBlue60:  Color { jarvisBlue.opacity(0.60) }

    // MARK: - AppKit Colors (for NSPanel / NSVisualEffectView)

    static let nsJarvisBlack = NSColor(red: 0.031, green: 0.047, blue: 0.078, alpha: 1.0)

    // MARK: - Fonts

    static let jarvisOutput      = Font.system(.body,    design: .monospaced)
    static let jarvisOutputSmall = Font.system(.caption, design: .monospaced)
    static let jarvisUI          = Font.system(.body)
    static let jarvisUISmall     = Font.system(.caption)

    // MARK: - Animation Durations

    static let bootSequenceDuration:    TimeInterval = 1.8
    static let characterRevealInterval: TimeInterval = 0.015  // 15 ms per char (streaming)
    static let bootCharRevealInterval:  TimeInterval = 0.025  // 25 ms per char (boot sequence)
    static let pulsePeriod:             TimeInterval = 2.0    // 0.5 Hz corner-bracket pulse
    static let sonarRingInterval:       TimeInterval = 0.3    // offset between sonar rings

    // MARK: - Spacing

    static let messagePadding:     CGFloat = 12
    static let cornerBracketArm:   CGFloat = 8
    static let cornerBracketStroke: CGFloat = 1
}
