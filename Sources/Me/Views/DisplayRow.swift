import Foundation

enum DisplayItem<Entity> {
    case header(String)
    case entity(Entity)
}

struct DisplayRow<Entity>: Identifiable {
    let index: Int
    let item: DisplayItem<Entity>

    var id: Int { index }
}
