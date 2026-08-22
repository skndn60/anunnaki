# Anunnaki — Agent Context

## Project Identity

A macOS knowledge management app for Sumerian/Mesopotamian mythology. Built with SwiftUI + SwiftData. Users curate structured data about deities, places, events, and sources with a native desktop UI, visual lineage trees, timelines, and natural language querying.

Product name: **Me** (displayed in window title, executable name in Package.swift). Project codename: **Anunnaki**.

## Project Genesis & Motivation

The app is a **personal interests project** — no commercial goals, not intended to be sold (at least not actively). Origins: the developer has long been fascinated by the Anunnaki and Sumerian civilization, but the sheer volume of figures and places involved in that mythology was bewildering, and no tool existed to organize it and make it more accessible. That gap, plus a second interest in Mac app development, is the cornerstone of the project.

**What this means for decisions:**
- It is also a way to stay connected to AI/LLM tooling (pair-programming, natural language querying) — so the AI-facing surface (QueryEngine, natural-language features) matters as much as the data model.
- No growth/audience pressure: the app is built to be useful to one person. "Niche audience" is not a risk to manage; data-entry speed for personal use is the lever that matters (see `docs/PRODUCT_WEAKNESSES.md`).
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

### SwiftUI & SwiftData pitfalls

- **Never fault a `@Model` property inside a SwiftUI `body`** — macOS 26 asserts (`EXC_BREAKPOINT` / `_assertionFailure` inside SwiftData), especially during `ForEach` render/layout passes. Precompute display values into plain value structs off the render path (`.task`, `.onChange`, button actions); keep bodies pure value-driven.
- **Deleting a parent whose cascade children are observed live**: empty the observed child arrays first, then delete inside `modelContext.transaction { }` — otherwise SwiftData's cascade faults deleted children mid-render (see group deletion, DuplicateMerger).
- **`.onChange` triggers compare ID collections** (`figures.map(\.persistentModelID)`), not model arrays: identity-preserving edits don't rebuild, structural changes do, and comparing IDs never faults deleted models.
- **Views placed with `.position()` inside a ZStack must render unconditionally** — no `if`/`if let` wrapping and no `.opacity()` on the whole sub-view (they render at zero visual presence). Per-element checks inside are fine.
- **Popovers/sheets don't work from Canvas/`.position()` overlays** — hoist them to `.sheet(item:)` on a dedicated view struct driven by state set from gesture handlers.
- **Extract complex `body` fragments** into computed properties or helper views when the Swift compiler times out type-checking.
- **Avoid `NSCursor.push()/pop()`** in SwiftUI contexts — unbalances the AppKit cursor stack.
- **Search fields use `.textFieldStyle(.roundedBorder)`**; inline editing/comment fields may be `.plain` inside a visible background container.
- **Unit tests can't reproduce SwiftUI + SwiftData coexistence crashes** (no live `@Query` observation in MeCoreTests) — crash reports in `~/Library/Logs/DiagnosticReports/*.ips` are ground truth for those.
- **macOS 26 SDK rename**: `ModelConfiguration`'s autosave parameter is `allowsSave:` (was `isAutosaveEnabled:`).

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
- `docs/PRODUCT_WEAKNESSES.md` — Product-level critique: the app's weak spots and strategy (cold-start data volume, trapped data, contradictory traditions, curation burden, niche risk, no feedback loop) + priorities
- `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` — Code-level technical debt review (SwiftData boilerplate, Relationship.source, width persistence, lineage complexity)
- `docs/TODO.md` — Open/backlog work items and completed feature checklists (the todo list previously inline in AGENTS.md)
- `docs/SESSION_LOG.md` — Full session-by-session history (context, changes, decisions, verification); append a new entry there at the top after each session

## Session Log

The full session-by-session history lives in `docs/SESSION_LOG.md` — one entry per working session (context, changes, key decisions, verification, files touched), newest first. **Append new entries there**, at the top, after each working session. Promote lessons that prove recurring into Coding Conventions above instead of re-explaining them here. This file holds durable reference material only.

## Debugging Visual Layout Issues

When investigating SwiftUI layout bugs (unexpected padding, misalignment, sizing), follow this procedure:

1. **Add a colored `.background()` to the outermost view first**, then run to observe which view claims the full frame.
2. **Work inward layer by layer**, moving the background color one level deeper each time, until you isolate which view has the unexpected size or position.
3. Only after identifying the root view should you look at modifier chains or data flow.

This is faster and more reliable than reading code to simulate the layout engine.

## Hard Constraints

- **NO reseeding.** Never run `--reseed`, never call `clearAll`, never destroy user data. All migrations must be additive only (check-by-name before creating). The user's existing database is sacred.

## Interaction Guidelines (from CONTRIBUTING.md)

- One change per request. Split large tasks into small steps.
- Validate JSON with `jq --exit-status . Sources/Resources/seed_data.json` before committing seed changes.
- Run `swift build` before submitting changes.
- Branch naming: `feat/`, `bugfix/`, `migration/` prefixes.
- Do not commit secrets, keys, or provisioning profiles.

