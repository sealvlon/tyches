import Foundation

// MARK: - Date Formatting Utilities

/// Shared date formatters to avoid repeated instantiation
enum TychesDateFormatters {
    /// ISO8601 formatter for API dates
    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        return formatter
    }()
    
    /// ISO8601 with fractional seconds (some API responses use this)
    static let iso8601Fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// ISO8601 for sending dates to API
    static let iso8601ForAPI: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    /// For displaying dates in UI
    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    /// For displaying just the date
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Relative date formatter
    static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

// MARK: - String Extensions for Date Parsing

extension String {
    /// Parse ISO8601 date string to Date
    func toDate() -> Date? {
        // Try standard ISO8601
        if let date = TychesDateFormatters.iso8601.date(from: self) {
            return date
        }
        // Try with fractional seconds
        if let date = TychesDateFormatters.iso8601Fractional.date(from: self) {
            return date
        }
        // Try PHP-style "YYYY-MM-DD HH:MM:SS"
        let phpFormatter = DateFormatter()
        phpFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        phpFormatter.timeZone = TimeZone(identifier: "UTC")
        if let date = phpFormatter.date(from: self) {
            return date
        }
        return nil
    }
    
    /// Format as relative time (e.g., "2h ago")
    func toRelativeTime() -> String {
        guard let date = toDate() else { return "" }
        return TychesDateFormatters.relative.localizedString(for: date, relativeTo: Date())
    }
    
    /// Format as display date
    func toDisplayDate() -> String {
        guard let date = toDate() else { return self }
        return TychesDateFormatters.displayDate.string(from: date)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Format as ISO8601 for API requests
    func toAPIString() -> String {
        TychesDateFormatters.iso8601ForAPI.string(from: self)
    }
    
    /// Calculate time remaining until this date
    func timeRemaining() -> String {
        let now = Date()
        let diff = self.timeIntervalSince(now)
        
        if diff < 0 { return "Closed" }
        if diff < 60 { return "\(Int(diff))s" }
        if diff < 3600 { return "\(Int(diff / 60))m" }
        if diff < 86400 { return "\(Int(diff / 3600))h" }
        return "\(Int(diff / 86400))d"
    }
    
    /// Human-readable time remaining
    func timeRemainingVerbose() -> String {
        let now = Date()
        let diff = self.timeIntervalSince(now)
        
        if diff < 0 { return "Closed" }
        
        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60
        
        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    /// Check if date is within the next hour
    var isClosingSoon: Bool {
        timeIntervalSinceNow < 3600 && timeIntervalSinceNow > 0
    }
    
    /// Check if date is within the next day
    var isClosingToday: Bool {
        timeIntervalSinceNow < 86400 && timeIntervalSinceNow > 0
    }
}

