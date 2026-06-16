# Anunnaki — Architecture

## Overview

Anunnaki is a single-window macOS desktop application for curating and exploring structured mythological knowledge. It uses **SwiftUI** with **SwiftData** for persistence, **AppKit** interop for specific controls, and **WebKit** for map previews. There are no external dependencies — all packages are Apple SDKs.

The app follows a straightforward **Model-View-Store** pattern:

- **Models** define the SwiftData schema
- **Views** provide the UI as SwiftUI components organized around list-detail splits
- **Store** encapsulates query logic, seeding, and API integration

A **dossier pattern** bundles related entities together for display, and the **QueryEngine** provides a natural language interface over the dossier system.

---

## Application Entry Point

`Sources/AnunnakiApp.swift` — `@main` struct `MeApp`

Initialization:
1. Declares a `Schema` with all 13 `@Model` types
2. Creates a `ModelContainer` with that schema
3. Calls `SeedData.seedIfEmpty(context:)` on first launch — loads `seed_data.json` from the bundle and populates the database
4. Presents a `WindowGroup("Me")` containing `ContentView` with `NavigationSplitView`

The app consistently uses `@main` on a SwiftUI `App` struct with `@NSApplicationDelegateAdaptor` for basic AppKit delegate callbacks (activation policy, icon loading).

---

## Data Layer

### SwiftData Models (`Sources/Models/`)

14 files, 13 `@Model final class` + 1 value type.

**Core entities** with relationships:

```
Figure  ──► Relationship ──► Figure   (family tree edges)
Figure  ──► AlternateName            (cross-cultural aliases)
Figure  ──► FigureImage              (attached images)
Figure  ──► FigurePlaceAssociation ──► Place

Event   ──► Figure                   (involved figures, many-to-many)
Event   ──► Place                    (location, many-to-one)

Place   ──► PlacePlaceAssociation ──► Place   (place–place links)
Event   ──► EventEventAssociation ──► Event   (event–event links)

Source  ──► Citation                 (source→entity reference)
Source  ──► Attachment               (URLs/files on sources)
```

Each model uses `@Relationship(deleteRule: .cascade, inverse: \...)` to maintain referential integrity.

**MythologicalDate** — A value type struct (not `@Model`) used as `@Attribute` on `Figure`, `Event`, and `Era`. Handles BCE dates via negative year values, "mythological" dates (nil year), and approximate indicators.

### Seed Data (`Sources/Store/SeedData.swift`)

On first launch, `SeedData.seedIfEmpty()` checks if any `Figure` exists. If not, it:
1. Loads `seed_data.json` from the bundle
2. Deserializes it through private `Seed*` codable structs (mirroring the model schema but with string-based references for cross-linking)
3. Inserts entities in dependency order: Eras → Figures → Relationships → Places → Events → Sources → Attachments → Citations → Alternate Names → Associations

The JSON file (`Sources/Resources/seed_data.json`, ~862 lines) contains canonical Mesopotamian data.

---

## View Layer (`Sources/Views/`)

27 SwiftUI views with a consistent set of patterns.

### Navigation

`ContentView` uses `NavigationSplitView` with three sidebar sections:

| Section | Items |
|---|---|
| **Tools** | Import from Wikipedia, Query |
| **Visualizations** | Lineage Tree, Timeline |
| **Data** | Figures, Places, Events, Relationships, Associations, Alternate Names, Eras, Sources |

Sidebar selection drives the detail pane via a `switch` statement.

### List-Detail Pattern

Every data entity has a `*ListView` / `*DetailView` pair:

- `FigureListView` + `FigureDetailView`
- `PlaceListView` + `PlaceDetailView`
- `EventListView` + `EventDetailView`
- `SourceListView` + `SourceDetailView`

**Layout**: `HStack` with a selectable `List` on the left (min 450pt wide) and a detail panel on the right (320pt wide). The detail panel shows a toolbar with edit/delete/explore buttons, then the entity's properties in a scroll view.

**Breadcrumbs**: Figure, Place, and Event list views maintain a `[(id: PersistentIdentifier, name: String)]` breadcrumb trail. Clicking a breadcrumb navigates back. The trail is capped at 12 entries.

**CRUD**: Each entity has a `*FormView` used for both add and edit, presented via `.sheet`. Forms use `.formStyle(.grouped)`.

### Visualizations

**TimelineView** — Horizontal columns for each `Era`, sorted by `orderIndex`. Figures are placed in eras based on their `birthDate.era` field matching the era name. Each column shows era name, date range, and a vertical list of figures as colored chips.

**LineageTreeView** — Recursive tree renderer. Root figures are identified as those who are not a child in any father/mother relationship. Each `TreeBranch` renders a `FigureCardView`, a vertical connector, and a `TreeChildrenRow` (with horizontal connector bars for multiple children). Supports click-to-select.

**FigureLineageExplorer** — Modal sheet centered on a single figure. Shows parents above, spouses beside, children below, with expandable grandparent/grandchildren sections. Clicking any figure recenters the tree.

### Query View

`QueryView` provides a text input using `AppKitTextField` (an `NSTextField` wrapper for proper focus handling). Results are displayed as dossier views (see Store section below).

### Other Views

- **ImportView** — Wikipedia search, extract preview, structured data import
- **MapPreviewButton/Sheet** — WKWebView wrapper loading OpenHistoricalMap
- **FigureImageGallery** — File picker for attaching images, stored in `~/Documents/Me/Images/`
- **EntityReportSheet** — Clickable entity links that show a dossier in a modal sheet

### Reusable Components

| Component | Purpose |
|---|---|
| `BreadcrumbBar` | History-based back navigation |
| `FigureTypeLegend` / `EventTypeLegend` / `PlaceTypeLegend` | Color/icon legend chips |
| `MiniLineageView` | Compact parent→figure→children display |
| `MiniChip` | Small clickable figure chip |
| `IconActionButton` | Hover-reveal icon toolbar button |
| `PropertyRow` | Label-value grid row |
| `MythologicalDateEditor` | Form section for date input |
| `FlowLayout` | Wrapping layout for chips |
| `FigureCardView` | Tree node card |

### Enum Extensions (`Sources/Extensions/`)

Each enum type has `color` and `icon` computed properties for consistent rendering:

| Enum | Colors | Icons (SF Symbols) |
|---|---|---|
| `Figure.FigureType` | purple/blue/orange/green | sparkles/star.fill/star.leadinghalf.filled/person.fill |
| `Place.PlaceType` | teal (all) | building.2/building.columns/map/sparkles/mountain.2/water.waves/arrow.down.to.line |
| `Event.EventType` | purple/red/blue/indigo/orange/teal/gray/yellow/green | shield/water.waves/arrow.down.circle/figure.walk/building.2/xmark.circle/arrow.up.circle/scroll |
| `Relationship.RelationshipType` | blue/pink/red/purple/orange/teal | arrow.down/heart/heart.circle/arrow.left.arrow.right/person.line.dotted.person/wand.and.stars |
| `Source.SourceType` | brown (all) | scroll/rectangle.portrait/text.alignleft/cylinder/book/graduationcap/list.number/music.note/doc |
| `AlternateName.Tradition` | Per-tradition colors | — |

---

## Store Layer (`Sources/Store/`)

### QueryEngine (`Sources/Store/QueryEngine.swift`)

A natural language query system that resolves user input against the database. Query processing order:

1. **Possessive patterns** — `"X's children"`, `"X's parents"`, `"X's spouse"`, `"X's siblings"`, `"X's creator/creations"`, `"X's events/figures"` (for places/events)
2. **Prepositional patterns** — `"children of X"`, `"parents of X"`, `"siblings of X"`, `"spouse of X"`, `"creator of X"`, `"events at X"`, `"figures at X"`, `"place of X"`, `"also known as X"`
3. **Direct entity match** — Exact match on figure/place/event name
4. **Question prefix stripping** — Removes `"what do we know about"`, `"tell me about"`, `"who is"`, `"what is"`, `"where is"` and retries

Returns a `QueryResult` enum:
- `.figure(FigureDossier)` — Single figure with all related data
- `.place(PlaceDossier)` — Single place with events and figures
- `.event(EventDossier)` — Single event with figures and place
- `.figureList(title, [Figure])` — Named list of figures (e.g., "Children of Anu")
- `.eventList(title, [Event])` — Named list of events
- `.placeList(title, [Place])` — Named list of places
- `.noMatch(String)` — Unresolved query

**Dossier** structs bundle an entity with all its related data:
- `FigureDossier` — figure + parents, children, spouses, creators, creations, events, places, placeAssociations, citations, matched alias
- `PlaceDossier` — place + events, figures
- `EventDossier` — event + figures, place

Entity resolution supports fuzzy matching (contains) and alternate name lookups.

### WikiClient (`Sources/Store/WikiClient.swift`)

HTTP client for three APIs:
- **Wikipedia Search API** — `action=query&list=search` — returns up to 10 results
- **Wikipedia Extract API** — `action=query&prop=extracts` — fetches plain text lead section
- **Wikidata Entity API** — fetches `Special:EntityData/{QID}.json` — returns claims, labels
- **Wikidata Label Resolution** — `wbgetentities` — batch-resolves QIDs to English labels

All API calls use `URLSession` async/await.

### WikidataParser (`Sources/Store/WikidataParser.swift`)

Maps Wikidata property claim values to model enums via QID lookup tables:

| Wikidata Property | Maps To |
|---|---|
| P31 (instance of) | `Figure.FigureType` / `Place.PlaceType` / `Event.EventType` |
| P21 (sex/gender) | `Figure.Gender` |
| P22 (father) / P25 (mother) | `.father` / `.mother` Relationship |
| P26 (spouse) | `.spouse` Relationship |
| P40 (child) | `.father` Relationship |
| P3373 (sibling) | `.sibling` Relationship |

The parser maintains hardcoded QID→enum mapping tables (e.g., Q5 → `.human`, Q6581097 → `.male`, Q515 → `.city`).

### Wikipedia Import Flow (`ImportView` + WikiClient `performImport`)

1. User searches Wikipedia → results displayed in a list
2. User selects a result → article extract fetched
3. User clicks "Import" → Wikidata entity fetched and parsed
4. Import auto-matches to existing entities by name (figures → places → events)
5. If matched:
   - A `Source` and `Citation` are created linking to Wikipedia
   - Entity properties are updated where empty (type, gender, description)
   - Relationships from Wikidata are created between matched local entities
6. If no match → saved as standalone `Source`

---

## Data Flow

### Typical Read Path

```
User taps "Figures" in sidebar
  → ContentView shows FigureListView
    → @Query fetches all [Figure] from SwiftData
    → User selects a figure
      → selectedFigureID set → Detail panel shows FigureDetailView
        → Relationships filtered via @Query([Relationship]) and local filter
        → Citations fetched ad-hoc via modelContext.fetch(FetchDescriptor)
```

### Typical Write Path (Add Figure)

```
User taps "Add Figure" → showingAddSheet = true
  → FigureFormView presented as .sheet
    → User fills form, taps "Add"
      → save() creates new Figure() and calls modelContext.insert()
      → dismiss()
```

### Seed Flow

```
MeApp.init()
  → ModelContainer created with Schema([...all models...])
  → SeedData.seedIfEmpty(context:)
    → fetchCount(Figure) == 0 → load seed_data.json → insert all objects
```

---

## Key Design Decisions

1. **No view models** — Views interact directly with SwiftData `@Query` and `ModelContext`. The "Store" layer is minimal (just QueryEngine + networking).
2. **No async state machines** — The import flow uses `Task { @MainActor in ... }` with simple boolean state flags (`isSearching`, `isFetching`, `isImporting`).
3. **Flat data model** — `MythologicalDate` is embedded as a struct attribute rather than a separate entity, keeping the schema simple for the scale of data (dozens of figures, not thousands).
4. **String-based references in seed JSON** — Cross-entity links use names (not IDs), resolved at import time. This makes the JSON human-editable but requires name uniqueness within entity types.
5. **AppKit interop only where needed** — `NSTextField` for the query input (SwiftUI `TextField` doesn't handle `onSubmit` reliably in all contexts), `WKWebView` for map preview.
