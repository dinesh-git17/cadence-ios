import Foundation

enum EmailValidator {
    private static let regex = try? NSRegularExpression(
        pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
    )

    static func isValid(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        return regex?.firstMatch(in: trimmed, range: range) != nil
    }
}
