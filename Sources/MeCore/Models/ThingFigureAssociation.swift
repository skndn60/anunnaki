import Foundation
import SwiftData

@Model
package final class ThingFigureAssociation {
    package var thing: Thing?
    package var figure: Figure?
    package var roleType: ThingFigureRoleType?
    package var source: String

    package init(
        thing: Thing? = nil,
        figure: Figure? = nil,
        roleType: ThingFigureRoleType? = nil,
        source: String = ""
    ) {
        self.thing = thing
        self.figure = figure
        self.roleType = roleType
        self.source = source
    }
}
