import SwiftUI
import SwiftData
import MapKit

struct CityMapView: View {
    let cityName: String
    let places: [Place]

    private struct MapPin: Identifiable {
        let id: PersistentIdentifier
        let name: String
        let coordinate: CLLocationCoordinate2D
        let isCity: Bool
        let tint: Color
    }

    private var mappablePlaces: [Place] {
        places.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var pins: [MapPin] {
        let eps = 0.0005
        let offsetMeters: Double = 280
        var clusters: [[Place]] = []
        for place in mappablePlaces {
            if let index = clusters.firstIndex(where: { cluster in
                guard let ref = cluster.first else { return false }
                return abs(place.latitude! - ref.latitude!) < eps && abs(place.longitude! - ref.longitude!) < eps
            }) {
                clusters[index].append(place)
            } else {
                clusters.append([place])
            }
        }
        var result: [MapPin] = []
        for cluster in clusters {
            guard cluster.count > 1, let ref = cluster.first else {
                for place in cluster {
                    result.append(MapPin(
                        id: place.persistentModelID,
                        name: place.name,
                        coordinate: CLLocationCoordinate2D(latitude: place.latitude!, longitude: place.longitude!),
                        isCity: place.name == cityName,
                        tint: place.placeType?.color ?? Color(white: 0.6)
                    ))
                }
                continue
            }
            for (index, place) in cluster.enumerated() {
                let count = cluster.count
                let angle = (2 * Double.pi * Double(index) / Double(count)) - Double.pi / 2
                let dLat = offsetMeters * cos(angle) / 111320
                let dLon = offsetMeters * sin(angle) / (111320 * cos(ref.latitude! * .pi / 180))
                result.append(MapPin(
                    id: place.persistentModelID,
                    name: place.name,
                    coordinate: CLLocationCoordinate2D(latitude: ref.latitude! + dLat, longitude: ref.longitude! + dLon),
                    isCity: place.name == cityName,
                    tint: place.placeType?.color ?? Color(white: 0.6)
                ))
            }
        }
        return result
    }

    private var initialRegion: MKCoordinateRegion {
        if let target = mappablePlaces.first(where: { $0.name == cityName }),
           let lat = target.latitude, let lon = target.longitude {
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
            )
        } else {
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 33.3, longitude: 44.4),
                span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
            )
        }
    }

    @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 33.3, longitude: 44.4),
        span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)
    ))

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(pins) { pin in
                Marker(pin.name, coordinate: pin.coordinate)
                    .tint(pin.isCity ? .orange : pin.tint)
            }
        }
        .mapStyle(.standard)
        .mapControlVisibility(.hidden)
        .onAppear {
            position = .region(initialRegion)
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(spacing: 4) {
                zoomButton(icon: "plus", delta: -0.3)
                zoomButton(icon: "minus", delta: 0.3)
            }
            .padding(10)
        }
        .frame(width: 380, height: 380)
    }

    private func zoomButton(icon: String, delta: Double) -> some View {
        Button {
            if let r = position.region {
                let lat = max(r.span.latitudeDelta * (1 + delta), 0.1)
                let lon = max(r.span.longitudeDelta * (1 + delta), 0.1)
                position = .region(MKCoordinateRegion(
                    center: r.center,
                    span: MKCoordinateSpan(latitudeDelta: lat, longitudeDelta: lon)
                ))
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
