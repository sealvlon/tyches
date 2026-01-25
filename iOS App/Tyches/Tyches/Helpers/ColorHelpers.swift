import SwiftUI

// MARK: - Color Parsing Utilities

/// Parse a hex color string to SwiftUI Color with a fallback
/// Uses the existing Color(hex:) extension from TychesTheme
/// This is a convenience function for handling optional hex strings
func parseHexColor(_ hex: String?, fallback: Color = TychesTheme.primary) -> Color {
    guard let hex = hex, !hex.isEmpty else { return fallback }
    return Color(hex: hex)
}

// Note: Color(hex:) extension is defined in TychesTheme.swift and used throughout the app
