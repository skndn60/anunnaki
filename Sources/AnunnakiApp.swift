import SwiftUI
import SwiftData
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        } else if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
                  let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
}

@main
struct MeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let container: ModelContainer

    init() {
        let schema = Schema([Figure.self, Relationship.self, Era.self, Place.self, Event.self, Source.self, Citation.self, AlternateName.self, Attachment.self, FigureImage.self, FigurePlaceAssociation.self, PlacePlaceAssociation.self, EventEventAssociation.self])
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            // Seed on first launch
            let context = container.mainContext
            SeedData.seedIfEmpty(context: context)
            try context.save()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("Me") {
            ContentView()
        }
        .modelContainer(container)
        .defaultSize(width: 1200, height: 800)
    }
}
