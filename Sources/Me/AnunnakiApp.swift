import SwiftUI
import SwiftData
import AppKit
import Foundation
import os

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

private let logger = Logger(subsystem: "com.me.app", category: "container")

package func storeURL() -> URL {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("Me").appendingPathComponent("Me.store")
}

extension Notification.Name {
    static let showBackupSheet = Notification.Name("MeShowBackupSheet")
    static let showNewFigure = Notification.Name("MeShowNewFigure")
    static let showNewPlace = Notification.Name("MeShowNewPlace")
    static let showNewEvent = Notification.Name("MeShowNewEvent")
    static let showNewThing = Notification.Name("MeShowNewThing")
}

struct CustomAboutCommand: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Me") {
                var options: [NSApplication.AboutPanelOptionKey: Any] = [
                    .applicationName: "Me",
                    .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                    .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
                    .credits: NSAttributedString(
                        string: "A knowledge management app for Sumerian mythology",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                    )
                ]
                if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
                   let icon = NSImage(contentsOf: iconURL) {
                    options[.applicationIcon] = icon
                } else if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
                          let icon = NSImage(contentsOf: iconURL) {
                    options[.applicationIcon] = icon
                }
                NSApplication.shared.orderFrontStandardAboutPanel(options: options)
            }
        }
    }
}

struct DatabaseMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Figure\u{2026}") {
                NotificationCenter.default.post(name: .showNewFigure, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Place\u{2026}") {
                NotificationCenter.default.post(name: .showNewPlace, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Event\u{2026}") {
                NotificationCenter.default.post(name: .showNewEvent, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Button("New Thing\u{2026}") {
                NotificationCenter.default.post(name: .showNewThing, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .control])
        }

        CommandMenu("Database") {
            Button("Back Up Database\u{2026}") {
                NotificationCenter.default.post(name: .showBackupSheet, object: nil)
            }
            .keyboardShortcut("b", modifiers: [.command, .shift])

            Button("Restore from Backup\u{2026}") {
                NotificationCenter.default.post(name: .showBackupSheet, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}

@main
struct MeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    package static let sharedContainer: ModelContainer = {
        let schema = Schema([Figure.self, FigureType.self, Relationship.self, RelationshipType.self, Era.self, Place.self, PlaceType.self, Event.self, EventType.self, Source.self, Citation.self, AlternateName.self, Attachment.self, ImageAsset.self, Tag.self, FigurePlaceAssociation.self, PlacePlaceAssociation.self, EventEventAssociation.self, EventPlaceAssociation.self, EventFigureAssociation.self, EventFigureRoleType.self, DataVersion.self, StickyNote.self, Thing.self, ThingType.self, ThingFigureAssociation.self, ThingFigureRoleType.self, ThingPlaceAssociation.self, ThingPlaceRoleType.self, ThingEventAssociation.self, ThingEventRoleType.self, Agent.self, CollectedDatum.self, BlindSpot.self, BlockedSource.self, DictionaryEntry.self, FigureGroup.self, FigureGroupAssociation.self, ContentAttribution.self, GroupTextBlock.self,             Pantheon.self, FigurePantheonAssociation.self,
            PopupTable.self, PopupTableAttribute.self, PopupTableCell.self, PopupTableColumn.self, CellSource.self,
            FindingDismissal.self, IntegrityFinding.self, User.self, ActivityLogEntry.self])

        let forceReseed = CommandLine.arguments.contains("--reseed")
        let storeURL = storeURL()
        let storeDirectory = storeURL.deletingLastPathComponent()

        if forceReseed {
            try? FileManager.default.removeItem(at: storeURL)
        }

        // Apply any staged restore now, before the container opens (after force-reseed wins).
        BackupService.applyPendingRestoreIfNeeded()

        try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)

        let config = ModelConfiguration(schema: schema, url: storeURL)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            logger.notice("Opened store at \(storeURL.path, privacy: .public)")
            return container
        } catch {
            logger.error("ModelContainer creation failed: \(error, privacy: .public)")
            let nsError = error as NSError
            logger.error("NSError domain=\(nsError.domain, privacy: .public) code=\(nsError.code)")
            Self.recoveryError = error.localizedDescription
            Self.recoveryBackupPath = storeURL.path
            logger.notice("Store left in place at \(storeURL.path, privacy: .public)")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: [fallback]) {
                logger.notice("Using in-memory fallback container")
                return container
            }
            fatalError("Cannot create any ModelContainer: \(error)")
        }
    }()

    package static var recoveryError: String?
    package static var recoveryBackupPath: String?

    let container: ModelContainer = Self.sharedContainer

    var body: some Scene {
        WindowGroup("Me") {
            ContentView()
                .onAppear {
                    if AgentService.container == nil {
                        AgentService.container = container
                    }
                }
        }
        .modelContainer(container)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CustomAboutCommand()
            DatabaseMenuCommands()
        }

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

        WindowGroup("Figure Detail", id: "figure-detail", for: PersistentIdentifier.self) { $figureID in
            FigureDetailWindow(figureID: figureID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 600, height: 500)

        WindowGroup("Entity Report", id: "entity-report", for: EntityReportRequest.self) { $request in
            EntityReportWindow(request: request)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 640, height: 520)

        WindowGroup("Place", id: "place-quickview", for: PersistentIdentifier.self) { $placeID in
            PlaceQuicklookWindow(placeID: placeID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 380, height: 420)

        WindowGroup("Event", id: "event-quickview", for: PersistentIdentifier.self) { $eventID in
            EventQuicklookWindow(eventID: eventID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 380, height: 420)

        WindowGroup("Collected Data", id: "datum-zoom", for: PersistentIdentifier.self) { $datumID in
            DatumZoomWindow(datumID: datumID)
                .modelContainer(container)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 720, height: 600)
    }
}

// MARK: - Quicklook windows

struct PlaceQuicklookWindow: View {
    let placeID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @State private var place: Place?

    var body: some View {
        Group {
            if let place {
                PlaceQuicklookContent(place: place)
            } else {
                Text("Place not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let placeID else { return }
            let fetch = FetchDescriptor<Place>(predicate: #Predicate { $0.persistentModelID == placeID })
            place = try? modelContext.fetch(fetch).first
        }
    }
}

private struct PlaceQuicklookContent: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "building.columns")
                    .foregroundStyle(.teal)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(place.name)
                        .font(.headline)
                    Text(place.placeType?.name ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !place.modernLocation.isEmpty {
                PropertyRow(label: "Modern Location", value: place.modernLocation)
            }

            if !place.placeDescription.isEmpty {
                Text(place.placeDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
        .padding(16)
    }
}

struct EventQuicklookWindow: View {
    let eventID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @State private var event: Event?

    var body: some View {
        Group {
            if let event {
                EventQuicklookContent(event: event)
            } else {
                Text("Event not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let eventID else { return }
            let fetch = FetchDescriptor<Event>(predicate: #Predicate { $0.persistentModelID == eventID })
            event = try? modelContext.fetch(fetch).first
        }
    }
}

private struct EventQuicklookContent: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text(event.name)
                        .font(.headline)
                    Text(event.eventType?.name ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if event.date != .unknown {
                PropertyRow(label: "Date", value: event.date.displayLabel)
            }

            if !event.eventDescription.isEmpty {
                Text(event.eventDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
        .padding(16)
    }
}

struct FigureDetailWindow: View {
    let figureID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @State private var figure: Figure?

    var body: some View {
        Group {
            if let figure {
                FigureQuicklookView(figure: figure)
            } else {
                Text("Figure not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let figureID else { return }
            let fetch = FetchDescriptor<Figure>(predicate: #Predicate { $0.persistentModelID == figureID })
            figure = try? modelContext.fetch(fetch).first
        }
    }
}
