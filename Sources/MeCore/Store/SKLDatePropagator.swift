import Foundation

package struct SKLDatePropagator {

    package struct ComputedReign {
        package let figure: Figure
        package let startBCE: Int?
        package let endBCE: Int?

        package var display: String {
            guard let s = startBCE, let e = endBCE else { return "" }
            let prefix = figure.birthDate.isApproximate ? "c. " : ""
            return "\(prefix)\(abs(s))\u{2013}\(abs(e)) BC"
        }
    }

    package struct DynastyTimeline {
        package let name: String
        package let orderIndex: Int
        package let reigns: [ComputedReign]

        package var startBCE: Int? { reigns.first?.startBCE }
        package var endBCE: Int? { reigns.last?.endBCE }
        package var totalYears: Int {
            reigns.reduce(0) {
                $0 + ($1.figure.reignYears ?? ReignLength.parse(from: $1.figure.figureDescription)?.years ?? 0)
            }
        }
    }

    package static func compute(figures: [Figure], eraOrder: [String: Int]) -> [DynastyTimeline] {
        let grouped = Dictionary(grouping: figures) { figure -> String in
            let era = figure.birthDate.era
            return era.isEmpty ? "Antediluvian" : era
        }

        return grouped.map { name, dynastyFigures in
            let order = name == "Antediluvian" ? -1 : (eraOrder[name] ?? Int.max)
            let sorted = dynastyFigures.sorted { $0.orderIndex < $1.orderIndex }
            let reigns = computeReigns(for: sorted)
            return DynastyTimeline(name: name, orderIndex: order, reigns: reigns)
        }.sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - Private

    private static let bcRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: "c\\.\\s*(\\d{3,4})[–-](\\d{3,4})\\s*BC\\b")
    }()

    private static func computeReigns(for figures: [Figure]) -> [ComputedReign] {
        var result: [(startBCE: Int?, endBCE: Int?)] = Array(repeating: (nil, nil), count: figures.count)

        for i in figures.indices {
            result[i] = extractExplicitDates(for: figures[i])
        }

        guard let anchorIdx = result.firstIndex(where: { $0.startBCE != nil }) else {
            return figures.map { ComputedReign(figure: $0, startBCE: nil, endBCE: nil) }
        }

        propagateForward(from: anchorIdx, figures: figures, result: &result)
        propagateBackward(from: anchorIdx, figures: figures, result: &result)

        return zip(figures, result).map { figure, dates in
            ComputedReign(figure: figure, startBCE: dates.startBCE, endBCE: dates.endBCE)
        }
    }

    private static func extractExplicitDates(for figure: Figure) -> (startBCE: Int?, endBCE: Int?) {
        if let birthYear = figure.birthDate.startYear {
            let deathYear = figure.deathDate.endYear ?? figure.deathDate.startYear ?? birthYear
            return (birthYear, deathYear)
        }

        let desc = figure.figureDescription
        let nsRange = NSRange(desc.startIndex..., in: desc)
        for match in bcRegex.matches(in: desc, range: nsRange) {
            guard let matchRange = Range(match.range, in: desc),
                  let startRange = Range(match.range(at: 1), in: desc),
                  let endRange = Range(match.range(at: 2), in: desc),
                  let startBCE = Int(desc[startRange]),
                  let endBCE = Int(desc[endRange]),
                  isReignDate(desc: desc, matchRange: matchRange) else { continue }
            return (-startBCE, -endBCE)
        }
        return (nil, nil)
    }

    private static func isReignDate(desc: String, matchRange: Range<String.Index>) -> Bool {
        let before = String(desc[..<matchRange.lowerBound].suffix(40))
        if before.range(of: #"\b(reigned|ruled|reign|lived)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }
        let after = String(desc[matchRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if after.isEmpty || after == "." || after == "," { return true }
        return after.hasPrefix("(short)") || after.hasPrefix("(middle")
    }

    private static func propagateForward(from anchorIdx: Int, figures: [Figure], result: inout [(startBCE: Int?, endBCE: Int?)]) {
        for i in (anchorIdx + 1)..<figures.count {
            if result[i].startBCE != nil { continue }
            guard let prevEnd = result[i - 1].endBCE,
                  let reign = ReignLength.parse(from: figures[i].figureDescription) else { break }
            let start = prevEnd
            result[i] = (start, start + reign.years)
        }
    }

    private static func propagateBackward(from anchorIdx: Int, figures: [Figure], result: inout [(startBCE: Int?, endBCE: Int?)]) {
        for i in (0..<anchorIdx).reversed() {
            if result[i].startBCE != nil { continue }
            guard let nextStart = result[i + 1].startBCE,
                  let reign = ReignLength.parse(from: figures[i].figureDescription) else { break }
            let end = nextStart
            result[i] = (end - reign.years, end)
        }
    }
}
