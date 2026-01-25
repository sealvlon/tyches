import Foundation

// MARK: - Number Formatting Utilities

enum TychesNumberFormatters {
    /// Formatter for token amounts with thousands separator
    static let tokens: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    /// Formatter for percentages
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    /// Formatter for odds (e.g., "2.50x")
    static let odds: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    /// Formatter for compact numbers (e.g., "1.2K", "5M")
    static let compact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}

// MARK: - Formatting Functions

/// Format a number as tokens with thousands separator
func formatTokens(_ value: Double) -> String {
    TychesNumberFormatters.tokens.string(from: NSNumber(value: value)) ?? "\(Int(value))"
}

/// Format a number as tokens with thousands separator
func formatTokens(_ value: Int) -> String {
    TychesNumberFormatters.tokens.string(from: NSNumber(value: value)) ?? "\(value)"
}

/// Format odds multiplier (e.g., "2.50x")
func formatOdds(_ odds: Double) -> String {
    let formatted = TychesNumberFormatters.odds.string(from: NSNumber(value: odds)) ?? String(format: "%.2f", odds)
    return "\(formatted)x"
}

/// Format percentage (e.g., "75%")
func formatPercent(_ percent: Int) -> String {
    "\(percent)%"
}

/// Format percentage from decimal (e.g., 0.75 -> "75%")
func formatPercentFromDecimal(_ value: Double) -> String {
    "\(Int(value * 100))%"
}

/// Format number in compact form (e.g., "1.2K", "5M")
func formatCompact(_ value: Int) -> String {
    if value >= 1_000_000 {
        let millions = Double(value) / 1_000_000
        return "\(TychesNumberFormatters.compact.string(from: NSNumber(value: millions)) ?? String(format: "%.1f", millions))M"
    } else if value >= 1_000 {
        let thousands = Double(value) / 1_000
        return "\(TychesNumberFormatters.compact.string(from: NSNumber(value: thousands)) ?? String(format: "%.1f", thousands))K"
    }
    return "\(value)"
}

/// Format compact with proper suffix for large numbers
func formatCompact(_ value: Double) -> String {
    formatCompact(Int(value))
}

