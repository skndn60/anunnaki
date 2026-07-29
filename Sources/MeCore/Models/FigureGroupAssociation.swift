import Foundation
import SwiftData

@Model
package final class FigureGroupAssociation {
    package var figure: Figure?
    package var group: FigureGroup?
    package var note: String

    package init(
        figure: Figure? = nil,
        group: FigureGroup? = nil,
        note: String = ""
    ) {
        self.figure = figure
        self.group = group
        self.note = note
    }
}