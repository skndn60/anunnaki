# Anunnaki — Agent Context

## Project Identity

A macOS knowledge management app for Sumerian/Mesopotamian mythology. Built with SwiftUI + SwiftData. Users curate structured data about deities, places, events, and sources with a native desktop UI, visual lineage trees, timelines, and natural language querying.

Product name: **Me** (displayed in window title, executable name in Package.swift). Project codename: **Anunnaki**.

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI + AppKit interop (`NSTextField`, `WKWebView`)
- **Persistence**: SwiftData (`@Model`, `@Query`, `ModelContext`)
- **Dependencies**: None external (stdlib only: SwiftUI, SwiftData, AppKit, WebKit, Foundation)
- **Platform**: macOS 14+ only
- **Build**: Swift Package Manager (`swift build` / `swift test`)

## Build & Test Commands

```bash
swift build
swift test
swift run                          # launches the app
swift run Me --reseed              # force re-seed database from seed_data.json
```

## Project Structure

```
Sources/
  Me/
    AnunnakiApp.swift              # @main entry point, SwiftData container setup
    Views/                         # SwiftUI views
    Resources/                     # App icons
  MeCore/
    Models/                        # SwiftData @Model classes
    Store/                         # QueryEngine, WikiClient, WikidataParser, SeedData
    Extensions/                    # Color/icon helpers for enums
    Resources/                     # seed_data.json, wikidata_qids.json
Tests/
  MeCoreTests/                     # Unit tests for MeCore
Package.swift                      # Me executable + MeCore library + MeCoreTests
```

## Data Seeding

- `SeedData.seedIfEmpty(context:)` is called in `ContentView.onAppear` via `.task` — not in `App.init()` — so the app window opens immediately with a "Seeding database…" progress view.
- Re-seeding: pass `--reseed` as a launch argument to wipe all existing data and re-import from `seed_data.json`. In Xcode: Product → Scheme → Edit Scheme → Run → Arguments → add `--reseed` to "Arguments Passed on Launch".
- `SeedData.clearAll(context:)` deletes all entities in dependency order (associations first, then root entities).
- Existing figures (28), 21 new SKL dynasty eras, 10 SKL places, 10 father-son relationships — 162 total figures.
- **Migration-safe seeding**: When adding a new `@Model` entity to the schema after the store has already been seeded, lightweight migration adds the table but the seed function skips (because `figureCount > 0`). Use `ensureTypesExist(context:)` (or similar per-entity helper) to backfill missing seed data. This is called in the early-return path of `seedIfEmpty` so new entities are always populated.

## Data Model (all `@Model final class`)

| Entity | Purpose | Key Fields |
|---|---|---|
| **Figure** | Deity, human, primordial | name, figureType, gender, domain, birth/deathDate, figureDescription |
| **Relationship** | Family/creator links | fromFigure→toFigure, relationshipType (.father/.mother/.spouse/.sibling/.creator etc.) |
| **Place** | City, temple, realm, etc. | name, placeType, modernLocation, latitude, longitude |
| **Event** | Mythological event | name, eventType, date, involvedFigures[], place |
| **Era** | Timeline period | name, orderIndex, startDate, endDate |
| **Source** | Reference work | name, sourceType, author, language, period, url |
| **Citation** | Source→entity link | source, location, entityType, linkedEntityName |
| **Attachment** | URL/file on a Source | source, title, url, attachmentType |
| **AlternateName** | Cross-cultural alias | figure, name, tradition (.sumerian/.akkadian/.greek/etc.), nameType |
| **FigurePlaceAssociation** | Figure↔Place with role | figure, place, role (.patronDeity/.ruler/.worshippedAt/etc.) |
| **PlacePlaceAssociation** | Place↔Place link | fromPlace→toPlace, role (.locatedWithin/.nearTo/etc.) |
| **FigureType** | Dynamic type for figures | name, icon, colorHex (replaces hardcoded `Figure.FigureType` enum) |
| **EventType** | Dynamic type for events | name, icon, colorHex (replaces hardcoded `Event.EventType` enum) |
| **PlaceType** | Dynamic type for places | name, icon, colorHex (replaces hardcoded `Place.PlaceType` enum) |
| **EventEventAssociation** | Event↔Event link | fromEvent→toEvent, role (.caused/.motivated/.precedes/.contradicts/.parallels) |
| **FigureImage** | Image attached to figure | figure, filename, caption, source |
| **MythologicalDate** | Struct (not @Model) | year (Int?, negative=BCE), era, isApproximate |

## Architecture Patterns

- **List-Detail split**: All list views (Figures, Places, Events, Sources) use an `HStack` with a selectable list on the left and a detail panel on the right (320pt wide).
- **CRUD forms**: Each entity has a `FormView` (e.g., `FigureFormView`) used for both add and edit via `.sheet(isPresented:)`.
- **Breadcrumb navigation**: Used in Figure/Place/Event list views for history-based back navigation (`BreadcrumbBar`).
- **Color/icon extensions**: Each enum type has extensions providing `color` and `icon` (SF Symbols) for consistent UI rendering.
- **Dossier pattern**: `QueryEngine` builds "dossiers" (e.g., `FigureDossier`) bundling all related data (parents, children, spouses, events, places, citations) for the query and detail views.
- **Seed on launch (async)**: `SeedData.seedIfEmpty()` is called from `ContentView.task` — shows a loading indicator while seeding.
- **Natural Language Query**: `QueryEngine` parses possessive patterns ("X's children"), prepositional patterns ("children of X"), question prefixes ("what do we know about X"), and direct entity lookup.
- **Wikipedia Import**: `WikiClient` fetches search results, extracts, Wikidata IDs and entities. `WikidataParser` maps Wikidata QIDs to model enums. Import auto-matches to existing entities or creates a new Source.

## Coding Conventions

- **Comments**: None in source files (agent should not add comments).
- **Naming**: Swift conventions (camelCase properties, PascalCase types). Models use `figureDescription`, `eventDescription`, `placeDescription` (not `desc`).
- **SwiftUI**: Use `@Query` for fetches, `@Environment(\.modelContext)` for mutations. Prefer `NavigationSplitView` with sidebar.
- **Optional strings**: Default to `""` not `nil` for string fields. Optional `PersistentIdentifier` for selection state.
- **Breadcrumbs**: Tuple type `[(id: PersistentIdentifier, name: String)]` consistent across list views.
- **SwiftData**: Inverse relationships specified with `@Relationship(deleteRule: .cascade, inverse: ...)`.
- **SwiftData relationship setting**: Always set relationships via the side that HAS `@Relationship(inverse:)`. For example, `type.relationships.append(rel)` works but `rel.relationshipType = type` silently fails (leaves property nil). This is because the forward side (`Relationship.relationshipType`) lacks `@Relationship` while the inverse side (`RelationshipType.relationships`) has it. Always use the annotated side to establish links.
- **SwiftData migration safety**: Every new property added to an existing `@Model` must be **optional** (`Type?`), not non-optional with a default. SwiftData lightweight migration fails on non-optional new attributes — existing rows have no value and CoreData rejects the mandatory column. Use `?? defaultValue` in computed properties or at call sites instead.
- **Shared container**: `MeApp.sharedContainer` is a static property on the `@main` App struct, allowing direct access to the `ModelContainer` from anywhere (useful for debugging or bypassing environment inheritance issues).
- **Mock data**: `SeedData` uses private Codable structs mirroring the entities (e.g., `SeedFigure`, `SeedEvent`).
- **No external packages** — all dependencies are Apple SDKs.

## Important Files

- `Sources/Me/AnunnakiApp.swift` — App entry, schema setup
- `Sources/MeCore/Store/SeedData.swift` — JSON deserialization + DB insertion, includes `clearAll()` for reseeding
- `Sources/MeCore/Resources/seed_data.json` — Canonical Mesopotamian data (28 deities + 134 SKL kings)
- `Sources/MeCore/Store/QueryEngine.swift` — Natural language query engine
- `Sources/MeCore/Store/WikiClient.swift` — Wikipedia/Wikidata API client
- `Sources/MeCore/Store/WikidataParser.swift` — Wikidata QID→model enum mapping
- `Sources/MeCore/Models/FigureTypeModel.swift` — Dynamic FigureType model + Color hex extensions
- `Sources/MeCore/Models/EventTypeModel.swift` — Dynamic EventType model
- `Sources/MeCore/Models/PlaceTypeModel.swift` — Dynamic PlaceType model
- `Sources/Me/Views/FigureTypeManagerView.swift` — Management list + add/edit sheet for figure types
- `Sources/Me/Views/EventTypeManagerView.swift` — Management list + add/edit sheet for event types
- `Sources/Me/Views/PlaceTypeManagerView.swift` — Management list + add/edit sheet for place types
- `Sources/Me/Views/ContentView.swift` — Sidebar navigation split view, handles loading/seed state
- `Tests/MeCoreTests/MeCoreTests.swift` — Unit tests for MeCore
- `/tmp/parse_skl.py` — Python parser for Sumerian King List wikitext, generates seed JSON with UUIDs

## Session Log

### 2026-06-18 — Section headers, SKL view, delete confirmations, icon transparency

**Changes made:**
- `Sources/Me/Views/DisplayRow.swift` — Created `DisplayRow<Entity>` shared type with `DisplayItem` enum for section headers in sorted lists
- `Sources/Me/Views/FigureListView.swift` — Section headers (name→first letter, type→type name, domain→domain, date→era), delete confirmation alert
- `Sources/Me/Views/PlaceListView.swift` — Section headers + delete confirmation alert
- `Sources/Me/Views/EventListView.swift` — Section headers + delete confirmation alert
- `Sources/Me/Views/EraListView.swift` — Delete confirmation alert
- `Sources/Me/Views/SumerianKingListView.swift` — New file: grouped by dynasty, reign parsing via `SKLReignLength`, colorized `"N kings"` and `"Duration: X years"` labels
- `Sources/MeCore/Models/SKLReignLength.swift` — New file: `ReignLength` struct + `parse(from:)` using regex pattern `"Reigned\\s+([\\d,]+)\\s+years"`
- `Sources/Me/Views/AlternateNameListView.swift` — Replaced figure `Picker` with search text field + filtered list; filter bar picker → text field
- `Sources/Me/Views/AlternateNameFormView.swift` — Search-based figure selector (text field + filtered scroll list) matching EventFormView pattern
- `Sources/Me/Views/ContentView.swift` — Added `SidebarSection.history`, `NavigationItem.sumerianKingList`, sidebar section between Visualizations and Data
- `Sources/Me/AnunnakiApp.swift` — Changed `Bundle.main` → `Bundle.module` for app icon resource loading
- `Sources/Me/Resources/AppIcon.png` — Corner transparency fixed: 22% rounded-rect mask applied (pixels beyond quarter-circle radius set to alpha=0)
- `Sources/Me/Resources/AppIcon.icns` — Regenerated from fixed PNG (all required sizes via iconset)

**Icon fix (known issue):** The Swift script sets corner pixels with `dist > cornerRadius` to A=0, but creates a hard cutoff. The icon may look jagged at small sizes. Need a proper approach: either use `NSImage` with `cornerRadius` mask or a proper image editor. The fix is a starting point but makes corners transparent instead of opaque as before.

**Relevant new/removed files:**
- `Sources/Me/Views/DisplayRow.swift` — Added
- `Sources/Me/Views/SumerianKingListView.swift` — Added
- `Sources/MeCore/Models/SKLReignLength.swift` — Added

### 2026-06-22 — Resizable detail panel dividers across all 6 list views

**Changes made:**
- `Sources/Me/Views/ResizableDivider.swift` — New reusable component: draggable vertical divider with cursor change (`NSCursor.resizeLeftRight`) and `DragGesture` for resizing detail panel width.
- `Sources/Me/Views/FigureListView.swift` — Replaced `Divider()` and `.frame(width: 320)` with `ResizableDivider` and `@AppStorage("figureDetailWidth")`.
- `Sources/Me/Views/PlaceListView.swift` — Same change with `@AppStorage("placeDetailWidth")`.
- `Sources/Me/Views/EventListView.swift` — Same change with `@AppStorage("eventDetailWidth")`.
- `Sources/Me/Views/SourceListView.swift` — Same change with `@AppStorage("sourceDetailWidth")`.
- `Sources/Me/Views/EraListView.swift` — Same change with `@AppStorage("eraDetailWidth")`.
- `Sources/Me/Views/SumerianKingListView.swift` — Same change with `@AppStorage("sklDetailWidth")`.

**Design decisions:**
- `@AppStorage` (Double) persists widths per view across launches.
- Drag range clamped to 200–800pt to prevent collapsing or over-expanding.
- Each view stores its own key so Figure, Place, Event, Source, Era, and SKL panels have independent widths.
- `ResizableDivider` uses `NSCursor.resizeLeftRight` on hover for native macOS feel.
- Minimum drag distance of 5pt prevents accidental activation.

**Relevant new/removed files:**
- `Sources/Me/Views/ResizableDivider.swift` — Added

### 2026-06-22 — Design note: `Relationship.source` as lineage discriminator

**The idea:** Different source texts (Enuma Elish, Atra-Hasis, SKL, Epic of Gilgamesh, etc.) each provide their own genealogical accounts, often contradictory. The `Relationship.source` string (already present, free-text) can serve as a discriminator to show separate lineage trees per source tradition, rather than merging all relationships into one monolithic tree.

**Open questions (need more thought):**
- Should lineage views get a source picker (e.g., "All Sources" / "Enuma Elish" / "Sumerian King List") that filters relationships by `source`?
- Or should `source` be promoted from a free-text string to a `@Relationship` to the `Source` model for referential integrity?
- How to display contradictions explicitly (e.g., "Enuma Elish says X is father of Y, but Atra-Hasis says Z is father of Y")?
- Should `QueryEngine`/natural language queries also respect source discrimination?
- Does `MiniLineageView` need the filter, or only the full-tree views?
- The `Citation` model already provides polymorphic entity→Source linking — should `Relationship` use it instead of/in addition to the string field?

**Current state (baseline):** All three lineage views (`LineageTreeView`, `FigureLineageExplorer`, `MiniLineageView`) query all relationships with no source predicate. The `source` string is displayed in `RelationshipListView` and `FigureDetailView` but unused for filtering.

### 2026-06-20 — Fix massive top padding in Pre-Flood timeline

**Changes made:**
- `Sources/Me/Views/TimelinePreView.swift` — Changed `ScrollView([.horizontal, .vertical])` to `ScrollView(.vertical)`. Dual-axis ScrollView in SwiftUI centers content in both axes when content is smaller than the viewport, creating massive top/bottom padding. Single-axis `.vertical` keeps content top-aligned. Pre-flood doesn't need outer horizontal scrolling (mythological swimlanes have their own internal horizontal scroll).
- `AGENTS.md` — Added Debugging Visual Layout Issues section with layered `.background()` procedure.

## Debugging Visual Layout Issues

When investigating SwiftUI layout bugs (unexpected padding, misalignment, sizing), follow this procedure:

1. **Add a colored `.background()` to the outermost view first**, then run to observe which view claims the full frame.
2. **Work inward layer by layer**, moving the background color one level deeper each time, until you isolate which view has the unexpected size or position.
3. Only after identifying the root view should you look at modifier chains or data flow.

This is faster and more reliable than reading code to simulate the layout engine.

### 2026-06-23 — Enoch Archangels backfill

**Problem:** Archangels section missing in EnochView for existing databases. `ensureTypesExist` gates FigureType creation on `figureTypeCount == 0`, so types added later (Archangel, Igigi, Commander) are never backfilled. `ensureEnochDataExists` early-returns if Mount Hermon exists, preventing any archangel creation.

**Fix:** Added `Migration.ensureArchangelsExist(context:)` — creates the Archangel FigureType if missing (same pattern as `ensureCommanderFigureTypeExists`), then creates the 7 archangel figures (Michael, Gabriel, Uriel, Raphael, Raguel, Saraqael, Remiel) by name if absent. Called at the top of `ensureEnochDataExists` before the Mount Hermon guard, so it runs on every launch.

**Lesson:** Any entity or type added to `seed_data.json` after the first public build needs a `Migration.swift` backfill for existing databases. Never rely solely on the fresh-seed path.

### 2026-06-27 — Parent search sheet: fix relationshipType not persisting

**Problem:** `ParentSearchSheet.selectParent` created a `Relationship` with `relationshipType: type` but the type was always nil in the database, despite the `RelationshipType` existing and the code explicitly passing it.

**Root cause:** SwiftData only syncs relationships when set via the side annotated with `@Relationship(inverse:)`. `Relationship.relationshipType` lacks `@Relationship`, so assigning `rel.relationshipType = type` silently fails — the property stays nil. `RelationshipType.relationships` has `@Relationship(inverse: \Relationship.relationshipType)`, so `type.relationships.append(rel)` correctly establishes the link and auto-syncs the forward side.

**Changes made:**
- `Sources/Me/Views/FigureDetailView.swift` — In `ParentSearchSheet.selectParent`, changed to `type.relationships.append(rel)` after `modelContext.insert(rel)`. Removed direct assignment to `rel.relationshipType`.
- `AGENTS.md` — Added "SwiftData relationship setting" convention rule documenting this behavior.

**Lesson:** Always set SwiftData bidirectional relationships via the side that has `@Relationship(inverse:)`. The unannotated forward side is effectively read-only.

### 2026-06-24 — Lineage ambiguity: collapse to 1 per type + alternative badges

**Problem:** When multiple relationships of the same parent type exist (e.g., two "Mother" entries for the same figure), all four lineage views rendered them side-by-side — confusing for contradictory traditions. The `isPreferred` flag existed but wasn't used for collapsing.

**Changes made:**
- `FigureLineageExplorer.swift` — Replaced `preferred()` + `altCounts()` with unified `resolveGeneration()` returning `(figures, alts)`. Added `resolvedParents`/`parentAlts`, `resolvedChildren`/`childAlts`, `resolvedGrandparents`/`grandparentAlts`, `resolvedGrandchildren`/`grandchildAlts`. Updated `generationRow` to accept `alts` + `onSelectAlt`. All callers pass alts dict.
- `LineageTreeView.swift` — Same pattern with parameterized methods (`parentsAndAlts(of:)`, `childrenAndAlts(of:)`, `grandparentsAndAlts(of:)`, `grandchildrenAndAlts(of:)`). Updated `generationRow` and all callers.
- `LineageExplorerWindow.swift` — Same instance-property pattern as FigureLineageExplorer. Added `resolveGeneration()`, resolved properties, updated `generationRow` and callers.
- `MiniLineageView.swift` — Fixed build error (stale `preferredParent()` calls → `parents(typeName:of:from:).preferred`). Then extracted `ParentChipView` struct so father/mother each own their `@State` for the popover (previously shared state caused empty popover). Moved `.popover` from `HStack` to the `+N` button itself. Removed intermediate `popoverFigures` copy — reads `alternatives` directly.

**Key design decisions:**
- All lineage views consistently use `resolveGeneration()` to collapse to ≤1 figure per type.
- Alternatives shown as `+N` badge → popover listing alternatives → click navigates/recenters.
- `resolveGeneration()` returns both the filtered figures AND an alternatives dictionary, avoiding redundant computations.
- `FigureCardView` already supported `alternatives` + `onSelectAlt` — lineage views just needed to pass them through.

**Relevant files:**
- `Sources/Me/Views/FigureLineageExplorer.swift` — Updated
- `Sources/Me/Views/LineageTreeView.swift` — Updated (includes `FigureCardView`)
- `Sources/Me/Views/LineageExplorerWindow.swift` — Updated
- `Sources/Me/Views/MiniLineageView.swift` — Updated + `ParentChipView` extracted

### 2026-07-03 — Yes/no relationship questions

**Problem:** "Was Bau a sibling of Enki?" returned Enki's full sibling list instead of a yes/no answer. Two bugs:
1. **Execution order**: `matchFigureRelationPrepositional` (line 136, matches "sibling of X") ran before `matchYesNoQuery` (line 206), so "was bau a sibling of enki" was interpreted as "siblings of enki" — a list query.
2. **No relationship awareness**: `matchYesNoQuery` only compared remaining text against the figure's type/domain/description — it couldn't answer "is X a sibling/father/child... of Y?"

**Fix:**
- Moved `matchYesNoQuery` to the top of the `query()` chain so yes/no questions are evaluated before any list-returning matcher.
- Added `matchRelationshipYesNo(text:lemText:)` — parses `"[relationshipWord] of [target]"` patterns from the lemmatized text, extracts both the subject and target figures directly (bypassing `extractEntity` which picks by name length, not position), and checks the relationship.
- 6 helper methods (`isFatherOf`, `isMotherOf`, `isChildOf`, `isCreatorOf`, `isSpouseOf`, `isSiblingOf`) using `outgoingRelationships`/`incomingRelationships` with explicit `for` loops to avoid Swift compiler type-checking timeouts on complex `contains(where:)` closures.
- Gender checking: "brother of" for a female figure returns "No, X is not a brother. X is a sister."

**Relevant files:**
- `Sources/MeCore/Store/QueryEngine.swift` — `query()` reordering, new `matchRelationshipYesNo()` + 6 helper methods

### 2026-07-18 — Fix lineage line coordinate mismatch

**Problem:** Lines drawn by `Canvas` appeared at wrong positions relative to figure cards. The `GeometryReader` in `FigureCardView` reported frames via `.frame(in: .named(coordinateSpace))`, but the named coordinate space was applied to the view *after* `.padding(40)`, while the `Canvas` drew relative to the ZStack's own top-left (inside the padding). This caused a 40pt offset — the GeometryReader coordinates included the padding offset, but the Canvas drawing did not.

**Root cause:** `.coordinateSpace(name: "tree")` was applied to the ScrollView's content (after `.padding(40)`), so the named space origin was 40pt away from the ZStack's origin. The Canvas draws at (0,0) relative to its own bounds (the ZStack), but `geo.frame(in: .named("tree"))` reported coordinates relative to the padded view's top-left.

**Partial fix:** Moved `.coordinateSpace(name:)` from the ScrollView content (after padding) to the ZStack returned by `lineageContent`. Both the Canvas and the GeometryReader are children of this ZStack, so they now share the exact same coordinate origin. This fixed the initial static rendering — lines now appear at correct positions on first load.

**Known remaining issue:** Lines are still visually wrong when clicking figures to recenter. The `nodePositions` dictionary accumulates stale entries from previous renders, and the Canvas `.id(nodePositions.count)` key doesn't invalidate correctly when positions change (only when count changes, not when values update). Lines become a "utter mess" after a few clicks.

**Relevant files:**
- `Sources/Me/Views/LineageTreeView.swift` — moved `.coordinateSpace` to ZStack inside `lineageContent(for:)`
- `Sources/Me/Views/FigureLineageExplorer.swift` — same fix
- `Sources/Me/Views/LineageExplorerWindow.swift` — same fix

### 2026-07-20 — Interactive lineage tree, Canvas gestures, unknown parent placeholders, figure→lineage nav

**Changes made:**

- `Sources/Me/Views/LineageTreeView.swift` — Full rewrite of interaction layer:
  - Canvas-native gestures: `onTapGesture` (tap-to-recenter + badge hit-testing for +N alternatives), `contextMenu` (Show Details / Recenter / Collapse Branch via `rightClickFigureID`), `onContinuousHover` (cursor tracking for context menu targeting).
  - Sheets extracted to separate `AlternativePartnersSheet` and `FigureDetailSheet` view structs with `.sheet(item:)` to avoid re-entrancy crashes.
  - **Unknown parent placeholders**: When a figure has no father/mother relationship, a dashed-border card with `?` icon and "UNKNOWN FATHER" / "UNKNOWN MOTHER" label appears as a lineage dead-end. Partial coverage (mother known, father missing) shows real card alongside placeholder for the missing type. Placeholder Figure objects created transiently (not persisted), looked up from `data.entries` in `drawNodes` to avoid being skipped by `@Query figures`.
  - **Gender indicator**: Gender symbol (♂/♀/⚧) shown next to figure name in each card.
  - **Back navigation**: `centerHistory` stack + `← Back` button in header, `goBack()` pops last entry.
  - **Stepper redesign**: Generation depth controls use `.bordered` button style with `title3` icons (32×28pt frames), max clamped to 4 per side. Removed line-visibility toggle button.
  - `collectAncestors` extended to create placeholder entries and backfill missing parent types (Father/Mother) per-figure.
- `Sources/Me/Views/FigureCardView.swift` — New shared view component for figure cards in lineage trees.
- `Sources/Me/Views/NavigationCoordinator.swift` — Added `pendingLineageFigureID`, `navigateToLineageFigure(_:)`, `consumePendingLineageFigureID()`.
- `Sources/Me/Views/FigureListView.swift` — Tree icon button now calls `coordinator?.navigateToLineageFigure()` (inline sidebar tree) instead of `openWindow(id:"lineage")` (separate window).
- `Sources/Me/Views/ContentView.swift` — Added `.lineage` branch in the detail `if/else` chain to pass `coordinator` to `LineageTreeView`.

**Key design decisions:**
- Placeholder Figure objects are created as transient `Figure(name: "Unknown Father")` outside of any ModelContext. They have temporary `persistentModelID` values that serve as layout keys within a single render cycle.
- `drawNodes` falls back to `data.entries` when a figure ID isn't found in `@Query figures` — necessary because transient figures don't appear in database queries.
- Placeholder cards are rendered with dashed borders, muted secondary colors, no partner alternatives or detail navigation.
- The `.bordered` button style for steppers provides clear visual affordance on macOS.
- `NavigationCoordinator.pendingLineageFigureID` follows the same consume-on-appear pattern as `pendingFigureID` for figures.

**Lessons learned:**
- Overlay views with `.position()` fail for popovers/sheets in Canvas — use `.sheet(item:)` with view structs and `onClose` callbacks instead.
- `NSCursor.push()/pop()` can unbalance the AppKit cursor stack — avoid in SwiftUI contexts.
- `NavigationSplitView` sidebar can be toggled off via `Cmd+Opt+S` on macOS — not a code bug.
- Transient `@Model` instances are valid SwiftData objects with usable `persistentModelID`, but won't appear in `@Query` results.

**Relevant files:**
- `Sources/Me/Views/LineageTreeView.swift` — Major rewrite
- `Sources/Me/Views/FigureCardView.swift` — New file
- `Sources/Me/Views/NavigationCoordinator.swift` — Extended
- `Sources/Me/Views/FigureListView.swift` — Updated tree icon handler
- `Sources/Me/Views/ContentView.swift` — Added `.lineage` coordinator branch

## TODO

- [ ] **Lineage lines broken on recenter:** This issue was in the old overlay-based LineageTreeView and is no longer present in the current Canvas-based implementation. Remove if confirmed fixed.
- [ ] **Lineage lines: consider PreferenceKey approach:** Named coordinate spaces are fragile. A `PreferenceKey` where each `FigureCardView` reports its frame via `.preference(key:value:)`, collected with `.onPreferenceChange`, would be more robust and avoid coordinate space mismatches entirely.

- [ ] Lineage source discriminator: Decide whether to add source picker to lineage views
- [ ] Lineage source discriminator: Promote Relationship.source from free-text to @Relationship with Source model
- [ ] Lineage source discriminator: Implement display for contradictory traditions (e.g., Enuma Elish vs Atra-Hasis)
- [ ] Lineage source discriminator: Add source discrimination to QueryEngine/natural language queries
- [ ] App icon fix: Replace hard cutoff corner transparency with proper NSImage cornerRadius mask
- [ ] Migration safety: Ensure any new @Model entities get Migration.swift backfill helpers

## Hard Constraints

- **NO reseeding.** Never run `--reseed`, never call `clearAll`, never destroy user data. All migrations must be additive only (check-by-name before creating). The user's existing database is sacred.

## Interaction Guidelines (from CONTRIBUTING.md)

### 2026-06-28 — Visual polish across all list views

**Changes:**
- `Sources/Me/Views/DashboardView.swift` — Normalized `arrow.counterclockwise.circle` → `arrow.counterclockwise`
- `Sources/Me/Views/FigureListView.swift` — Added `.background(.thinMaterial)` + slide transition to detail panel; extracted `typeFilterButton` and `figureGroupSection` helpers to fix type-checking timeouts
- `Sources/Me/Views/PlaceListView.swift` — Same material + transition; extracted `placeGroupSection` helper
- `Sources/Me/Views/EventListView.swift` — Same material + transition; extracted `eventGroupSection` helper
- `Sources/Me/Views/SourceListView.swift` — Same material + transition
- `Sources/Me/Views/EraListView.swift` — Same material + transition
- `Sources/Me/Views/ThingListView.swift` — Same material + transition; extracted `thingGroupSection` helper
- `Sources/Me/Views/SumerianKingListView.swift` — Same material + transition; added `.help("Close")` tooltip
- `Sources/Me/Views/SumerianKingPlaceListView.swift` — Same material + transition; added `.help("Close")` tooltip
- `Sources/Me/Views/SumerianKingEventListView.swift` — Same material + transition; added `.help("Close")` tooltip

**Key pattern:** All `if let ... { ... }.transition(...)` blocks wrapped in `Group { if let ... { ... } }.transition(...)` to avoid "instance member 'transition' cannot be used on type 'View'" compiler errors when the detail panel has `.background(.thinMaterial)` modifier.

### 2026-06-28 — Inline place link popover in FigureDetailView

**Problem:** Adding a Figure↔Place association required navigating to the separate `AssociationsView` in the sidebar, disrupting the data analysis workflow. The "Associated Places" section in `FigureDetailView` was read-only.

**Fix:** Added a `+` button next to the "Associated Places" header that opens a `PlaceLinkPopover` — an inline popover with a search field, filtered place list, role picker, and "Link" button. The association is created directly without leaving the detail view. Section now always visible (previously hidden when empty, now shows "No places linked").

**SwiftData relationship pattern:** Follows the convention from the 2026-06-27 fix — create the `FigurePlaceAssociation`, insert into context, then set relationships via the annotated inverse arrays (`figure.placeAssociations.append`, `place.figureAssociations.append`, `roleType.associations.append`).

**Changes made:**
- `Sources/Me/Views/FigureDetailView.swift` — Added `PlaceLinkPopover` private struct at bottom of file. Added state vars `showPlaceLinkPopover`, `placeSearchText`, `selectedPlaceForLink`, `selectedPlaceRole`. Replaced conditional `if !figure.placeAssociations.isEmpty { Divider() ... }` with unconditional `Divider() + HStack(header + + button + popover)`. Extracted `headerView`, `alternateNamesView`, `relationshipsView`, `eventsView`, `citationsView` as computed properties to fix Swift compiler type-checking timeout from the increased body complexity.

- One change per request. Split large tasks into small steps.
- Validate JSON with `jq --exit-status . Sources/Resources/seed_data.json` before committing seed changes.
- Run `swift build` before submitting changes.
- Branch naming: `feat/`, `bugfix/`, `migration/` prefixes.
- Do not commit secrets, keys, or provisioning profiles.

### 2026-06-30 — Parental couples: groupID for Relationship, ParentCoupleSheet, couple-groped lineage

**Problem:** Adding parents via separate Father/Mother sheets created unlinked relationships. The lineage view displayed father and mother as independent columns with per-parent alternatives (e.g., father: Dumuzi alt: Nanna, mother: Inanna alt: Ningal), allowing semantically invalid pairings like Dumuzi+Ningal. The `isPreferred` flag couldn't express which parents belong together as couples.

**Solution:**
1. **`groupID: String = ""` on `Relationship`** — Two relationships with the same non-empty `groupID` (one Father, one Mother) form a parental couple. Declaration-site default `= ""` ensures safe lightweight migration.
2. **`ParentCoupleSheet`** — New two-column sheet (Father + Mother side by side). Each side has a search field and figure list. Both parents are optional (add one or both). On "Add", both relationships are created with the same `UUID().uuidString` groupID.
3. **`buildCouples()`** — File-level function that groups parent relationships by `groupID`. Legacy relationships (empty `groupID`) are paired dynamically: first Father + first Mother = couple 1, etc. No data mutation needed.
4. **`MiniLineageView` refactor** — Replaced independent father/mother columns with couple-based display. Shows one preferred couple's father + mother with a `—` connector. Alternative couples shown via `+N` badge → popover → selecting an alternative calls `setPreferredCouple()` to toggle `isPreferred`.

**Design decisions:**
- Legacy relationships are NOT migrated in the database — `buildCouples()` handles pairing dynamically using insertion order.
- New relationships created via `ParentCoupleSheet` always get a `UUID().uuidString` groupID.
- `setPreferredCouple()` marks all relationships in the selected couple as `isPreferred = true` and all others as false.
- The larger lineage views (FigureLineageExplorer, LineageTreeView, LineageExplorerWindow) remain unchanged — they group by `relationshipType.name` and handle alternatives independently.
- `parentSearchText` state var removed from FigureDetailView (now internal to ParentCoupleSheet).

**Relevant files:**
- `Sources/MeCore/Models/Relationship.swift` — Added `groupID: String = ""` field + init parameter
- `Sources/Me/Views/MiniLineageView.swift` — Refactored to couple-based layout: `buildCouples()`, `ParentCouple`, `AltCouplesButton`, `setPreferredCouple()`
- `Sources/Me/Views/FigureDetailView.swift` — Replaced `ParentSearchSheet` + `parentSearchText` with `ParentCoupleSheet` (two-column father+mother selection)

### 2026-07-22 — Fix post-flood era bars: avoid conditional views and .opacity() inside ZStack

**Problem:** Colored era background bars (`eraBar`) in the post-flood timeline were invisible. Debug diagnostics confirmed `hasValidDates=true` and correct coordinate computation. The bars rendered correctly only when placed unconditionally in the ZStack without `.opacity()` or `if`/`if let` wrapping.

**Root cause:** SwiftUI conditional views (`if`, `if let`) and the `.opacity()` modifier applied to views with `.position()` inside a `ZStack` wrapped in `AnyView` rendered at zero visual presence. The views existed in the tree but were not visible, even with `.opacity(1)` and `hasValidDates=true`. This appears to be a SwiftUI bug specific to local-scope computed properties used in `.opacity()` or conditional blocks within this view hierarchy.

**Fix:** Compute coordinates at function level (outside the ZStack). Always render `eraBar` and life bars unconditionally — no `if`, no `if let`, no `.opacity()`. Each figure's per-element `if let` inside `ForEach` is safe since it operates on individual data, not the entire rendering block.

**Lesson:** Never use `.opacity()` with local computed Bool variables or `if` conditionals on entire sub-views when using `.position()` inside a `ZStack` + `AnyView` combo. Always render views unconditionally and let per-element checks control visibility.
