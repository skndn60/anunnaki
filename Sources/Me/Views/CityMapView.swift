import SwiftUI
import SwiftData
import MapKit

struct CityMapView: View {
    let cityName: String
    let places: [Place]

    private var mappablePlaces: [Place] {
        places.filter { $0.latitude != nil && $0.longitude != nil }
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
            ForEach(mappablePlaces, id: \.persistentModelID) { place in
                let coord = CLLocationCoordinate2D(
                    latitude: place.latitude!,
                    longitude: place.longitude!
                )
                if place.name == cityName {
                    Marker(place.name, coordinate: coord)
                        .tint(.orange)
                } else {
                    Marker(place.name, coordinate: coord)
                        .tint(place.placeType?.color ?? Color(white: 0.6))
                }
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
