import Foundation
import SwiftData

extension Migration {
    package static func fixEgalmahCoordinates(context: ModelContext) {
        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        guard let egalmah = places.first(where: {
            Self.seedNameKey($0.name) == Self.seedNameKey("E-galmah")
        }),
        let lat = egalmah.latitude, let lon = egalmah.longitude,
        abs(lat - 31.9) < 0.0001, abs(lon - 44.5) < 0.0001
        else { return }

        let canonicalSource = places.first(where: {
            Self.seedNameKey($0.name) == "isin"
                && $0.latitude != nil
                && $0.longitude != nil
        })
        if let canonicalSource,
           let sourceLat = canonicalSource.latitude,
           let sourceLon = canonicalSource.longitude {
            egalmah.latitude = sourceLat
            egalmah.longitude = sourceLon
        } else {
            egalmah.latitude = 31.93351
            egalmah.longitude = 45.28521
        }
        try? context.save()
    }
}