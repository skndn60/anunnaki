import Foundation

package func sortName(for name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    let stripped = trimmed.trimmingCharacters(in: .punctuationCharacters)
    guard !stripped.isEmpty else { return trimmed }
    let lower = stripped.lowercased()
    for prefix in ["the ", "a ", "an "] {
        if lower.hasPrefix(prefix) {
            return String(stripped.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: .punctuationCharacters)
        }
    }
    return stripped
}
