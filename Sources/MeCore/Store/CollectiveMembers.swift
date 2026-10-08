import Foundation
import SwiftData

/// The figures that belong to a collective, in ruling order: members with a known reign
/// year first (earliest first), then the rest alphabetically.
///
/// A collective's member roll is the one place that reads a `membership` relationship, and
/// it reads only the member → collective direction. That makes the direction load-bearing,
/// which is why `RelationshipManager.addMembership` is the sole sanctioned writer of these
/// rows: a row recorded the other way round is not an error the store will catch, it is a
/// member that silently never appears. Live data is currently clean — every membership row
/// in the store points at a collective.
package func collectiveMembers(of figure: Figure, from relationships: [Relationship]) -> [Figure] {
    let memberRels = relationships.filter {
        $0.relationshipType?.category == RelationshipManager.membershipCategory &&
        $0.toFigure?.persistentModelID == figure.persistentModelID
    }
    var seen = Set<PersistentIdentifier>()
    let members = memberRels.compactMap(\.fromFigure).filter { seen.insert($0.persistentModelID).inserted }
    return members.sorted { lhs, rhs in
        switch (lhs.reignStartYear, rhs.reignStartYear) {
        case let (l?, r?): return l < r
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
