import Foundation

/// Utility to detect and extract @mentions from a message.
struct ChatMentionHelper {
    static func extractMentions(from text: String) -> [String] {
        let pattern = "@([A-Za-z0-9_\\.]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)
        return matches.compactMap { match -> String? in
            guard match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range]).lowercased()
        }
    }
}

