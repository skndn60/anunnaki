import SwiftUI
import SwiftData
import AppKit
import Foundation

struct EntityReportRequest: Codable, Hashable {
    let name: String
    let kind: String
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let bundle = Bundle.module
        if let iconURL = bundle.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        } else if let iconURL = bundle.url(forResource: "AppIcon", withExtension: "png"),
                  let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main
struct MeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    static let sharedContainer: ModelContainer = {
        let schema = Schema([Figure.self, FigureType.self, Relationship.self, RelationshipType.self, Era.self, Place.self, PlaceType.self, Event.self, EventType.self, Source.self, Citation.self, AlternateName.self, Attachment.self, ImageAsset.self, Tag.self, FigurePlaceAssociation.self, PlacePlaceAssociation.self, EventEventAssociation.self, EventPlaceAssociation.self, DataVersion.self, StickyNote.self])

        let forceReseed = CommandLine.arguments.contains("--reseed")
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDirectory = appSupport.appendingPathComponent("Me", isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("Me.store", isDirectory: false)

        print("[Me] Store URL: \(storeURL.path)")
        print("[Me] Force reseed: \(forceReseed)")

        if forceReseed {
            try? FileManager.default.removeItem(at: storeURL)
            print("[Me] Deleted store for reseed")
        }

        do {
            try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        } catch {
            print("[Me] Failed to create store directory: \(error)")
        }

        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            print("[Me] ModelContainer created successfully")
            return container
        } catch {
            print("[Me] Failed to create ModelContainer: \(error)")
            print("[Me] Store file: \(storeURL.path)")
            print("[Me] Attempting backup before recovery...")
            let backupURL = storeDirectory.appendingPathComponent("Me.store.crashed-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: storeURL, to: backupURL)
            print("[Me] Backed up old store to: \(backupURL.path)")
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                print("[Me] ModelContainer created after recovering from crash")
                return container
            } catch {
                fatalError("Failed to create ModelContainer after crash recovery: \(error)")
            }
        }
    }()

    let container: ModelContainer = Self.sharedContainer

    var body: some Scene {
        WindowGroup("Me") {
            ContentView()
        }
        .modelContainer(container)
        .defaultSize(width: 1200, height: 800)

        WindowGroup("Lineage Explorer", id: "lineage", for: PersistentIdentifier.self) { $figureID in
            LineageExplorerWindow(figureID: figureID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 650)

        WindowGroup("Map Preview", id: "map-preview", for: PersistentIdentifier.self) { $placeID in
            MapPreviewWindow(placeID: placeID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 800, height: 600)

        WindowGroup("Image Detail", id: "image-detail", for: PersistentIdentifier.self) { $imageID in
            ImageDetailWindow(imageID: imageID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 800, height: 600)

        WindowGroup("Figure", id: "figure-quickview", for: PersistentIdentifier.self) { $figureID in
            FigureQuicklookWindow(figureID: figureID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 380, height: 420)

        WindowGroup("Entity Report", id: "entity-report", for: EntityReportRequest.self) { $request in
            EntityReportWindow(request: request)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 640, height: 520)
    }
}
