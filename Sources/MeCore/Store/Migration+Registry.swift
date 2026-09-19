import Foundation
import SwiftData

extension Migration {

    /// Lightweight descriptor for seeding a role-type or simple enum-like @Model
    /// that carries (name, icon, colorHex). Used by the generic `ensureTypesExist`
    /// helper so each role-type migration is a single-line delegation.
    package struct RoleTypeConfig {
        let name: String
        let icon: String
        let colorHex: String
        init(_ name: String, _ icon: String, _ colorHex: String) {
            self.name = name
            self.icon = icon
            self.colorHex = colorHex
        }
    }

    /// Generic idempotent seeder: inserts items for every config whose `name`
    /// is absent from the store. `create` receives the config and returns a
    /// fully-initialized `@Model` instance to insert. Works with any
    /// `PersistentModel` — role types, FigureTypes, or any future simple
    /// name+icon+color model.
    static func ensureTypesExist<T: PersistentModel>(
        context: ModelContext,
        type: T.Type,
        configs: [RoleTypeConfig],
        create: @escaping (RoleTypeConfig) -> T,
        nameKeyPath: KeyPath<T, String>
    ) {
        let existing = Set((try? context.fetch(FetchDescriptor<T>()))?.map { $0[keyPath: nameKeyPath] } ?? [])
        for config in configs where !existing.contains(config.name) {
            context.insert(create(config))
        }
        try? context.save()
    }
}
