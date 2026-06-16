# TODO — Architecture Improvements

## 1. Eliminate dossier construction duplication ~~— DONE~~
**Files**: `Sources/Store/QueryEngine.swift:295`, `Sources/Views/EntityReportSheet.swift:137`

`buildFigureDossier`/`buildPlaceDossier`/`buildEventDossier` were duplicated nearly verbatim between the query engine and the entity report sheet.

**Resolution**: Moved dossier types (`FigureDossier`, `PlaceDossier`, `EventDossier`) and builder methods into a shared `ModelContext` extension in `Sources/Store/DossierBuilder.swift`. Both `QueryEngine` and `EntityReportSheet` now delegate to `context.build*Dossier()`.

---

## 2. Unify fetch pattern ~~— DONE~~
Some views use `@Query` (declarative, `FigureDetailView`), others used `try? modelContext.fetch(FetchDescriptor<T>())` with nil-coalescing to `[]`, silently swallowing errors.

**Resolution**: Added `ModelContext.fetchAll<T>() -> [T]` helper in `Sources/Extensions/ModelContextExtensions.swift`. Replaced all 21 ad-hoc fetch sites across 7 files with the single helper. `@Query` remains in use for reactive view data; `fetchAll()` is used for non-view code and dynamic lookups.

---

## 3. Replace string-based foreign keys in seed JSON ~~— DONE~~
Seed data cross-references entities by name (`fromFigureName`, `toFigureName`, `placeName`). Renaming a figure silently breaks relationships. No referential integrity between seed entities.

**Resolution**: Python script assigned deterministic UUID v5 (`uuid5("DNS", "EntityType:name")`) to every figure, place, event, era, and source. All 14 name-based FK fields replaced with `*Id` UUID references. SeedData.swift updated from name-keyed to UUID-keyed lookup dicts. JSON validated with `jq`.

---

## 4. Fix structural layout bug in EventDetailView ~~— DONE~~
**File**: `Sources/Views/EventDetailView.swift:~85-145`

The "Sources & Citations" section was placed inside the `ForEach(involvedFigures)` loop, rendering citations once per involved figure.

**Resolution**: Moved citations section after the Involved Figures `VStack`, outside the `ForEach`. Also moved the displaced `figureType.rawValue` label back into the figure row `HStack`.

---

## 5. Split overloaded import flow ~~— DONE~~
**File**: `Sources/Views/ImportView.swift:180`

`performImport` handled entity matching, Wikidata parsing, figure/place/event updates, relationship creation, source creation, and error handling in a single ~120-line method.

**Resolution**: Created `Sources/Store/ImportService.swift` with 9 extracted methods: `fetchWikidata`, `matchFigure`/`matchPlace`/`matchEvent`, `applyToFigure`/`applyToPlace`/`applyToEvent`, `createCitation`, and `createStandaloneSource`. `performImport` shrank to ~48 lines — a declarative pipeline: fetch Wikidata, fetch local entities, try figure/place/event match, fallback to standalone source.

---

## 6. Decouple hardcoded Wikidata QID mappings ~~— DONE~~
**File**: `Sources/Store/WikidataParser.swift`

QID → enum mappings were hardcoded switch tables across 5 methods (70+ lines).

**Resolution**: Created `Sources/Resources/wikidata_qids.json` with all QID-to-enum mappings in a flat array-per-value format. Created `Sources/Store/QIDMapper.swift` — a struct that loads the JSON at init and inverts it into QID-keyed lookup dictionaries. WikidataParser now accepts an optional `QIDMapper` parameter (defaults to `.load()`), replacing all 5 private switch-table methods.

---

## 7. Replace sidebar switch navigation ~~— DONE~~
**File**: `Sources/Views/ContentView.swift:75-104`

The `detail` body used a 12-case `switch selection { ... }`. Adding a screen required updating the enum, icon mapping, section mapping, *and* the switch body.

**Resolution**: Added `@ViewBuilder var destination: some View` on `NavigationItem` — each case dispatches to its own view. ContentView's detail block is now `selection?.destination` with a nil fallback. Adding a screen = add enum case + one line in `destination`. No separate switch to maintain.

---

## 8. Name the breadcrumb tuple type ~~— DONE~~
**Files**: `Sources/Views/FigureListView.swift`, `PlaceListView.swift`, `EventListView.swift`

The type `[(id: PersistentIdentifier, name: String)]` was repeated across multiple list views and `BreadcrumbBar`.

**Resolution**: Defined a `struct Breadcrumb: Identifiable` in `BreadcrumbBar.swift`. Updated the bar signature and all three list views to use `[Breadcrumb]`. No more anonymous tuple type leaking across files.
