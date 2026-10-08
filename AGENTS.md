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
| **FigureType** | Dynamic type for figures | name, icon, colorHex, category? (replaces hardcoded `Figure.FigureType` enum) |
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
- **A collective has members, not parents.** A figure typed with a `FigureType` whose `category == "collective"` is an assembly (Anunnaki, Assyrians), not an individual, so father/mother do not apply to it — rendering parent slots for one is a category error, not a data gap, and the slots are clickable ("Add father" for the Assyrians is nonsense). `Figure.isCollective` / `FigureType.isCollective` are the **only** predicates: never `name.localizedCaseInsensitiveContains("Collective")`, which is a match on a user-editable display name and silently breaks on a rename in the Type Manager. `FigureDetailView` branches on it to show `CollectiveMembershipStrip` (reads `collectiveMembers(of:from:)` in MeCore) instead of `MiniLineageView`. The lineage explorers and the sidebar "Lineage Tree" entry are **not** yet gated — see `docs/TODO.md`.
- **A `membership` relationship is directed: member → collective, and that is the only direction anything can read.** `ConsistencyEngine.checkBidirectionalMismatch` handles the opposite case (types recorded in *both* directions); nothing else in the model encodes "exactly one valid direction", which is what made this easy to get wrong. Write these rows with `RelationshipManager.addMembership(member:collective:)` — the direction is a parameter of the method, not of its caller, so it cannot be inverted. `RelationshipFormView` is the only sanctioned writer and enforces it at the entry point: it relabels its two ends to "Member"/"Collective" and refuses to commit unless the far end is a collective, so the bad spelling is inexpressible rather than merely discouraged. A row written backwards is **not** a store error — it is a member that silently never appears in any roll, so the read side must keep assuming the direction is correct.
- **A source-equivalence claim ("these two names are one people") is not a fact to be seeded; check the source, and attribute it to whoever made it.** A `Local form of` edge asserts an identity, and the Nephilim migration seeded two of them (Rephaim, Gibborim → Nephilim) on the strength of 1 Enoch and the Septuagint, while the Hebrew Bible says no such thing: it uses the Repha'îm as a heading for the Transjordan peoples and never equates them with the antediluvian Nephilim. The mistake survived because *both* the umbrella reading and the "no edge, on purpose" reading sounded scholarly, and only reading the verses in full showed that Deut 2:11 and 2:20 count the Emim and Ammon's Zamzummim *with* the Repha'îm rather than beside them. So: for any equivalence, find the verse that states it, check that a second tradition is not being silently substituted for the primary one, and if the identification genuinely belongs to a later book, attribute it there rather than writing it as the figure's own description. Where the two traditions genuinely conflict, record both and say which one the graph follows.
- **Withdrawing a seeded claim means deleting what you wrote, at full width.** When a model is corrected, three things have to go, not one: the edges (narrow — match *every* axis the seeding function wrote, not the name, so a user's own row of the same type survives), the prose on the figure (narrower still — correct a description **only** when it still reads verbatim what an earlier build wrote, carried in the seed as `previousDescription`, since that is the one case where overwriting is repairing our own text rather than the user's), and the **review notes**, because stickies are append-only and a store that ran the old build otherwise carries both the withdrawn claim and its retraction on the same figure. Withdraw the superseded notes by full-text match against a fixed list of the strings you wrote, never by prefix — a prefix match also deletes the replacement note. Every deletion gets a test that builds the old shape **by hand**, so it does not depend on the old build still existing to be reproduced, and after any deletion assert identity on **content**: CoreData recycles the `persistentModelID` of a deleted row, so a delete plus an insert in one save can hand the freed ID to the replacement, and two equal IDs prove nothing either way.
- **A `FigureType` holding both peoples and persons cannot be categorised at all — split the type, never the category.** `category` is one value per type, and "collective" means "has members instead of parents", so a type that carries both an assembly and an individual has no correct value. The store's own `Nephilim` type was exactly that (Anakim/Emim/Rephaim/Zuzim as peoples, Hahyah/Ohyah/Og of Bashan as persons), so it stays **uncategorised** and the peoples moved to `Mythical Collective`; `testEnsureFigureTypeCategoriesNeverCategorisesTheNephilimType` pins it and the reason is on the constant in `Migration+NephilimCollectives.swift`. Do not "fix" it back by categorising the type — that reintroduces the "? unknown father" bug of 2026-09-29 for the three named giants. Related: a type name is not a claim about the figures on it, so when a theme mixes kinds, put the kind in the *type* and let the *figure* carry the nuance. Never park a synonym or a person in a member roll either: the Repha'îm are the Torah's ethnic category with a real roll of four (Deut 2:11, 2:20, 3:11), while `Gibborim` is a common noun, "the mighty ones", and lives on the uncategorised type as an `AlternateName` typed `Epithet` rather than as a collective — see the Source-is-a-work rule below for why the two words must not be equated.
- **`reignStartYear` is negative for BCE.** All 160 dated figures in the live store are negative (Alulim is `-269200`), so ascending numeric order *is* chronological order. Writing a test with a positive "1900 BCE" and expecting it to sort first is a bug in the test, not in the sort — the same "suspect the measurement first" trap as the `ZCITATION.ZENTITYTYPE` case-wrong query.
- **Never name a `@Model` property `entityName`** — SwiftData aborts (`swift_dynamicCastFailure`, SIGABRT) reading such properties even in trivial tests. Use `linkedEntityName` (stored) or `safeEntityName` (computed) as in `Citation`/`ActivityLogEntry`.
- **Never implement relations with Strings — always via keys.** Any entity-to-entity join or source attribution must be a `@Relationship` to the target `@Model` (e.g. `sourceRef: Source?` with an annotated inverse array on `Source` supervised by `RelationshipManager`). Free-text string fields are display/legacy mirrors only — never the join mechanism, never the discriminator. A new `source: String`-only join field is a design violation.
- **A `Source` is a work; a verse, folio, line or tablet number is a location inside it.** Never bake the locator into `Source.name` — one work cited from five places is **one** `Source` with five `Citation`s, each carrying its locator in `Citation.location`. On 2026-09-30 the store held `Bible - Genesis 6:4`, `Bible - Numbers 13:33`, `Bible - Deuteronomy 3:11`, … because a migration copied the shape of a hand-made row instead of questioning it; `Book of Enoch (1 Enoch)` had always been right, cited twenty times from one row. The same rule covers tablets (`BM 36322`, not one source per obverse) and tablets-of-lines. When collapsing such rows, two things bite: a citation whose locator lived **only** in the source name loses its reference the moment the name goes, so write it into `Citation.location` first; and user prose on the doomed row must be copied onto the surviving one, because `DuplicateMerger.mergeSources` only adopts a string into an *empty* field. `Source.citations`/`.attachments` cascade, so re-point all twelve relationship sides before deleting — `DuplicateMerger.mergeSources` already does this. `Migration.isPerVerseBibleSourceName` is the shape test.
- **`#Unique` requires macOS 15** — the app targets macOS 14; enforce uniqueness in service code instead (see `AuthService`).
- **SwiftUI**: Use `@Query` for fetches, `@Environment(\.modelContext)` for mutations. Prefer `NavigationSplitView` with sidebar.
- **Optional strings**: Default to `""` not `nil` for string fields. Optional `PersistentIdentifier` for selection state.
- **Breadcrumbs**: Tuple type `[(id: PersistentIdentifier, name: String)]` consistent across list views.
- **SwiftData**: Inverse relationships specified with `@Relationship(deleteRule: .cascade, inverse: ...)`.
- **SwiftData relationship setting**: Always set relationships via the side that HAS `@Relationship(inverse:)`. For example, `type.relationships.append(rel)` works but `rel.relationshipType = type` silently fails (leaves property nil). This is because the forward side (`Relationship.relationshipType`) lacks `@Relationship` while the inverse side (`RelationshipType.relationships`) has it. Always use the annotated side to establish links.
- **SwiftData migration safety**: Every new property added to an existing `@Model` must be **optional** (`Type?`), not non-optional with a default. SwiftData lightweight migration fails on non-optional new attributes — existing rows have no value and CoreData rejects the mandatory column. Use `?? defaultValue` in computed properties or at call sites instead.
- **Every save goes through `Commit.save(_:_:)` (`MeCore/Store/Commit.swift`).** Never write a bare `try? …save()`: `try?` discards the error, so a failed write leaves the in-memory context showing a change the store never got, with no signal anywhere. This directly violates the "the database is sacred" constraint, and it has bitten for real — three migrations silently failed to decode null non-optional strings until a temporary `do/catch` was added to find out why (`docs/SESSION_LOG.md`, 2026-07-20). On 2026-09-27 all **274 sites across 71 files** were converted to `Commit.save(context, "label")`, where `label` is the enclosing function (or `Type.func` in views) so the log line and the startup report name something actionable. `Commit.save` logs via `Logger(subsystem: "com.me.app", category: "store")` and returns a discardable Bool. Inside `Commit.collectFailures { }` (used by `SeedRunner` for the whole launch chain) failures are also collected and surfaced to the user as a banner, so a migration that cannot commit is no longer invisible. **A test enforces this:** `MeCoreTests.testNoUncheckedTrySaveInSources` fails the build if the pattern reappears in `Sources/` — verified to fail on an injected violation, including the no-space `try?modelContext.save()` form. Do not `try!` a save instead: a crash is worse than a logged error. `try?` on **`fetch`** is still fine and idiomatic (`?? []`) — the 409 fetch sites are deliberately not covered by the lint.
- **Shared container**: `MeApp.sharedContainer` is a static property on the `@main` App struct, allowing direct access to the `ModelContainer` from anywhere (useful for debugging or bypassing environment inheritance issues).
- **Mock data**: `SeedData` uses private Codable structs mirroring the entities (e.g., `SeedFigure`, `SeedEvent`).
- **No external packages** — all dependencies are Apple SDKs.

### SwiftUI & SwiftData pitfalls

- **Never fault a `@Model` property inside a SwiftUI `body`** — macOS 26 asserts (`EXC_BREAKPOINT` / `_assertionFailure` inside SwiftData), especially during `ForEach` render/layout passes. Precompute display values into plain value structs off the render path (`.task`, `.onChange`, button actions); keep bodies pure value-driven.
- **Every selectable `List(selection:)` needs `.listArrowKeyNavigation(selection:orderedIDs:)`** (`Sources/Me/Views/ListArrowKeyNavigation.swift`) — on macOS 27 a SwiftUI `List` no longer takes keyboard focus, so arrow keys do nothing even after clicking a row. Pass the rows in on-screen order (flatten sections/subgroups, including a group's children only while expanded). The modifier re-adds `.focusable()`, suppresses the focus ring with `.focusEffectDisabled()`, focuses on appear, and moves the selection on Up/Down. New list views must apply it or they'll regress.
- **Keep test/scratch `ModelContainer`s alive with a `let`** — `ModelContext` holds its container weakly, so `let context = makeContainer().mainContext` can leave the container deallocated while the context lives. Inserting into such a context intermittently traps with a silent `brk #0x1` (EXC_BREAKPOINT, sig 5) inside SwiftData (`___lldb_unnamed_symbol_...`, no stderr message) — passes in some builds/runs, crashes in others. Always `let container = makeContainer(); let context = container.mainContext`.
- **Deleting a parent whose cascade children are observed live**: empty the observed child arrays first, then delete inside `modelContext.transaction { }` — otherwise SwiftData's cascade faults deleted children mid-render (see group deletion, DuplicateMerger).
- **`.onChange` triggers compare ID collections** (`figures.map(\.persistentModelID)`), not model arrays: identity-preserving edits don't rebuild, structural changes do, and comparing IDs never faults deleted models.
- **Views placed with `.position()` inside a ZStack must render unconditionally** — no `if`/`if let` wrapping and no `.opacity()` on the whole sub-view (they render at zero visual presence). Per-element checks inside are fine.
- **Popovers/sheets don't work from Canvas/`.position()` overlays** — hoist them to `.sheet(item:)` on a dedicated view struct driven by state set from gesture handlers.
- **Never create or order any `NSWindow` in `applicationWillFinishLaunching`** — an empty borderless window (or hosting content, or a "veil") ordered there makes SwiftUI's `WindowGroup` silently skip creating its main window (it never enters `NSApp.windows`, app shows nothing). Delegate observers can be registered there, but window creation/ordering belongs in `applicationDidFinishLaunching` or later. "Cover with a full-screen `.floating` opaque window" beats "hide the big window via observers": the window is created mid-bootstrap before your observers can exist, and `NSApplication.didUpdateNotification` never fires while the main thread is blocked.
- **Keep seeding/migration off the main thread** (`SeedRunner` in `Sources/Me/Views/SeedRunner.swift`): run the migration chain on a spawned `DispatchQueue` with its own background `ModelContext(container)`; hop `completion` to `DispatchQueue.main`. Otherwise the main actor is blocked for seconds at launch — the splash freezes, the spinner stops, clicks queue, and any launch-time window choreography (hide/reveal, frame restore) silently falls over. All `Migration.*`/`SeedData.*` funcs are nonisolated `package static func(context:)` and are testable off the main thread.
- **Extract complex `body` fragments** into computed properties or helper views when the Swift compiler times out type-checking.
- **Avoid `NSCursor.push()/pop()`** in SwiftUI contexts — unbalances the AppKit cursor stack.
- **Search fields use `.textFieldStyle(.roundedBorder)`**; inline editing/comment fields may be `.plain` inside a visible background container.
- **Row/item deletion is always a small red trash icon** — `Image(systemName: "trash")` with `.font(.system(size: 10))`, `.foregroundStyle(.red.opacity(0.7))`, `.buttonStyle(.plain)`, `.help("...")`, placed at the trailing edge of the row. Do not invent other delete glyphs (e.g. `minus.circle.fill`); check an existing list row (AlternateNamesSection, PantheonsSection, CitationListSection) before writing a new one.
- **Unit tests can't reproduce SwiftUI + SwiftData coexistence crashes** (no live `@Query` observation in MeCoreTests) — crash reports in `~/Library/Logs/DiagnosticReports/*.ips` are ground truth for those.
- **macOS 26 SDK rename**: `ModelConfiguration`'s autosave parameter is `allowsSave:` (was `isAutosaveEnabled:`).
- **Snap any Grid/frame dimension from a live drag to whole points** (`.rounded()`) — feeding SwiftUI `Grid` raw fractional `translation.width` causes subpixel pixel-alignment flip between frames on retina (the classic "jittery/jerky" resize).
- **A SwiftUI `.sheet` auto-tracks its content's ideal size**, fighting a manual `NSWindow.setFrame`. To resize the sheet to content (release-time fit or grow) without the window chasing the pointer mid-gesture: pin the content frame to a `@State` size that is **not** touched during the drag, then on release set **both** the SwiftUI content frame and the `NSWindow` frame from the **same clamped value** so the two can never disagree/undo each other (see `PopupTableView.fitHostWindowToTable`).

## Important Files

- `docs/QUALITY_RISKS.md` — **Read first, every session.** Standing quality tripwires with current baselines; the user is not told about these unless a tripwire moves, and a finding that stays in a doc has not been delivered.
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

## Debugging Data-Versus-View Mismatches

When a user reports that on-screen content is in the wrong order or doesn't match another view (e.g. a sidebar list vs. a timeline):

1. **Trace the exact view that displays the content** (which struct renders it, what sort/computed property it uses) *before* touching any data.
2. **A symptom like "sorted alphabetically" is a view-layer signature** — alphabetical order can only come from a name-based sort in the view (e.g. `FigureGroup.sortMode == .alphabetical`), not from the data. If the user reports alphabetical order, look for the view's sort mode first.
3. Verify the fix against the live store/app state (sqlite on the real `Me.store`, or the running app), and confirm the actual rendering path uses the corrected value — not just that the underlying data looks right.
4. Only fix data (orderIndex, missing rows, migrations) after the view layer is ruled out.
5. **When a fresh measurement contradicts a recorded baseline, suspect the measurement first.** Re-derive the recorded number before calling it stale — a mis-specified query returns a plausible number, not an error. (2026-09-27: `ZCITATION.ZENTITYTYPE` stores `'Figure'`, not `'figure'`. A case-wrong filter silently dropped every citation, reporting 2.2 linked rows per figure against a true 2.72, and would have "corrected" a good 2026-09-26 baseline into a wrong one. Always compare against the documented figures in `docs/QUALITY_RISKS.md` / `docs/SESSION_LOG.md` via `./scripts/quality-check.sh` before changing any recorded number.)

## Hard Constraints

- **NO reseeding.** Never run `--reseed`, never call `clearAll`, never destroy user data. All migrations must be additive only (check-by-name before creating). The user's existing database is sacred.

## Interaction Guidelines (from CONTRIBUTING.md)

- One change per request. Split large tasks into small steps.
- Validate JSON with `jq --exit-status . Sources/Resources/seed_data.json` before committing seed changes.
- Run `swift build` before submitting changes.
- Branch naming: `feat/`, `bugfix/`, `migration/` prefixes.
- Do not commit secrets, keys, or provisioning profiles.

