# Anunnaki — Agent Context

## Project Identity

A macOS knowledge management app for Sumerian/Mesopotamian mythology. Built with SwiftUI + SwiftData. Users curate structured data about deities, places, events, and sources with a native desktop UI, visual lineage trees, timelines, and natural language querying.

Product name: **Me** (displayed in window title, executable name in Package.swift). Project codename: **Anunnaki**.

## Project Genesis & Motivation

The app is a **personal hobby project** — no commercial goals, not intended to be sold (at least not actively). Origins: the developer has long been fascinated by the Anunnaki and Sumerian civilization, but the sheer volume of figures and places involved in that mythology was bewildering, and no tool existed to organize it and make it more accessible. That gap, plus a second interest in Mac app development, is the cornerstone of the project.

**What this means for decisions:**
- It is also a way to stay connected to AI/LLM tooling (pair-programming, natural language querying) — so the AI-facing surface (QueryEngine, natural-language features) matters as much as the data model.
- No growth/audience pressure: the app is built to be useful to one person. "Niche audience" is not a risk to manage; data-entry speed for personal use is the lever that matters (see `PRODUCT_WEAKNESSES.md`).
- Data safety and long-term maintainability outrank shipping velocity; the user's existing database is sacred (see Hard Constraints).

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
- `Sources/Me/Views/WizardContainer.swift` — Reusable multi-step wizard container with step indicator and navigation
- `Sources/Me/Views/FigureFormView.swift` — Extracted 3-step wizard form for adding/editing figures (Identity → Details → Source & Tags)
- `Sources/Me/Views/ContentView.swift` — Sidebar navigation split view, handles loading/seed state
- `Tests/MeCoreTests/MeCoreTests.swift` — Unit tests for MeCore
- `/tmp/parse_skl.py` — Python parser for Sumerian King List wikitext, generates seed JSON with UUIDs
- `PRODUCT_WEAKNESSES.md` — Product-level critique: the app's weak spots and strategy (cold-start data volume, trapped data, contradictory traditions, curation burden, niche risk, no feedback loop) + priorities
- `ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` — Code-level technical debt review (SwiftData boilerplate, Relationship.source, width persistence, lineage complexity)
- `TODO.md` — Open/backlog work items and completed feature checklists (the todo list previously inline in AGENTS.md)

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

### 2026-07-27 — FigureFormView wizard + WizardContainer

**Changes made:**
- `Sources/Me/Views/WizardContainer.swift` — New reusable generic container: step indicator (dots + labels), back/next/save navigation bar, cancel action. Designed for any multi-step form flow.
- `Sources/Me/Views/FigureFormView.swift` — Extracted from inline in FigureListView.swift. Rebuilt as 3-step wizard using WizardContainer:
  - Step 1 (Identity): name, disambiguation, title, type picker, gender picker, domain
  - Step 2 (Details): description, birth/death dates, reign start/end years
  - Step 3 (Source & Tags): source text, cause of death, tags
- `Sources/Me/Views/FigureListView.swift` — Removed inline `FigureFormView` struct (~140 lines). All 5 callers (FigureListView, SumerianKingListView, EntityReportSheet, EnochView, DashboardView) continue to reference `FigureFormView` unchanged — no import changes needed since it's in the same module.
- `AGENTS.md` — Updated TODO: "Wizard system" replaced with "Wizardify remaining forms (PlaceFormView, EventFormView, ThingFormView)". Added WizardContainer + FigureFormView to important files list.

**Design decisions:**
- Save deferred to final step (clicking "Save"/"Add" on step 3). No incremental saves.
- Name field required to enable Next on step 1 (matching original behavior where Save was disabled when name empty).
- Step indicator shows connected dots with current step highlighted. Step labels shown below.
- Window height reduced from 680 → 520 (wizard nav is more compact than the original full-form layout).
- Back button hidden on step 1, Next/Save uses `.keyboardShortcut(.defaultAction)`.

**Relevant new/removed files:**
- `Sources/Me/Views/WizardContainer.swift` — Added
- `Sources/Me/Views/FigureFormView.swift` — Added (extracted from FigureListView.swift)

**Relevant files:**
- `Sources/Me/Views/FigureListView.swift` — Updated

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

### 2026-07-24 — Figure detail shared components + declarative query templates

**Changes made:**

- `Sources/Me/Views/FigureDetailInfoView.swift` — New file: 8 reusable atomic components extracted from FigureDetailView and FigureDossierView:
  - `FigureTypeBadge` — colored pill with type name
  - `FigureIconCircle` — colored circle with type icon (parameterized size)
  - `FigureNameWithGender` — name + gender symbol + optional disambiguation
  - `FigureTitleRow` — subtitle line
  - `FigureHeaderView` — composite header (icon + name + type + optional birth date)
  - `FigureDescriptionView` — body text block
  - `FigurePlaceAssociationRow` — place assoc with callback navigation (used in FigureDetailView)
  - `FigurePlaceAssociationDossierRow` — place assoc with EntityLink (used in FigureDossierView)
  - `FigureCitationsRow` — single citation row (identical in both views)
  - `FigureRelationshipRow` — generic relationship line with callback
  - `FigureDossierRelationshipList` — labeled list of entity links for family section
- `Sources/MeCore/Store/QueryEngine.swift` — Replaced 110 lines of hardcoded pattern-matching in `matchCountAtPlaceQuery`/`matchListAtPlaceQuery` with a declarative template array (`queryTemplates: [QueryTemplate]`). 15 regex-based templates defined as data, executed by a generic `matchFallbackQuery` + `executeMeasure` pipeline. Added era-anchored patterns ("which X belonged to Y", "X of the Y"). All existing behavior preserved.
- `Sources/Me/Views/FigureDetailView.swift` — Replaced inline icon circle, type badge, citation rows, and place association rows with shared components from FigureDetailInfoView.
- `Sources/Me/Views/QueryView.swift` — Refactored `FigureDossierView` to use shared components (FigureHeaderView, FigureDescriptionView, FigureDossierRelationshipList, FigurePlaceAssociationDossierRow, FigureCitationsRow). Removed unused `entityLine` helper.
- `Tests/MeCoreTests/MeCoreTests.swift` — Added 4 tests for declarative query templates (`testCountDynastiesAtPlace`, `testCountKingsAtPlace`, `testListDynastiesAtPlace`, `testWhoRuledPlace`) and 2 tests for era-anchored queries (`testWhichRulersBelongedToEra`, `testKingsOfTheEra`).

**New query patterns (declarative data, not code):**
- Place-anchored: "how many [measure] did [place] have", "how many [measure] in/at [place]", "what [measure] ruled [place]", "who ruled [place]"
- Era-anchored: "which/ [measure] belonged to [era]", " [measure] of the [era]", "how many [measure] in the [era]"

**Relevant new/removed files:**
- `Sources/Me/Views/FigureDetailInfoView.swift` — Added

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

### 2026-07-27 — SKL events, figures & places enrichment; JSON decode debugging

**Objective:** Enrich the database with historically attested events across SKL dynasties (project 1) and temple places (project 2) via additive migration only (no reseeding).

**Changes made to seed_data.json (207 figures, 37 places, 67 events):**
- Added 40 new events across all SKL dynasties: Kish I (4), Uruk I (4), Lagash-Umma (5), Uruk III (2), Akkad (8), Gutian (4), Ur III (4), Isin (5), other dynasties (4). Events include battles, foundations, treaties, reforms, transitions, and constructions.
- Added 5 new figures: Eannatum, Entemena, Urukagina, Ukush, Mesilim (with stable UUIDs).
- Added 4 new places: Girsu (City), Gu-Edin (Region), Aratta (Region), Dabrum (City).
- Added 56 `eventPlaceAssociations` entries for place-linked events.
- Sanitized all `null` values for non-optional `String` fields across the JSON.
- Added missing `"things": []` key.

**New code:**
- `Migration.ensureSKLEventsAndFigures(context:)` — Reads seed_data.json, backfills missing figures, places, and events for existing databases. Creates figure→event involvement and event→place associations.
- `ContentView.swift` — Added migration call to launch sequence (after `ensureEventCitations`).

**Debugging saga — JSON decode failures:**
1. **Stale resource copy:** `Sources/Me/Resources/seed_data.json` had only 197 figures (old version). `Me_Me.bundle` served stale data to `Bundle.main` fallback paths. Fixed by syncing both copies.
2. **Missing `"things": []` key:** `SeedDataRoot.things` is non-optional `[SeedThing]`. The generated JSON had no `things` key, causing `JSONDecoder.decode` to throw `keyNotFound` silently.
3. **Null non-optional strings:** 6 places had `"source": null` or `"modernLocation": null`. Swift `Codable.init(from:)` throws `valueNotFound` on `null` for non-optional `String`. The `try?` in all 3 migrations (`ensureSKLAnchorDates`, `ensureMissingCitiesAndAssociations`, `ensureSKLEventsAndFigures`) swallowed the error.
4. **Debug lesson:** Added `do/catch` with `print(error)` to identify the actual decode error. After fix, all 3 migrations load 207 figures, 37 places, 67 events successfully.

**Other fixes:**
- `EventListView.swift`, `PlaceListView.swift` — Wrapped `proxy.scrollTo` in `Task { @MainActor in }` to silence "reentrant operation in NSTableView delegate" warning (FigureListView was previously fixed).

**Relevant files:**
- `Sources/MeCore/Resources/seed_data.json` — Updated
- `Sources/Me/Resources/seed_data.json` — Synced copy
- `Sources/MeCore/Store/Migration.swift` — `ensureSKLEventsAndFigures` added
- `Sources/Me/Views/ContentView.swift` — Migration call added
- `Sources/Me/Views/EventListView.swift` — NSTableView fix
- `Sources/Me/Views/PlaceListView.swift` — NSTableView fix

### 2026-07-26 — Query results actionable: sidebar nav, lineage button, copy

**Changes made:**
- `Sources/Me/Views/QueryView.swift` — Added `coordinator: NavigationCoordinator?` to `QueryView`, `FigureDossierView`, `PlaceDossierView`, `EventDossierView`, `FigureListDossierView`, `EventListDossierView`, `PlaceListDossierView`. All dossier views now pass coordinator through from QueryView.
- `FigureDossierView` — Added "Open in Sidebar" and "Show Lineage" action buttons below header, navigating via `coordinator.navigateToFigure()` / `navigateToLineageFigure()`.
- `PlaceDossierView` — Added "Open" button in header row, navigating to sidebar place detail.
- `EventDossierView` — Added "Open" button in header row, navigating to sidebar event detail.
- `FigureListDossierView` — Added sidebar-navigation icon per row + "Copy list" button with NSPasteboard export.
- `EventListDossierView` — Same copy + per-row sidebar navigation.
- `PlaceListDossierView` — Same copy + per-row sidebar navigation.
- `Sources/Me/Views/ContentView.swift` — Added `.query` branch in the detail `if/else if` chain passing `coordinator` to `QueryView(coordinator:)`. Removed `.query` from the enum's `destination` fallback to avoid duplicate handling.

**Key design decisions:**
- `EntityLink` (opens separate report window) preserved as-is for quick lookups. Sidebar navigation added as an additional `sidebar.left` icon button per row, preserving both interaction patterns.
- Copy-to-clipboard uses `NSPasteboard.general` with temporary checkmark feedback, matching the existing `AnswerView` pattern.
- The `destination` computed property on `NavigationItem` keeps `.query` as a bare `QueryView()` (no coordinator) to satisfy exhaustive switch. The explicit coordinator-aware branch in the detail chain takes priority at runtime.

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

### 2026-07-25 — Code reuse analysis: MiniLineageView vs LineageTreeView

**Task:** Determine whether `MiniLineageView` could be optimized by sharing code from `LineageTreeView`.

**Analysis findings:**
- **Rendering backends are incompatible**: MiniLineageView uses SwiftUI (`HStack`/`VStack`/`MiniChip`/`ParentChipView`), LineageTreeView uses Canvas (`graphicsContext.drawCard()`).
- **Data models differ**: MiniLineageView groups parents into `ParentCouple` (Father+Mother paired by `groupID`). LineageTreeView renders each `relationshipType` as an independent entry with Spouse/Consort as partner column — no couple concept.
- **Interaction models differ**: MiniLineageView uses popovers and confirmation dialogs for alternatives and unknown parents. LineageTreeView uses Canvas hit-testing with `AlternativePartnersSheet` and `FigureDetailSheet`.
- **What's duplicated**: String constants (`"Father"`, `"Mother"`, `"Spouse"`, `"Consort"`), and trivial 8-line `parents(typeName:of:from:)` helper. Neither is worth extracting.

**Decision:** Leave as-is. The two views evolved different architectures for different contexts (inline panel vs full-screen tree) and the duplication is natural.

**Relevant files:**
- `Sources/Me/Views/MiniLineageView.swift` — 497-line SwiftUI mini lineage view
- `Sources/Me/Views/LineageTreeView.swift` — 933-line Canvas-based full lineage tree
- `Sources/Me/Views/FigureCardView.swift` — Shared card component (used by FigureLineageExplorer, not LineageTreeView)

### 2026-07-26 — SKL anchor dates: additive migration for 9 dynasties

**Problem:** The SKLDatePropagator could only compute dates for 5 dynasties (Akkad, Ur III, Uruk III, Uruk V, Isin). The remaining 9 historically-plausible SKL dynasties (Ur I, Uruk II, Adab, Mari, Kish III, Akshak, Kish IV, Uruk IV, Gutian) had no anchor figures with explicit `c. XXXX–XXXX BC` dates, so the propagator returned nil for all ~92 figures in those dynasties.

**Hard constraint:** No reseeding allowed. All work must be additive.

**Solution (two parts):**

1. **seed_data.json** — Added `c. XXXX–XXXX BC` date ranges to one strategic king per dynasty (anchor). Used short chronology throughout. Each anchor's range spans ~its reign length so the propagator's forward/backward propagation fills in the rest of the dynasty automatically.

2. **Migration.ensureSKLAnchorDates** — Reads seed_data.json dynamically, finds each SKL anchor figure in the DB by name, and additively appends the date range to `figureDescription` only if no `c. XXXX–XXXX BC` pattern is already present. Also strips any legacy `c. Xth century BC` pattern before appending. Called at every app launch after `removeAutoGeneratedStickies`.

**Key decisions:**
- One anchor per dynasty placed strategically (first king for forward-prop dynasties, last king for backward-prop, middle for balanced). Exception: Fourth dynasty of Kish uses Nanniya (last king) because Ur-Zababa has no reign length.
- Mythological dynasties (Antediluvian, Kish I, Awan, Kish II, Hamazi) left untouched — reign lengths of 600–43,200 years make dates meaningless.
- Century-style dates ("c. 27th century BC") replaced with specific year ranges for propagator compatibility.
- The `Second dynasty of Ur` (2 kings, one reign=120) and `First rulers of Uruk` (12 kings, mix of mythological and plausible) skipped — not enough confidence in dates.

**Relevant files:**
- `Sources/MeCore/Resources/seed_data.json` — 9 anchor date ranges added
- `Sources/MeCore/Store/Migration.swift` — `ensureSKLAnchorDates` method
- `Sources/Me/Views/ContentView.swift` — Migration call added to launch sequence

### 2026-07-29 — Type filter pills for Places/Events/Things + search field visibility audit

**Changes made:**

- `Sources/Me/Views/PlaceListView.swift` — Added `selectedTypeFilters` + clickable `typeFilterButton` for `PlaceType`, replacing static `PlaceTypeLegend`. `sortedPlaces` → `filteredPlaces` with type filtering.
- `Sources/Me/Views/EventListView.swift` — Same treatment: `selectedTypeFilters` + clickable `typeFilterButton` for `EventType`, replacing static `EventTypeLegend`. `sortedEvents` → `filteredEvents`.
- `Sources/Me/Views/ThingListView.swift` — Added `@Query` for `ThingType` + `selectedTypeFilters` + type filter bar with clickable pills (was missing entirely).
- `Sources/Me/Views/PlaceTypeLegend.swift` — Removed (replaced by inline filter buttons)
- `Sources/Me/Views/EventTypeLegend.swift` — Removed (replaced by inline filter buttons)
- `Sources/Me/Views/EventFormView.swift` — Changed figure and location search fields from `.textFieldStyle(.plain)` with `.quaternary.opacity(0.15)` background (nearly invisible) to `.textFieldStyle(.roundedBorder)` (macOS standard bezel).
- Global search field audit: 22 search fields across 9 files changed from `.textFieldStyle(.plain)` to `.textFieldStyle(.roundedBorder)`:
  - `EventDetailView.swift` — 2 popover searches (figures, places)
  - `PlaceDetailView.swift` — 2 popover searches (figures, events)
  - `FigureDetailView.swift` — 1 filter bar + 3 popover searches (entities, places, groups)
  - `RelationshipListView.swift` — 1 entity search
  - `AlternateNameListView.swift` — 2 search fields (figures, places)
  - `AssociationsView.swift` — 5 search fields (2x figures, 2x places, 1x generic)
  - `FigureGroupFormView.swift` — 1 search figures field
  - `ThingListView.swift` — 3 association form search fields
  - `ContentView.swift` — 1 global search toolbar
- 4 inline editing fields (comments, notes) left as `.plain` intentionally.

**Coding convention added:** Search fields should use `.textFieldStyle(.roundedBorder)` for visible macOS-standard bezel. Inline editing/comment fields may use `.textFieldStyle(.plain)` with a visible background container.

**Relevant files:**
- `Sources/Me/Views/PlaceListView.swift` — Updated
- `Sources/Me/Views/EventListView.swift` — Updated
- `Sources/Me/Views/ThingListView.swift` — Updated
- `Sources/Me/Views/EventFormView.swift` — Updated
- `Sources/Me/Views/PlaceTypeLegend.swift` — Removed
- `Sources/Me/Views/EventTypeLegend.swift` — Removed

### 2026-07-29 — Rich text descriptions, EventFigureAssociation join model, DetailToolbar polish

**Rich text support for descriptions:**
- `Sources/Me/Views/RichTextEditor.swift` — NSViewRepresentable wrapping NSTextView with native format toolbar (B/I/U, font panel). Toolbar buttons use `regularSquare` bezel, 15pt semibold font, 38pt toolbar height. `syncRichData()` called on attribute-only changes. `updateNSView` uses `isEqual()` for full attribute comparison.
- `Sources/Me/Views/RichTextDisplay.swift` — renders `Data?` as `Text(AttributedString)` with plain text fallback
- `Sources/Me/Views/DescriptionEditorSheet.swift` — reusable quick-edit sheet, sized 640×480
- `Figure.swift`, `Place.swift`, `Event.swift`, `Thing.swift` — added `richDescription: Data?` (optional, migration-safe)
- All form views (FigureFormView, PlaceFormView, EventFormView, ThingFormView) — replaced TextEditor with RichTextEditorSection
- All detail views — display via RichTextDisplay; edit button in DetailToolbar

**DetailToolbar polish:**
- `Sources/Me/Views/IconActionButton.swift` — Enlarged to 15pt semibold / 30×30pt (was 12pt / 24×24)
- `Sources/Me/Views/DetailToolbar.swift` — Added `onEditDescription` parameter. Button order: Edit → Edit description → Delete → leadingButtons → Close. Close button enlarged to match.
- Moved edit-description button from system `.toolbar` (invisible on embedded child views) to DetailToolbar leadingButtons, then to dedicated `onEditDescription` slot.

**EventFigureAssociation join model (per-event display name override for figures):**
- `Sources/MeCore/Models/EventFigureAssociation.swift` — New `@Model` with `event`, `figure`, `displayName: String?`, `roleType: EventFigureRoleType?`
- `Sources/MeCore/Models/EventFigureRoleType.swift` — New dynamic role type (follows EventPlaceRoleType pattern)
- `Sources/MeCore/Models/Event.swift` — Added `figureAssociations: [EventFigureAssociation]?` (optional for migration safety). Existing `involvedFigures` preserved for backward compat.
- `Sources/Me/AnunnakiApp.swift` — Schema updated with new models
- `Sources/Me/Views/EventDetailView.swift` — Figure link popover redesigned: two-step flow (search → confirm display name). Picker prefilled with figure's AKA names. Edit-pencil per row for display name changes. Delete-X per row removes from either `involvedFigures` or `figureAssociations`. Search also matches alternate names.
- `figureDisplayList` computed property merges old `involvedFigures` + new `figureAssociations`, deduplicating by figure ID.

**Relevant new/removed files:**
- `Sources/Me/Views/RichTextEditor.swift` — Added
- `Sources/Me/Views/RichTextDisplay.swift` — Added
- `Sources/Me/Views/DescriptionEditorSheet.swift` — Added
- `Sources/MeCore/Models/EventFigureAssociation.swift` — Added
- `Sources/MeCore/Models/EventFigureRoleType.swift` — Added

### 2026-07-30 — ContentAttribution model + inline source badges

**Problem:** Users had no way to track which source contributed which part of an entity's description, or to link back to the original source URL. The model and form existed but were not fully wired (no edit, no URL, no inline display).

**Changes made:**

- `ContentAttribution.swift` — Added `url: String?` for linking back to the source, all properties optional for migration safety
- `ContentAttributionFormView.swift` — Added editable URL field (`.textContentType(.URL)`), edit support in `ContentAttributionSection` (pencil button per row), clickable hostname link in section rows
- `AttributedPropertyView.swift` — New reusable inline badge: when a matching `ContentAttribution` exists for the displayed property, shows a small teal book icon + source name + clickable link below the property value
- `FigureDetailView.swift` — Wired : description and title with `AttributedPropertyView`; added `editingAttribution` state + edit sheet via `.sheet(item:)`
- `PlaceDetailView.swift` — Same for description
- `EventDetailView.swift` — Same for description
- `ThingListView.swift` (ThingDetailView) — Same for description

**Key design decisions:**
- `AttributedPropertyView` uses `@ViewBuilder` to wrap any content — generic reusable component
- Badge only appears when a `ContentAttribution` with matching `propertyName` exists
- Domain in the `LazyVGrid` left un-attributed (grid layout doesn't support wrapping cleanly)
- `.sheet(item: $editingAttribution)` pattern matches the existing `showAddAttribution` pattern

**New files:**
- `Sources/Me/Views/AttributedPropertyView.swift` — Added

**Relevant files:**
- `Sources/MeCore/Models/ContentAttribution.swift` — Updated (`url: String?`)
- `Sources/Me/Views/ContentAttributionFormView.swift` — Updated (URL field, edit pencil, hostname link)
- `Sources/Me/Views/FigureDetailView.swift` — Updated (wired for title + description)
- `Sources/Me/Views/PlaceDetailView.swift` — Updated
- `Sources/Me/Views/EventDetailView.swift` — Updated
- `Sources/Me/Views/ThingListView.swift` — Updated

### 2026-07-31 — Data-driven sidebar groups (GroupKind system)

**Goal:** Let the user create new figure groups and have them appear in the sidebar with zero programming effort. Specialized views (Book of Enoch, Sumerian King List, The Flood) become data-driven groups that dispatch to their dedicated views.

**Changes made:**

- `Sources/MeCore/Models/FigureGroup.swift` — Added `GroupKind` enum (`.standard`/`.enoch`/`.skl`/`.flood`, each with `displayName`) + `kindRawValue: String?` (migration-safe) + computed `kind`. Init takes `kind: GroupKind = .standard`.
- `Sources/Me/Views/ContentView.swift` — Added `@Query(sort: \FigureGroup.orderIndex)`; sidebar gained a data-driven "Groups" section (icon + colored label per group). All sidebar rows now tagged with new `SidebarSelection` (`.item(NavigationItem)` / `.group(PersistentIdentifier)`). Detail dispatch switched to a `switch` on `SidebarSelection`; `.group(id)` routes through `groupDestination(group:)`. Removed `.enoch`, `.sumerianKingList`, `.flood` from `NavigationItem` (icon/section/destination) — they are now groups.
- `Sources/Me/Views/NavigationCoordinator.swift` — `selectedItem: NavigationItem?` → `selection: SidebarSelection?`. `navigateToGroup` now sets `.group(id)`. `navigateToHistory` returns to the group's dedicated view via the new selection type.
- `Sources/Me/Views/FigureGroupCollectionView.swift` — New clean read-oriented collection view for `.standard` groups: large header (icon/name/description/count), search field, adaptive `LazyVGrid` of member cards → navigates to figure detail in sidebar.
- `Sources/Me/Views/FigureGroupFormView.swift` — Added Kind picker to Identity step (loads/saves `group.kind`).
- `Sources/MeCore/Store/Migration.swift` — `ensureDefaultFigureGroups` now assigns kinds + adds a 7th "The Flood" default group. New `ensureFigureGroupKinds` backfills kinds by name (Book of Enoch→.enoch, SKL Kings/Sumerian King List→.skl, The Flood→.flood) and creates "The Flood" if missing — additive, safe for existing DBs.

**Key design decisions:**
- The sidebar Groups section is fully `@Query`-driven: creating a group in the Figure Groups manager immediately shows it in the sidebar. Zero code per new `.standard` group.
- New code is only needed for a *new kind* with a bespoke view; the three existing hardcoded History items became that migration, done once.
- `.standard` group destination is a clean read-only collection; the management UI (bulk add/sync/edit/delete) stays under the Figure Groups item in Data.
- `Color(hex:)` stays file-private per existing convention (duplicated in ContentView, FigureGroupFormView, FigureGroupListView, FigureGroupCollectionView).

**Relevant new/removed files:**
- `Sources/Me/Views/FigureGroupCollectionView.swift` — Added

**Relevant files:**
- `Sources/MeCore/Models/FigureGroup.swift` — Updated
- `Sources/Me/Views/ContentView.swift` — Updated
- `Sources/Me/Views/NavigationCoordinator.swift` — Updated
- `Sources/Me/Views/FigureGroupFormView.swift` — Updated
- `Sources/MeCore/Store/Migration.swift` — Updated

### 2026-07-31 — FigureGroup subgroups + unified expandable collection view

**Goal:** Let users build "pages" like Book of Enoch from data alone — top-level group in the sidebar, subgroups for sections, figures as members — with zero programming. Follow-up to the GroupKind system.

**Changes made:**

- `Sources/MeCore/Models/FigureGroup.swift` — Added `parentGroup: FigureGroup?` / `subgroups: [FigureGroup]?` (`.nullify` delete rule, inverse `\FigureGroup.parentGroup`), `directFigures: [Figure]` computed property (figures directly in this group, excluding descendants' figures).
- `Sources/Me/Views/FigureGroupFormView.swift` — Parent Group picker on Identity step, cycle-safe `setParent(_:parent:)` (removes prior parent, appends to new, excludes self + descendants).
- `Sources/Me/Views/FigureGroupCollectionView.swift` — Rewrote the `.standard` group view as a unified expandable outline:
  - Removed the Figures/Subgroups segmented tabs (felt artificial).
  - Top level mixes direct figures and subgroup rows, sorted by name, via a file-level `MixedItem` enum (`.figure`/`.group`).
  - Recursive `FigureGroupTreeNode` renders each subgroup as an expandable row (chevron toggles via `@State Set<PersistentIdentifier>`) that reveals its figures and its own subgroups inline, indented.
  - Subgroup rows show icon, subgroup count, figure count; context menu "Open as Page" navigates into the subgroup via `coordinator.navigateToGroup(recordHistory: false)`.
  - Stateless ancestor breadcrumb trail at top (derived from walking `parentGroup` chain) — click any ancestor to navigate back up; works at any depth, no shared-history pollution.
  - Removed grid/list toggle; search filters across figures + subgroup names.
- `Sources/Me/Views/FigureGroupListView.swift` — Manager rows show an indent arrow for subgroups and a folder badge for groups with children.
- `Sources/Me/Views/ContentView.swift` — Sidebar groups section filters to top-level + published; detail lookup uses all groups so subgroups render when navigated to.
- `AGENTS.md` — Added TODO: inline 320pt figure-detail panel + place membership for groups (to fully replicate EnochView with data alone).

**Key design decisions:**
- Sidebar shows top-level published groups only; subgroups are reached by drilling into their parent (avoids sidebar bloat). Clicking any ancestor in the trail re-renders that group as its own page.
- Navigation between group levels uses `navigateToGroup(recordHistory: false)` — no group breadcrumbs pushed into the shared figure/place/event history trail.
- Expansion state (`Set<PersistentIdentifier>`) lives in the collection view so it survives re-renders but resets when navigating between groups.
- Subgroups are recursive — a subgroup can contain its own subgroups, so hierarchy depth is unlimited.
- `MixedItem` and `FigureGroupTreeNode` are file-private in FigureGroupCollectionView.swift (tree recursion needs a shared type).

**Relevant files:**
- `Sources/MeCore/Models/FigureGroup.swift` — Updated
- `Sources/Me/Views/FigureGroupCollectionView.swift` — Rewritten
- `Sources/Me/Views/FigureGroupFormView.swift` — Updated
- `Sources/Me/Views/FigureGroupListView.swift` — Updated
- `AGENTS.md` — TODO updated

### 2026-07-31 — Generic EntityGroup planning (Places/Events/Things groups)

**Context:** User wants to replicate the "Book of Enoch" experience (curated sidebar page with subgroups + inline detail panel) for Places, Events, and Things — i.e., data-driven groups for all four entity types, no programming. This is a research-only session; nothing was built.

**Findings:**
- `FigureGroup` system spans 6 pieces across 10 files (~76 references): model + `FigureGroupAssociation` join, `FigureGroupFormView` (2-step wizard), `FigureGroupListView` manager (bulk add, sync filter, published checkbox, subgroup indicators), `FigureGroupCollectionView` (expandable outline + ancestor trail + search), sidebar + `NavigationCoordinator` wiring, `Migration.ensureDefaultFigureGroups`/`ensureFigureGroupKinds`.
- Two design options evaluated:
  - **Option A (generic `EntityGroup`)**: one `entityType`-parameterized model/join/views used by all 4 types. Estimated **4–5 days**. Chosen for long-term maintainability.
  - **Option B (3 parallel copies)**: replicate the stack for Place/Event/Thing groups. Estimated **5–6 days**, more maintenance debt, but zero risk to the working FigureGroup system.
- The inline 320pt detail panel (EnochView pattern) is a prerequisite to make any group page feel "Book of Enoch"-like; currently only opens figures in a separate window.

**Decision:** Deferred to TODO. User is credit-constrained and does NOT want a half-finished refactor that leaves the tree uncompiling. Full plan written into the TODO item ("Generic EntityGroup system (Option A)") with explicit warning: must reach a compiling state in one sitting. A session that starts this must budget for the complete refactor before running low on resources.

**Relevant files:**
- `AGENTS.md` — TODO updated (Generic EntityGroup system item)

### 2026-08-01 — Generic EntityGroup system implemented (Option A, all 4 types)

**Goal:** Give Places, Events, and Things the same Enoch-style sidebar pages that figures have, entirely data-driven. Implemented WITHOUT renaming the stored `FigureGroup` class — the model keeps its name for migration safety; genericity comes from a new `entityType` field. The old `FigureGroupCollectionView` was replaced by `EntityGroupCollectionView` (inline 320pt detail panel included, so the previous "inline detail panel + place members" TODO is subsumed).

**Changes made:**

- `Sources/MeCore/Models/FigureGroup.swift`:
  - New `GroupEntityType` enum (`.figure`/`.place`/`.event`/`.thing`) with `displayName`, `pluralName`, `sidebarHeader`, `icon`.
  - Added `entityTypeRawValue: String?` (migration-safe) + computed `entityType` (defaults to `.figure` when nil). `init` gains `entityType: GroupEntityType = .figure`.
  - Added `directPlaces`, `directEvents`, `directThings` computed properties (parallel to `directFigures`).
  - `GroupMemberFilter` extended with `placeTypeNames`, `eventTypeNames`, `thingTypeNames`, `matchesPlace/matchesEvent/matchesThing`, and type-aware `summary`. Init arg order (declaration order): `figureTypeNames, domainKeywords, placeTypeNames, eventTypeNames, thingTypeNames, nameMatch`.
- `Sources/MeCore/Models/FigureGroupAssociation.swift` — Rewritten as a polymorphic join: optional `figure`/`place`/`event`/`thing` references; `init` accepts any one.
- `Sources/MeCore/Models/Place.swift`, `Event.swift`, `Thing.swift` — Added inverse `@Relationship(deleteRule: .cascade, inverse: \FigureGroupAssociation.<type>) groupAssociations`.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — NEW, replaces deleted `FigureGroupCollectionView.swift`. Type-aware unified expandable outline (recursive `EntityGroupTreeNode`, `MixedItem` mixing entities + subgroups), search, stateless ancestor breadcrumb trail, plus an inline 320pt detail panel (FigureDetailView/PlaceDetailView/EventDetailView/ThingDetailView) with Edit/Delete per type and "Open in Window" for figure/place/event (window IDs `figure-detail`, `place-quickview`, `event-quickview`; image detail via `image-detail`).
- `Sources/Me/Views/GroupMemberItem.swift` — NEW shared enum (`.figure/.place/.event/.thing`) with `entityType`, `name`, `icon`, `color`, `subtitle`, `makeAssociation()`, `init?(association:)`.
- `Sources/Me/Views/EntityGroupsSection.swift` — NEW reusable "Groups" section with "+" link popover, wired into `PlaceDetailView`, `EventDetailView`, `ThingListView` (ThingDetailView) alongside the existing `FigureDetailView` one.
- `Sources/Me/Views/ContentView.swift` — Sidebar shows per-entity-type group sections (Figure Groups, Places Groups, Events Groups, Things Groups); `groupDestination` dispatches by `entityType` (`.enoch`/`.skl`/`.flood` kinds keep their dedicated views for figures, all others → `EntityGroupCollectionView`); sidebar label renamed "Figure Groups" → "Groups".
- `Sources/Me/Views/FigureGroupFormView.swift` — "Members Are" entity-type picker in Identity step (changing it clears selected member IDs); type-aware member selection via `GroupMemberItem`; `kind` picker disabled (forced `.standard`) when `entityType != .figure`; parent group picker forces child `entityType` to match the parent.
- `Sources/Me/Views/FigureGroupListView.swift` — Title "Figure Groups" → "Groups"; `FigureGroupDetailView` member rows now take `onOpenMember: ((GroupMemberItem) -> Void)?`; `syncMembers()` type-aware; `BulkAddMembersSheet` rewritten type-aware with a `TypePill` helper.
- `Sources/Me/Views/FigureDetailView.swift` — `GroupLinkPopover` filters groups to `entityType == .figure` only.
- `Sources/MeCore/Store/Migration.swift` — Sumerian Pantheon filter call reordered to match the new `GroupMemberFilter` declaration order.
- `Tests/MeCoreTests/MeCoreTests.swift` — Schema now includes `FigureGroup`/`FigureGroupAssociation`; 6 new tests: entityType default, round-trip, nil-raw backward compatibility, filter matches place/event/thing types, direct members across types, inverse associations. 63 tests pass.
- `AGENTS.md` — TODO items "Generic EntityGroup system (Option A)" and "inline detail panel + place members" marked done; design doc updated.

**Design decisions:**
- **No model rename.** `FigureGroup`/`FigureGroupAssociation` keep their names; `entityTypeRawValue` is a nullable new attribute defaulting to `.figure`, so the user's existing Book of Enoch store migrates via lightweight migration with zero data work. An eventual rename is cosmetic-only.
- **No default place/event/thing groups.** Only the existing figure defaults are seeded — avoids sidebar clutter; users build non-figure groups via the Groups manager.
- Sidebar shows per-type headers so group pages are discoverable; subgroups still drill in via parent pages (not the sidebar).
- `kind` applies to figures only; a non-figure group is always `.standard` (its dedicated Enoch/SKL/Flood views are figure-specific).
- The group form's "Members Are" picker is the single source of truth for a group's type; parent/child type consistency is enforced in the form (children must match parent).

**Lessons learned:**
- Swift requires labeled `init` args in declaration order — alphabetizing `GroupMemberFilter`'s parameters broke existing call sites; keep declaration order stable and put mutable defaulted args (e.g., `nameMatch`) last.
- `GroupEntityType` derives its `icon`/display strings once; all views consume them, so per-type rendering differences stay in one place.

**Relevant files:**
- `Sources/MeCore/Models/FigureGroup.swift`, `FigureGroupAssociation.swift`, `Place.swift`, `Event.swift`, `Thing.swift`
- `Sources/Me/Views/EntityGroupCollectionView.swift` (new), `GroupMemberItem.swift` (new), `EntityGroupsSection.swift` (new), `ContentView.swift`, `FigureGroupFormView.swift`, `FigureGroupListView.swift`, `FigureDetailView.swift`, `PlaceDetailView.swift`, `EventDetailView.swift`, `ThingListView.swift`
- `Sources/MeCore/Store/Migration.swift`
- `Tests/MeCoreTests/MeCoreTests.swift`
- `FigureGroups.md` (updated), `AGENTS.md` (TODO + session log)

### 2026-08-02 — Custom group member ordering: sortMode + orderIndex, reorder UI, SKL reign auto-assign

**Problem:** Group members always rendered alphabetically by name (`MixedItem.name`/`GroupMemberItem.name` sorts in `EntityGroupCollectionView` and `FigureGroupDetailView`). No way to express a sequence determined by something other than the name — e.g. SKL kings whose order follows reign succession, not alphabet.

**Changes made:**

- `Sources/MeCore/Models/FigureGroupAssociation.swift` — Added `orderIndex: Int?` (optional, migration-safe) + init param. `nil` = no explicit position.
- `Sources/MeCore/Models/FigureGroup.swift`:
  - New `GroupSortMode` enum (`.alphabetical` default / `.ordered`) with `displayName`; stored as `sortModeRawValue: String?` + computed `sortMode` (nil-safe backward compat). `init` gains `sortMode: GroupSortMode = .alphabetical`.
  - `sortedAssociations` — the group's member associations in display order: alphabetical, or by `orderIndex` (nil→`Int.max`) with name tie-break when `.ordered`.
  - `setSortMode(_:)` — switching to `.ordered` seeds every association with sequential `orderIndex` so the current order becomes a stable fine-tunable baseline.
  - `moveAssociation(_:direction:)` — swaps an association up/down and renumbers 0..n (used by the reorder arrows).
  - `regnalKey(_:)` / `applyRegnalOrder()` — chronological key = `era.orderIndex * 1_000_000 + figure.orderIndex` (seed's per-era sequence counter, i.e. the SKL reign order); events key on `event.date.sortValue`. `applyRegnalOrder()` writes sequential `orderIndex` over associations sorted by key.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — File-scope `memberItems(for:)` helper builds members from `group.sortedAssociations` (carries `displayName`). `mixedItems` and `EntityGroupTreeNode.children` keep `.ordered` sequence; otherwise alphabetical as before. Subgroups still sort by `(orderIndex, name)`.
- `Sources/Me/Views/FigureGroupListView.swift` — `FigureGroupDetailView.members` now maps `group.sortedAssociations` (no re-sort). Added a sort-mode menu (Name / Manual Order) in the Actions row, and `MemberReorderButtons` (up/down chevrons) per member row when `.ordered`. `syncMembers()` and `BulkAddMembersSheet.addAllMatching()` call `applyRegnalOrder()` when an ordered figure group syncs new members.
- `Sources/MeCore/Store/Migration.swift` — `ensureSKLRegnalOrder(context:)`: for every group whose kind (or an ancestor's kind) is `.skl`, orders figure members chronologically and sets `.ordered`. Only runs when **all** members have `orderIndex == nil`, so user-arranged orders are never overwritten. Additive.
- `Sources/Me/Views/ContentView.swift` — `Migration.ensureSKLRegnalOrder` added to the launch sequence (after `ensureFigureGroupKinds`).
- `Tests/MeCoreTests/MeCoreTests.swift` — 11 new tests: sortMode default/nil-backcompat/round-trip, alphabetical default, ordered by orderIndex, nil-defers-by-name, `setSortMode` seeding, `moveAssociation` (+no-op at edge), `applyRegnalOrder` across eras, event-date regnal key, association orderIndex round-trip. 75 tests pass.

**Design decisions:**
- The position lives **on the association** (`FigureGroupAssociation.orderIndex`), not the entity — the same figure can appear in several groups with different positions, and it's migration-safe (optional). Entity-intrinsic date sorting was rejected as too fragile (missing dates) and unable to express a bare user-chosen sequence.
- `applyRegnalOrder()` intentionally does **not** flip `sortMode` — the migration/UI sets `.ordered` separately, so "reign order" and "manual order mode" stay decoupled.
- Auto-assign is one-time-and-optional: only SKL chains, only when no positions exist yet; the manual menu/arrows let users override.
- Members-then-subgroups (not interleaved) in `.ordered` mode — a unified member/subgroup spine is deferred to the text-blocks TODO.

**Relevant files:**
- `Sources/MeCore/Models/FigureGroup.swift`, `FigureGroupAssociation.swift`
- `Sources/Me/Views/EntityGroupCollectionView.swift`, `FigureGroupListView.swift`, `ContentView.swift`
- `Sources/MeCore/Store/Migration.swift`
- `Tests/MeCoreTests/MeCoreTests.swift`
- `AGENTS.md` (this entry + TODO update)

### 2026-08-02 — Store-level backup & restore (snapshot prototype)

**Goal:** A real safety net for the "never reseed" rule — a way to back up the entire database and recover it — without a lossy JSON codec. Backups are plain copies of the store's backing files, so they cover every model automatically.

**Changes made:**
- `Sources/Me/Views/BackupService.swift` — NEW. Snapshot helper over the live store at `~/Library/Application Support/Me/Me.store`:
  - `makeBackup(in:)` copies `Me.store` + `-shm` + `-wal` (whichever exist) into a timestamped `MeBackup-<ISO>` folder.
  - `chooseAndBackup()` (async, @MainActor) — folder picker (NSOpenPanel) → runs `makeBackup`.
  - `stageRestore(from:)` writes the chosen backup dir into `UserDefaults` (`com.me.app.pendingRestoreDirectory`).
  - `applyPendingRestoreIfNeeded()` — on launch, before the container opens: if a pending restore exists, save a `MeBackup-prestore` safety copy of the current store, then swap in the backup's files. Removes the flag regardless.
  - `isValidBackup(_:)` — true if the folder contains a `Me.store`.
- `Sources/Me/AnunnakiApp.swift`:
  - `sharedContainer` init calls `BackupService.applyPendingRestoreIfNeeded()` **after** the `--reseed` block, so an explicit reseed still wins.
  - New `DatabaseMenuCommands` (Commands scene) — **Database ▸ Back Up Database…** (`⌘⇧B`) and **Restore from Backup…** (`⌘⇧R`), which post `.showBackupSheet`.
  - `Notification.Name.showBackupSheet`.
- `Sources/Me/Views/BackupSheet.swift` — NEW sheet UI: "Back Up Now" and "Restore from Backup…", status line, restore-confirm alert ("Yes, Restore & Quit" terminates to relaunch and apply). Notes when a pre-restore safety copy exists.
- `Sources/Me/Views/ContentView.swift` — `archivebox` toolbar button (primaryAction, right of search) opens `BackupSheet`; also observes `.showBackupSheet` to open it from the menu/`⌘⇧B`/`⌘⇧R`.

**Design decisions:**
- Chose the **store-file snapshot** over a portable JSON codec: zero schema mirroring (all 30+ models covered), tiny surface, and a genuine full backup. Restore requires a relaunch because it swaps the live SQLite file; the app applies it on the next launch, before the container is created.
- No MeCore changes — everything lives in the UI layer (`Me`), so tests are unaffected.
- Backup restore keeps a `MeBackup-prestore` copy so a mistaken restore is never data loss.

**Relevant files:**
- `Sources/Me/Views/BackupService.swift` (new), `Sources/Me/Views/BackupSheet.swift` (new)
- `Sources/Me/AnunnakiApp.swift`, `Sources/Me/Views/ContentView.swift`
- `AGENTS.md` (this entry)

### 2026-08-02 — Add from Text: single-entity-and-links parser

**Goal:** The daily-driver data-entry step. Type a sentence like `Marduk is the son of Enki and Damkina; consort of Sarpanit; patron of Babylon` and have the app parse a subject figure, its family relationships, and patron/ruler place links into one action.

**Changes made:**
- `Sources/MeCore/Store/FromTextParser.swift` — NEW. Parses text into a `FromTextResult` (subject + relationships + placeLinks + new figure/place names). Grammar:
  - Family words mapped to output relationship types: `father`/`mother` (parentOf), `son`/`daughter` (childOf), `brother`/`sister`/`sibling` (siblingOf), `spouse`/`consort`/`wife`/`husband` (partnerOf, `isPreferred`), `creator` (creatorOf).
  - Place links: `patron of X` → "Patron Deity", `ruler of X` → "Ruler".
  - Clauses split on semicolons; names split on " and ". Lowercased keyword matching on the lemma text, but original-case values are preserved by re-extracting the tail from the original clause (`originalTail`).
- `Sources/Me/Views/FromTextSheet.swift` — NEW. Sheet with live parse preview (subject/relationships/place links/new figures/places) and an "Add" button. `FromTextRecognizer` resolves-or-creates figures/places/relationship-types/role-types and inserts the associations/relations using the appendix.
- `Sources/Me/Views/ContentView.swift` — Added `text.badge.plus` toolbar button + `showFromTextSheet` state + `.sheet(isPresented:)`.
- `Tests/MeCoreTests/MeCoreTests.swift` — 13 new tests (subject-only, son/daughter/father/mother of, consort preferred, creator of, patron/ruler place links, and-splitting, siblings, empty). 88 total pass.

**Key decisions:**
- Reimplemented, not reused: `QueryEngine`'s lemmatize/tokenize/resolve are `private` and read-only, so `FromTextParser` reimplements a small lemmatizer + resolver.
- Case preservation: keyword detection runs on lowercased text, but entity names (Enki, Babylon) are pulled from the original clause so capitalization is kept.
- Creates-or-merges by name (case-insensitive exact match) — never reseeds; matches the additive-migration constraint.

**Follow-up — no-semicolon parsing (2026-08-02):** Clauses are now detected by their **keyword** (`son of`, `consort of`, `patron of`, …) anywhere in the text rather than by explicit `;` delimiters, so natural prose with commas/newlines/no punctuation works. `parse` scans for the earliest keyword occurrence, splits each clause's tail at the next keyword, and `cleanSubject` strips leading/trailing connector words only from the leading edge. Added `testFromTextMultipleClausesWithoutSemicolons` (comma-separated) and `testNewlineDelimitedClauses`. 90 tests total.

**Relevant new/removed files:**
- `Sources/MeCore/Store/FromTextParser.swift` — Added
- `Sources/Me/Views/FromTextSheet.swift` — Added

**Relevant files:**
- `Sources/Me/Views/ContentView.swift` — Updated

**Follow-up — field-oriented result + structured preview (2026-08-02):** The user wanted the parse to feed the **standard Figure form fields**, not just relationships. `FromTextResult` grew into a field-oriented struct (subject, `gender`, `figureKind` (deity/human/primordial/unknown + `.figureTypeName`), `title`, `domain`, `birthYear`/`deathYear`, `description`=whole clip, `parents`, `otherRelationships`, `placeLinks`, `alternateNames`, `newFigures`, `newPlaces`). The preview in `FromTextSheet` now renders those as structured field rows. Detection helpers: `detectGender`/`detectFigureKind` (word-tokenized via `CharacterSet.alphanumerics.inverted`, so "a goddess," with a comma still tokenizes to `goddess`), `detectTitle` ("lord of/king of"), `detectDomain` ("god of X, Y"), `detectYears` (BCE/BC/CE/AD regex → negative BCE). For "son/daughter of X and Y", the two parents alternate Father/Mother (son-of with multiple targets → first Father, rest Mother). `splitNames` strips stopwords ("the", "a", "of", …) so alternate-name clauses don't leak stray words. 94 tests pass.

**Relevant files (follow-up):**
- `Sources/MeCore/Store/FromTextParser.swift` — Field-oriented result + detection helpers
- `Sources/Me/Views/FromTextSheet.swift` — Structured field-row preview

### 2026-08-03 — From-text revert log & history panel; `aka` marker word-boundary fix

**Context:** Two sessions. (1) The user worried an "Add from Text" mistake would contaminate the database and wanted a way to revert it — with "search and destroy" cleanup being too error-prone. (2) A regression report: pasting the Ptah article generated bogus AKA names "Stone", "Twenty-Fifth Dynassts" [Dynasty], and "tongue".

**Changes made — revert log & history:**

- `Sources/MeCore/Store/FromTextRecognizer.swift` — NEW. The `FromTextRecognizer` enum moved out of `FromTextSheet.swift` into MeCore (so tests can drive it). `apply(_:in:)` now returns a `FromTextApplyRecord?` and **persists `result.parents + result.otherRelationships`** (previously `parents` were silently dropped — a pre-existing bug fixed in the rewrite). New `revert(_:in:)` → `FromTextRevertReport`.
  - Record types (all Codable/Hashable/Identifiable): `FromTextApplyRecord` (id, date, subject, createdFigureNames, createdPlaceNames, createdFigureTypeNames, createdRelationshipTypeNames, createdRoleTypeNames, alternateNames, relationships, placeLinks, figureMutations, revertedAt), `FromTextRecordedRelationship`, `FromTextRecordedPlaceLink`, `FromTextFigureMutation`, `FromTextFieldState`, `FromTextRevertReport`.
  - Revert deletes only objects created by that add, in dependency order (relationships/links/alternate names/types, then orphaned figures/places via `isOrphaned` checks covering relationships, placeAssociations, alternateNames, thingAssociations, stickies, groupAssociations, images, tags, events, contentAttributions). Pre-existing figures keep their field values; mutations are restored only if the user hasn't edited them since (`skippedMutations`). Requires `try? context.save()` mid-revert before orphan checks so deletions are flushed.
- `Sources/Me/Views/FromTextLog.swift` — NEW. Append-only JSON persistence at `BackupService.storeDirectory/from_text_log.json` (`load`/`append`/`markReverted`). Best-effort: a failed log write never blocks an add.
- `Sources/Me/Views/FromTextHistorySheet.swift` — NEW. History list of past adds with per-entry result summary and a Revert button (with confirm); opened from the toolbar clock icon.
- `Sources/Me/Views/FromTextSheet.swift` — After Add, shows a green "Added X" banner with a red "Undo This Add" button; no longer auto-dismisses; Done closes. `apply` appends to `FromTextLog`; `undo` calls `FromTextRecognizer.revert`, saves, and alerts "Could not undo" if nothing was removed.
- `Sources/Me/Views/ContentView.swift` — Added `clock.arrow.circlepath` toolbar item + `showFromTextHistorySheet` state + `.sheet`.

**Changes made — `aka` word-boundary fix (2026-08-03):**

- `Sources/MeCore/Store/FromTextParser.swift` — `scanClauses` now requires markers to begin at a word boundary: the character before a marker match must not be a letter/number. Root cause of the Ptah regression: `aka ` matched inside "Shab**aka** Stone", so the alternate-marker clause swallowed "Stone, from the Twenty-Fifth Dynasty, … through this heart and this tongue" as an alias list. Verified against the full Origin-and-symbolism paragraph + epithet list: `alternateNames == []`.
- `Tests/MeCoreTests/MeCoreTests.swift` — 5 new apply/revert tests (`testFromTextApplyCreatesFiguresPlacesAndLinks`, `testFromTextRevertRemovesCreatedData`, `testFromTextApplyReusesExistingFigureAndRevertRestoresIt`, `testFromTextRevertKeepsFigureWithLaterData`, `testFromTextApplyRecordCodableRoundTrip`) + regression `testFromTextAkaMarkerWordBoundary`. 108 tests pass.

**Key decisions:**
- Log is append-only JSON on disk (not a new `@Model`) so it works even if a restore/relaunch resets the store, and requires no schema migration.
- Revert is scoped and additive-safe: only the add's own creations are touched; user edits made after the add are preserved via `FromTextFieldState` before/after comparison.
- The `aka` fix distinguishes a genuine marker from a mid-word substring rather than trying to filter the resulting names — the clause never fires at all.

**Relevant new/removed files:**
- `Sources/MeCore/Store/FromTextRecognizer.swift` — Added
- `Sources/Me/Views/FromTextLog.swift` — Added
- `Sources/Me/Views/FromTextHistorySheet.swift` — Added

**Relevant files:**
- `Sources/Me/Views/FromTextSheet.swift` — Updated (recognizer moved out; banner + undo)
- `Sources/Me/Views/ContentView.swift` — Updated (history toolbar item)
- `Sources/MeCore/Store/FromTextParser.swift` — Updated (word-boundary check)
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-03 — Product-level critique written: PRODUCT_WEAKNESSES.md

**Context:** The user remembered an earlier discussion where the app's weak spots were surveyed, with "data volume" being one. That conversation had never been captured. To avoid losing the reasoning again, this session wrote it down.

**Changes made:**
- `PRODUCT_WEAKNESSES.md` — NEW. Product-level critique (complements the existing `ARCHITECTURAL_WEAKNESSES_CRITIQUE.md`): six weaknesses (cold-start data problem, single-user trapped data, contradictory traditions not modeled, curation burden, niche-audience risk, no feedback loop), a suggested priority order, and a deliberately-de-prioritized list. Data snapshot at review time: 207 figures / 46 places / 67 events / 30 eras / 14 sources / 114 relationships.
- `AGENTS.md` — Added both critique docs to Important Files; added a top-of-TODO item pointing at `PRODUCT_WEAKNESSES.md` with the four priorities (data-entry speed, source-discriminated lineage, export/portability, attribution nudging).

**Key decisions:**
- The critique is grounded in the current codebase (quotes specific features: Add-from-Text, ContentAttribution, backup/restore, the open source-discriminator TODO) rather than being generic.
- The developer then shared the project's genesis (personal hobby, no commercial goals, fascination with Anunnaki/Sumerian civilization + Mac app development + AI/LLM interest) — this was captured in a new "Project Genesis & Motivation" section at the top of AGENTS.md, and the critique was amended: niche-audience is now framed as a neutral personal-tool stance (not a risk), with data-entry speed and the AI-facing surface as the levers.
- Attribution is treated as a nudge problem (make it cheap, auto-attach on import/parse) rather than an enforcement problem.

**Relevant new/removed files:**
- `PRODUCT_WEAKNESSES.md` — Added

**Relevant files:**
- `AGENTS.md` — Updated (Important Files + TODO)

### 2026-08-05 — Split TODO out of AGENTS.md into TODO.md

**Changes made:**
- `TODO.md` — NEW. The entire `## TODO` checklist was moved out of AGENTS.md into its own `TODO.md` (AGENTS.md was ~53 lines lighter). Kept content verbatim: open items, completed feature checkboxes (FigureGroup kind/type system, Generic EntityGroup, ContentAttribution, etc.), each with its historical notes.
- `AGENTS.md` — Removed the inline `## TODO` section; added `TODO.md` to the Important Files list. README-style forward reference so future sessions know where the backlog lives.

**Key decisions:**
- TODO is now a standalone driving document; AGENTS.md keeps only durable reference material (project identity/constraints/architecture/conventions/session log). This keeps AGENTS.md from growing unboundedly.
- Session log entries that mentioned "AGENTS.md TODO" now conceptually point at TODO.md.

**Relevant new/removed files:**
- `TODO.md` — Added

### 2026-08-05 — Collapsible sidebar groups with persisted expand state

**Problem:** The sidebar flattened every group *and* all of its subgroups into one always-expanded list (`sidebarRows(for:type:depth:)` in ContentView). Any curated hierarchy (e.g., Book of Enoch with its Watchers/Commanders/Archangels/Humans subgroups) rendered fully expanded, letting the sidebar grow enormous.

**Changes made:**
- `Sources/Me/Views/ContentView.swift` — Replaced the flat `sidebarRows` recursion with a new nested `SidebarGroupRow` view:
  - Groups with no subgroups render as a plain selectable `Label`.
  - Groups with subgroups render as a `DisclosureGroup` (recursive — each subgroup that itself has children gets its own disclosure), so any depth is collapsible.
  - Expand/collapse state persisted via `@AppStorage("sidebarExpandedGroupPaths")` keyed by a path string (`"figure/Book of Enoch/Watchers"`), exposed through a `@Binding<Set<String>>` and written back as a semicolon-joined sorted string.
  - Default state is **collapsed on first launch** (empty set) — only top-level published groups show until the user expands them.
- Removed the now-unused `sidebarRows(for:type:depth:)` helper.

**Design decisions:**
- Path key (not `PersistentIdentifier`) chosen so the persisted state survives across launches/store resets and is human-readable in UserDefaults. Trade-off: renaming a group changes its path key, resetting just that group's expansion state to collapsed.
- Subgroups are rendered by the same recursive `SidebarGroupRow`, so arbitrarily deep "pages" (Book of Enoch → subgroup → sub‑subgroup) all collapse cleanly.

**Relevant files:**
- `Sources/Me/Views/ContentView.swift` — Updated

### 2026-08-05 — Subgroup ordering: orderIndex on FigureGroup + reorder UI

**Context:** Follow-on to the 2026-08-02 member-ordering work — subgroups had no manual ordering, only `orderIndex`-then-name sorting. The user wanted to manually sequence subgroups (e.g. dynasty subpages within the Sumerian King List) exactly like members. Still uncommitted at time of writing.

**Changes made:**
- `Sources/MeCore/Models/FigureGroup.swift` — Added `sortedSubgroups` (order-by-`orderIndex`, name tie-break). `setSortMode(.ordered)` now also seeds sequential `orderIndex` across `sortedSubgroups` (not just members). Added `moveSubgroup(_:direction:)` — swaps a subgroup up/down and renumbers 0..n.
- `Sources/Me/Views/FigureGroupListView.swift` — `FigureGroupDetailView` gained a "Subgroups" section: folder icon + name per row, with up/down `MemberReorderButtons` (chevrons) when the group's `sortMode == .ordered`; tapping calls `group.moveSubgroup` + save.
- `Tests/MeCoreTests/MeCoreTests.swift` — 84 new lines covering subgroup order seeding, `moveSubgroup` (incl. edge no-ops), and sorted ordering.

**Design decisions:**
- Reuses the same `orderIndex` + `.ordered` sort mode mechanism as member ordering — one concept for "manual sequence" across both members and subgroups.
- Subgroup positions live on the subgroup `FigureGroup` itself (each group has its own `orderIndex`); not stored on the parent association.

**Relevant files:**
- `Sources/MeCore/Models/FigureGroup.swift`, `Sources/Me/Views/FigureGroupListView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`

> **Note:** This session also produced the TODO split, collapsible sidebar, and subnet-in-`groupDestination` changes above. All uncommitted as of end of 2026-08-05 session.

### 2026-08-05 — Subgroup routing: legacy kind views only dispatch at the root

**Problem:** The user had a subgroup "Antedeluvian Kings" under "Sumerian King List" whose `kind` was `.skl`. Clicking it routed to the legacy `SumerianKingListView` — a pre-FigureGroups hand-coded dynasty cruncher that re-derives the whole king list from `source contains "Sumerian King List"` and ignores group membership entirely. So the subgroup showed the "old" edition instead of its curated members.

**Root cause:** `ContentView.groupDestination(group:)` dispatched `.enoch`/`.skl`/`.flood` kinds to their dedicated legacy views whenever the group had no subgroups — regardless of whether the group was a top-level dedicated root or a normal subgroup.

**Changes made:**
- `Sources/Me/Views/ContentView.swift` — `groupDestination` now gates the legacy-view dispatch behind `isDedicatedRoot = group.parentGroup == nil`. Only top-level `.enoch`/`.skl`/`.flood` figure groups with no subgroups still route to `EnochView` / `SumerianKingListView` / `ComingSoonView`. Every subgroup falls through to the normal `EntityGroupCollectionView`, showing its own members.

**Design decisions:**
- `kind` on a subgroup is now effectively inert for routing — only the root drives which dedicated view (if any) renders.
- No database changes were made. The subgroup's `kind` still reads `.skl` but is harmless.

**Investigation notes (open, user to continue tomorrow):** The user is investigating whether the pre-Groups-era "Sumerian King List" top-level group (DB PK 3) + its 4 dynasty subgroups are redundant/old and can be deleted, given the Groups system seeds a group named "SKL Kings" instead. Pending user decision — **no deletions performed.** The routing fix stands regardless.

**Relevant files:**
- `Sources/Me/Views/ContentView.swift` — Updated

### 2026-08-06 — Group aggregation summaries (sum/average over members)

**Context:** The user wanted to compute a dynasty's total duration ("sum operation of all members in a group"). Chose option 2: a user-defined aggregation config stored on the group (like `memberFilter`), rendered in the collection-view header.

**Changes made:**
- `Sources/MeCore/Models/FigureGroup.swift` — Added `aggregationRawValue: String?` (migration-safe optional) + computed `decodedAggregation` (JSON, mirroring `decodedFilter`). New types: `GroupAggregationOperation` (`.sum`/`.average`), `GroupAggregationTarget` (`.reignYears`/`.reignSpan`/`.lifespan`/`.birthYear`/`.deathYear`/`.eventYear`, each with `displayName`, `shortName`, `isDuration`, `supportedEntityTypes`, and `value(for:)` extraction), `GroupAggregation` (operation + target + optional label; `title`, `compute(in:)`, `formattedValue(for:)`), `GroupAggregationResult` (count/sum/average).
- `Sources/Me/Views/FigureGroupFormView.swift` — New "Summary" section in Identity step: enable toggle + operation/target pickers + optional label. Target list filtered to the group's entity type (figures: reign/reign-span/lifespan/birth/death year; events: event year; places/things: none → note shown, toggle disabled). Loaded/saved via `decodedAggregation`.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Header renders the aggregation next to the member/subgroup counts: "Total listed reign: 141 years" with a `sum` icon, plus a "(N of M members have data)" hint when some members lack values.
- `Tests/MeCoreTests/MeCoreTests.swift` — 8 tests: codable round-trip, nil back-compat, reign-sum, average lifespan, event-year sum (BCE formatting), missing-data filtering, all-nil → nil, custom label wins. 123 tests pass.

**Key decisions:**
- `.count` is NOT an aggregation operation — member count is already always shown in the header; adding it as a config would duplicate it.
- Reign years use the existing `ReignLength.parse` (matches literal "Reigned X years"). Kings written as "reigned for around X years" or "c. X–Y BC" are silently skipped (with the "N of M" hint showing partial coverage). Widening the parser is a separate task.
- Aggregation runs over **direct members** only (subgroups are separate pages and excluded).
- BCE year targets format as "4,400 BCE"; duration targets as "141 years"; averages round to the nearest integer.
- Store is JSON in a new optional attribute — lightweight migration safe, no schema changes to the container.

**Relevant files:**
- `Sources/MeCore/Models/FigureGroup.swift` — Updated
- `Sources/Me/Views/FigureGroupFormView.swift` — Updated
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Updated
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-06 — Figure reign duration as an explicit attribute (`reignYears`)

**Context:** Reign length was only ever derived by regex-parsing `figureDescription` (`ReignLength.parse`, matching literal uppercase "Reigned X years"), so it was fragile and couldn't follow the SKL's actual listed numbers. The user wanted it as a first-class attribute on `Figure` so the SKL data is explicit and aggregation-friendly. (Confirmed there was NO existing stored field — only `reignStartYear`/`reignEndYear` date ranges, `ReignLength` as a parse helper, and the aggregation target name.)

**Changes made:**
- `Sources/MeCore/Models/Figure.swift` — Added `reignYears: Int?` (migration-safe optional), explicitly documented as distinct from `reignStartYear`/`reignEndYear` (duration vs chronological date range).
- `Sources/MeCore/Models/SKLReignLength.swift` — Widened `ReignLength.parse` to try, in order: `(Listed reign: X years.)` suffix, then `Reigned/Ruled X years` (case-insensitive, optional "for"/"around"). Added explicit `package init`. This covers the seed's varied phrasings ("ruled for 28,800 years", "reigned for around 670 years", etc.).
- `Sources/MeCore/Store/Migration.swift` — New `ensureReignYears(context:)`: for every figure with `reignYears == nil`, parse the description and write it. Additive + idempotent — never overwrites a user-entered value. Called every launch after figure-creating migrations (`enrichSKLData`, `ensureSKLEventsAndFigures`) so newly seeded figures backfill on the same launch.
- `Sources/Me/Views/ContentView.swift` — Added `Migration.ensureReignYears` to the launch sequence (after `ensureSKLEventsAndFigures`).
- `Sources/Me/Views/FigureFormView.swift` — Added "Duration (years)" field to the Reign step (load/save for both edit and create).
- Read sites now prefer the field with a parse fallback: `FigureGroup.swift` aggregation `.reignYears` target, `SKLDatePropagator.DynastyTimeline.totalYears`, `SumerianKingListView.KingRow.reignLength` (with a `NumberFormatter` for comma grouping).

**Key decisions:**
- The field is the source of truth once set; `ReignLength.parse` remains only as a fallback for figures where it's still nil (pre-backfill or unparseable). Descriptions stay untouched historical prose.
- Backfill is additive + non-overwriting per the sacred-data rule — no reseed, no `clearAll`.
- Kings written with date ranges ("c. X–Y BC") or that can't be parsed get no auto value; the user fills them in via the form (the "follow the SKL data" use case).
- No seed_data.json edits needed — the backfill migration reads existing descriptions.

**Relevant files:**
- `Sources/MeCore/Models/Figure.swift`, `Sources/MeCore/Models/SKLReignLength.swift`, `Sources/MeCore/Store/Migration.swift`, `Sources/MeCore/Store/SKLDatePropagator.swift`, `Sources/MeCore/Models/FigureGroup.swift`
- `Sources/Me/Views/FigureFormView.swift`, `Sources/Me/Views/SumerianKingListView.swift`, `Sources/Me/Views/ContentView.swift`
- `Tests/MeCoreTests/MeCoreTests.swift` — 6 new tests (parser variants, backfill, no-overwrite, aggregation-precedes-field). 129 tests pass.

### 2026-08-07 — NSTableView reentrancy warning: List→ScrollView exploration, then partial revert

**Context:** Three list views (Figures, Relationships, Associations) logged "Application performed a reentrant operation in its NSTableView delegate" on macOS. Initially suspected inline SwiftData mutations in row buttons; those were deferred via `Task { @MainActor }` but the warning persisted on *open* (no interaction).

**Diagnosis:** For Figure/Relationship/Associations, the probe confirmed the warning fires on opening the view with zero interaction — the known macOS-only SwiftUI `List` (NSTableView-backed) behavior where rows are inserted asynchronously (from `@Query`) while the table is measuring. This is harmless console noise but unavoidable with `List`.

**Changes made (Phase 1 — migrate to ScrollView):**
- `Sources/Me/Views/FigureListView.swift`, `RelationshipListView.swift`, `AssociationsView.swift` — Replaced `List(...)`/`List(selection:)` with `ScrollView` + `LazyVStack`. FigureListView lost native selection, so selection highlight + `onTapGesture` were added to `FigureRow`, and the `.onDelete` in RelationshipListView was dropped.
- Deferred inline row mutations via `Task { @MainActor }`: 5 `modelContext.delete(assoc)` in AssociationsView, the RelationshipListView star toggle (`isPreferred` + save), and `FigureListView.deleteFigure` (removed `withAnimation`).

**Phase 2 — keyboard regression + revert:** The user lost figure-list arrow-key navigation. A fix using `.focusable()`/`.focused()` + `onKeyPress` restored it but drew a 3px blue focus ring the user disliked; that approach was reverted. Then became apparent the manual implementation diverged from other lists.

**Phase 3 — uniformity + rollback (final state):**
- Added `Sources/Me/Views/AlternatingRowBackground.swift` — `.alternatingRowBackground(index:)` using `Color(nsColor: .alternatingContentBackgroundColors[1])` to reproduce the native `alternatesRowBackgrounds` striping in ScrollView lists.
- Applied the modifier to FigureListView (running `figureRowOffsets` index across grouped sections), RelationshipListView, and all 5 AssociationsView tabs.
- `ThingListView` was still a `List` but missing the stripe style — added `.listStyle(.inset(alternatesRowBackgrounds: true))`.
- **FigureListView reverted to native `List(selection:)`** (selection color + arrow keys match Places/Events/Things). Removed all ScrollView remnants: `figureRowOffsets`, FigureRow `isSelected`/`onSelect`, `figureGroupSection` restored.

**Design decision:** The user accepted the reentrancy warning ("annoying but doesn't cost anything"). Final state: **FigureListView = native `List`** (consistent selection + keyboard, warning may return on open); **Relationship/Associations remain `ScrollView`** (no row-selection to lose, manual striping retained) — left as-is per user.

**Relevant files:**
- `Sources/Me/Views/FigureListView.swift`, `RelationshipListView.swift`, `AssociationsView.swift`, `ThingListView.swift`, `AlternatingRowBackground.swift` (new)

### 2026-08-07 — Figure↔Thing association visible on figure detail

**Context:** The `ThingFigureAssociation` model existed and was fully rendered on the Thing side (ThingDetailView "Associated Figures" section + AddThingFigureAssociationForm), but `FigureDetailView` had no section for `figure.thingAssociations` — so a figure's associated things were invisible from the person's sidebar detail.

**Changes made:**
- `Sources/Me/Views/FigureDetailView.swift` — Added an "Associated Things" section (after the Places section, before Groups): lists `figure.thingAssociations` showing thing icon, name (honoring the `displayName` override as "X as Y"), role badge, source, and a trash button; shows "No things linked" when empty. Added state vars (`showThingLinkPopover`, `thingSearchText`, `selectedThingForLink`, `selectedThingRole`).
- Added `ThingLinkPopover` private struct mirroring `PlaceLinkPopover`: search field, filtered thing list (excluding already-linked), role picker over `ThingFigureRoleType`, and Link that creates `ThingFigureAssociation` set on both `figure.thingAssociations` and `thing.figureAssociations`.

**Design decisions:**
- Followed the existing `PlaceLinkPopover` pattern (popover + `+` header button), so the interaction is consistent with places/groups.
- Partly observable via `assets.roleType?.icon/color` fallback to `.brown`/`shippingbox` for things without a type, same as EventDetailView's thing rows.

**Relevant files:**
- `Sources/Me/Views/FigureDetailView.swift` — Updated (`Associated Things` section + `ThingLinkPopover`)

### 2026-08-08 — Text block ordering: unified spine in manager; max width; alignment

**Context:** Continuation of the "Book of Enoch–style story pages" work. Three parts: (1) finish the manager's reorder support for text blocks so the "can't move it" bug is actually fixed and visible, (2) give a text block a max width, (3) give a text block left/center/right alignment — both for the prose inside the box and for where the box sits in the page column.

**Part 1 — Manager now renders the unified spine (reorder visibility fix):**

**Problem:** The user had a text block under "Antedeluvian Kings" that appeared pinned below the kings in the manager (as if at the bottom) and couldn't move up. Debugging via sqlite (`~/Library/Application Support/Me/Me.store`) showed the block actually had `orderIndex = 0` — the *top* of the member+text spine — while the group's 8 members had `orderIndex` 1–8. The up arrow was legitimately disabled (nothing above it). The UI lied because the manager rendered Members / Subgroups / Text Blocks as three separate sections, so the block always *looked* bottom-pinned no matter its real spine position, and reordering was invisible.

**Changes made:**
- `Sources/Me/Views/FigureGroupListView.swift` — In Manual Order mode the manager now renders a single interleaved "ORDERLABEL & Text" section from `group.memberTextSpine` (members + text in one list), with `MemberReorderButtons` on every row. Alphabetical mode keeps the separate Members + Text Blocks sections (no arrows). New `SpineEntry` enum (`.member(GroupMemberItem, FigureGroupAssociation)` / `.text(GroupTextBlock)`, `id` via `hashValue`), `spineRow(_:)`, `memberRow(_:group:showReorder:)`, `canSpineMove(_:direction:)`, `moveSpine(_:direction:)` helpers. Old standalone Text Blocks section removed.
- `Sources/MeCore/Models/FigureGroup.swift` — added `appendTextBlock(_:)` (appends to the END of the spine — max `memberTextOrder` index + 1). Fixes a latent bug where `addTextBlock` assigned `orderIndex = textBlocks.count` (text-only count), putting a new block at the *top* of the spine when text blocks were the only thing in its `orderIndex` domain.
- `Sources/MeCore/Models/FigureGroup.swift` — `canMoveMemberTextItem(_:direction:)` now computes enablement from the unified spine position (not the per-type array index), so a sole text block between members can move up *and* down.
- `Tests/MeCoreTests/MeCoreTests.swift` — `testGroupMemberTextSpineCanMoveUsesSpinePosition` (spine-aware enablement; first member can't move up, sole text block can move both ways).

**Part 2 — max width on a text block:**

- `Sources/MeCore/Models/GroupTextBlock.swift` — Added `maxWidth: Double?` (optional, migration-safe) + init param.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `TextBlockRow` now applies `.frame(maxWidth: block.maxWidth.map { CGFloat($0) } ?? .infinity)`. `GroupTextBlockSheet` gained a "Max width:" segmented picker (Full / 420 / 560 / 700) loaded/saved via the new state var.

**Part 3 — alignment (two distinct capsule concerns separated):**

- `Sources/MeCore/Models/GroupTextBlock.swift` — Added `TextBlockAlignment` enum (`.left` / `.center` / `.right`) stored as `alignmentRawValue: String?` (optional, migration-safe) with computed `alignment` defaulting to `.left`.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `TextBlockRow` now uses the alignment in two places: (a) the box's position within the page column, and (b) text-line alignment inside the box. `GroupTextBlockSheet` gained an "Align:" segmented picker.

**The "it doesn't work" bug (card always centered):** The bordered box itself was being centered by the surrounding `LazyVStack` (default `.center` alignment), so the capped-width box floated center regardless of the picker. Fixed by wrapping the `.frame(maxWidth:)` box in an outer `.frame(maxWidth: .infinity, alignment: block.maxWidth == nil ? .leading : frameAlignment)`, so the *box* is positioned left/center/right within the full row — the inner `RichTextDisplay` still applies `multilineTextAlignment` separately.

**Design decisions:**
- `SpineEntry.id` uses `hashValue` because `PersistentIdentifier` exposes no stable string on macOS 14 — matches the existing `TagCloudView` pattern.
- Alignment and width are stored as optional raw fields (migration-safe), consistent with `sortModeRawValue` / `kindRawValue`.
- The `LazyVStack` centering trap was found via the layered-`.background()` debugging procedure (AGENTS.md Debugging Visual Layout Issues).

**Verify:** `swift build` + `swift test` — 139 tests pass (no new tests this session; existing suite green). Manual: Antedeluvian Kings → Manual Order → block visible at its true spine position, arrows move it visibly; edit sheet has Max width + Align pickers; the box and its text respect both.

**Relevant files:**
- `Sources/MeCore/Models/GroupTextBlock.swift` — Updated (`maxWidth`, `TextBlockAlignment`/`alignmentRawValue`)
- `Sources/Me/Views/FigureGroupListView.swift` — Updated (unified spine section + reorder helpers)
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Updated (maxWidth + alignment rendering, sheet pickers)
- `Tests/MeCoreTests/MeCoreTests.swift` — updated only indirectly from previous session (139 passing)

### 2026-08-09 — Drag-and-drop spine reordering finalized; Figure epithet attribute + migration; deferred research-notes & text-block attribution planning

**Part 1 — Drag-and-drop spine reordering (gap-dead-zone bug):**

**Problem:** Per-row drop targets in the manual-order spine had dead zones — the 8pt spacing between rows, plus the slivers above the first and below the last row, belonged to no row, so edge drops silently failed ("first/last don't work", middle "often fails"). A first attempt switched from `NSItemProvider.loadObject(ofClass: String.self)` (which never delivers — `String` isn't `NSItemProviderReading`) to row-level `.dropDestination`, but edge drops still failed because of the target-rect gaps.

**Fix:** Single container-level drop target on the entire spine `VStack` in `FigureGroupListView.swift`. Each row publishes its frame (via `SpineDropFrameReader` publishing `SpineEntryDropFrame` through the `SpineDropFrameKey` preference, measured in the shared `SpineDropSpaceName` coordinate space). `insertionIndex(for:in:)` maps a drop location to the spine index by finding the first row whose `midY` is below the drop point — so drops in gaps, above the first row (prepend), and past the last row (append) all resolve. `isSpineDropTargeted` tints the whole container so the drop zone is obvious. Frames are accumulated (not overwritten) in `SpineDropFrameKey.reduce` (an initial `value = nextValue()` bug left only one frame). Removed now-dead `SpineDropRow`/`SpineDropDelegate`/`SpineDropFrame`/`SpineRowHeightKey`/`SpineEntry.dragPayload`.

**Part 2 — Figure epithet as a first-class attribute:**

**Context:** User pointed out that an epithet (e.g. Etana's "the shepherd who ascended to heaven and consolidated all the foreign countries") isn't an alternate name — storing it as `AlternateName(nameType: .epithet)` mischaracterizes a title as an alias (confirmed: most seed epithets weren't even in that table, they're prose *inside* `figureDescription`, e.g. `Epithet: ''"the boatman"''.`).

**Changes made:**
- `Sources/MeCore/Models/Figure.swift` — Added `epithet: String?` (migration-safe optional, same pattern as `reignYears`; not in the `init`, set post-construction).
- `Sources/MeCore/Store/Migration.swift` — `ensureEpithets`: backfills `Figure.epithet` from `figureDescription` by regex-extracting `Epithet: ''"X"''` or `Epithet: 'X'` prose (both seed formats). Additive + idempotent, never overwrites user-entered values. Wired into `ContentView` launch sequence after `ensureReignYears`.
- `Sources/Me/Views/FigureFormView.swift` — "Epithet" field in Identity step (between Title and Type picker).
- `Sources/Me/Views/FigureDetailInfoView.swift` — New `FigureEpithetRow` shared component (italic, quoted, with "EPITHET" caption label); added to `FigureHeaderView`.
- `Sources/Me/Views/FigureDetailView.swift` — `FigureEpithetRow` after the title row.
- `Tests/MeCoreTests/MeCoreTests.swift` — 4 new tests: double-quoted prose backfill, single-quoted prose backfill, no-overwrite, ignore-figures-without-epithet. 144 tests pass. **Existing `AlternateName` rows with `nameType: .epithet` (e.g. Enki's "Nudimmud") left untouched — those read like genuine aliases.**

**Part 3 — Research-notes discussion (no code):**

The user wants a place to park Wikipedia factoids that fit no existing attribute. Determined this is NOT a "commenting system" and NOT StickyNotes — sticky notes are throwaway remind→resolve→delete to-dos and must never hold valuable info. Framed as a **catch-all annotation slot** with a driven decision rule: if a snippet recurs across many figures, promote it to a real field; otherwise a structured snippet slot (title/url/topic). Recorded in TODO.md with the design sketch (polymorphic link like StickyNote's, `title`/`text`/`url`/`createdAt`, global-search integration).

**Part 4 — Text-block ContentAttribution deferred:**

User asked whether group text blocks support content attributions — **no**: `ContentAttribution` only self-link to Figure/Place/Event/Thing, and `GroupTextBlockSheet` has no attribution UI. Recorded in TODO.md: add `groupTextBlock: GroupTextBlock?` to `ContentAttribution` + inverse, reuse `ContentAttributionFormView`/`ContentAttributionSection` in the sheet.

**Relevant files:**
- `Sources/Me/Views/FigureGroupListView.swift` — Updated (container-level drop, `spineDropFrames`/`isSpineDropTargeted` state, `insertionIndex(for:in:)`, `SpineDropFrameReader`, `SpineDropFrameKey`, `SpineEntryDropFrame`, `SpineDropSpaceName`; removed per-row drop structs + dead `dragPayload`)
- `Sources/MeCore/Models/Figure.swift` — Updated (`epithet: String?`)
- `Sources/MeCore/Store/Migration.swift` — Updated (`ensureEpithets` + `extractEpithet`)
- `Sources/Me/Views/ContentView.swift` — Updated (launch sequence gains `Migration.ensureEpithets`)
- `Sources/Me/Views/FigureFormView.swift` — Updated (Epithet field)
- `Sources/Me/Views/FigureDetailInfoView.swift` — Updated (`FigureEpithetRow`)
- `Sources/Me/Views/FigureDetailView.swift` — Updated (epithet in header)
- `Tests/MeCoreTests/MeCoreTests.swift` — 4 new epithet tests
- `TODO.md` — Added "Catch-all annotation slot for un-attributable snippets" (refined framing) + "Content attribution on text blocks" items

### 2026-08-09 — Smart groups: membership rule evaluated live

**Context:** The user's "Sumerian Pantheon" group is hand-curated via the wizard, which is a maintenance burden — every new figure has to be added to every group it belongs to. The ask: define an *expression* as the membership (e.g. all figures whose domain is Sumerian) and have it **evaluated live before the group is displayed** so new figures appear automatically. Chosen semantics: **strict smart** — while smart is on, manual picking/ordering is disabled and stored associations are hidden (kept in DB, restored if smart is turned back off).

**Design decisions:**
- The "expression" **is** the existing `GroupMemberFilter` (figure/place/event/thing type names, domain keywords, name match) — the same rule Bulk Add/Sync persists. "WHERE PANTHEON = 'Sumer'" maps to a domain-keyword rule. No new query language.
- `isSmart` (evaluation switch) and `memberFilter` (the expression) stay decoupled. A manual group can keep a stored filter for Sync; flipping smart on just makes that filter live.
- Smart groups always render name-sorted; the manual-order spine, Bulk Add, Sync, and reorder UI are hidden/disabled while smart.
- `liveMatchIDs(in:)` does a full fetch + in-memory filter per evaluation (DB is small — fine, matches the Bulk Add sheet's pattern).
- No auto-flip of existing groups (user's DB is sacred; converting is a deliberate roundtrip in the form). Only fresh-install default groups that carry a filter are seeded smart.

**Changes made:**
- `Sources/MeCore/Models/FigureGroup.swift` — New migration-safe `isSmartRawValue: Bool?` + computed `isSmart` (default false; `init` param). New `liveMatchIDs(in context:)` returning the entity types' PersistentIdentifiers that match `decodedFilter` (the tested, MeCore-pure core). `GroupAggregationResult` gained a `package init`.
- `Sources/Me/Views/FigureGroupSmartMembers.swift` — NEW Me-layer extension: `effectiveMemberItems(in:)` (smart → live matches sorted by name; manual → `sortedAssociations`), `effectiveMemberCount(in:)`, plus `GroupAggregation.compute(items:)` / `GroupAggregationTarget.value(for: GroupMemberItem)` mirroring the association/contentated variants so aggregation works over live members.
- `Sources/Me/Views/FigureGroupListView.swift` — manager rows show `bolt` badge + **live** member count; detail view hides Bulk Add / Sync / manual-order spine when smart and shows the rule summary as a teal "Smart" line; alphabetical members section shows an "Automatic membership — evaluated live" note; members read `effectiveMemberItems`.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `memberItems(for:in:)` built from `effectiveMemberItems`; `mixedItems` and `EntityGroupTreeNode.children` force the alphabetical path when smart; header count, aggregation hint, and `reignTower`/`heroStats` compute from effective members; `EntityGroupTreeNode` gained `@Environment(\.modelContext)` to read live counts.
- `Sources/Me/Views/FigureGroupFormView.swift` — Members step toggles between the existing picker and a new **rule builder** when "Smart group — membership comes from a rule" is checked: entity-type-aware type pills + keywords (figures only) + name match, and a live "N currently match" preview with the first 15 names. `load`/`save` carry `isSmart` + the stored filter; `syncMembers` is skipped when smart.
- `Sources/MeCore/Store/Migration.swift` — `ensureDefaultFigureGroups` seeds the filter-carrying default groups (Sumerian Pantheon, Akkadian/East Semitic, Primordial Beings, SKL Kings) as smart on a fresh install. Existing DBs are left manual.
- `Tests/MeCoreTests/MeCoreTests.swift` — 6 new tests: `isSmart` default/round-trip/init, `liveMatchIDs` for figure (domain-only and type-only OR semantics), manual group → empty, place group smart, group-is-smart gating. 150 tests pass; `swift build` clean.

**Known limitation:** the entity detail "Groups" sections list only stored associations, so a figure that is a *live* member of a smart group won't be listed there (only on the group's own page). Worth a future TODO.

**Relevant new/removed files:**
- `Sources/Me/Views/FigureGroupSmartMembers.swift` — Added

**Relevant files:**
- `Sources/MeCore/Models/FigureGroup.swift`, `Sources/Me/Views/FigureGroupListView.swift`, `Sources/Me/Views/EntityGroupCollectionView.swift`, `Sources/Me/Views/FigureGroupFormView.swift`, `Sources/MeCore/Store/Migration.swift`, `Tests/MeCoreTests/MeCoreTests.swift`

### 2026-08-09 — Pantheon as a first-class entity

**Context:** There was no way to filter "Sumerian deities" — the `domain` field is sphere-of-influence (e.g. "Sky, Kingship, Authority"), not a culture marker. The ask: a `Pantheon` model (Mesopotamian, Greek, Hebrew, …) with many-to-many membership to `Figure`, its own management UI, a smart-group filter rule, and an additive default migration. User decisions: many-to-many membership; migration assigns **all** currently-unassigned figures to a single new "Mesopotamian" pantheon.

**Changes made:**
- `Sources/MeCore/Models/Pantheon.swift` — NEW `@Model`: `name`, `pantheonDescription`, `icon`, `colorHex`, `color` (via `Color(hex:)`), `figures: [Figure]`. Inverse relationship declared only on the Figure side (bare `@Relationship` here) to avoid the "circular reference resolving attached macro 'Relationship'" error.
- `Sources/MeCore/Models/Figure.swift` — Added `pantheons: [Pantheon] = []` with `@Relationship(deleteRule: .nullify, inverse: \Pantheon.figures)`.
- `Sources/MeCore/Models/FigureGroup.swift` — `GroupMemberFilter` gained `pantheonNames: [String]?` (declaration, init, `matches(_ figure:)` OR-semantics by name, `summary` → "Pantheon: …").
- `Sources/MeCore/Store/Migration.swift` — `ensureMesopotamianPantheons(context:)`: creates "Mesopotamian" if absent, then appends it to figures with empty `pantheons`. Additive + idempotent, never reassigns existing membership.
- `Sources/Me/Views/ContentView.swift` — added `Migration.ensureMesopotamianPantheons` after `ensureEpithets` in the launch sequence.
- `Sources/Me/Views/FigureDetailView.swift` — New "Pantheons" section (icon/name/description rows, remove `minus.circle` button, `+` header button) + `PantheonLinkPopover` (search + filtered list + Link), mirroring the Groups section pattern.
- `Sources/Me/Views/FigureFormView.swift` — Identity step gained a Pantheons multi-select pill grid (`@Query(sort: \Pantheon.name)`); loaded in `loadIfEditing`, saved in `save()` for both edit and create.
- `Sources/Me/Views/FigureGroupFormView.swift` — Smart-group rule builder gained "By Pantheon" pills (figures only) → `rulePantheonNames` carried through `buildSmartRule`/`loadRule`/`hasSmartRule`.
- `Sources/Me/Views/TypeSettingsView.swift` — New "Pantheons" GroupBox with a dedicated `PantheonSubSection` + `PantheonEditSheetView` (name/description/icon/color, add + edit, figure count badge).
- `Tests/MeCoreTests/MeCoreTests.swift` — 7 new tests: defaults, many-to-many, filter match + summary, migration create + idempotency + keeps-existing-membership. 157 tests pass.

**Design decisions:**
- Many-to-many, not one-to-many: a figure like Enki legitimately belongs to both Mesopotamian and (via syncretism literature) Greek-adjacent discussions. `Figure.pantheons` is the owning side for setting/list mutation; `Pantheon.figures` is the non-annotated inverse (per the 2026-06-27 SwiftData relationship-setting rule, assign via `figure.pantheons`).
- Smart-group pantheon rule reuses `GroupMemberFilter` OR semantics — no new DSL.
- The migration is deliberately coarse: on a fresh DB or one with zero pantheon data, all figures get the Mesopotamian pantheon by default. Users refine per-figure via the form or the popover. Existing user pantheon memberships are untouched.

**Known limitation:** the entity detail "Groups" sections list only stored associations, so a figure that is a *live* member of a smart group won't be listed there (only on the group's own page). Worth a future TODO.

**Relevant new/removed files:**
- `Sources/MeCore/Models/Pantheon.swift` — Added

**Relevant files:**
- `Sources/MeCore/Models/Figure.swift`, `Sources/MeCore/Models/FigureGroup.swift`, `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/FigureDetailView.swift`, `Sources/Me/Views/FigureFormView.swift`, `Sources/Me/Views/FigureGroupFormView.swift`, `Sources/Me/Views/TypeSettingsView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`

### 2026-08-09 — Group deletion crash: macOS 26 SwiftData cascade fault

**Problem:** Deleting the "Sumerian Pantheon" smart group beachballed/crashed on every attempt. `_assertionFailure` inside SwiftData's own cascade `Sequence.forEach` faulting `FigureGroupAssociation.persistentBackingData` synchronously from `modelContext.delete(group)` (confirmed via `~/Library/Logs/DiagnosticReports/Me-2026-08-09-*.ips`, register x22 = `type metadata for FigureGroupAssociation`, x26 = `persistentBackingData` conformance).

**Root cause:** macOS 26 SwiftData bug (Apple Dev Forums #822241, StackOverflow #79742362): when a model with `@Relationship(deleteRule: .cascade)` children is deleted while live `@Query` views still reference those children, SwiftData tears down the children's backing data and a still-rendering view faults a deleted child's backing data → fatal assert. This app made it worse: `FigureGroupAssociation` is cascade-owned from **five** sides (`FigureGroup.figureAssociations`, `Figure.groupAssociations`, plus Thing/Place/Event group associations). The join model's own `group`/`figure`/`thing` to-ones are un-annotated and optional — the inverse arrays on every owner carry `.cascade`.

**Why plain unit tests couldn't reproduce:** model-level deletes pass in every config (disk/in-memory, autosave on/off, explicit child-deletion, fresh copy of the live store with all relationships faulted). The trigger requires SwiftUI coexisting with the delete — no live `@Query` observation exists in `MeCoreTests`.

**Fix (the one that works):**
- `Sources/Me/Views/FigureGroupListView.swift` — `deleteGroup(_:)` now wraps the deletion in `modelContext.transaction { }` AND empties the observed children arrays (`group.figureAssociations = []`, `group.textBlocks = []`) **before** `modelContext.delete(group)`. Emptying the arrays lets the observation layer react to the collection change (views drop the children) before SwiftData cascade-deletes them; the transaction batches it so no re-entrant fault can fire mid-delete.
- Earlier attempts that did NOT work: deferring via `Task { @MainActor }` + `withAnimation` removal; loop-deleting each association child before deleting the group (this *moved* the crash into the loop — same fault path). The empty-array + transaction combination is the documented macOS 26 remedy.

**Lessons:**
- macOS 26 SwiftData asserts (not returns nils) when a live view faults a cascade-deleted child's backing data. Deleting a parent whose children are observed = must empty the observed arrays first.
- When a `@Model` is cascade-owned from multiple inverse relationships (join models) AND observed live, prefer letting SwiftUI detach from the children via array mutation instead of raw `modelContext.delete(child)` loops.
- Unit tests prove model correctness but canNOT reproduce SwiftUI-coexistence crashes; crash reports (`DiagnosticReports/*.ips`) are the ground truth for these.
- `ModelConfiguration`'s autosave parameter was renamed `isAutosaveEnabled:` → `allowsSave` in the macOS 26 SDK.

**Tests:** 163 pass (incl. hermetic `testGroupDeleteRealStoreCopy`, `testGroupDeleteRealStoreAutosaveNoManualSave`, `testGroupDeleteRealStoreExplicitChildDeletion` — all skip cleanly when the live store isn't present).

**Relevant files:**
- `Sources/Me/Views/FigureGroupListView.swift` — Updated (`deleteGroup`)
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated (3 real-store diagnostic tests)
- Crash reports: `~/Library/Logs/DiagnosticReports/Me-2026-08-09-{221737,222531,224256,230314}.ips`
