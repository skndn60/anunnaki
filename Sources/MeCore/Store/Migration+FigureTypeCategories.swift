import Foundation
import SwiftData

extension Migration {
    /// Marks the collective `FigureType` rows with `category == "collective"`.
    ///
    /// A collective (the Anunnaki, the Assyrians) is an assembly of figures rather than
    /// an individual, so father/mother do not apply to it — it has members, not parents.
    /// The views used to decide this by substring-matching the type's *display name*
    /// ("Collective"), which silently broke if the row was renamed in the Type Manager.
    /// `FigureType.category` mirrors `RelationshipType.category` and gives the question
    /// exactly one owner.
    ///
    /// Additive + idempotent: it only writes a value onto rows that are still
    /// uncategorised, and never removes one. Types the user has deliberately
    /// re-categorised are left alone.
    package static func ensureFigureTypeCategories(context: ModelContext) {
        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        // "Mythical Collective" is here for the same reason as the other three, and despite
        // not being a behavioural class either: it is the type the antediluvian peoples were
        // moved onto, the way "Igigi" is named for a clade rather than for a behaviour.
        //
        // The user's own "Nephilim" type is deliberately NOT in this set. It carries the named
        // giants — Hahyah, Ohyah, Og of Bashan — who are persons with parents, and no single
        // category value is true of a type holding both them and the peoples. Categorising it
        // would have replaced their parent slots with a membership strip.
        let collectiveNames: Set<String> = ["Divine Collective", "Human Collective", "Mixed Collective", "Mythical Collective"]

        var changed = false
        for type in types where type.category == nil {
            guard collectiveNames.contains(type.name) else { continue }
            type.category = "collective"
            changed = true
        }

        if changed {
            Commit.save(context, "ensureFigureTypeCategories")
        }
    }
}
