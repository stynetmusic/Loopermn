import Foundation

extension Formatter {
    static let duration: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}

extension String {
    func trimmingWhitespace() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func camelCaseToWords() -> String {
        let pattern = "([A-Z])"
        let replacement = " $1"
        return self.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .capitalized
    }
}