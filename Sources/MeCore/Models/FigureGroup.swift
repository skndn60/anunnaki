import Foundation
import SwiftData

@Model
package final class FigureGroup {
    package var name: String
    package var groupDescription: String
    package var icon: String
    package var colorHex: String
    package var orderIndex: Int
    package var memberFilter: String?

    @Relationship(deleteRule: .cascade, inverse: \FigureGroupAssociation.group)
    package var figureAssociations: [FigureGroupAssociation] = []

    package var decodedFilter: GroupMemberFilter? {
        get {
            guard let data = memberFilter?.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(GroupMemberFilter.self, from: data)
        }
        set {
            guard let newValue, let data = try? JSONEncoder().encode(newValue) else {
                memberFilter = nil
                return
            }
            memberFilter = String(data: data, encoding: .utf8)
        }
    }

    package init(
        name: String = "",
        groupDescription: String = "",
        icon: String = "rectangle.3.group",
        colorHex: String = "8E8E93",
        orderIndex: Int = 0,
        memberFilter: String? = nil
    ) {
        self.name = name
        self.groupDescription = groupDescription
        self.icon = icon
        self.colorHex = colorHex
        self.orderIndex = orderIndex
        self.memberFilter = memberFilter
    }
}

package struct GroupMemberFilter: Codable, Equatable {
    package var figureTypeNames: [String]?
    package var domainKeywords: [String]?
    package var nameMatch: String?

    package init(
        figureTypeNames: [String]? = nil,
        domainKeywords: [String]? = nil,
        nameMatch: String? = nil
    ) {
        self.figureTypeNames = figureTypeNames
        self.domainKeywords = domainKeywords
        self.nameMatch = nameMatch
    }

    package func matches(_ figure: Figure) -> Bool {
        if let typeNames = figureTypeNames, !typeNames.isEmpty {
            if let figureTypeName = figure.figureType?.name,
               typeNames.contains(where: { $0.localizedCaseInsensitiveCompare(figureTypeName) == .orderedSame }) {
                return true
            }
        }
        if let keywords = domainKeywords, !keywords.isEmpty {
            if keywords.contains(where: { figure.domain.localizedCaseInsensitiveContains($0) }) {
                return true
            }
        }
        if let match = nameMatch, !match.isEmpty {
            if figure.name.localizedCaseInsensitiveContains(match) {
                return true
            }
        }
        return false
    }

    package var summary: String {
        var parts: [String] = []
        if let typeNames = figureTypeNames, !typeNames.isEmpty {
            parts.append("Type: \(typeNames.joined(separator: ", "))")
        }
        if let keywords = domainKeywords, !keywords.isEmpty {
            parts.append("Domain: \(keywords.joined(separator: ", "))")
        }
        if let match = nameMatch, !match.isEmpty {
            parts.append("Name: \"\(match)\"")
        }
        return parts.isEmpty ? "No filter" : parts.joined(separator: " · ")
    }
}