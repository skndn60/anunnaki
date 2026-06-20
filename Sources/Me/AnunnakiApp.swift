import SwiftUI
import SwiftData
import AppKit
import Foundation

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
        let schema = Schema([Figure.self, FigureType.self, Relationship.self, Era.self, Place.self, PlaceType.self, Event.self, EventType.self, Source.self, Citation.self, AlternateName.self, Attachment.self, ImageAsset.self, Tag.self, FigurePlaceAssociation.self, PlacePlaceAssociation.self, EventEventAssociation.self, EventPlaceAssociation.self, DataVersion.self])

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
            try? FileManager.default.removeItem(at: storeURL)
            do {
                let container = try ModelContainer(for: schema, configurations: [config])
                print("[Me] ModelContainer created after deleting store")
                return container
            } catch {
                fatalError("Failed to create ModelContainer after deleting store: \(error)")
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

        WindowGroup("Lineage Explorer", for: PersistentIdentifier.self) { $figureID in
            LineageExplorerWindow(figureID: figureID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 650)
    }
}
