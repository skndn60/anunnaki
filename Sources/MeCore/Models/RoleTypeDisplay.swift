import Foundation

/// Shared capability for role types that can describe an association from both
/// sides. The `name` reads from the "forward" side (e.g. a figure's patron
/// deity role); `reverseName` reads from the other side (e.g. a place's
/// patronised-by view). Falls back to `name` when no reverse name is set.
package protocol RoleTypeDisplay {
    var name: String { get }
    var reverseName: String? { get }
    func displayName(isReverse: Bool) -> String
}

extension RoleTypeDisplay {
    package func displayName(isReverse: Bool) -> String {
        guard isReverse, let reverse = reverseName, !reverse.isEmpty else { return name }
        return reverse
    }
}

/// Mutable reverse-name setter used by `Migration.ensureRoleReverseNames` to
/// backfill seeded role types through a generic erase.
package protocol RoleReverseNameSettable: AnyObject {
    var reverseName: String? { get set }
}

extension FigurePlaceRoleType: RoleReverseNameSettable {}
extension PlacePlaceRoleType: RoleReverseNameSettable {}
extension EventEventRoleType: RoleReverseNameSettable {}
extension EventPlaceRoleType: RoleReverseNameSettable {}
extension ThingFigureRoleType: RoleReverseNameSettable {}
extension ThingPlaceRoleType: RoleReverseNameSettable {}
extension ThingEventRoleType: RoleReverseNameSettable {}
extension EventFigureRoleType: RoleReverseNameSettable {}
