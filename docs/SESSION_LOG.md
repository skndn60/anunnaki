# Anunnaki — Session Log

Chronological record of working sessions: context, changes made, key decisions, verification, files touched. **Newest first — append new entries at the top.**

AGENTS.md holds only durable reference material. When a lesson from an entry proves recurring, promote it into AGENTS.md's Coding Conventions instead of relying on this history being re-read.

Entries below were moved verbatim from AGENTS.md on 2026-08-22 (same pattern as the 2026-08-05 TODO split). Path references inside entries are historical and were intentionally left as written.

---

### 2026-09-26 — Custodianship failure: silent-save defect class never surfaced (274 sites)

**Context:** After the filter-field removal, the user asked me to rate the app, then pushed back that my rating leaned on dataset fill rate rather than the software. Re-rated on engineering terms, which surfaced 842 `try?` against 23 `do/catch`. The user's response: *at no point was I warned about this; if it is such a grave issue why was I not warned?* — followed by the operating instruction that I am the custodian of the documentation (they do not read it and only ask for review), and steer functional aspects only.

**Self-correction on the headline number:** 842 was the wrong figure to lead with and I should not have called it "grave" off a raw grep ratio. Breaking it down by operation: 274 `try? context/modelContext.save()`, 409 `try? …fetch`, ~61 `JSONDecoder`/`JSONSerialization`, ~80 FileManager/regex/encoder, 9 elsewhere. The 409 fetches degrade to `?? []` and are idiomatic, not defects — conflating recoverable reads with irreversible writes overstated the problem roughly threefold. The accurate, serious figure is **274 unchecked saves across 71 files**.

**Why it was never flagged — four concrete failures, not one:**
1. **Session logs are a narrative of the task at hand, not an audit of the tree.** Every entry records what the current session touched. A cross-cutting metric is nobody's task, so it was never nobody's finding.
2. **The one document whose stated job was this review retired while the gap was still open.** `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` covers relationship anti-patterns, migration burden, the `Relationship.source` ambiguity, width persistence, lineage complexity and cognitive load — and error handling is *absent from it*. It is now banner-marked "archival record of findings and resolutions" with every item ✅ resolved. The mechanism that should have produced this warning was closed out before it was ever asked the question.
3. **The lesson was learned at the site and never generalised.** `docs/SESSION_LOG.md` (2026-07-20) already records the real incident: three migrations silently failed to decode null non-optional strings *because* `try?` swallowed the error, and the fix was to temporarily add `do/catch` with a `print`. That is proof the defect class is live in this codebase, logged as a fact about one afternoon rather than raised as a class-level rule. Nobody ever asked how many other sites had the same shape.
4. **AGENTS.md had no error-handling convention at all.** The Coding Conventions are meticulous about macOS-focus quirks, `@Relationship` inverse mechanics, the `entityName` abort and migration safety — and completely silent on failure handling. I maintain those conventions; the omission was mine.

**Changes (documentation only — the code fix is the user's call):**
- **`AGENTS.md`** — new Coding Conventions bullet, *Never write a bare `try? context.save()`*, recording the 274/71 measurement, the 2026-07-20 precedent, the two-tier rule (MeCore/Store saves are commits: `do/catch` + `Logger`; view-layer saves acceptable only when paired with a visible state change), and an explicit instruction **not** to "fix" the 409 `fetch` sites.
- **`docs/TODO.md`** — new HIGH item splitting the work into Tier 1 (MeCore/Store, ~40 sites, no undo path) and Tier 2 (view layer, ~234 sites), proposing a `Migration.commit(_:_:)` helper so call sites stay one-liners, warning that blanket `try?`→`try!` is worse than the status quo, and requesting a lint so the count cannot regress.

**Standing lesson (this is the process failure, not the code one):** because the user does not read these documents, a finding that only exists in a doc is functionally *not delivered*. Audits must be run proactively and surfaced in-session, and any doc marked resolved/archival must have actually been asked the full set of questions. Closing a critique document is a claim, and this one was closed on incomplete evidence.

**Files:** `AGENTS.md`, `docs/TODO.md`, `docs/SESSION_LOG.md`.

---

### 2026-09-26 — Figure-detail filter field removed (unintended feature, no data value)

**Context:** The user asked what the "Filter relationships, places, events, names…" field at the top of the figure detail panel does, then said they did not remember putting it there. Provenance confirmed they were right: `git log -S` pins it to **`9a4a9ea`** (2026-07-22, *"Timeline swimlane fix, new views/models, query engine enhancements"*) — a 58-file, +4878-line kitchen-sink commit whose message covers era bars, timelines, five new models, a 403-line QueryEngine expansion and migrations, and never mentions a filter. The corresponding SESSION_LOG entry for that day covers only the post-flood era bars. The field arrived incidentally with a +460-line rewrite of `FigureDetailView`; the section views were extracted later in `105a43a`, carrying `filterText` in as a parameter. It was also the only content filter of its kind in the app — the search fields in `PlaceDetailView`/`EventDetailView` belong to link-picker popovers, not the detail panel.

**Why removed (measured on a read-only copy of the live store, 629 figures):** counting the rows it could filter (relationships + alternate names + places + events + citations) the average figure has **2.7**; **179 of 629 (28%) have zero**, making the field dead UI; only **30 figures exceed 10** rows and only **14 exceed 12** (2.2%). Only **9 figures have more than 10 relationships**. The one real beneficiary was a handful of hub figures — Enki's 35 relationships split 14 spouse / 14 father / 2 creator / 2 consort, so typing "father" genuinely narrowed it.

**Quirks this removed:**
- **Sticky across figures.** No host keys the view by identity (no `.id(...)` at any of the nine `FigureDetailView` call sites; `FigureListView` holds it in `if let figure = selectedFigure`), so `@State filterText` survived switching figures — type "father" in Enki, click a linked figure, and the next figure's lists were silently filtered too.
- **Sections vanished rather than emptying.** Relationships and Events hid entirely on no-match, while Places and Also Known As kept a heading over an empty body because their emptiness guards checked the *unfiltered* array — so the same query produced two different-looking pages.
- **The mini lineage tree ignored the filter**, receiving `matchingRelationships` rather than the filtered set, so rows disappeared while the tree above still drew all of them.
- Single substring match with no tokenizing (`"father enki"` matched nothing), and a placeholder that omitted citations entirely.

**Changes:** `FigureDetailView` — removed the field, its `HStack` chrome, `matchesFilter`, and the `filterText` argument at all four section call sites; `filteredRelationships` → `sortedRelationships` (filter dropped, the type-prefix + name sort kept, since that grouping is what makes a 35-row list scannable). `AlternateNamesSection` (`sortedAlternateNames`), `PlacesSection`, `EventsSection`, `CitationsSection` — dropped the `filterText` property, `matchesFilter` and the filtered collections, each with exactly one call site. `CitationsSection`'s empty state reworded from "No matching citations found" to "No citations yet" and its `if/else` re-indented (it had been left misaligned by an earlier edit). Pure view-layer deletion: no model, migration or seed change, and the store was never written. The separate `filterText` fields in `TagCloudView` and `AssociationsView` are different screens and were left alone.

**Accepted trade-off:** Enki, Samyaza and An (35/29/25 relationship rows) are now fully expanded with no way to narrow them, mitigated by the existing type-prefix sort. If that proves annoying, the cheaper follow-up is type sub-grouping or `.searchable` on that one section — not a whole-panel filter.

**Verification:** `grep` confirms no `filterText`/`matchesFilter` references remain in the five touched files. `swift build` clean. `swift test` 618 passed, 0 failures. Runtime check still owed from the user: Enki (worst case, 35 relationships), a figure with no linked rows (empty states should read correctly, not blank), and a figure with citations.

**Files:** `Sources/Me/Views/FigureDetailView.swift`, `Sources/Me/Views/AlternateNamesSection.swift`, `Sources/Me/Views/PlacesSection.swift`, `Sources/Me/Views/EventsSection.swift`, `Sources/Me/Views/CitationsSection.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-25 — macOS 27: arrow-key selection restored across all lists

**Context:** On macOS 27 the user lost Up/Down arrow-key navigation in every list view (figures, places, events, sources, … *and* the sidebar). Diagnosis via targeted questions: both the sidebar and detail lists were affected, and clicking a row did **not** help — so the regression is that a SwiftUI `List(selection:)` no longer takes keyboard focus at all (the click selects a row but never makes the list first responder), leaving arrow keys with nowhere to go. This is distinct from the 2026-08-07 keyboard work, which was about a `ScrollView` replacement, not an OS change.

**Changes:**
- **New `Sources/Me/Views/ListArrowKeyNavigation.swift`** — reusable `listArrowKeyNavigation(selection:orderedIDs:)` modifier: `.focusable()` puts the list back in the key view loop, `.focusEffectDisabled()` suppresses the focus ring that made the earlier `.focusable()`/`.focused()` attempt unacceptable, `.focused(...)` + `.onAppear` focuses it on appear, and `onKeyPress(.upArrow/.downArrow)` moves `selection` through `orderedIDs` (rows in on-screen order) as a fallback if native handling is gone.
- Applied to the sidebar (`ContentView`) and the selectable detail lists: `FigureListView`, `PlaceListView`, `EventListView`, `SourceListView`, `ThingListView`, `SumerianKingListView`, `FigureGroupListView`, `AlternateNameListView`, `DictionaryListView`.
- `ContentView.swift` — sidebar loses its `.focusable(false)`; new `sidebarOrderedSelections` mirrors the sidebar's section/group order (subgroup children included only while expanded) so arrow navigation can walk it. The "Dynasties" disclosure gained tracked state (`dynastiesSidebarExpanded`) so its children are included in the order only when visible.

**Key decisions:** Native arrow handling on a focused `List` was assumed to be the causal path, so the fix restores focus first and only supplies explicit `onKeyPress` movement as a safety net (native consumption, when it happens, pre-empts the fallback rather than double-moving). `focusEffectDisabled()` is the missing piece versus the rejected 2026-08-07 approach.

**Verification:** `swift build` clean; `swift test` 618 passed, 0 failures. **Runtime confirmed by the user:** arrow keys work again in both the sidebar and the detail lists.

**Files:** `Sources/Me/Views/ListArrowKeyNavigation.swift` (new), `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/FigureListView.swift`, `Sources/Me/Views/PlaceListView.swift`, `Sources/Me/Views/EventListView.swift`, `Sources/Me/Views/SourceListView.swift`, `Sources/Me/Views/ThingListView.swift`, `Sources/Me/Views/SumerianKingListView.swift`, `Sources/Me/Views/FigureGroupListView.swift`, `Sources/Me/Views/AlternateNameListView.swift`, `Sources/Me/Views/DictionaryListView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-25 — First Dynasty of Babylon added as first-class data

**Context:** The database modelled the SKL dynasties but had no first-class entity for Babylon's First Dynasty: rulers (Sumu-abum → Samsu-ditana) existed as stray Human figures (some only in the live store), tagged to the flat "Old Babylonian Period", with no dynasty era/group, and every Human figure had an auto-generated SKL citation. Scope was narrowed to Sumerian/Mesopotamian dynasties; the immediate target was the Amorite First Dynasty of Babylon, with Lagash/Sealand/Kassite deferred.

**Changes:**
- **New `Sources/MeCore/Store/Migration+FirstBabylonianDynasty.swift`** — `ensureFirstBabylonianDynasty(context:)`, additive + idempotent:
  - Creates/reuses `Era "First Dynasty of Babylon"` (lane 31, c. −1894…−1595) and fills blank fields only.
  - Roster of the eleven BKL rulers (Hammurabi is **sixth**, not fourth) matched to existing figures by `NameDuplicateCheck.normalizedKey`, so spelling variants ("Sin-muballit" vs "Sin-Muballit") don't duplicate. Missing rulers (Sabium, Apil-Sin, Ammisaduqa) are created as Human figures with Middle Chronology reign spans written through `Figure.updateKingship`.
  - Moves a ruler to the new era only when its birth-era string is empty, "Old Babylonian Period", or already the dynasty; a ruler the user filed under a custom era is left alone (the birth/death era strings move with the relationship so `ensureFigureEraLinks` can't revert it).
  - Creates `Source "Babylonian King List A"` (`.kingList`) for succession/lineage and `Source "The Ancient Near East"` (Kuhrt, `.scholarlyWork`) for the conventional absolute dates; deduped figure citations plus one era citation.
  - Adds the ten father→son `Relationship`s attested by the king list, via `RelationshipManager.addRelationship` on the annotated side.
- **`Sources/Me/Views/SeedRunner.swift`** — calls the migration early (after `ensureParentRelationshipsExist`, before `fixEraOrderIndices`) so the new lane is pinned in the same launch and the figures exist before `ensureCollectiveMembers`.
- **`Sources/MeCore/Store/Migration+EraChronology.swift`** — `fixEraOrderIndices`: inserts `First Dynasty of Babylon` at 31 and shifts Old Assyrian→32 … Sassanid→47.
- **`Sources/MeCore/Store/Migration+OraccEpisodes.swift`** / **`Migration+TimelineMacroEras.swift`** — historical era configs 32–34 and macro configs 35–47 (so a fresh store doesn't collide before the order fixer runs). Corrected the Old Babylonian description to credit Sumu-abum as founder.
- **`Sources/MeCore/Store/Migration+SKLAndGenealogy.swift`** — `enrichSKLData` step 4 now backfills SKL citations only for Humans whose era is inside the SKL block (< lane 31); figures in the new dynasty (and later periods) no longer inherit a false "Sumerian King List" citation.
- **`Sources/MeCore/Store/Migration+DynastyBoundaries.swift`** — added the authored territory ring for `"first dynasty of babylon"` (core Babylonia: Sippar/Kish/Nippur in the north through Isin/Uruk/Larsa/Ur in the south, Babylon inside), so `ensureDynastyBoundaries` backfills `Era.boundaryGeoJSON` on the next launch.
- **Tests** — seven new focused tests in `Tests/MeCoreTests/MeCoreTests+Migration.swift` (roster/era/sources/lineage, idempotency, spelling-variant match + user-data preservation, lane pinning/shift, no SKL citation for non-SKL kings, dynasty subgroup, territory boundary contains Babylon); updated `timelineMacroEraConfigs` lanes and the historical-era lane assertions in `MeCoreTests+ConsistencyTags.swift`.

**Key decisions:** No schema change — the existing `Era` + auto `FigureGroup` machinery carries the dynasty, and `ensureDynastyGroups` builds the mixed subgroup from the new era. Absolute dates use the Middle Chronology and are labelled approximate; the king list supplies succession, not absolute years. Existing (incorrect) live SKL citations are left in place per the additive-only rule — the correct BKL/Kuhrt citations are added alongside; a separate cleanup can remove them if the user wants.

**Verification:** `swift build` clean; `swift test` 618 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+FirstBabylonianDynasty.swift` (new), `Sources/Me/Views/SeedRunner.swift`, `Sources/MeCore/Store/Migration+EraChronology.swift`, `Sources/MeCore/Store/Migration+OraccEpisodes.swift`, `Sources/MeCore/Store/Migration+TimelineMacroEras.swift`, `Sources/MeCore/Store/Migration+SKLAndGenealogy.swift`, `Sources/MeCore/Store/Migration+DynastyBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Migration.swift`, `Tests/MeCoreTests/MeCoreTests+ConsistencyTags.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-24 — Retire era-territory Place records (map de-clutter)

**Context:** User noticed "Late Bronze Age Collapse" in the Places list — an era-shadow that felt like an event, not a place — and reported the map cluttered with "regions here, there and everywhere." Root cause: `Migration.ensureEraTerritoryPlaces` (drawn from `eraTerritoryPlaces`, added with the dynasty-boundary work) auto-created a **Place** for every non-SKL macro-era that had an authored territory ring ("Old Assyrian Kingdom", "Mitanni", "Karduniaš", "Neo-Assyrian Empire", "Late Bronze Age Collapse", "Roman Mesopotamia", … — 16 in all, none in the seed). Each drew its huge polygon in the Region/Kingdom layer AND a labeled pin at its anchor — on top of the same ring already drawn by the atlas's "Dynasties" layer from `Era.boundaryGeoJSON`. The dynasty maps (`SumerianDynastyMapView`/`DynastyEvolutionMapView`/`GroupEraMapView`) never read these Places — they all use `era.boundaryGeoJSON` directly.

**Decision (user-approved):** Stop creating them + delete the existing artifacts. The eras always keep their rings. Only the deferred auto-created records go.

**Changes:**
- `Sources/MeCore/Store/Migration+DynastyBoundaries.swift` — replaced `ensureEraTerritoryPlaces(context:)` with `removeEraTerritoryPlaces(context:)`: deletes only records whose name matches a retired artifact AND whose description has the migration's exact `"<era.name> territory"` signature (era resolved via normalized key), so a user-authored place sharing a name (e.g. a hand-made "Mitanni") is never touched. `eraTerritoryPlaces` doc comment updated to its new role as the canonical retired-artifact list.
- `Sources/Me/Views/SeedRunner.swift` — the chain now calls `removeEraTerritoryPlaces` in place of `ensureEraTerritoryPlaces`.
- `Tests/MeCoreTests/MeCoreTests+Groups.swift` — replaced `testEnsureEraTerritoryPlacesCreatesRegionPlaces` with `testRemoveEraTerritoryPlacesRemovesOnlyArtifacts` + `testRemoveEraTerritoryPlacesLeavesNonArtifactPlacesAlone`, asserting all 16 artifacts are removed while a same-named user place is preserved.

**Verification:** `swift build` clean; targeted filter run plus full `swift test` — 611 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+DynastyBoundaries.swift`, `Sources/Me/Views/SeedRunner.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-22 — Splash review + hardening (borderless app-delegate panel)

**Context:** User asked for a review of the shipped startup splash (borderless 350×300 app-delegate `NSWindow`, `SplashScreenView` + `SeedRunner`). The working tree holds the *borderless hide/reveal* design — this contradicts the entry directly below, which claims a full-screen "veil/cover" rewrite landed and that `hideNonSplashWindows`, `mainWindow`, the `didUpdate` observer and `--autodismiss-splash` were "all gone." None of that full-screen code exists (`presentVeil`, `veilWindows`, `autosavedMainWindowFrame` are absent), so treat that entry as not-landed until reconciled.

**Changes:**
- `Sources/Me/AnunnakiApp.swift`:
  - Removed the `logProbe` diagnostic (`/tmp/me_visprobe.txt`) and the two log-only `NSWindowDidBecomeKey/Main` observers.
  - `hideNonSplashWindows()` now prefers a window matching `isMainContentWindow` (an `NSHostingController<ContentView>` or title `"Me"`) when capturing the main window, keeping the first-visible fallback so a capture is always guaranteed (a nil `mainWindow` would strand the hidden main window).
  - `finishSplash()` falls back to `NSApp.windows.first(where: isMainContentWindow)` when no main window was captured.
  - `--autodismiss-splash` gated behind `#if DEBUG`.
  - Splash panel: dropped `isMovableByWindowBackground`; set `isOpaque = true` and `backgroundColor` to the splash blue so no default (light) window background can show through during first layout. (A `collectionBehavior` change was tried and reverted — see below.)
- `Sources/Me/Views/SplashScreenView.swift`: minimum 0.6s display so an already-seeded launch doesn't flash; "Seeding database" → "Preparing database"; the ready state is now a `Button` (`.keyboardShortcut(.defaultAction)`) plus `.onExitCommand` for Esc, so dismissal is keyboard/VoiceOver accessible rather than tap-only.
- **Main-window flash diagnosed and fixed (pre-existing, not a review regression).** User reported the main window flashing just before the splash. A `CGWindowList` probe (rebuilt `winwatch`, now printing `kCGWindowAlpha`) showed the big main window (`Me[L0] 1475×1297`) and the small splash (`Me[L3] 350×300`) appearing in the *same* sample and coexisting for ~400 ms before `hideNonSplashWindows`'s `orderOut` finally landed — while SwiftUI was still creating/activating the main window and re-showing it. The pre-change run `winwatch11.out` shows the identical pattern, confirming it long predates this review; the small splash simply cannot cover the much larger main window. Fix: `hideNonSplashWindows()` now sets `window.alphaValue = 0` (which SwiftUI's re-show cannot undo) in addition to `orderOut`, is invoked synchronously in `presentSplashScreen` before the splash is ordered front, and `finishSplash()` restores `alphaValue = 1` on every zeroed window by matching the captured (or identified) main window. Probe after the fix: only `Me[L3,a1.00]` present for the splash's lifetime, `Me[L0]` absent, then `Me[L0,a1.00]` returns at its saved size the instant the splash closes.
- Also reverted a cosmetic `.frame(width: 350, height: 300)` and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` change while isolating the flash; the window stays pinned by `sizingOptions = []` + `setContentSize`, and its `backgroundColor` is the splash blue so no default light background can peek through.

**Key decision — `applicationShouldHandleReopen` was correct as written.** The review initially flagged `return isSplashDone` as inverted; Apple's docs settle it: returning **true** = "proceed as normal", **false** = "do nothing". Suppressing reopen during the splash (false) and allowing normal reactivation after (true) is exactly the intent. Left unchanged.

**Verification:** `swift build` clean; `swift test` 610 passed, 0 failures. Not headless-launched this session.

**Files:** `Sources/Me/AnunnakiApp.swift`, `Sources/Me/Views/SplashScreenView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-22 — Startup flash fix (full-screen veil) + seeding-slowness diagnosis

**Context:** After the splash work, the user saw the big main window flash on screen for ~0.4s just before the splash appeared. CGWindowList traces (`winwatch`, a temp poller in the opencode scratch dir) showed the main window on-screen from **t=21ms**, before `applicationDidFinishLaunching`, with the splash arriving ~469ms and hiding only possible at first idle ~916ms — the main thread is blocked during SwiftUI bootstrap, so no observer can preempt the window's initial display.

**Changes:**
- `Sources/Me/AnunnakiApp.swift` — `ApplicationDelegate` gained `presentVeil()`: called from `applicationWillFinishLaunching`, creates one full-screen borderless `.floating` NSWindow per `NSScreen.screens` entry, dark-blue (same 0.07/0.14/0.32 theme), `collectionBehavior = [.canJoinAllSpaces]`, `orderFrontRegardless()`, retained in `veilWindows`. The splash (same level, ordered later) sits above it. `finishSplash()` orderOuts and clears `veilWindows` before revealing the main window.

**Diagnosis:** An in-process file-based `diag()` timeline showed the full launch sequence without any hang; the main thread was not deadlocked. A `sample` of the process pinned the 2–4s stall to `runSeeding` → `Migration.ensureEventCitations` (Migration+EraChronology.swift:398): a `contains(where:)` over Citations faulting `Citation.linkedEntityName` per element on the main thread. The queued `hideMainWindowUntilSplashDone` sweep just runs late — expected backward-burn, not a bug. Longer cold-launch seeding also explains the initial "main window visible during splash" symptom: the main thread is blocked through the whole migration, so the hiding sweep and the `didUpdate` observer cannot fire until seeding completes.

**Second follow-up (same day, user: "utter mess"):** two user-reported failures on the veil attempts — (1) solid blue wall after the main window opened, (2) the main window never appearing. Both traced to structural flaws in the veil/hide/reveal machinery; the architecture was scrapped. Final design is the standard **full-screen splash window** (created in `applicationDidFinishLaunching`; the whole screen is the splash content — logo + title centered, status + click-to-continue pinned bottom; opaque, `.floating`, dark blue) that Covers the real main window from frame one; `finishSplash()` just orderOuts it. The main window is never hidden, never re-framed, never captured — it keeps its autosaved size untouched. Two hard-won lessons made this stick:
- **NEVER create/order ANY NSWindow in `applicationWillFinishLaunching`** — an empty 350×300 borderless window (_or_ a hosting window, or a veil) ordered there suppresses SwiftUI WindowGroup's main-window creation entirely (it simply never enters `NSApp.windows`; verified headless + real world). Register observers there if needed, but create no windows. Observers/window-visible callbacks also proved unreliable for hiding the big window (the window is created mid-bootstrap before the observers the app can install, and `didUpdateNotification` doesn't fire while the main thread is in seeding). Covering, not hiding, is the robust strategy.
- **Move seeding off the main thread.** `runSeeding` (now `SeedRunner`, a new `Sources/Me/Views/SeedRunner.swift`) runs the ~100-migration chain on a `DispatchQueue(label: "me.seed", qos: .userInitiated)` with its own background `ModelContext(container)`, keeping the main thread free: the UI stays responsive, the spinner animates, the click-to-continue lands, and no accelerator-timing machinery is needed. All `Migration.*`/`SeedData.*` funcs are nonisolated `package static func(context:)`, and the 610 test-suite already exercised them off the main thread, so this is safe.
- `hideMainWindowUntilSplashDone`, the `didUpdate` observer, `mainWindow` capture, `autosavedMainWindowFrame()`, the veil array, and the `--autodismiss-splash` hook are all gone. `applicationDidFinishLaunching` = watchdog + icon + activate + full-screen splash; `finishSplash` = orderOut splash + activate.

**Verification:** headless CGWindowList run with a temporary auto-dismiss: `splash+main` state (full-screen 2560×1440 L3 splash covering the 1473×1295 L0 main window) from first sample → transition to `main-only` (1473×1295) the instant the splash closes; the main window was never absent nor re-sized. `swift build` clean, `swift test` 610 passed, 0 failures. Remaining known trade-offs: the whole display is covered (menu bar hidden) while the splash is up — that IS the splash; and a ~300–400 ms window early in bootstrap exists where the main window may appear before the full-screen splash mounts (acceptable; closing it would require window creation in `applicationWillFinishLaunching`, which breaks window creation — see the lesson above).

**Note for the user:** the blue screen at launch is now the splash itself (logo + "Seeding database…" + click-to-continue), and the main window appears only when you click, at its saved size.

---

### 2026-09-22 — Launch splash screen (borderless 350×300 NSWindow owned by AppDelegate)

**Context:** At launch the app's big main window showed immediately and seeding finished behind it (~1s), often with a "Seeding database…" progress view that completed almost instantly. User asked for a proper startup splash: small borderless 350×300 window showing "Seeding database, please wait…" while seeding runs, then "Initialisation complete. Click to continue", click dismisses and reveals the main app window.

**Changes:**
- `Sources/Me/Views/SplashScreenView.swift` — NEW. Dark-blue splash UI (logo 150×150 centered, title, status message pinned low) plus `runSeeding(context:)` — the full migration/seed block moved verbatim out of `ContentView` (Theme: `Color(red: 0.07, green: 0.14, blue: 0.32)`, white text). Root view is a FIXED `.frame(width: 350, height: 300)` so the hosting controller's ideal size can never distort the window. Tap dismisses only when seeding finished (`onContinue` closure).
- `Sources/Me/AnunnakiApp.swift` — `AppDelegate` now owns the splash: `presentSplashScreen()` builds a borderless `.floating` NSWindow (350×300, `isMovableByWindowBackground`, `NSHostingController` with `sizingOptions = []`), hosts the splash on `MeApp.sharedContainer.mainContext`, `.orderFrontRegardless()`. `hideMainWindowUntilSplashDone()` hides every visible non-splash window (grabbing the main window reference) — driven by an `NSApplication.didUpdateNotification` observer (AppKit has no `NSWindow.didBecomeVisibleNotification`) plus one initial `.async` sweep. `finishSplash()` removes the observer, closes the panel, reveals the stored main window.
- `Sources/Me/Views/ContentView.swift` — removed the old in-window splash machinery: `hasSeededThisLaunch`, `isSeeding`, `splashDismissed`, `selfWindow`, `launchFrame`, `splashView`, `appLogo`, `splashStatus`, `configureSplashWindow`, `configureMainWindow`, `SplashWindowConfig`. `body` is now just the login/main gate; skipLogin auto-select stays in the root `.task`.

**Key decisions:**
- The earlier main-window-injection approach failed structurally: seeding runs synchronously on the main actor, starving deferred (main-queue) window restyling, so the titled window stayed fully visible and the `.task` kept restarting. Separate app-delegate-owned borderless panel is the established pattern: it is on screen from the first frame and the main window stays hidden until seeding completes.
- `NSHostingController`'s default `sizingOptions` resizes a borderless window to the content's ideal size (observed: 350×348 and 150×348). Two-part fix: `sizingOptions = []` AND a fixed 350×300 SwiftUI frame — the frame is required because `.frame(maxWidth:.infinity, maxHeight:.infinity)` reports an ideal height larger than 300, which still widened the window by 48pt even with sizing disabled.

**Verification:** `swift build` clean. Headless launch runs confirmed: only the 350×300 splash visible (main "Me" window hidden), seeding completes, click → splash closes and main window revealed (a temporary `--autodismiss-splash` hook exercised the real `onContinue → finishSplash` path, then removed). `swift test` 610 passed, 0 failures.

Same-day follow-up: user reported the revealed main window was tiny (~815×348). Root cause: our very-early `orderOut` in `hideMainWindowUntilSplashDone` fires during SwiftUI's window-creation/reveal race, and AppKit's `NSWindow Frame Me.ContentView-1-AppWindow-1` autosave (user's real window: ~1506×1185 on a 2560×1410 screen) is never re-applied by SwiftUI on our `makeKeyAndOrderFront`. Fix: in `finishSplash`, deterministically restore the autosaved frame via `autosavedMainWindowFrame()` — parses the `UserDefaults` "NSWindow Frame …" string, matches the saved screen record (falling back to `NSScreen.main` when the saved screen size is stale — observed 1410 saved vs 1440 actual), converts the top-left-origin record into an AppKit bottom-left rect, and sanity-clamps to 800…6000×600…6000 before `setFrame(display: false)`. Verified reveal at 1473×1295, close to the user's pre-splash setting. If the autosave key ever changes the restore silently no-ops and the window opens at the WindowGroup `.defaultSize(width: 1200, height: 800)` — acceptable degradation. Clean `swift build`, crash-free launch, 610 tests pass. (Also discovered en route: `NSScreen.screens.first` frame-width/height must be compared against the *saved* screen record — a strict match silently fails when the display resolution changed between sessions.)

---

**Context:** Continuing the 2026-09-19 macro-period work (`orderIndex` 31–46), the 16 historical eras had been imported but had no territory: `Era.boundaryGeoJSON` was nil (the `Dynasties` atlas overlay draws nothing for them) and `ensureDynastyGroups` deliberately skips them (not dynasty-named, outside the SKL block), so they inherited no group silhouette either. Two-part ask: (1) author territory rings so the eras render on the map, (2) create `Place` records for the territories so they appear in Atlas/Places with the silhouette.

**Changes:**
- `Migration+DynastyBoundaries.swift` — restored/re-added the 16 authored `dynastyBoundaryRings` entries covering the historical eras: Old Assyrian Period, Old Babylonian Period, Neo-Assyrian Period, Uruk Period, Jemdet Nasr Period, Mitanni, Karduniaš (Kassite Babylonia), Middle Assyrian Period, Late Bronze Age Collapse, Neo-Babylonian Empire, Achaemenid Empire, Macedonian Empire, Seleucid Empire, Parthian Empire, Roman and Byzantine Mesopotamia, Sassanid Empire. `ensureDynastyBoundaries` backfills `era.boundaryGeoJSON` on next launch (additive, gated on missing/degenerate only, never overwrites).
- `Migration+DynastyBoundaries.swift` — NEW `eraTerritoryPlaces` seed + `ensureEraTerritoryPlaces(context:)`: for each era with an authored ring, create (if absent) a territory `Place` ("Old Assyrian Kingdom", "Mitanni", "Karduniaš", "Neo-Assyrian Empire", …) typed Region or Kingdom (created on demand), anchored at a capital/modern coordinate with a modern-location string, and given the same authored ring as its stored boundary. Same never-overwrite guard as `ensurePlaceBoundaries`.
- `ContentView.swift` — wired `ensureEraTerritoryPlaces` right after `ensureDynastyBoundaries`.
- `MeCoreTests+Groups.swift` — NEW `testEnsureEraTerritoryPlacesCreatesRegionPlaces` (all 16 places created, each with a closed Polygon stored boundary + anchor coords), `testEnsureDynastyBoundariesBackfillsHistoricalEras` (16 eras get boundaries, always closed), `testEnsureDynastyBoundariesContainsHistoricalCapitals` (Assur/Babylon/Nineveh/Uruk/Washukanni/Susa/Ctesiphon/Nisibis etc. all fall inside their era ring).

**Key decisions:**
- Territory rings keyed by normalized era name so era backfill and place creation share one source of truth (`dynastyBoundaryRings`).
- Places get a *stored* boundary (not group inheritance) — matching `ensurePlaceBoundaries` precedent for region places, since these eras have no dynasty groups to inherit from.
- Ring ≤ orderIndex 30 (SKL dynasties) was already present; only the 16 non-SKL eras were re-authored. Middle Assyrian ring initially failed its capital-containment test (Assur sat just south of the ring's bottom edge at 35.46°N) — south edge lowered from ~35.20 to ~35.15°N to enclose Assur.

**Verification:** live `Me.store` confirms all 16 eras exist at `orderIndex` 31–46 with names that normalize exactly to the ring/place keys (including the `š` in Karduniaš). `swift build` clean; `swift test` 610 passed, 0 failures (12 new present in the +Groups suite). Purely additive — no existing era/place boundaries touched.

---

### 2026-09-19 — Variant reign lengths (ReignVersion): SKL manuscript copies and the Ur-Isin king list

**Context:** The user reported encountering kings with two or more competing reign figures and asked whether the app can model them. It could not: `Figure` carries a single `reignYears` plus a single `reignStartYear`/`reignEndYear` span, `ReignLength.parse` takes only the first prose match, and every alternative lived as free-text inside `figureDescription` — invisible to queries, the timeline, and the date propagator. Documented instances in the seed: Kullassina-bel "960 years (or 900 in some copies)", Etana "1,500 years (some copies read 635)", and three SKL-vs-Ur-Isin splits (Bur-Suen 21 vs 22, Iter-pisha 4 vs 3, Ur-du-kuga 4 vs 3). A second axis exists beyond durations: competing chronological spans between chronology editions (e.g. Middle vs Short) that the scalar span columns cannot express either. User approved building it.

**Decision:** Add a `ReignVersion` `@Model` child of `Figure` (migration-safe optional to-many, `.cascade`). Each row = `years` (variant duration) and/or `startYear`/`endYear` (variant span) + free-text `tradition` (attribution, display-only) + `note` + `isApproximate`. The canonical scalars stay untouched so `SKLDatePropagator`, aggregations, and the `Kingship` accessor never change semantics. Backfilled additively by `Migration.ensureReignVersionBackfill` for the five documented kings (check-by-figure via `DuplicateMerger.normalizationKey`, dedupe on `(years, tradition)`). Note the seed's figure for the Isin king is named **Bur-Suen** (not the macron form Būr-Sîn from the prose), so the config targets the stored name.

**Changes:**
- `Sources/MeCore/Models/ReignVersion.swift` — NEW `@Model`; `displayLabel` mirrors `Kingship.reignSpanLabel`'s BCE styling ("900 years (Some copies of the Sumerian King List)" / "1728–1686 BCE (Short chronology)").
- `Figure.swift` — `@Relationship(deleteRule: .cascade, inverse: \ReignVersion.figure) reignVersions: [ReignVersion] = []` + `sortedReignVersions` (duration rows by years first, then span rows by start year).
- `Sources/MeCore/Store/Migration+ReignVersions.swift` — NEW `Migration.ensureReignVersionBackfill(context:)`: 5 configs, only applies when the normalized figure name exists and no `(years, tradition)` row already present; saves once if anything was created.
- `ContentView.swift` — wired `ensureReignVersionBackfill` right after `ensureReignYears`.
- Schemas: `ReignVersion.self` registered in `MeApp.sharedContainer` and the test container.
- `FigureDetailView.swift` — "Variant Reigns" detail section listing `displayLabel` + note when present.
- `FigureFormView.swift` — Reign step gains a "Variant Reigns" editor (add/remove/edit drafts, `ReignVariantDraft` tracks its `original` model); `syncReignVariants(for:)` reconciles drafts against stored rows on save in both create and edit paths (update kept, delete removed, create new).
- Tests: round-trip + cascade delete, `sortedReignVersions` ordering, `displayLabel` cases; migration creates all 5 with correct years/traditions, idempotent, skips unknown figures, does not duplicate a matching user-entered variant.

**Verification:** `swift build` clean (pre-existing unrelated warnings only); `swift test` 607 passed, 0 failures (7 new, up from 600). Purely additive — no scalar reign field behavior or seeding changed.

Same-day follow-up: the variant editor originally exposed only the duration field. Asked whether variants could be entered as a start/end-year span (the model's second axis), the form's Reign step now shows Duration + Start Year + End Year per variant row; `ReignVariantDraft` gained `startYearText`/`endYearText` and `syncReignVariants` round-trips them (empty text → nil) for both created and edited rows. `displayLabel` renders a span variant as "1728–1686 BCE (Short chronology)". `swift build` clean.

Second follow-up (same day): user called the variant layout messy — the first pass packed three label-less boxes (Duration/Start/End) plus the remove glyph elbow-to-elbow in one HStack under a grouped form. Extracted the row into a `ReignVariantRow` subview: each variant is now a vertical stack with a caption header ("Variant N" + a trailing remove button) above five aligned `LabeledContent` rows (Duration / Start Year / End Year / Tradition / Note) and a `Divider` between rows — the standard grouped-form look. `variantDrafts` index for the caption derived via `firstIndex` inside the bindings-based `ForEach($variantDrafts)` (no index-based iteration, so add/remove stays animation/id-stable). `swift build` clean.

Third follow-up (same day): two more form complaints — (1) the delete affordance was a red circle "traffic-light" `minus.circle.fill` next to the variant title; replaced with the app's standard small red trash (`Image(systemName: "trash")`, `.font(.system(size: 10))`, `.foregroundStyle(.red.opacity(0.7))`, `.buttonStyle(.plain)`) used consistently across AlternateNames/Pantheons/Sections. (2) The sample numbers ("900", "-1700", "1,600") and example phrases rendered OUTSIDE the fields: the strings were being passed as the TextField *title* parameter, which macOS promotes to a visible label rather than an in-field placeholder when the field sits inside a `LabeledContent`. Switched to `TextField("", text:prompt:)` so the sample data now renders only as in-field placeholders. `swift build` clean.

---

### 2026-09-19 — Mesopotamian macro-period eras from the Wikipedia timeline

**Context:** The user asked whether the *Timeline of Mesopotamia* Wikipedia template (https://en.wikipedia.org/wiki/Template:Timeline_of_Mesopotamia) could feed the app's `Era` entities. It is a clean structured table — each band is a `(date-range, region(s), name)` row, already read from the raw wikitext. Cross-checking the 19 bands against the store: the Uruk/Jemdet Nasr/Early Dynastic split, the SKL doctrine eras (Dynasty of Akkad, Gutian rule, Third Dynasty of Ur, etc.), and the three historical period labels (Old Assyrian 31 / Old Babylonian 32 / Neo-Assyrian 33) were all present; the genuinely new macro-periods were the second-millennium northern powers and the first-millennium+ imperial sequence. User approved adding them.

**Decision:** Add 13 macro-eras as lanes 34–46 (skipping the SKL/historical eras already present): Uruk Period (34), Jemdet Nasr Period (35), Mitanni (36), Karduniaš (Kassite Babylonia) (37), Middle Assyrian Period (38), Late Bronze Age Collapse (39), Neo-Babylonian Empire (40), Achaemenid Empire (41), Macedonian Empire (42), Seleucid Empire (43), Parthian Empire (44, −129→224 CE), Roman and Byzantine Mesopotamia (45, −63→700 CE), Sassanid Empire (46, 224–651). Ranges follow the template's bands (Sassanid trimmed from "mid-700s" to the historical 651 fall). Appended after the existing periods per the established convention (no renumbering of seed lanes). Checklist before writing:
- No name collisions in `seed_data.json` or migration-created eras.
- No test asserts a global era count.
- `TimelinePostView` renders only eras *with figures* (`postFloodErasWithFigures`), so the new empty eras don't widen the BCE window or inject swimlanes; `DynastyEvolutionMapView` iterates `DynastyRun`s (eras with boundaries), `MesopotamiaMapView` filters `boundaryGeoJSON != nil` — all safe.
- Era date display quirk noted: `MythologicalDate.displayLabel` mislabels BCE→CE spans (e.g. Parthian −129…224 shows "~129 – 224 BCE") — pre-existing, endpoint points only, not touched.
- `fixEraOrderIndices`'s catch-all bumps any *unlisted* post-flood era by +1 on every launch, so every new name is registered in its name map at the canonical lane — otherwise these lanes would drift +1/launch.

**Changes:**
- `Sources/MeCore/Store/Migration+TimelineMacroEras.swift` — NEW `Migration.ensureTimelineMacroEras(context:)`: check-by-name creation (via `NameDuplicateCheck.normalizedKey`), 13 configs with date bands and one-line descriptions, inserts only absent names, saves once if any created.
- `Migration+EraChronology.swift` — `fixEraOrderIndices` newOrder map gains the 13 names at lanes 34–46 so the catch-all can never drift them.
- `ContentView.swift` — wired `Migration.ensureTimelineMacroEras` right after `ensureHistoricalPeriodEras` in the launch migration sequence.
- Tests in `MeCoreTests+Migration.swift`: all-13-created-with-lanes/dates/descriptions, idempotency (second run adds none), a pre-existing same-name era is left untouched (lanes/data preserved), and two consecutive `fixEraOrderIndices` runs pin lanes (no drift).

**Verification:** `swift build` clean; `swift test` 600 passed, 0 failures (4 new tests, up from 596). Additive only — no existing era modified, no re-sequencing of user data; the new eras become available to the era pickers (Figure/Event/MythologicalDate) immediately.

Same-day follow-up: the newly visible crossing spans exposed the pre-existing `MythologicalDate.displayLabel` range bug — a BCE→CE range (e.g. Parthian −129…224 CE) rendered as "~129 – 224 BCE" with a single BCE suffix. Fixed in `MythologicalDate.swift`: crossing ranges now label each endpoint with its own era sign ("~129 BCE – 224 CE"); same-sign ranges keep the compact form ("~2,000 – 1,750 BCE"). All downstream consumers read `displayLabel` or separate per-endpoint labels, so the single fix covers every view. `testMythologicalDateDisplayLabel` extended with crossing + same-sign + forward-CE span cases. `swift build` clean; `swift test` 600 passed, 0 failures.

---

### 2026-09-19 — Sticky-note dismissals: deleted migration review flags stop coming back

**Context:** The user deleted the yellow "FROM 26-08-2026 IMPORT" sticky on Damkina and it reappeared after every restart. Root cause: `Migration.markPreExistingSyncretisms` re-runs on every launch and treats "figure no longer carries the sticky" as "needs the sticky again" — the idempotency guard is the sticky's own existence. `Migration.alignNergalErraSyncretism` has the same shape. Every other auto-sticky (`"IMPORTED — needs review"`, `"IMPORTED FROM ORACC"`, `"Import daily life events"`, …) is creation-coupled (only inserted inside the create-if-absent loops), so those never re-add after deletion — only these two "flag a pre-existing entity" migrations loop.

**Decision:** Follow the existing `FindingDismissal` precedent — the app already models "user reviewed this, don't flag again" with a signature + tombstone row for integrity findings that are recomputed on every scan. Same problem, same shape, same answer: a `StickyDismissal` tombstone keyed by `(textPrefix, entity normalized name)`.

**Changes:**
- `Sources/MeCore/Models/StickyDismissal.swift` — NEW `@Model` (`textPrefix`, `entityKey`, `createdAt`, `signature`), a direct analogue of `FindingDismissal`.
- `Sources/MeCore/Store/Migration+StickyDismissals.swift` — NEW: `Migration.autoStickyPrefixes` (the six known review-flag prefixes), `isStickyDismissed(textPrefix:entityKey:context:)`, `recordStickyDismissal(for:context:)` (prefix-matches a deleted note, derives the entity key via `DuplicateMerger.normalizationKey`, no-op for user-typed stickies).
- `Migration+MaintenanceSplits.swift` — `markPreExistingSyncretisms` and `alignNergalErraSyncretism` now skip re-adding a sticky whose `(prefix, figure)` is dismissed.
- `StickyNoteListView.swift` — both trash buttons (card + global list) call `recordStickyDismissal` before deleting.
- Schema: `StickyDismissal.self` registered in `MeApp` (app) and the test container. New table, no migration-safety issues.
- Tests: deleted-sticky-stays-deleted (Damkina), dismissal scoped per-figure (Ninhursag still flagged), Nergal/Erra dismissal (Erra's twin note survives), user-typed stickies record nothing.

**Verification:** `swift build` clean; `swift test` 596 passed, 0 failures (7 focused migration tests added). The user's next launch will still run `markPreExistingSyncretisms` once — if Damkina's sticky is still present it stays (no behavior change); once deleted it records the tombstone and never returns.

Same-day follow-up: deleting/resolving a sticky left the yellow `hasUnresolvedSticky` dot in the Figures list stuck on — the list draws the dot from the `FigureRowDisplay` snapshot, which only rebuilt on figure/popup-table/dynasty/sheet triggers. Fix: `FigureListView` adds `@Query private var stickies: [StickyNote]` + a `stickyChangeSignature` (id-hash → `isResolved`) `.onChange` trigger that calls `rebuildRows()`; dot now updates live on add/delete/resolve. Place/event lists were unaffected (they read live `stickies` in `body`). View-layer fix, not covered by MeCoreTests.

---

**Context:** After the boundary-hover prototype, the user reported three issues in quick succession. (1) The highlight and tooltip "stuck" on a region after leaving to empty map space — the exit path ran a rAF re-query at the last hovered point that re-affirmed the old highlight. (2) Sweeping over rivers "lost tracking" for seconds — rivers are thin elongated boundary polygons, so each sweep hammers the leave→re-enter cycle; every crossing reset the whole water layer's paints (3 `setPaintProperty` calls) and re-added the popup DOM, piling up MapLibre's render backlog. (3) The highlight could claim a river while the cursor sat over a kingdom territory — layer-bound events query each layer independently, so overlapping features raced and last-registered won.

**Changes:** `MesopotamiaMapView.swift`:
- Removed the exit-path re-query (`lastLayerPoint`, the `boundaryFillLayerIds.push` that re-registered the dyn layer) so `mouseleave` clears immediately — leave-to-empty now snaps off in the same frame.
- Added a 50 ms hover lease: exit defers the clear (`scheduleClear` / `cancelPendingClear`, `pendingClearTimer`), and re-entering any boundary within the window cancels it. River sweeps therefore never reset paints or rebuild the popup; exit to empty still clears within a few frames.
- Replaced the per-layer `mousemove`/`mouseenter`/`mouseleave` handlers with one global `map.on('mousemove', onMapMouseMove)` that runs a single `queryRenderedFeatures(e.point, {layers: boundaryFillLayerIds})` and highlights the topmost (paint-ordered) feature — the canonical MapLibre pattern — so overlaps resolve deterministically by what is actually drawn on top. Each `l-<key>-fill` and `l-dyn-fill` registers itself into `boundaryFillLayerIds` at setup; per-layer `click` popups kept. Map-level `mouseleave` hard-clears (cursor + highlight). Old `handleHoverLeave` removed.

**Verification:** `swift build` clean; `swift test` 592 passed, 0 failures. User confirmed exit-to-empty clearing is immediate, river lag is gone, the river/kingdom overlap resolves, and the map "performs pretty snappy" given the layer count.

**Next-up (map enhancement suggestions from the 2026-09-17 conversation; user to pick up on a future session):** 1) figure markers on their associated places via `FigurePlaceAssociation` (patronDeity/ruler/worshippedAt; icon from FigureType, colored; click → figure quickview via the `placeClicked` bridge) — agreed to be the first priority; 2) a time slider combining dynasty-era spans + figures' `MythologicalDate`s to dim territories inactive at the selected year; 3) click-through on boundaries to the era/place quickview (currently popup-only); 4) relationship arcs (spouse/alliance/creator) between the cities of related figures via a toggleable GeoJSON line layer; 5) nested regions from `PlacePlaceAssociation` (.locatedWithin) instead of flat per-type layers; 6) overlaying the EventTrail layer onto this atlas for a consolidated geography story. Order settled: figure associations first, then time.

**Files:** `Sources/Me/Views/MesopotamiaMapView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-17 — Boundary hover highlight on the Mesopotamia map

**Context:** After the basemap-city-label work, the user asked whether drawn layer geometry could detect mouse-over. MapLibre already provides per-layer `mousemove`/`mouseenter`/`mouseleave`; the Mesopotamia map used only the latter two for a pointer cursor. User asked for a prototype: hover over the southern marshes territory → thicken its outline + tooltip with the name.

**Changes:** `MesopotamiaMapView.swift` — new `highlightBoundary(name, lngLat)` + a dedicated `hoverPopup` (no close button). On `mousemove` over any `l-<key>-fill` or `l-dyn-fill` layer it sets data-driven `line-width` (2.5→4.6, dyn 2.2→4.2) and `fill-opacity` bump via `['case', ['==', ['get','name'], hoverName], …]` on every boundary line/fill layer, and moves the popup to the cursor; `mouseleave` resets paints and removes the popup. Keyed on feature `name` (matches the existing click-popup convention). Highlights key on name, so duplicate names across layers would both light up (accepted, matches existing name-based identification).

**Verification:** `swift build` clean; `swift test` 592 passed, 0 failures. User ran the prototype and confirmed "Works great!".

**Files:** `Sources/Me/Views/MesopotamiaMapView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-17 — Basemap city labels hidden (no more duplicate pins)

**Context:** The user noticed the OHM basemap draws its own city/place label layers (IDs starting with `city_` — `city_labels_*`, `city_capital_labels_*`, `city_locality_labels_*`) underneath the app's own place markers, producing visible duplicates on the Mesopotamia Map and both dynasty maps. Asked if they could be turned off; chose a UI toggle, default off (hidden), applied to all maps.

**Changes:** shared `@AppStorage("mapHideBasemapCities")` flag (default `true` = hidden) surfaced as a toggle in each map's existing chrome: a new sidebar row in Mesopotamia Map, a caption switch next to the Sumer palette in Dynasty Map, and a dedicated switch in the Dynasty Evolution header. Wired to a JS `applyBasemapCityLabels()` / `applyBasemapCities()` pass that sets `layout.visibility = 'none'` on every basemap layer whose id starts with `city_` (theme-agnostic across all four OHM themes), re-applied on `styledata` so it survives style reloads and the OHM date-plugin filter cycle — the dynasty `snapshotAndApply()` gained the call, and Mesopotamia registered a `styledata` listener plus a call inside `setLayerState`. `DynastyHistoricalMapView` gained an `hideBasemapCities` property (default `true`) threaded through `mapHTML(for:)` and diff-checked in `updateNSView` like `labelMinZoom`.

**Verification:** `swift build` clean; `swift test` 592 passed, 0 failures.

**Files:** `Sources/Me/Views/MesopotamiaMapView.swift`, `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/DynastyEvolutionMapView.swift`, `docs/SESSION_LOG.md`.

---

**Context:** The user has been curating region "territory" polygons one kingdom at a time (latest: Amurru, Elam, Hurri, Kassite homeland), placing a Kingdom-type pin then asking me to author the bound. Each new place has `storedBoundaryGeoJSON` NULL when created, so adding/updating a key in `placeBoundaryRings` (plus nothing else) lets `ensurePlaceBoundaries` backfill at next launch — no upgrade migration needed unless a place already holds a seed ring (cf. Cedar Forest/marshes, which *did* need `upgradeSeeded…Boundary`).

**Amurru (was already a seed key, but wrong):** the old ring (a steppe blob, 36.4–41.5E) excluded the user's new pin at Qadesh/Homs and even swallowed Aleppo (Yamhad). Refined to the Amorite land = Syrian steppe + middle Euphrates (Jebel Bishri, Palmyra, Dura-Europos, Sinjar-side) + the Orontes valley up to Qadesh/Homs and the port Sumur/Tell Kazel. OUT: Aleppo, Damascus, Beirut, Tripoli, Baalbek, Baghdad, Raqqa.

**Elam (seed key was also wrong):** the old ring hung a lobe onto the Mesopotamian alluvium (Amara, Basra — not Elam) and swallowed Isfahan, while dropping the Elamite Gulf port Liyan/Bushehr. Refined to Susiana + Anshan/Fars highlands + the Gulf coast: IN Susa, Choga Zanbil, Haft Tepe, Madaktu, Ahvaz, Shushtar, Anshan, Persepolis, Shiraz, Firuzabad, Liyan; OUT Amara, Basra, Isfahan, Khorramabad, Baghdad, Kerman.

**Hurri (new key):** user pin 36.8/41.0 in the Khabur triangle (correct heartland). Ring = Khabur triangle + Tur Abdin + upper Tigris basin: IN Washukanni, Urkesh/Tell Mozan, Brak, Leilan, Hamoukar, Nisibis, Mardin, Tell Halaf, Harran, Urfa, Diyarbakır, Sinjar; OUT Nineveh, Assur, Mosul (Assyrian Tigris), Mari, Terqa, Bitlis/Van, Adiyaman. (Deliberately excluded Nuzi/Arrapha east of the Tigris — keeping Arrapha in would also pull in Assur, which sits at the same latitude 1° west.)

**Kassite homeland (new key):** user called it "Kassite homeland" since the Kassite kingdom had no formal name (Karduniaš only while ruling Babylon). Pin 48.33/33.5 = Lorestan, matching the scholarly central-Zagros homeland. Ring covers Lorestan + Kermanshah + Hamadan + Ilam: IN Khorramabad, Hamadan, Kermanshah, Sanandaj, Kangavar, Borujerd, Malayer, Ilam; OUT Kirkuk, Arak, Zanjan, Deh Luran, Mehran, Baghdad, Isfahan. Known partial overlap with the Gutium ring — accepted (both are Zagros peoples; ranges genuinely overlap in scholarship).

**Method:** every ring point-edited then verified with a Python point-in-polygon battery of the architecturally decisive landmarks *before* touching Swift; each target gets its own `test…BoundaryGeoreferenced` (pip assertions) plus entries in the all-rings test's `centers` dict and place list. None of the live places (pk 114 Amurru, 115 Elam, 117 Hurri, 118 Kassite homeland) hold a stored boundary, so fresh-keys/updated-keys backfill cleanly.

**Verification:** `swift build` clean; `swift test` 592 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+PlaceBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-16 — Cedar Forest boundary refined to Mount Lebanon

**Context:** User asked me to double-check the Cedar Forest territory. The stored boundary (pk 17) was the seed-authored corridor: 33.9°–37.2°N × 35.4°–36.8°E, a ~370 km Levantine swath covering both the Lebanon and Amanus cedar ranges. Verdict: right region but over-generous — it swept in Tripoli/Antakya, dropped the southern Chouf/Barouk groves, and swallowed the Amanus (the alternative scholarly location). User approved replacing with a tighter Mount Lebanon ring.

**Refined ring (10 pts, ~110×115 km):** hugs the Mount Lebanon cedar belt only. Verified by point-in-polygon battery: Cedars of God (Bsharri 36.052,34.243), Ehden (35.99,34.31), Barouk/Chouf (35.72,33.70), and the app's own pin (36.0,34.2) all inside; Tripoli, Beirut, Sidon, Byblos, Baalbek, Damascus, Ugarit, Latakia, Antakya, and the Amanus range all out.

**Migration design (mirrors the marshes upgrade):** `placeBoundaryRings["cedar forest"]` updated for fresh installs; new `legacySeededCedarForestRing` constant + `upgradeSeededCedarForestBoundary(context:)` that replaces the stored ring only when it decodes exactly to the legacy seeded corridor (user-drawn boundaries never touched). Wired in `ContentView.swift` right after `upgradeSeededMarshesBoundary`. 3 new tests: legacy→refined replacement, user ring untouched, refined-ring georeference battery.

**Verification:** live-store probe confirmed the stored ring equals the legacy constant (upgrade fires on next launch); `swift build` clean; `swift test` 588 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+PlaceBoundaries.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-16 — E-galmah coordinate fix (was mid-Euphrates on the map)

**Context:** User noticed E-galmah's pin rendered in the middle of the Euphrates on the Mesopotamian map and asked whether that was correct. It is not: the seed carries longitude 44.5, but the true site (E-galmah temple at Isin, on the ancient Isinnitum Canal branch of the Euphrates) is ~45.27E. The app's own "Isin" place entry had the correct coordinates (31.93351, 45.28521); E-galmah never inherited them.

**Changes:** new `Migration+CoordinateFixes.swift` → `fixEgalmahCoordinates(context:)`: corrects the place named "E-galmah" only when it still holds the known-bad seed value (31.9/44.5, ±0.0001) — user-corrected coordinates are never overwritten. Uses the live "Isin" place as the coordinate source (falls back to the hardcoded value 31.93351/45.28521). Wired in `ContentView.swift` right after `ensureMapFlags`. Also corrected the seeded value in both `seed_data.json` copies (Me and MeCore) so fresh installs get it right. 5 new tests (seeded-value → Isin copy, fallback without Isin place, user-corrected untouched, idempotent, missing-E-galmah no-op).

**Verification:** live-store probe confirmed the E-galmah row holds 31.9/44.5 (migration will fire on next launch); `jq --exit-status` on both seed files; `swift build` clean; `swift test` 583 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+CoordinateFixes.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/MeCore/Resources/seed_data.json`, `Sources/Me/Resources/seed_data.json`, `Tests/MeCoreTests/MeCoreTests+Migration.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-16 — Shatt al-Nil (ancient Iturungal) corridor boundary

**Context:** User asked to fill a missing waterway: "The Shatt al-Nil (ancient Iturungal)" (store pk 73, PlaceType "Body of water" — the user's own typing, left as-is). No stored boundary.

**Identity:** Shatt al-Nil = **Naru Kabari** = the ancient **Iturungal canal** (Wikidata Q10362464, pin 32.127N 45.231E at Nippur/Afak) — arguably an early course of the Euphrates that carried the old Sippar–Kish–Nippur–Adab line south toward the marshes, per the Iturungal scholarship (Wikipedia/Nippur/Iturungal articles; UNESCO Nippur "Shatt al-Nil" canal bed bisecting the site).

**OSM situation:** Nominatim finds only a ~1.5 km named "Shatt al-Nil" waterway stretch at Afak (ways 962835081/962835080, 45.46–45.48E 32.08–32.10N); no relation; a name-based way-walker and a full flood-fill both failed (the latter ballooned into the irrigation network + thousands of node/ways API calls, too slow). Overpass 504s on this region. Decided: hand-authorized corridor along the documented ancient line, anchored on the OSM fragment and the Wikidata pin — house "fuzzy ancient geography" convention, same as Irnina.

**Corridor (10-pt centerline, 4 km buffer):** Sippar/Euphrates flank (44.42,32.72) → Kish (44.63,32.54) → Nippur (45.231,32.127) → Afak stretch (OSM) → Adab (45.685,31.951) → south to the marsh fringe (46.02,31.35). Buffered with the `BoundaryGeometry.bufferPolyline` mirror at 4 km (canal width, matching Irnina) → ~891 km², 21-pt ring. pip-validated: Sippar/Kish/Nippur/Adab/mid anchors in; Najaf, Baghdad, Kut, Diwaniya out.

**Changes:** new resource `Sources/MeCore/Resources/shatt_al_nil_boundary.geojson` (ODbL provenance in properties); `riverBoundaryResources` + `"shatt al-nil (ancient iturungal)"` entry; backfill test + place + 4 reach checks (Nippur, Adab, Kish, mid-segment). `ensureRiverBoundaries` matches by normalized name only (no PlaceType filter), so the "Body of water" place gets its corridor without the type being touched.

**Verification:** live-store probe confirmed pk 73 has no stored boundary and its normalized name equals the dict key (backfill fires next launch); `swift build` clean; `swift test` 578 passed, 0 failures.

**Files:** `Sources/MeCore/Resources/shatt_al_nil_boundary.geojson`, `Sources/MeCore/Store/Migration+RiverBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-16 — Southern Mesopotamian Marshes (Hawizeh / Hammar System) boundary upgrade

**Context:** User flagged that "The Southern Mesopotamian Marshes (Hawizeh / Hammar System)" (store pk 72) had a coarse placeholder boundary and asked to fill it properly. The DB held the original seeded 10-point oval (verified: 11 stored pts closed, byte-decode-equal to `legacySeededMarshesRing`).

**Ground truth attempt:** Overpass (both mirrors) 504s on this region even for minimal queries; Nominatim has no Hammar object and 404s the Hawizeh relation polygon. Fell back to hand-authoring against known geography, consistent with the app's "intentionally fuzzy" region style.

**Ring (16 pts):** hourglass wetland belt across both systems — Hawizeh lobe (Iraq + Hur al-Azim/Iran side) east of the Tigris, the Hammar lobe south of the Euphrates bracketing Basra-ward, connected through the Central marshes belt; south edge hugs the Shatt corridor. Iterated with a 21-target pip battery until green:
- Inside: Hawizeh Iraq/Hur al-Azim/Hawizeh S+W, Hammar mid/W/E, Central + W, the Basra-plain belt, and the existing test landmark (47.0,31.0).
- Outside: Amara, Kut, Ahvaz, Susangerd (first revision swallowed it — indent the NE corner), Shadegan, Khoramshahr, Al-Faw, Kuwait City, Baghdad-area. Basra stays inside the corridor lobe (the Shatt delta *is* marshland; the old placeholder also covered it) — deliberate.

**Migration design (new pattern):** `ensurePlaceBoundaries` never overwrites a stored non-degenerate ring, so the seeded placeholder would survive forever. Added a targeted `upgradeSeededMarshesBoundary(context:)` that replaces `storedBoundaryGeoJSON` only when the stored ring decodes exactly (1e-9 tolerance, closed-ring drop-last) to `legacySeededMarshesRing` — i.e. only our own seeded placeholder, never a user-drawn/edited boundary. Idempotent after one run. Wired in `ContentView.swift` right after `ensurePlaceBoundaries`.

**Changes:** `Migration+PlaceBoundaries.swift` (new `legacySeededMarshesRing` constant, marsh dict ring → 16-pt refined ring, new `upgradeSeededMarshesBoundary`), `ContentView.swift` (call site), `MeCoreTests+Groups.swift` (2 new tests: legacy→refined replacement incl. landmark containment; user-drawn ring left untouched).

**Verification:** real-store probe confirmed stored ring == legacy constant (upgrade will fire on launch); `swift build` clean; `swift test` 578 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+PlaceBoundaries.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-15 — Mediterranean Sea (The Upper Sea) region boundary

**Context:** User's follow-up to the Persian Gulf: add its twin, "The Mediterranean Sea (The Upper Sea)" (store pk 66, "Body of water"). Same region pattern: hand-authored ring in `placeBoundaryRings`.

**Scope decision:** Covers the eastern Mediterranean basin — the "Upper Sea" Mesopotamians actually knew (Levant/Aegean-coast to the Nile delta, incl. Cyprus) — rather than the full Gibraltar-to-Levant sea. The app's atlas is Mesopotamia-focused so a full-Med polygon would be a mostly off-frame blob.

**Ring design (~17 pts):** Gulf of Iskenderun arm at the NE, coastal-faithful Levant edge (Beirut/Antalya/Mersin/Haifa/Damascus all verified outside), south edge off Sinai/Nile delta, western edge toward Crete. pip-tested: land points out (incl. Iskenderun bay's *coast* — (35.60,36.60) is actually land, the bay's water is more like (35.85,36.35)). Nicosia ends up inside the water region — accepted (a mid-sea island inside an ocean region is normal; same reasoning as the Gulf).

**Changes:** `Migration+PlaceBoundaries.swift` added `"mediterranean sea (the upper sea)"` → 17-pt ring; `testEnsurePlaceBoundariesBackfillsRegions` extended with landmark (33.0, 34.5) (SW of Cyprus).

**Verification:** `swift build` clean; `swift test` 576 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+PlaceBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-15 — Persian Gulf (The Lower Sea) region boundary

**Context:** User asked for the Persian Gulf. Unlike rivers (corridor pattern via buffered OSM centerlines), this is a water-body *region*, so it fits the hand-authored `placeBoundaryRings` region pattern in `Migration+PlaceBoundaries`. The store already has "Persian Gulf (The Lower Sea)" (pk 65, PlaceType "Body of water"); its ancient epithet "The Lower Sea" is preserved in the name.

**Process:** Pulled OSM relation 9326283 (the Persian Gulf bay polygon, 68 MB, 949 outer ways, outer ring 169,574 pts, bbox lon 47.7–55.8, lat 24.0–30.5) purely as a coastline *guide* — note OSM's polygon includes the Shatt/Haffar arm up to Basra and Kuwait Bay. Extracted + RDP-simplified the outer rim, then hand-authored a ~26-point region ring that keeps the app's coarse "intentionally fuzzy" house style while remaining geographically faithful:
- Notches around the Qatar peninsula (east-of-Qatar leg → north strait → Salwa arm on the west) so Doha/mainland stays outside (the naive ~20-pt simplification visibly swallowed Qatar — caught by pip-testing).
- Keeps the Gulf proper only: excludes Iranian/UAE/Saudi/Qatar mainland, Basra, Ahvaz, Kuwait City, Riyadh.
- The authoring ring's validity checkpointed with a point-in-polygon probe over 7 water + 7 land targets before committing (verified 51.3,26.1 = NW Qatar land and 49.9,26.2 = interior Saudi are correctly outside — spots first mistaken as water).

**Changes:**
- `Migration+PlaceBoundaries.swift`: added `"persian gulf (the lower sea"` → 26-pt ring to `placeBoundaryRings`.
- `testEnsurePlaceBoundariesBackfillsRegions`: added the gulf with central-gulf landmark (50.5, 27.0).

**Noted for later:** "The Mediterranean Sea (The Upper Sea)" (pk 66, same type, the Gulf's sibling) still has no boundary — identical pattern if the user wants symmetry.

**Verification:** `swift build` clean; `swift test` 576 passed, 0 failures.

**Files:** `Sources/MeCore/Store/Migration+PlaceBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Three river asks: Karun (store pk 67) and Khabur (store pk 70, the *Syrian* Khabur per user decision) exist in the user's curated data; the Zab did not exist at all (only the city "Zabala"). User approved adding both Zabs as two separate places via migration and both Khabur options. Hubur (mythological, pk 77) stays untouched.

**Pipeline hardening (`chain_river.py` scratch):**
- Discovered greedy nearest-tip chaining can finish with a **trailing backtracking spur**: after the walker reaches the river's mouth it can still bridge small backtracking fragments upstream and stall mid-river (Greater Zab: walked 39 ways head→south, ended with a spur at 43.51,36.10 though the chain already reached lat 35.99 near the confluence). Added a **southmost-point trim**: cut the chain at the *last* occurrence of the minimum latitude (the natural terminus for south-flowing systems).
- Bridge cap raised 0.2° → 0.35° (fragmented lower Zab fragments celebrated gaps ~0.13–0.24°).
- Fixed an empty-generator crash when all member ways are consumed.
- Karun (relation 2397367): 26/27 ways, 867 km; tail now at the Shatt mouth (48.166,30.428). Leftover way is a 188 km-disconnected fragment (dropped).
- Khabur/Syria (r 9735745): 40/40, 598 km. Greater Zab (r 368962): 39-line mainstem, 542 km after trim, ends at the mapped lower Zab (43.339,35.994). Lesser Zab (r 367790): 46/46, 570 km.

**Data changes (all additive, check-by-name):**
- `Sources/MeCore/Resources/{karun,khabur,greater_zab,lesser_zab}_boundary.geojson` (new): 6 km corridors, ODbL provenance per file. Ring sizes: 3103 / 7471 / 10607 / 4793 pts.
- `Migration+RiverBoundaries.swift`: four dict entries; new **`ensureRiverPlaces(context:)`** that creates "The Greater Zab River" and "The Lesser Zab River" as `River, canal` only if absent (never overwrites/duplicates) — user data otherwise untouched.
- `ContentView.swift`: `ensureRiverPlaces` runs just before `ensureRiverBoundaries` so the new places get corridors the same launch.

**Bugs caught by tests:** zab dict keys were "the greater zab river" — `normalizedGroupName` strips "the", so keys had to be "greater zab river". Karun/Khabur first reaches landed in self-overlapping meander rings (pointInRing edge case); swapped for validated straight stretches.

**Verification:** `swift build` clean; `swift test` 576 passed, 0 failures.

**Files:** `Sources/MeCore/Resources/{karun,khabur,greater_zab,lesser_zab}_boundary.geojson` (new), `Sources/MeCore/Store/Migration+RiverBoundaries.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Karkheh (store name "The Karkheh River", normalized `karkheh river`) is a real Iranian river (Khuzestan). OSM relation **2390658**, 26 ways / 777 km.

**Pipeline hardening (scratch `chain_river.py`):** the first run chained only 1 of 26 segments — a latent bug: after laying the first segment `cur` was set to the headwater **tip** instead of its **far end**, so the very first step looked for a neighbor at the dangling source and stopped. Fixed to start walking from the far end. Also replaced the bucket-based matcher with a global **nearest-tip walk** (shared junctions are distance ~0, ≤0.2° bridges heal gaps). Executes all 26 ways → 777 km mainstem (Zagros → Hawizeh/Khuzestan, lon 46.8–48.6, lat 31.5–34.2). Re-verified the Diyala with the fixed script: unchanged 63/83, 463 km.

**Changes:**
- `Sources/MeCore/Resources/karkheh_boundary.geojson` (new, ~125 KB): 6 km corridor → 3,071-pt closed ring (~4,170 km²), ODbL provenance in `properties`.
- `Migration+RiverBoundaries.swift`: added `"karkheh river": "karkheh_boundary"`.
- `testEnsureRiverBoundariesBackfillsRivers`: asserts Karkheh Susa / mid / lower reaches.

**Verification:** `swift build` clean; `swift test` 575 passed, 0 failures.

**Files:** `Sources/MeCore/Resources/karkheh_boundary.geojson` (new), `Sources/MeCore/Store/Migration+RiverBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** The Irnina Canal ("The Irnina Canal", store pn 74, PlaceType "River, canal") is a historically attested ancient canal — "linking the Tigris and Euphrates north of Kish and Akkad" — with only an approximate stored pin (33.2°N, 43.9°E). No modern mapping exists (OSM/Nominatim: nothing), and the Hubur-style skip didn't apply — user chose to author a fuzzy corridor per the app's existing "intentionally fuzzy where ancient borders are poorly known" convention.

**Changes:**
- `Sources/MeCore/Resources/irnina_boundary.geojson` (new, ~1 KB): hand-drawn 5-point centerline on the Fallujah→Baghdad inter-river axis (~33.3°N, dipping through the stored 33.2°N/43.9°E pin), buffered via the `bufferPolyline` mirror at **4 km** so a canal reads slimmer than river corridors; 11-pt closed ring (~399 km²). `properties` explicitly flag it as hand-authored from textual geography, not survey data.
- `Migration+RiverBoundaries.swift`: added `"irnina canal": "irnina_boundary"`.
- Tests: `testEnsureRiverBoundariesBackfillsRivers` asserts five on-centerline reaches; the ring-fidelity assert relaxed from `> 100` to `>= 4` points (a corridor can legitimately be coarse). First test run caught that a buffer endpoint sits exactly on the polygon boundary (pip edge-case) — nudged the east-terminus reach to an interior point.

**Notable:** Hubur (mythological underworld river) was skipped by user request. The "given its name" pipeline now supports three sources: OSM relations (real rivers), OSM-style gap-bridged chains (Diyala), and hand-authored fuzzy corridors (canals/ancient features) — selected per feature.

**Verification:** `swift build` clean; `swift test` 575 passed, 0 failures.

**Files:** `Sources/MeCore/Resources/irnina_boundary.geojson` (new), `Sources/MeCore/Store/Migration+RiverBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Diyala (store name "The Diyala River", normalized `diyala river`; OSM relation **368541**). First two chaining attempts failed: the relation's 83 member ways are NOT id-connected — junctions use duplicated node ids and there's a real ~1.7 km topological split in the Khanaqin reach (upper Zagros half and lower Baghdad half).

**Pipeline hardening (scratch tool, `/tmp/opencode/chain_river.py`):** replaced the endpoint-node-id walker with a **coordinate-aware** chainer: match segment tips by rounded coordinate buckets (1e-3°), prefer exact-touch joins, walk downstream (lowest lat) at branches, and **bridge** small gaps (≤0.2°) to the nearest unused tip when the walk stalls. Result: 63/83 segments, ~463 km mainstem (Tigris confluence at Baghdad → Zagros/Iran), bridging the two halves.

**Changes:**
- `Sources/MeCore/Resources/diyala_boundary.geojson` (new, ~109 KB): 6 km corridor → 2,685-pt closed ring (~2,560 km²), ODbL provenance in `properties`.
- `Migration+RiverBoundaries.swift`: added `"diyala river": "diyala_boundary"`.
- `testEnsureRiverBoundariesBackfillsRivers`: asserts Diyala Baqubah / Khanaqin / confluence reaches.

**Verification:** `swift build` clean; `swift test` 575 passed, 0 failures.

**Files:** `Sources/MeCore/Resources/diyala_boundary.geojson` (new), `Sources/MeCore/Store/Migration+RiverBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Third river, the Balikh (Syrian tributary of the Euphrates). OSM relation **17712188** (البليخ) is a single way, ~113 km (Harran plain → Raqqa confluence, lat 35.9–36.7, lon ~39.0); buffered to a 6 km corridor → 353-pt ring (~596 km²). Store name is "The Balikh River" → normalized key `balikh river` (the "the " stripping in `normalizedGroupName`).

**Changes:**
- `Sources/MeCore/Resources/balikh_boundary.geojson` (new, ~14.6 KB, ODbL provenance in `properties`).
- `Migration+RiverBoundaries.swift`: added `"balikh river": "balikh_boundary"`.
- `testEnsureRiverBoundariesBackfillsRivers`: now inserts "The Balikh River" and asserts its confluence + mid-course reaches.

**Verification:** `swift build` clean; `swift test` 575 passed, 0 failures.

**Files:** `Sources/MeCore/Resources/balikh_boundary.geojson` (new), `Sources/MeCore/Store/Migration+RiverBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Re-ran the Tigris pipeline for the Euphrates. OSM relation **10106318** (الفرات), 7.4 MB full, 156 member ways → 81 chained into a ~2,496 km centerline (Turkey→Gulf, lon 37.8–47.4, lat 30.9–39.8); buffered to a 6 km corridor → 13,239-pt ring (~14,400 km²).

**Changes:**
- `Sources/MeCore/Resources/euphrates_boundary.geojson` (new, ~536 KB, ODbL provenance in `properties`).
- `Migration+RiverBoundaries.swift`: added `"euphrates river": "euphrates_boundary"`.
- Tests: `testEnsureRiverBoundariesBackfillsRivers` now asserts both rivers (on-river reaches: Tigris Baghdad/Samarra, Euphrates Deir ez-Zor/Ramadi/Kufa) and uses an unlisted "Zagros river" as the untouched control.

**Verification:** `swift build` clean; `swift test` 575 passed, 0 failures.

**Files:** `Sources/MeCore/Resources/euphrates_boundary.geojson` (new), `Sources/MeCore/Store/Migration+RiverBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** The prototype Tigris corridor was generated; the place already exists in the live store as "Tigris river" (PlaceType "River, canal", ZPLACE pk 64) — not in seed_data. Wired the boundary in so the atlas draws it on the river layer without touching the sacred DB destructively.

**Changes:**
- `Sources/MeCore/Store/Migration+RiverBoundaries.swift` (new): `riverBoundaryResources` map (normalized place name → bundled GeoJSON resource) + `ensureRiverBoundaries(context:)` which re-serializes the GeoJSON through the canonical `polygonGeoJSON` writer and backfills `Place.storedBoundaryGeoJSON` for each listed river. Same never-overwrite guard as `ensurePlaceBoundaries` (user-drawn/edited boundaries are left alone); additive + idempotent.
- `Sources/MeCore/Resources/tigris_boundary.geojson`: full-fidelity ring (12,717 pts, ~515 KB) with ODbL provenance in `properties`; stored raw but re-canonicalized at seed time.
- `ContentView.swift:314`: invoked `Migration.ensureRiverBoundaries(context:)` right after `ensurePlaceBoundaries`.
- Tests in `MeCoreTests+Groups.swift`: initial Tiger backfill (baghdad/Samarra reaches on-river, unlisted river untouched), never-overwrite, idempotency. Note: Baghdad city-center coordinates sit ~5 km off the OSM centerline, so the "contains" assertions use on-river points extracted from the relation itself.

**Verification:** `swift test` — 575 passed, 0 failures; `swift build` clean.

**Files:** `Sources/MeCore/Store/Migration+RiverBoundaries.swift` (new), `Sources/MeCore/Resources/tigris_boundary.geojson`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Curiosity question — could a boundary territory be auto-created for a named river? Answer proven with the Tigris. The app already has the corridor-buffering machinery (`BoundaryGeometry.bufferPolyline`, `Migration.polygonGeoJSON`); the only missing link was sourcing the centerline.

**Pipeline (reusable):**
1. Resolve name → OSM relation: Nominatim search "Tigris river" → relation **2188548** ("نهر دجلة").
2. Fetch geometry: `GET /api/0.6/relation/2188548/full` (6.8 MB OSM XML, 109 member ways, 32,928 nodes).
3. Chain by shared endpoints into one ordered centerline (`/tmp` python) — key correctness fix: relation member order is NOT topological; naive in-order chaining gave a bogus 4,622 km; endpoint-chaining gave the true **1,918 km**. 84/109 members used (rest are braids/side channels), downsample 5× → 6,359 pts.
4. Buffer with a 1:1 mirror of `BoundaryGeometry.bufferPolyline(... widthKm: 6)` (the boundary editor's default river width) → 12,716-point ring, ~11,117 km², closed `Polygon` GeoJSON.
5. Artifact: `Sources/MeCore/Resources/tigris_boundary.geojson` (514 KB, `[lon,lat]`, provenance in `properties` — **OSM data is ODbL; attribution kept in-file**).

**Not done:** no app wiring yet — would need a "Tigris" `Place` (type River) with `storedBoundaryGeoJSON` or an `Era` polygon for the atlas layers; that touches the sacred DB (additive, check-by-name) so it's deferred pending user choice.

**Verification:** `jq --exit-status` round-trip valid JSON; ring closed; axis order and extent (lon 39.4–47.5, lat 31.0–38.5) sane for the Tigris.

**Files:** `Sources/MeCore/Resources/tigris_boundary.geojson` (new), `docs/SESSION_LOG.md`. Scratch pipeline in `/var/folders/dl/l_wpv_yn6m55_9jz8zq2fjy80000gn/T/opencode/`.

---

**Context:** After wiring marker clicks, two nits: (1) the MapLibre territory/centroid popup on the Mesopotamia atlas had no close button (`closeButton: false`), leaving users unable to dismiss it; (2) the Place/Event quicklook windows' compact `VStack` content rendered centered in the window.

**Changes:**
- `MesopotamiaMapView`: `new maplibregl.Popup({ closeButton: true, offset: 16 })` — the ✕ is back on territory/centroid-name popups.
- `AnunnakiApp.swift`: `PlaceQuicklookContent` and `EventQuicklookContent` now use `.padding(.horizontal 20 / .top 24 / .bottom 16)` + `.frame(maxWidth/Height: .infinity, alignment: .top)` so the content pins to the top with a top margin instead of floating centered.

**Verification:** `swift build` clean.

**Files:** `Sources/Me/Views/MesopotamiaMapView.swift`, `Sources/Me/AnunnakiApp.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Cursor changed to a pointer over markers but clicks were a dead-end on three surfaces (atlas landmark markers only popped a name; GroupEraMapView and the boundary editor had no-op `onPlaceSelected` handlers). User asked to make clicking do something.

**Changes:** Reused the app's existing `place-quickview` window (`@Environment(\.openWindow)`), matching `EntityGroupCollectionView`.
- `MesopotamiaMapView`: JS `makeMarker` now takes `isPlace`; landmark markers post the place name via a new `placeClicked` webkit handler instead of the popup (territory/dynasty centroid markers keep the popup). Coordinator handles `placeClicked` → `onPlaceSelected(name)` → `openPlace(named:)` matches `@Query places` case-insensitively → opens the quickview window. `MesopotamiaMapWebView` registers the extra script-message handler and threads the closure through.
- `GroupEraMapView`: `onPlaceSelected` looks up the tapped `Place` via `group.directPlaces` and opens the quickview window.
- `BoundaryDrawEditorView` (place + era flavors): `onPlaceSelected` fetches the `Place` by name from `modelContext` (`#Predicate { $0.name == name }`) and opens the quickview window — guarded by `!drawMode` so drawing gestures are never hijacked by the marker click.

**Verification:** `swift build` clean.

**Files:** `Sources/Me/Views/MesopotamiaMapView.swift`, `Sources/Me/Views/GroupEraMapView.swift`, `Sources/Me/Views/PlaceBoundaryEditorView.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Following the co-located-marker spread, further decluttering: below a zoom threshold only marker dots are shown; labels fade in at the threshold and above. User asked for it configurable in App Settings.

**Changes:**
- New shared setting `"mapLabelRevealZoom"` (Int 0–14, default 8) read via `@AppStorage` in App Settings (new "Map Labels" section with a `Stepper`).
- `DynastyHistoricalMapView`: `mapHTML(for:)` gains `labelMinZoom: Int = 8`; JS adds `labelMinZoom`, `applyLabelReveal()` (toggles `.place-label` display by `map.getZoom() >= labelMinZoom`), `setLabelMinZoom(z)`, hooked to `map.on('zoom', …)` and `snapshotAndApply`. Coordinator tracks `lastLabelMinZoom`; a settings change without a full reload propagates live via `setLabelMinZoom`; full reloads bake it into the HTML.
- `MesopotamiaMapView`: `stateJSON` now carries `labelZoom`; JS `state` defaults to `{ hidden: [], labelZoom: 8 }`, `makeMarker` returns `{ el, label }`, markers store the label element, and `applyZoomReveal()` hides a marker's label when zoom is below `state.labelZoom` (still honoring group-hide and per-place `level`). No HTML reload needed — `setLayerState` re-applies on toggle/ready.

**Verification:** `swift build` clean.

**Files:** `Sources/Me/Views/AppSettingsView.swift`, `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/MesopotamiaMapView.swift`, `docs/SESSION_LOG.md`.

---

**Context:** Temples (E-kur, E-anna, Esagila, …) share near-identical coordinates with their host cities (Nippur, Uruk, Babylon, …), so on all three maps their markers stacked pixel-on-pixel into an unreadable blob.

**Changes:** Added a spread step before markers are placed: group markers whose lat/lon are within `EPS = 0.0005°`, and for clusters of 2+ offset each member around a circle of `OFFSET_METERS = 280` (~100× loosely arbitrary but human-scale; ~2× the 12 px dot at dynasty zoom). Applied in all three map implementations:
- `SumerianDynastyMapView` (JS `spreadOverlapping`) — computed against the `places` array; marker indices/tap routing unchanged.
- `MesopotamiaMapView` (JS `spreadOverlapping`) — point markers are now collected into `pointItems` across all place-type layers first, spread globally (so a temple layer and its city layer de-overlap), then created; `group`/`level`/`minor` preserved for zoom-reveal/toggling.
- `CityMapView` (Swift `pins`) — same clustering math in Swift, rendering `Marker`s from a `MapPin` value struct (builds a raw `Place` array so no faulting in render).

**Verification:** `spreadOverlapping` logic exercised in `node` (Nippur/E-kur & Uruk/E-anna split ~280 m apart at same lat, isolated Akkad untouched); `swift build` clean.

**Files:** `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/MesopotamiaMapView.swift`, `Sources/Me/Views/CityMapView.swift`, `docs/SESSION_LOG.md`.

---

**Context:** During idle (display off) the Mac runs a ~15–16 min maintenance DarkWake cycle. The watchdog's heartbeat clock used `Date()` (wall-clock), so every wake saw a gap of the full sleep interval (>3 s) and wrote a `.spin` hang report every ~15 min — all showing a perfectly idle main thread. Correlated to the second with `pmset -g log` wake/DarkWake entries going back to Sep 8.

**Changes:** Swapped the heartbeat clock from `Date()` to `ProcessInfo.processInfo.systemUptime` (`lastHeartbeatUptime: TimeInterval`). Uptime does not advance while the machine sleeps, so machine-sleep gaps no longer register as stalls. Wall-clock `Date()` is still used only for the `captureCooldown` to limit report frequency.

**Verification:** `swift build` clean; full suite green — 572 tests, 0 failures.

**Files:** `Sources/Me/MainThreadWatchdog.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-14 — Mesopotamia Map: zoom-revealed landmarks (per-place zoom levels)

**Context:** "Wild thought: show more landmarks on the map as the zoom level goes up." Agreed design: drop the coarse "Major landmarks only" toggle for a per-place reveal ladder — each `Place` carries a MapLibre zoom threshold (`zoomLevel`, 0–14) and its pin appears only once the map crosses it. Level 0 = shown on the overview; higher levels appear progressively as you zoom in.

**Changes:**
- Data model (migration-safe optional): `Place.zoomLevel: Int?`; computed `Place.mapZoomLevel` (stored wins; else major→0, minor→8 — 8 sits just past the whole-region fit at ~7.5 so the overview stays majors-only and the first zoom step reveals the rest). Backfill in `Migration.ensureMapFlags`: existing majors get `zoomLevel = 0` when nil (idempotent, user-set values untouched).
- `PlaceFormView`: "Major landmark" toggle is now a shortcut for level 0; otherwise a `Stepper` (0–14) "Reveal on map at zoom level N" on the Identity step, saved on add & edit.
- `MesopotamiaMapView`: `pointFeature` carries `zoomLevel` via `mapZoomLevel`; "Major landmarks only" toggle + `@AppStorage("mesopotamiaMapMajorOnly")` + `state.majorOnly` removed (replaced by the reveal ladder); header now shows a hint "More landmarks appear as you zoom in". JS: markers track `level`, `applyZoomReveal()` shows a marker when `map.getZoom() >= level` (group-hidden markers stay hidden), run on `map.on('zoom', …)`, after `fitView()`, and from `setLayerState`; dynasty centroid labels fixed at level 0.

**Verification:** `swift build` clean; full suite green — 572 tests (2 new/updated `MapFlagsTests`: major zoom-level backfill + `mapZoomLevel` defaults, explicit-level preservation).

**Files:** `Sources/MeCore/Models/Place.swift`, `Sources/MeCore/Store/Migration+MapFlags.swift`, `Sources/Me/Views/PlaceFormView.swift`, `Sources/Me/Views/MesopotamiaMapView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-13 — Mesopotamia Map polish: zoom churn, dynasty default, readable labels

**Context:** User feedback after the first atlas build: (1) the map "nervously" zoomed in/out when checkboxes were ticked, (2) switch dynasties off by default, (3) no clear text labels — couldn't tell what they were looking at.

**Changes:**
- **Zoom churn root cause:** `updateNSView` compared the *generated HTML string* to decide reloads; Swift `Dictionary` iteration order is not stable across separately-built dictionaries, so the embedded ATLAS JSON intermittently differed on nothing → spurious full page reloads → camera reset to `fitView()` on every toggle. Fixed by comparing a canonical snapshot key instead: `MesopotamiaMapHTMLBuilder.atlasJSON` now serializes with `.sortedKeys` and the WebView only reloads when that key changes. Toggles mutate JS state only (`setLayerState`) and never touch the camera.
- **Dynasties off by default:** `defaultHidden` now always includes `"dyn"`. Bumped the hidden-layers AppStorage key to `mesopotamiaMapHiddenLayersV2` so the new default isn't overridden by a previously-persisted toggle string (the user had already clicked checkboxes).
- **Clear labels:** replaced the MapLibre symbol/circle layers (silently no-op rendering if the style lacks the glyph font) with DOM markers in the proven dynasty-map style — every pin is a colored dot + always-on text label (minor pins smaller/lighter), dynasty eras get a centroid marker labeled with the era name, all markers honor layer-visibility and major-only toggles via `display`. Added a bottom-left "Visible" legend panel listing the currently shown layers with their colors, so the color scheme is self-explanatory even with the sidebar collapsed. Fill/line boundary layers kept (clickable → name popup).

**Verification:** `swift build` clean; full suite green (571 tests).

**Files:** `Sources/Me/Views/MesopotamiaMapView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-13 — Mesopotamia Map: layered atlas of all places, dynasties & bodies of water

**Context:** The user wanted a single map of Mesopotamia showing "basically all places" — first major cities, then user-added ones, plus dynasties and bodies of water, each switched on/off with checkboxes. Agreed design: per-place-type checkboxes (dynamic, not fixed curated buckets), `isWater` on `PlaceType` for recognising wet stuff, `isMajor` on `Place` for the "major landmarks only" filter, dynasties from existing `Era.boundaryGeoJSON`, and kingdoms/empires (Hittites, Assyria) later as `Place` rows drawn with the existing boundary editor.

**Changes:**
- Data model (migration-safe optionals): `PlaceType.isWater: Bool?`, `Place.isMajor: Bool?`.
- New backfill `Migration.ensureMapFlags` (`Sources/MeCore/Store/Migration+MapFlags.swift`): flags `isWater = true` for any place type whose lowercased name contains a water token (sea/gulf/river/lake/ocean/marsh/swamp/water) and `isMajor = true` for a curated list of ~22 famous sites (Ur, Uruk, Babylon, Akkad, Eridu, Kish, Nippur, Lagash, Larsa, Sippar, Girsu, Umma, Assur, Nineveh, Susa, Mari, Ebla…). Only writes nil values — user-set `false`/`true` never overwritten. Wired into ContentView seeding task after `ensurePlaceBoundaries`.
- UI wiring: `EntityTypeEditSheetView` shows a "Water body" toggle only when `T is PlaceType` (sheet height 300→340); `PlaceFormView` gains a "Major landmark" toggle on the Identity step, saved on both add and edit paths.
- New `Sources/Me/Views/MesopotamiaMapView.swift`:
  - Sidebar: one toggle row per place type (color dot, SF symbol, flag icons for water — shows `water.waves`, place/boundary counts) plus a fixed "Dynasties" toggle; "Major landmarks only" switch; Fit button. Visibility + majorOnly persisted via `@AppStorage` (`mesopotamiaMapHiddenLayers`, `mesopotamiaMapMajorOnly`); default shows City + water types + Dynasties.
  - Map: single MapLibre canvas (OHM style) with a GeoJSON source per type — Point features split major (`pin`) vs minor (`pin-minor`) plus boundary Polygons as `boundary` features; per-type layers fill/line/dots/dots-minor/labels (symbol labels only on major pins, `text-allow-overlap: false`); one `dyn` source with per-feature dynasty colors (palette indexed by era order) + fill/line; popup on pin/area click; `fitView()` bounds every coordinate at load.
  - Reload safety: HTML is built from a pure value snapshot (no `@Model` faulting in render paths); toggles never rebuild the HTML (state applied via JS `setLayerState`, delivered after a `ready` message-handler handshake so visibility isn't lost on the first load).
- Sidebar entry `.mesopotamiaMap` (icon `mappin.and.ellipse`, Visualizations section) in `ContentView.swift`.
- `MapZoomController.fitView()` added.

**Verification:** `swift build` clean; full suite green — 571 tests (569 + 2 new `MapFlagsTests`: water-type/major-place backfill, user-value preservation).

**Files:** `Sources/MeCore/Models/PlaceTypeModel.swift`, `Sources/MeCore/Models/Place.swift`, `Sources/MeCore/Store/Migration+MapFlags.swift` (new), `Sources/Me/Views/MesopotamiaMapView.swift` (new), `Sources/Me/Views/TypeSettingsView.swift`, `Sources/Me/Views/PlaceFormView.swift`, `Sources/Me/Views/MapPreview.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-13 — Boundary editor: vertex drag editing for existing boundaries

**Context:** After tracing the Persian Gulf with the blob tool, the user wanted to come back to the boundary and nudge the few lines that were off — rather than redrawing the whole shape. Asked for drag-and-drop of individual vertices.

**Changes:**
- `BoundaryDrawStyle.edit` (displayName "Edit") in `SumerianDynastyMapView.swift`.
- Map JS: edit mode shows the existing ring's vertices (closing duplicate excluded) as enlarged draggable dots in the existing `boundary-vertices` layer (radius 5→7 / stroke 2→3 while editing, reset on mode leave). `mousedown` grabs the nearest vertex within `CLOSE_PX`, `mousemove` drags it live (first vertex keeps the closing point in sync), `mouseup` posts the full unclosed ring via `boundaryDrawn`. Hover shows a `grab` cursor near vertices, `grabbing` while dragging.
- `setBoundary()` now also keeps `boundaryData` in sync so edit mode always reads the current on-map ring (previously only the load-time copy was tracked).
- `BoundaryDrawEditorView`: edit-mode hint row ("Drag a dot to nudge that vertex…") plus a "Re-trace as blob" button that regenerates a fresh parametric silhouette from the current blob sliders, and a dedicated `drawModeHelp` string.
- Reuses the existing `pendingRing`/`onBoundaryDrawn`/Save pipeline — every drag updates `pendingRing`; saving persists to `storedBoundaryGeoJSON` as before (inherited bounds become stored on save).

**Verification:** `swift build` clean; full suite green (569 tests, 0 failures).

**Files:** `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/PlaceBoundaryEditorView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-13 — Water-body boundary tools: Blob generator + River buffer in the boundary editor

**Context:** User asked how to display rough contours for bodies of water (hard to hand-trace a fuzzy coastline). Suggested reusing the polygon boundary machinery (`Place.storedBoundaryGeoJSON`, freehand editor) with two authoring tools: a parametric wavy "blob" for lakes/seas/gulfs and an auto-buffered corridor for rivers. User: "Yes, both please."

**Changes:**
- New `Sources/MeCore/Store/BoundaryGeometry.swift` — pure geometry helpers:
  - `blobRing(center:radiusKm:lonStretch:vertices:roughness:seed:)` — deterministic (seeded) wavy polar ring around a centroid; roughness warps a sum-of-harmonics outline from perfect ellipse to jagged.
  - `bufferPolyline(_:widthKm:)` — offsets a clicked river centerline by half-width per vertex (bisector normals at corners) into a closed corridor ring.
- `BoundaryDrawStyle` gained `.blob` and `.river` (displayNames "Blob"/"River") in `SumerianDynastyMapView.swift`.
- Map JS: `setDrawStyle` now passes `blob`/`river` through; river drops click points like line (no near-first snap); new `finishRiver()` posts the unclosed polyline via `boundaryDrawn`; blob mode is inert to pointer events (slider-driven).
- `DynastyHistoricalMapView` gained `minBoundaryPoints` (default 3; editor passes 2 for river so a 2-point polyline isn't dropped by the message guard).
- `updateNSView` pushes boundary changes live (`lastBoundaryStr` compare → `setBoundaryStr`), so blob slider edits preview on the map.
- `MapZoomController.finishRiverStroke()` added.
- `BoundaryDrawEditorView` (Place + Era flavors share it): Blob panel (radius, wobble, elongate, contour points, dice re-roll) and River panel (width slider + Finish stroke button); river strokes are buffered at the current width, `onChange(of: riverWidthKm)` re-buffers the stored polyline; Discard resets both; footer picker widened to 260, sheet grown to 680×600.

**Verification:** `swift build` clean; full suite green — 569 tests (563 + 6 new `BoundaryGeometryTests`: blob shape/determinism/ellipse-when-roughness-0, buffer thickness/corner/min-input rejection).

**Files:** `Sources/MeCore/Store/BoundaryGeometry.swift` (new), `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/MapPreview.swift`, `Sources/Me/Views/PlaceBoundaryEditorView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-13 — Timeline feature: sidebar item + list/detail/entry/narrative UI

**Context:** Follow-up to the Timeline models sketch — the user asked where the new Timeline entity lived in the sidebar; it didn't exist yet (pure model + migration scaffold). Asked, got "yes please": wire up a full list-detail surface.

**Changes:**
- `NavigationItem.timelines = "Timelines"` (icon `calendar.badge.clock`, section `.data`, destination `TimelineListView()`) in `ContentView.swift`; sits in the Data sidebar section alongside Events/Places/etc. (No clash with the existing `.timeline` "Timeline" visualization item.)
- `DetailWidthSlot.timeline` added (key `timelineDetailWidth`, default 380).
- New `TimelineListView.swift` (all-in-one like `EraListView.swift`):
  - `TimelineListView` — list-detail split; row shows name + entry count + description; context-menu Add Entry / Edit / Delete.
  - `TimelineDetailView` — header, description, entries in `sortedEntries` order; per-entry Up/Down reorder (via `Timeline.moveEntry`), Edit / Remove, and per-entry **Narrative** blocks (title + prose) added through `TimelineEntry.appendBlock`; blocks deletable.
  - `TimelineFormView` — add/edit (name via `NameDuplicateCheck`, order stepper, description).
  - `TimelineEntrySheet` — event picker over all events (empty guard) + optional note.
  - `TimelineBlockSheet` — title + prose narrative block.
- Delete cascade: timeline → entries → blocks (both `@Relationship(.cascade)`), handled by SwiftData; alert wording reflects it.

**Verification:** `swift build` clean; full suite green (563 tests, 0 failures).

**Files:** `Sources/Me/Views/TimelineListView.swift` (new), `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/DetailWidth.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-13 — Timeline feature: Timeline + TimelineEntry models with GroupTextBlock narrative reuse

**Context:** User proposed a Timeline entity as a first-class model (not a group) collecting events in presentation order (by placement, not date), with rich-narrative prose per event. Requested scope was a code sketch: both models, reuse of `GroupTextBlock` for blocks, and an additive `Migration.ensureTimeline...` scaffold.

**Design decisions (user):**
- Timeline is a first-class `@Model`, not a group; ordering is by `orderIndex` (placement/narrative flow), not by date.
- Narrative lives as rich text blocks on the **association record** (`TimelineEntry`) — reuse `GroupTextBlock` (pro-reuse as long as practical); `eventDescription`/`richDescription` stay short/clinical.

**Changes:**
- **`Timeline.swift`** (new): `name`, `timelineDescription`, `orderIndex`, `createdAt`, `entries` (`[TimelineEntry]?`) with `@Relationship(deleteRule: .cascade, inverse: \TimelineEntry.timeline)`; `sortedEntries` (orderIndex, then event name tie-break); `appendEntry`, `moveEntry`.
- **`TimelineEntry.swift`** (new): `timeline`, `event`, `orderIndex`, `note`, `blocks` (`[GroupTextBlock]?`) cascade inverse `\GroupTextBlock.timelineEntry`; `sortedBlocks` (orderIndex, then title); `appendBlock`.
- **`GroupTextBlock.swift`**: added optional `timelineEntry: TimelineEntry?` (no `@Relationship`, mirroring the existing `group`) + init param — enables the block reuse.
- **Schema**: `Timeline.self, TimelineEntry.self` registered in `AnunnakiApp.swift` and in the main test container schema (live-store diagnostic schemas left untouched).
- **Migration**: `Migration+Timelines.swift` with `ensureTimelineDefaults(context:)` (fetch/guard no-op scaffold); called from the `ContentView` launch chain after `ensureRefinedDomainTags`.
- **Test**: `testTimelineEntryBlockWiring` verifies timeline→entries→block wiring, inverse links, order indices, and the migration call.

**Verification:** `swift build` clean; full suite green (563 tests, 0 failures).

**Container-lifetime lesson (candidate for AGENTS.md):** `let context = makeContainer().mainContext` (discarding the container) leads to a SwiftData `brk #0x1` trap (EXC_BREAKPOINT, sig 5) at `context.insert(...)` **intermittently** — it passed in some builds/runs and crashed in others (offset-468 trap in SwiftData, no stderr message). Keeping the container strongly referenced (`let container = makeContainer(); let context = container.mainContext`) makes the crash deterministic-to-green across the full suite. Added `Migration.ensureTimelineDefaults` test call — must guard line numbers/counts.

**Files:** `Sources/MeCore/Models/Timeline.swift`, `Sources/MeCore/Models/TimelineEntry.swift`, `Sources/MeCore/Models/GroupTextBlock.swift` (timelineEntry reuse), `Sources/MeCore/Store/Migration+Timelines.swift` (new), `Sources/Me/AnunnakiApp.swift` (schema), `Sources/Me/Views/ContentView.swift` (launch chain), `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-13 — Sidebar reorganisation: "Dynasties" top-level group with three sub items

**Context:** User asked to reorganize the sidebar History grouping so the dynasty tools live under one top-level "Dynasties" entry instead of a "Dynasty Maps" disclosure plus a separate "Dynasties" group row.

**Changes:**
- Sidebar History section: `DisclosureGroup("Dynasty Maps")` → `DisclosureGroup("Dynasties")` (top-level item).
- The old "Dynasties" FigureGroup row moved inside the new disclosure, relabeled **"List and rulers"** (still navigates to the Dynasties group page and expands into the 20 dynasty subgroups). Added a `displayName` override to `SidebarGroupRow` so the row label can differ from `group.name`; `sidebarHistoryGroupRows` now excludes the "Dynasties" group.
- `.sklMap` raw value "Dynasty Map" → **"Map"** (SumerianDynastyMapView).
- `.dynastyEvolution` raw value "Dynasty Evolution" → **"Animation"** (DynastyEvolutionMapView).
- Result: one "Dynasties" item in the sidebar with three sub items — List and rulers, Map, Animation.

**Verification:** `swift build` clean (pre-existing warnings only). View-internal headings ("Dynasty Map", "Dynasty Evolution", "Dynasties") and App Settings labels left untouched — scope was the sidebar navigation only.

**Files:** `Sources/Me/Views/ContentView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — Fix stale-snap bug in line drawing preview

**Context:** With the new Line mode, clicking a vertex right after hovering near the start point drew the preview segment back to the start instead of to the clicked vertex — "the last line is not drawn; it snaps to the departure point".

**Cause:** `nearStart` was set on `mousemove` and then *read* by `updateLinePreview`. If it was still `true` from an earlier hover (cursor had been near the start), the click-to-add-vertex path pushed the start vertex into the preview instead of the newly clicked vertex.

**Fix (`SumerianDynastyMapView.swift` JS):** removed the shared `nearStart` state entirely; `updateLinePreview(cursorLngLat)` now computes snap distance from the passed pointer location on every call (mousemove *and* click), so each render uses the true current position. Verified: extraction + `node --check` on the emitted `<script>`, `swift build` clean, 558/558 tests pass.

**Files:** `Sources/Me/Views/SumerianDynastyMapView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — Boundary editor add "Line" (point-click) drawing mode

**Context:** The user liked the boundary editor but wanted a second, alternative gesture: click to drop corner points, with the polygon auto-closing when the cursor nears the first point — and a selector to choose between "Freehand" and "Line based polygon" (not replacing the existing freehand stroke).

**Changes:**
- **Map JS (`SumerianDynastyMapView.mapHTML`)**: added `drawStyle` (`'freehand'`/`'line'`) + `setDrawStyle()`; line mode tracks `lineVertices`; `click` drops vertices, and when ≥3 vertices exist and the click lands within `CLOSE_PX` (24 px) of the first vertex the polygon auto-closes and posts via `boundaryDrawn` (`finishLine`). `mousemove` in line mode renders a live polyline preview to the cursor and snaps it visually closed (preview includes the first vertex) while near the start; a new `boundary-vertices` GeoJSON source + circle layer draws red/white dots at each placed vertex. `setDrawMode(false)` and switching style clear line state. Freehand mousedown now guards `drawStyle !== 'freehand'`.
- **Map representable**: new `drawStyle: BoundaryDrawStyle` prop (default `.freehand`, so the dynasty page is unaffected) with `Coordinator.lastDrawStyle` diffing → `setDrawStyle(...)`; reload branch resets both. `BoundaryDrawStyle` enum (freehand/line, `displayName`) defined in `SumerianDynastyMapView.swift`.
- **Editor (`PlaceBoundaryEditorView.swift`)**: segmented Picker (Freehand | Line, 150 pt, disabled until Draw mode on) in the footer; style flows into the map; Draw-mode help text adapts to the selected style.
- Verified: the emitted `<script>` was extracted and `node --check` passed (Swift interpolation lines neutralized via balanced-paren scan); 558/558 tests pass, build clean.

**Notes:** auto-close requires a click while hovering near the first vertex (preview snaps closed as a hint) rather than closing on mere proximity — avoids accidental closes while passing near the start. A mid-stroke draft can be abandoned by toggling Draw mode off (clears vertices/preview).

**Files:** `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/PlaceBoundaryEditorView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — Dudael territory ring authored

**Context:** Following the "no territory yet" workflow fix, the user asked for a pre-authored Dudael ring.

**Change (`Migration+PlaceBoundaries.swift` + test):** added a coarse `"dudael"` ring — the Enoch wilderness east of the Dead Sea — spanning the Jordan rift + Moab desert plateau (lon 34.8–36.9, lat 30.6–32.4; contains Dudael's stored center (35.25, 31.56), the Dead Sea, Amman, Jerusalem, Hebron; Petra south of the wilderness correctly excluded). Landmark added to `testEnsurePlaceBoundariesBackfillsRegions`. 558/558 pass.

**Files:** `Sources/MeCore/Store/Migration+PlaceBoundaries.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — Territory card shows for boundary-less places

**Context:** The user asked what to do with places that have no territory yet (e.g. Dudael) — the Territory card (and its "Edit boundary…" button) only rendered once a boundary existed, so there was no way to reach the editor for a boundary-less place.

**Change (`PlaceDetailView.swift`):** the Territory card now renders for every place that has stored coordinates — if a boundary exists it shows the silhouette + source caption as before; otherwise it shows an "No territory boundary yet. Use Edit boundary…" hint. The Edit button is always present (coordinates only). Places without coordinates (cosmic/legendary, stored 0,0) keep the existing NoCoordinates map view and still can't be drawn, since drawing needs a map vantage point.

**Files:** `Sources/Me/Views/PlaceDetailView.swift`, `docs/SESSION_LOG.md`. Build clean, 558/558 tests pass.

---

### 2026-09-11 — Era territory boundary editor (dynasty boundaries), shared with places

**State:** `swift build` clean, **558/558** tests pass. No store/schema change.

**Context:** Following the place boundary editor, the user asked for the same draw-save editor for dynasty `Era.boundaryGeoJSON`.

**Changes:**
- **`PlaceBoundaryEditorView.swift`** refactored into three pieces: generic `BoundaryDrawEditorView` (all shared UI/state — header, OHM map in draw mode, zoom buttons, Draw/Discard/Clear/Cancel/Save footer, AppStorage prefs) driven by content-agnostic props (`title`, `subtitle`, `mappable`, `capitalIndex`, `boundaryColorHex`, `currentBoundaryGeoJSON`, `canClear`, `mapID`, `onSave`, `onClear`); a thin `PlaceBoundaryEditorView` wrapper (place marker, place-type color, persists to `storedBoundaryGeoJSON`); and new `EraBoundaryEditorView` wrapper (orange color, members of the era's dynasty group marked via `@Query` → `group.directPlaces`, persists to `era.boundaryGeoJSON`). `Color(hex:)` reused for the header accent (not re-declared).
- **`EraDetailView.swift`**: new "Territory" card — "Edit boundary…" button (always), `PlaceSilhouetteView` when a boundary exists, hint text when none — plus `.sheet` presenting `EraBoundaryEditorView`.

**Notes:** Era drawings replace the authored dynasty territory for that era; `ensureDynastyBoundaries` preserves closed, non-degenerate stored boundaries (drawings win, slivers/dots repaired), and Clear restores the authored default on next launch. Both editors share one code path, so future entity flavors (e.g. group boundaries) are thin wrappers.

**Files:** `Sources/Me/Views/PlaceBoundaryEditorView.swift`, `Sources/Me/Views/EraDetailView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — In-app place boundary draw-save editor

**State:** `swift build` clean, **558/558** tests pass. No store/schema change — writes the existing `Place.storedBoundaryGeoJSON` via the launch-migration-safe mechanism.

**Context:** The dynasty map's draw mode already existed but was inert: the JS captured rings and posted `boundaryDrawn`, yet Swift registered only `placeClicked`, so every stroke was silently discarded. This session wired it up and built a focused sheet editor for place territories.

**Changes:**
- **`SumerianDynastyMapView.swift`** (`DynastyHistoricalMapView`): added `drawMode: Bool = false` + `onBoundaryDrawn: (([[Double]]) -> Void)?` (both defaulted → existing call sites unaffected). `makeNSView` now also registers a `boundaryDrawn` message handler; `Coordinator` decodes the `[[lon,lat]]` ring body (defensive `[NSNumber]` bridging, ≥3 points) and forwards it. `updateNSView` diffs `drawMode` against the coordinator's `lastDrawMode` and pushes `setDrawMode(true/false)`; the reload branch resets `lastDrawMode = false` so a post-reload re-enable is safe.
- **New `PlaceBoundaryEditorView.swift`**: a 640×560 sheet wrapping `DynastyHistoricalMapView` (single place, capitalized marker, its place-type color as boundary color, no era/date filter, no Sumer ring, animations off). Toggle "Draw mode" (`.toggleStyle(.button)`) enables freehand capture; the drawn ring is mirrored into `displayGeoJSON` immediately (the JS already `setBoundary()`s the live polygon + shows dashed preview). Footer: Discard stroke (resets pending ring), Clear (nils `storedBoundaryGeoJSON`), Cancel, Save boundary (closes the ring via `Migration.polygonGeoJSON`, writes `place.storedBoundaryGeoJSON`, saves, dismisses). Header notes whether the current boundary is inherited (from an era) or hand-drawn. Only reachable for places with coordinates (nil `capitalIndex`/marker handling avoided).
- **`PlaceDetailView.swift`**: Territory card header gained an "Edit boundary…" button (coordinate-guarded) + `.sheet(isPresented: $showBoundaryEditor)`.

**Notes:** The editor reuses the OHM historical engine with the user's dynasty-map AppStorage prefs (theme/language/label size), so it feels like the rest of the app; the drawn ring is honored verbatim (never repaired) — closing is done at serialization, matching the `saveBoundary` closing behavior. A follow-up could add the same editor to `Era.boundaryGeoJSON` (dynasty boundaries) with a per-era map.

**Files:** `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/PlaceBoundaryEditorView.swift` (new), `Sources/Me/Views/PlaceDetailView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — Region place boundary profiles (Mesopotamia, Cedar Forest, Dilmun, Lebanon + a broader region set)

**State:** `swift build` clean, **558/558** tests pass (+5 for region boundaries). Additive only — no reseeding, no schema-affecting change beyond an optional stored column added by lightweight migration.

**Context:** User asked whether the dynasty-boundary silhouette mechanism could cover region-type places (Mesopotamia, Cedar Forest, Dilmun, Lebanon) whose borders are fuzzy. Chose "Plumbing + author the 4". Verified all four actually exist in the live store (`~/Library/Application Support/Me/Me.store` — only "Cedar Forest" is in `seed_data.json`; Mesopotamia/Dilmun/Lebanon are user-created). Drawing a region can't ride the derived group→era chain (regions aren't dynasties), so it needed a stored override. There is **no in-app boundary editor**: the dynasty map's draw mode posts `boundaryDrawn` but Swift registers only `placeClicked` — the JS handler silently no-ops (drawings were always discarded).

**Changes:**
- **`Place` model** (`Place.swift`): new migration-safe optional `storedBoundaryGeoJSON` (hand-authored override). `boundaryGeoJSON` (unchanged API) is now **effective**: stored wins, else the inherited dynasty wing from a linked group's era. `boundarySourceEraName` still reports the era for the inherited case; nil when hand-authored.
- **New `Migration+PlaceBoundaries.swift`**: `placeBoundaryRings` — coarse hand-authored `[[lon,lat]]` polygons for the four regions, georeferenced to known landmarks, intentionally fuzzy: Mesopotamia (outer ring touching Assur/Nineveh north, Zagros foothills east, Shatt al-Arab + Persian Gulf head south, Syrian-steppe edge west — verified to contain Babylon, Baghdad, Ur, Uruk, Nippur, Mari, Assur, Nineveh), Cedar Forest (Lebanon/Amanus cedar belt, contains the Cedars of God), Dilmun (Bahrain island + the Gulf's SW shore/Al-Hasa), Lebanon (rough modern bounds containing Beirut + Baalbek). `ensurePlaceBoundaries(context:)` mirrors `ensureDynastyBoundaries`: backfills once, additive + idempotent, honors valid closed non-degenerate existing boundaries (`decodedRing`/`ringAreaSq`/`ringMinAxisDegrees`/`sliverMinAxisDegrees` reuse), repairs slivers. **Ring convention is `[lon, lat]`** (same as dynasty rings) — first draft was `[lat,lon]`, caught by `pointInRing` tests.
- **`ContentView`**: `Migration.ensurePlaceBoundaries(context:)` runs in the launch migration chain right after `ensureDynastyBoundaries`.
- **`PlaceDetailView`**: Territory card caption now distinguishes "Hand-authored territory boundary" (stored) from "Territory boundary inherited from {era}". Silhouette + map overlay read the effective `boundaryGeoJSON` and are unchanged.
- **Tests** (+3): `testStoredPlaceBoundaryWinsOverInherited`, `testEnsurePlaceBoundariesBackfillsRegions` (each ring closed + contains its landmark via `pointInRing`, unlisted place untouched), `testEnsurePlaceBoundariesNeverOverwrites`.
- **Expansion pass (user: "yes please do…")**: authored 8 more region rings — Upper Mesopotamia (Jezirah/Assyria tier, contains Harran), The Southern Mesopotamian Marshes (Hawizeh/Hammar), Gutium (Zagros zone, contains Sulaymaniyah), Magan (Oman peninsula, contains Muscat), Meluhha (Indus, contains Mohenjo-daro), Elam (Susiana, contains Susa), Subartu (northern highland arc, contains Mardin), Amurru (western highlands/Syrian steppe, contains Palmyra). Elam/Subartu/Amurru places don't exist in the store yet — the migration keys are forward-compatible and backfill automatically once such a place is created. Skipped as unbounded/mythical: Gu-Edin, Dudael, Aratta, Mesopotamian canals. Landmark set in the backfill test extended to all 12.

**Follow-ups (open):** same mechanism could cover other vague-region places already in the store — Upper Mesopotamia, The Southern Mesopotamian Marshes (Hawizeh/Hammar), Elam, Gutium, Subartu, Amurru, Magan, Meluhha — and an in-app place-map editor (wire the existing draw mode) that writes `storedBoundaryGeoJSON`.

**Files:** `Sources/MeCore/Models/Place.swift`, `Sources/MeCore/Store/Migration+PlaceBoundaries.swift` (new), `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/PlaceDetailView.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — Place territory silhouettes (featured: dynasty borders on places) + association-card work (above)

**State:** `swift build` clean, **555/555** tests pass (+2 new). No schema change — the silhouette is a **derived** attribute, resolved through the existing group→era chain.

**Context:** User asked whether the dynasty border silhouettes (drawn GeoJSON territory rings first added for `Era.boundaryGeoJSON`) could become a Place attribute. Chose: **auto-inherit** from the era of a linked dynasty group (no manual authoring), displayed **on the place's map overlay AND in a plain (non-map) view**.

**Changes:**
- **`Place` model** (`Place.swift`): computed `boundaryGeoJSON` + `boundarySourceEraName`, both through a private `boundarySilhouette` helper that walks `place.groupAssociations → group.era.boundaryGeoJSON`, returning the first non-empty polygon (+ that era's name). No stored field, zero migration risk.
- **Map overlay** (`MapPreview.swift`): `mapHTML(for:)` now injects `place.boundaryGeoJSON`; a `map.on('load')` block adds `place-boundary` GeoJSON source + fill (0.22) + line (3px) layers in the place-type color (`.hex` extension). Reuses exactly the layer pattern from `SumerianDynastyMapView`.
- **Plain-view silhouette** (`PlaceSilhouetteView.swift`, new): SwiftUI `Canvas` drawing the exterior ring equirectangularly (fit-to-box, padded), filled 0.18 + stroked, given a plain `String` input + `Color` — usable in any non-map context.
- **`PlaceDetailView`**: new "Territory" section (shown only when a boundary resolves) — 120×84 silhouette beside a caption "Territory boundary inherited from {era name}", placed just above the "Map" card.
- **Tests** (+2): `testPlaceBoundaryInheritsEraFromGroup` (era→group→place chain resolves; source era name correct) and `testPlaceBoundaryNilWithoutDynastyGroup` (group without era → nil).

**Note for the user:** silhouettes appear for a place only once it's a member of a group whose era has a boundary (the seeded dynasty groups currently contain kings+events, not places). Adding a place to such a group via the Groups card or event propagation immediately gives it a silhouette + map overlay. Follow-up if wanted: a capital-based migration linking dynasty capitals to their era groups.

**Files:** `Sources/MeCore/Models/Place.swift`, `Sources/Me/Views/MapPreview.swift`, `Sources/Me/Views/PlaceSilhouetteView.swift` (new), `Sources/Me/Views/PlaceDetailView.swift`, `Tests/MeCoreTests/MeCoreTests+Groups.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-11 — Association cards: edit buttons + two-line wide-width-safe rows

**State:** `swift build` clean (pre-existing warnings only), **553/553** tests pass. No schema change.

**Context:** User noticed two issues in the detail-view association cards: (1) they were effectively delete-only with near-zero editing — a typo in an alias meant delete-and-re-add; (2) rows were flat single-line `HStack`s with no `lineLimit`/truncation, so narrow window widths overflowed instead of reflowing.

**Why it was inconsistent:** the standalone management views (`AlternateNameListView`, `AssociationsView`, `RelationshipListView`) already had full CRUD with edit forms (e.g. `AlternateNameFormView` took an optional `AlternateName?` for edit mode). The section cards just never surfaced the edit action; `ContentAttributionSection` was the sole card with `onAdd`/`onEdit`/`onDelete` callbacks.

**Changes — shared 2-line row pattern (identity + actions on line 1, metadata on line 2, `.lineLimit(1)`+`.truncationMode(.tail)` on primary text):**
- **Aliases** (`AlternateNamesSection.swift`): new shared `AlternateNameCardRow` (name + tradition + pencil + trash on L1; nameType + note on L2). Added pencil → `AlternateNameFormView(alternateName:)`. PlaceDetailView inline alias block switched to the same shared row + own `editingAltName`/sheet.
- **Citations** (`CitationListSection.swift`): new shared `CitationFormSheet` (add/edit, used for figure/place/event); `CitationListRow` upgraded to 2-line + pencil (source on L1, location + note below); `CitationListSection` + `CitationsSection` (figure) both own edit state + `.sheet(item:)`. FigureDetailView's private `AddCitationSheet` deleted, replaced by `CitationFormSheet(entityType: .figure, linkedEntityName:)`.
- **Attachments** (`SourceListView.swift`): `AttachmentFormView` now takes `attachment: Attachment?` + `source: Source?` (edit mode loads + writes back), rows 2-line (title L1, type badge + note + url below) with pencil + delete.
- **Places** (`FigurePlaceAssociationRow` in `FigureDetailInfoView.swift`): role badge + source moved to L2 with icon indent; place name truncates. Existing inline comments editing untouched.
- **Groups** (`GroupsSection.swift`, `EntityGroupsSection.swift`): group name L1 + note L2 indented under icon.
- **Pantheons** (`PantheonsSection.swift`): name L1, "as `<alias>`" TextField moved to L2.
- **Place↔Place** (`PlaceDetailView.swift` relatedPlacesSection): direction words L1 (truncated), role badge + source L2.
- **ContentAttribution**: tightened source-line texts with `lineLimit(1)` + tail truncation.

**Files:** `Sources/Me/Views/AlternateNamesSection.swift`, `Sources/Me/Views/PlaceDetailView.swift`, `Sources/Me/Views/CitationListSection.swift`, `Sources/Me/Views/CitationsSection.swift`, `Sources/Me/Views/FigureDetailView.swift`, `Sources/Me/Views/SourceListView.swift`, `Sources/Me/Views/FigureDetailInfoView.swift`, `Sources/Me/Views/GroupsSection.swift`, `Sources/Me/Views/EntityGroupsSection.swift`, `Sources/Me/Views/PantheonsSection.swift`, `Sources/Me/Views/ContentAttributionFormView.swift`, `docs/SESSION_LOG.md`.

**Deferred** (edit forms for these remain in `AssociationsView`/`RelationshipListView`, cards still delete-only): figure↔place role/confidence/source full-form edit, place↔place, event↔place, thing associations, figure↔figure relationship rows (detail card), event-entity group note editing. Same 2-line + pencil treatment can be applied when their edit forms are wanted inline.

---

### 2026-09-10 — Causal Chain Diagram + Knowledge Gap Heatmap (queue complete) + viz polish + hang hardening

**State:** `swift build` clean (one pre-existing `PlaceListView` `as?` cast warning, untouched), **553/553** tests pass. No schema change. The five-idea visualization queue from 2026-09-09 is now fully shipped (Pantheon Power, Dynasty Evolution, Event Trail, Causal Chain, Knowledge Gap Heatmap).

**Pantheon Power Map polish** (`PantheonPowerMapView.swift`): user approved growing the sunburst; radii scaled 29% to `SunburstRadii(101, 191, 194, 271, 273, 351)` (was `78,148,150,210,212,272`) for iteration. Fixed the deprecated `.onChange(of:perform:)` to the macOS 14 two-parameter closure (`{ _, newSize in … }`). **Sheet close-button convention** applied to `PantheonFigureSheet`: content wrapped in `NavigationStack`, `ToolbarItem(placement: .cancellationAction)` `Button("Close") { dismiss() }`, fixed 840×680 frame.

**Event Trail sidebar icon:** `"route"` didn't render visibly → `NavigationItem.eventTrail.icon` = `"arrow.triangle.2.circlepath"`.

**History sidebar grouping:** Dynasty Map + Dynasty Evolution nested under `DisclosureGroup("Dynasties")` in the History section (The Me's stays standalone).

**Causal Chain Diagram** (`CausalChainDiagramView.swift`, new): Event↔Event associations (caused/motivated/precedes/contradicts/parallels) drawn as a layered left-to-right DAG on a `Canvas`. Layout = longest-path ranks (≤ node-count iterations), barycenter column ordering ("previous column's row" otherwise sortName), 6 smoothing passes clamping to column row slots; bezier edges with arrowheads + role labels (only when dx ≥ 130, parallel duplicates offset 7 pt), hover dims non-neighbors. Node cards = era-color fill/rail, event-type icon, date·era subline. Role filter chips toggle `hiddenRoles`; unlinked events render as a side-panel list (never drawn on canvas). Chains assembled via union-find + Kahn topological order (sortName tiebreak, DAG leftover appended). Clicking a node or a row opens a details pane; "Open Detail" → `CausalChainEventSheet` (fetch by `PersistentIdentifier`, `EventDetailView` in NavigationStack + Close button). **Live-store quirk:** all 5 seeded associations have NULL role type → falls back to `"Related To"`/gray.

**Main-thread hang investigation (user-reported beach ball, 12:56):** all hang reports (`…-123943`, `…-125620`, Sep 5–9) sample the main thread **idle** — the ≥3 s stall always recovered before the 5 s `sample` ran, so no capture holds the guilty stack. The stall is transient/recurring and predates today's views, so it is not provably the Causal Chain. Even so, `CausalChainDiagramView` was hardened against the exact stall class this project has fixed twice already: `CausalCanvasView` was extracted to **own `hoveredID` + canvas size**, so hover no longer invalidates the parent's 160-row side panel; both side lists switched to `LazyVStack`; the dead `@Query allEventTypes` was removed. Follow-up: if a future capture connects with a busy main thread, the real stack will finally be visible.

**Knowledge Gap Heatmap** (`KnowledgeGapHeatmapView.swift`, new, closing the queue): entity-coverage matrix — Figures / Places / Events / Sources sections, rows = entities, columns = per-kind data fields (figure: description/domain/type/birth/death/parents/children/events/places/images/alt-names/pantheon/attributions; place: +modern-loc/coords honouring `coordinatesUnknown`; event: +date/figures/places; source: +author/language/period/publication/url/attachments/citations), cells green = filled / red = gap. Column headers carry a live coverage bar + `n/N` count and sort on click (gap-first ⇄ filled-first toggle). Top bar: search filter, kind chips, **"Include exempt"** toggle (legendary/SKL auto-exempted rows are dimmed with a badge, matching `DashboardView` semantics), overall gaps/fields + %-complete pill. Click a row → the entity's detail sheet via fetch-by-`PersistentIdentifier` wrappers (`KGFigureSheet`/`KGPlaceSheet`/`KGEventSheet`/`KGSourceSheet`). Heavy derivation (`rebuild()`) runs once off the render path behind `.task` + ID-collection `.onChange` (project convention); body is pure value math. Registered as `NavigationItem.knowledgeGap` ("Knowledge Gap Heatmap", `square.grid.3x3.fill`) in `.visualizations` alongside `.pantheonPower`/`.eventTrail`/`.causalChain`.

**Files:** `Sources/Me/Views/PantheonPowerMapView.swift`, `Sources/Me/Views/ContentView.swift` (`.eventTrail` icon, `DisclosureGroup("Dynasties")`, `.knowledgeGap` case/icon/section/destination), `Sources/Me/Views/CausalChainDiagramView.swift` (new + hardening), `Sources/Me/Views/KnowledgeGapHeatmapView.swift` (new), `Sources/Me/MainThreadWatchdog.swift` (read-only: 1 s ping / 3 s threshold / 300 s cooldown — explains report cadence), `docs/SESSION_LOG.md`.

---

### 2026-09-09 — Legendary SKL dynasties join Dynasty Evolution + territory watermark

**State:** `swift build` clean, **553/553** tests pass (5 new). No schema change.

**Context:** User noticed the Dynasties list shows 20 territory dynasties but the Evolution playback only plays ~9–10, and asked what happened to the rest.

**Root cause:** `rebuildRuns` needs a `startBCE`/`endBCE` per dynasty (from `SKLDatePropagator`, which requires ≥1 dated king as anchor). The ten "missing" dynasties (Kish I, Uruk I, Ur I, Awan, Kish II, Hamazi, Uruk II, Ur II, Adab, Kish III) are the legendary early dynasties — every king carries a listed *mythological* reign (Kish I alone sums ~18,000 yrs) and **zero** BCE dates, so they were dropped despite having territory. Not a drawing failure.

**Decision (user approved "Compress to real windows"):** New migration `ensureLegendaryDynastyWindows` pins each dynasty to a conventional archaeological window (~2900–2393 BCE, SKL order) and compresses its kings onto that span proportionally to their listed reigns via pure helper `fitLegendaryWindow(shares:earliestBCE:latestBCE:)`. Writes per-king `birthDate`/`deathDate` (`MythologicalDate`, `.computed`, approximate); era only touched while none of its kings carry a date (additive, never clobbers user data). Windows: Kish I −2900…−2550, Uruk I −2700…−2550, Ur I −2560…−2430, Awan −2550…−2470, Kish II −2500…−2430, Hamazi −2470…−2410, Uruk II −2450…−2400, Ur II −2430…−2395, Adab −2410…−2394, Kish III −2400…−2393. Axis grows to ~2900–1790 BCE. Wired in ContentView after `ensureComputedSKLDates`.
- **Info-panel "N yrs" now shows the dynasty's actual span** (`spanYears = abs(start−end)`), not the sum of listed mythological reigns (Kish I would have shown "18,000 yrs" beside a 350-year bar). `DynastyRun.totalYears` removed.
- **Right-pane territory watermark (earlier request):** Territory canvas in `infoPanel` was a fixed 110 pt box hugging the top; now fills the panel (ring scales + centers) with an XXL (88 pt, 10% opacity, rounded black) dynasty-name watermark behind the silhouette. Build clean, no warnings.
- **Follow-up visual tweaks (same day, all in the info-panel territory box):**
  1. Watermark opacity 0.10 → 0.16 ("just a tad" clearer).
  2. **Zoom pulse on dynasty change**: `@State territoryZoom` (0.86 → 1.0 spring) triggered from `.onChange(of: currentRun?.id)` via a 60 ms delayed `withAnimation` — silhouette pulls back then settles onto the new territory whenever the ruling dynasty changes (playback, scrub, filmstrip). Scoped to the Canvas only (name steady); panel `.clipShape` keeps overshoot inside the rounded rect.
  3. **Shape resized/shifted**: `drawRing` gained `shrink`/`upShift` params (0.8, +40 px up) — silhouette smaller and higher, watermark untouched.
  4. **Capital pin**: `capitalName(for:)` → `capitalPin(for:)` returns name + lat/lon (prefers the city after "of " so "First rulers of Uruk" pins Uruk, not the substring Ur). `DynastyRun` carries `capitalLat`/`capitalLon`. `drawRing` refactored onto a shared `RingProjection` so `drawCapitalPin` geo-projects the capital onto the shrunken shape: 25 px dynasty-color dot (white ring) + 22 pt heavy rounded city name beside it, flipping side/under based on available room.

**Pre-existing anomaly flagged (NOT touched):** "Dynasty of Mari" has inverted dates — first five kings (Anbu → Limer) are dated −1927…−1820 while the last king (Sharrum-iter) is −2350…−2341 — so its run bar renders as a ~0.004 sliver. This predates this session; needs a separate data-reconciliation decision.

**Files:** `Sources/MeCore/Store/Migration+EraChronology.swift` (migration + `fitLegendaryWindow`), `Sources/Me/Views/ContentView.swift` (call site), `Sources/Me/Views/DynastyEvolutionMapView.swift` (watermark panel, `spanYears`), `Tests/MeCoreTests/MeCoreTests+Migration.swift` (5 tests), `docs/SESSION_LOG.md`.

---

### 2026-09-09 — Event Trail Map (new viz) + dynasty playhead desync fix

**State:** `swift build` clean, **548/548** tests pass. No schema change.

**Context:** User loved the Dynasty Evolution playback; picked the next queued viz — Event Trail Map.

**Playhead desync fix (prelude):** In `timelineStrip` the playhead `<Rect>.offset(x: fraction*width)` sat inside a **centered** ZStack, so its center was `w/2 + fraction*width` — past the halfway point it slid off the strip entirely ("slider completely disappears"). Fixed with the same coordinate math as the year pill and drag scrub: `.frame(width: 2, height: 22).position(x: fraction*width, y: 15)` so playhead, pill, and drag all share `fraction*width`.

**Event Trail Map** (`Sources/Me/Views/EventTrailMapView.swift`, new). Concept from data reconnaissance (sqlite on `Me.store`): per-*figure* journeys are empty here — every figure joins exactly 1 mapped event — so the "trail" is a **chronological thread through events grouped by era**. Data: 114 events have mapped places, 107 have numeric years; the dated+mapped set forms era clusters (Neo-Assyrian 13, Old Babylonian 9, Ur III 5, Akkad 5, …).
- **MapKit SwiftUI `Map`** (reuses the `CityMapView` pattern, not OHM): per-era `MapPolyline` connecting each era's events in year order (consecutive duplicate stops deduped), event `Annotation` markers (small colored dots with bolt glyph, tinted by era color, deduped by place ~3dp), `.annotationTitles(.hidden)`.
- **Sweep playback**: chronologically reveals events+trails as the playhead advances (`.task(id: isPlaying)`, 100 ms tick = ~1/240th of the year axis). Default playhead = max year → full map up front; play button restarts from min. Slider scrubs; selecting a list row or marker jumps the playhead *and* pans the camera (`MapCameraPosition` region).
- **Era chips** in the top bar (colored, count badges) toggle a single-era focus; an "All" chip restores. Right pane = 320 pt chronological event list (year / name / era dot), selected row highlighted.
- Data is precomputed into plain `TrailEvent`/`TrailStop` value structs in `rebuild()` from `.task` + `.onChange(of: events.map(\.persistentModelID))` — no `@Model` faulting in the render path (per convention), so all derived trails/markers are cheap value math in `body`.
- **Follow-up (same day): swapped the Apple Maps renderer for the OHM/MapLibre historical basemap** (user: "Yes, I want the OHM map"). `EventTrailMapView.swift` no longer imports MapKit. It now hosts a self-contained `EventTrailOHMMapView` (`NSViewRepresentable`): same maplibre-gl 4.7.1 CDN + OHM `main.json` style as the dynasty maps, with the scene sent as one GeoJSON bundle over a `setScene(json)` hook. Era trails = per-era `LineString` features (colored via `['get','color']`), event markers = a `circle`-layer `Point` source (era-colored dot, white stroke, click → `eventClicked` message → selects the list row). Reveal-by-playhead and era filtering are computed Swift-side each render and pushed as a fresh scene (≤ ~10 Hz during playback; scene JSON compared in the coordinator to skip no-op updates). List/marker selection flies the camera via a `focus(lon,lat,zoom)` request (seq-incremented `TrailMapFocus`, buffered pre-load). Duplicates the maplibre bootstrap template (deliberately scoped; the dynasty template's boundary/draw/grow JS is irrelevant here) but reuses shared `HistoricalMapTheme`/enums from `SumerianDynastyMapView.swift`.

**Files:** `Sources/Me/Views/EventTrailMapView.swift` (new), `Sources/Me/Views/DynastyEvolutionMapView.swift`, `Sources/Me/Views/ContentView.swift` (new `.eventTrail` nav item, icon `route`, visualizations section, destination), `docs/SESSION_LOG.md`.

---

### 2026-09-09 — Dynasty Evolution beach-ball fix (perf)

**State:** `swift build` clean (warning-free), **548/548** tests pass. No schema change.

**Context:** On first exploration the user reported continuous beach balls in the Dynast Evolution view during playback/scrubbing.

**Root cause:** `SKLDatePropagator.compute(...)` was a computed property re-invoked **8-10× per body pass** (`runs`, `currentRun`, `infoPanel`'s king count/years, `currentRuler` each touched `timeline`, and `ForEach(runs)` in strip + filmstrip rebuilt it again). Each call re-runs `ReignLength.parse` (3 regexes compiled **per figure** from scratch) over ~134 SKL figures. During playback the view re-rendered ~10×/s and ~60×/s while dragging the playhead → essentially 100% main-thread block → beach balls. Bonus: when the playhead crossed a dynasty boundary, `boundaryGeoJSON` was part of `DynastyHistoricalMapView`'s reload signature, so each transition threw away the WKWebView and did a full MapLibre/HTML re-init (network + JS bootstrap).

**Fixes:**
1. **Memoize the heavy derivation.** In `DynastyEvolutionMapView`, replaced the `timeline`/`runs` computed props with `@State cachedRuns`, built once in `rebuildRuns()` from `.task` (initial) and `.onChange(of: dataSignature)` (data edits). `DataSignature = skl figure PersistentIdentifiers + eraOrder`, so live edits still refresh. Render path now reads only plain value structs.
2. **Precompute per-run aggregates off the render path.** `DynastyRun` now carries `reigns`, `kingCount`, `totalYears` (from `DynastyTimeline.reigns/totalYears`) so body never faults `figure.kingship` or re-computes totals.
3. **`rebuildRuns()` also snaps `currentYear` into the new bounds** (replaces the old `onAppear` clamp).
4. **No full map reloads on boundary change.** `updateNSView` sig now covers only `places` (+ nullable `defaultCenter`); boundary/color/selection changes flow through the existing lightweight `focusToken` JS path (`setCapital` + `setBoundaryStr` + `focus` + `setDate`). Also added `setBoundaryStr(\"\")` to the nil-capital branch so interregnum/overview clears a stale boundary overlay.
5. **Idle timer removed.** Playback is now a `.task(id: isPlaying)` loop (100 ms tick, `Task.isCancelled`-guarded) that only runs while playing.
6. Added a `ProgressView("Computing dynasty chronology…")` placeholder for the one-time initial compute (no more "No map data" flash while `cachedRuns` populates).

**Files:** `Sources/Me/Views/DynastyEvolutionMapView.swift`, `Sources/Me/Views/SumerianDynastyMapView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-09 — Fun data visualizations: Pantheon Power Map + Dynasty Evolution Timeline

**State:** `swift build` clean. Two new visualizations registered in the sidebar. No schema change.

**Context:** User asked for 5 fun, data-driven ideas in the spirit of the dynasty map borders; picked #4 (Pantheon Power Map) and #5 (Dynasty Evolution Timeline) in that order, and queued #1 (Event Trail Map), #2 (Causal Chain Diagram), #3 (Knowledge Gap Heatmap) on the todo list.

**Pantheon Power Map** (`Sources/Me/Views/PantheonPowerMapView.swift`):
- Sunburst: 3 rings center→out = Pantheons → Domains → Figures, slice area proportional to a "power" weight, 3 metrics (`Power` = 1 + 2×relationships + events + places + aliases + images; `Relationships`; `Balanced`).
- Value tree (`PowerPantheon`/`PowerDomain`/`PowerFigure`) built off the render path from `@Query` (same pattern as `TagCloudView`); `Canvas` draws parametric annular sectors with centroid labels auto-hidden when a slice is too thin to fit.
- Hover → brighter fill + tooltip (name, type, breakdown); tap a figure → `FigureDetailView` sheet by `PersistentIdentifier`; tap a pantheon → focus it (re-layout to full circle); side panel = pantheon legend (click to focus) + figure-type legend.
- Registered as `NavigationItem.pantheonPower` ("Pantheon Power", `circle.hexagongrid.fill`) in `.visualizations`.

**Dynasty Evolution Timeline** (`Sources/Me/Views/DynastyEvolutionMapView.swift`):
- Play/pause playback over the BCE year axis (slow/normal/fast) reusing `DynastyHistoricalMapView`; the playhead drives both the map and the OHM date filter so the basemap itself changes as you scrub.
- Reuses existing app settings keys (`dynastyMapHistoricalStartupZoom/Theme/Language/LabelSize`); new `dynastyEvolutionDateFilter` toggle.
- **Dynasty strip** below the map: color-coded per-dynasty bars proportional to reign span with a draggable playhead + tap/drag scrubbing + live "c. X BCE" pill.
- **Territory filmstrip**: horizontal row of mini boundary-polygon thumbnails (parsed from `Era.boundaryGeoJSON`), current dynasty highlighted, click to jump; info panel shows ruling king at the playhead (opens quicklook).
- Registered as `NavigationItem.dynastyEvolution` ("Dynasty Evolution", `film.stack`) in `.history` next to `sklMap`.
- Enhanced `DynastyHistoricalMapView`: `dateString` changes now apply incrementally via `setDate(...)` in `updateNSView` (tracked in `Coordinator.lastDateString`) instead of requiring a full HTML reload — enables live basemap evolution during playback.

**Gotcha worth remembering:** `Era.boundaryGeoJSON` rings are `[Double]` pairs, not tuples — use `$0[0]`/`$0[1]`, not `\.0`/`\.1` (compiler refused the key path form).

**Follow-up (same day), user feedback once it actually played:** three more issues surfaced:
1. **Antediluvian mega-bar.** The dated antediluvian kings carry fixed BCE years (−269,200…−46,600), so the `Antediluvian Period` run owned ~222,000 of the ~224,000-year axis; every real dynasty was a 1-2px sliver and the playhead parked in a territory-less bar (hence "the map is static / No territory drawn"). Fix: `rebuildRuns` now skips any run without a `boundaryGeoJSON` territory — only territorial dynasties (the 12 dated SKL dynasties) appear, and the map/territory panel are populated from the very first frame.
2. **Strip vs. playhead misalignment.** The strip was an `HStack` that concatenated run bars in era-order (∑spans ≈ 2.3× the width → overflow/clip), while the playhead positions by absolute year — so after the first dynasty every bar was off-screen or misaligned and playback "zipped past" invisible dynasties. Fixed by positioning each bar absolutely: `startFrac…endFrac` years → x/width, with a base layer so interregnum gaps read as a subtle shade instead of white void; run names hidden below ~46px.
3. **Overlap disambiguation.** Because Mari (−2350…−1820) chronologically overlaps every later dynasty, first-index matching always resolved to Mari → the map showed Mari's border for 88% of playback. `currentRunIndex` now picks the *most recently established* dynasty covering the year (`max startBCE` among covering runs): Akshak → Uruk III → Kish IV → Akkad → Gutian → Uruk IV → Ur III → Isin…
4. Also fixed: `setBoundaryStr` now renders in the nil-capital JS branch (so a dynasty with a territory but no matched capital place, e.g. "Gutian rule", still draws its border on the map when you scrub into it).

**Follow-up (same day):** playback recalibration + custom numeric speed. Speeds were ~2-3× too fast for the ~600-year axis; recalibrated Slow 20 / Normal 60 / Fast 150 yr/s (old "Slow" ≈ new Normal). Added a `Custom` segment to the speed picker that reveals an inline `yrs/s` numeric field (`@AppStorage dynastyEvolutionCustomSpeed`, clamped 5…2000, applied live during playback via `playRate`). `playSpeed` moved from `@State` to `@AppStorage`-backed computed property (`nonmutating set` + explicit `Binding` for the `Picker`).

**Follow-up (same day):** territory grow-from-center animation. `DynastyHistoricalMapView` gained `animateBoundaryTransitions` (default true); the JS boundary swap now calls `animateBoundaryTo(geojson, 650)` which grows the polygon from its centroid outward with cubic ease-out (`growRing`, rAF per-frame `setData`). Boundary updates are buffered (`pendingBoundary`/`pendingBoundaryAnimate`) if they arrive before `boundaryReady` and flushed in `onLoad()` — this also fixes a latent race where a pre-load transition could be silently dropped. Evolution view has a persisted "Grow borders" toggle (`dynastyEvolutionAnimateBoundaries`).

**Files:** `Sources/Me/Views/DynastyEvolutionMapView.swift`, `Sources/Me/Views/SumerianDynastyMapView.swift`, `docs/SESSION_LOG.md`.

**Files:** `Sources/Me/Views/PantheonPowerMapView.swift` (new), `Sources/Me/Views/DynastyEvolutionMapView.swift` (new), `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/ContentView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-09 — Dating-investigation + phantom "Antediluvian" dynasty fix

**State:** `swift build` clean, **548/548** tests (545 baseline + 3 new). No schema change.

**Context:** Following the overview-mode work, the user asked why some dynasties lack from–to years. Investigation (throwaway Python replica of `SKLDatePropagator` against a copy of the real store in `/var/folders/.../T/opencode/Me.store`) showed it's a data-coverage gap, not a rendering bug: the pre-2450 BCE mythological dynasties (Kish I, Uruk I, Ur I, Awan, Hamazi, Kish II, Uruk II, Ur II, Adab, Kish III, Kish IV) have *no king* with an explicit date — every king carries only a mythological reign length ("Reigned 1,200 years (mythological length)") and empty `ZSTARTYEAR`/`ZENDYEAR1`. `SKLDatePropagator` needs at least one anchored king per dynasty to walk the reign-length chain; the first anchored block starts at the Dynasty of Akshak (−2392) / Akkad (Sargon −2360). Verified concretely: Kubaba, Gilgamesh, Jushur all have empty date columns.

**The bug found along the way:** a stray 1-king "Antediluvian" dynasty row (Mesh-ki-ang-gasher). His `birthDate.era` was seeded empty, so the null-era fallback bucket swallowed him even though the SKL lists him as the founder of the *First rulers of Uruk* block.

**Change:**
- New `Migration.ensureMeshKiAngGasherEra(context:)` in `Migration+SKLAndGenealogy.swift`: assigns `birthDate.era = "First rulers of Uruk"` when the key matches and the era string is empty (additive + idempotent; never overwrites an existing/user-set era).
- Registered in the `ContentView` seeding chain *between* `enrichSKLData` and `ensureComputedSKLDates` so the timeline recomputation in the same launch no longer produces the phantom dynasty.
- Distinct-era-preservation test + idempotency test + happy-path test added to `MeCoreTests+Migration.swift`.

**Gotcha worth remembering:** `seedNameKey("Mesh-ki-ang-gasher")` is `"meshkianggasher"` — the hyphen-strip concatenates "ang"+"gasher" into a *doubled `g`*. First draft compared against `"meshkiangasher"` and silently matched nothing (2 test failures caught it).

**Files:** `Sources/MeCore/Store/Migration+SKLAndGenealogy.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests+Migration.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-09 — "Dynasties" living-map feature: authored territory polygons + overview-with-hover

**State:** `swift build` clean, **545/545** tests. No schema change.

**Context:** User wanted the "Dynasties" History page (and the Dynasty Map) to "bring the data to life". Investigation found a gap: the authored SKL territory rings (`Migration.ensureDynastyBoundaries` → `Era.boundaryGeoJSON`) and the engraving JS boundary renderer already existed, but nothing threaded them together — the map showed cities but no territories.

**Changes (all in the shared `DynastyHistoricalMapView` engine + two call sites):**
- **Territory rendering**: new `boundaryGeoJSON` param; filled territory + solid 4px outline drawn in the dynasty color. Wired from `SumerianDynastyMapView` (selected dynasty) and `GroupEraMapView` (the group's era). `Era.boundaryGeoJSON` initial fill is embedded in the HTML; dynasty switches repaint via `setBoundaryStr` + recolor via `setCapital` paint update (no page reload).
- **"No dynasty selected" overview**: `selectedDynastyIndex` became `Int?` (dropdown gains a nil entry). In overview mode the info panel lists all dynasties in SKL ruling order with color swatch + date span; clicking one selects it (detail panel). Camera flies back to the Mesopotamia home region when nothing is selected (`focusDefault`, `INITIAL_INDEX === -1` path on reload).
- **Hover preview**: hovering an overview row draws that dynasty's territory border in the same **solid width-4** style as a selected dynasty's border (via the long-dormant `boundary-preview` layer, `setPreviewBoundaryStr` + `pendingPreview` replay on load), colored per dynasty. The first iteration used a dashed 3px outline, which users read as "the border became thin and dotted" — the preview now matches the committed border styling exactly.

**Regression hunt:** a stale hover could bleed a preview line over a committed territory's border when a hover survived into selected mode. Fix contributed two rules: `hoveredBoundaryGeoJSON` is gated to overview mode (`selectedDynastyIndex == nil`), and the row's `Button` clears the hover before selecting. The preview update block no longer short-circuits the focus path. Border is back to solid dynasty-color 4px.

**Key decisions:**
- Preview reuses the existing `boundary-preview` source/line layer (dashed) instead of a new layer; `boundaryGeoJSON` overloads the main `boundary` source.
- Boundary switches intentionally trigger a full HTML reload when signature changes (fresh `capitalIndex`/`capitalColorHex`/center/date all rebuild together); per-dynasty-day-territory paints the *lightweight* path is JS-only for the common picker case.
- Default startup state is now overview (nil selection) — discovery-first.

**Files:** `Sources/Me/Views/SumerianDynastyMapView.swift`, `Sources/Me/Views/GroupEraMapView.swift`, `docs/SESSION_LOG.md`.

---

**State:** No code change (working tree clean at `c7ac653`). 542/542 tests from the prior entry stand.

**Context:** Follow-up to the cold-boot timeout / truncation fixes. User rebooted the Mac, then asked the app "what was the population of Babylon" as the very first question against a freshly loaded Ollama.

**Result:** The first query returned a full, complete answer — an honest refusal ("the database does not provide information on the population of Babylon") followed by the DB-adjacent events summary and a general-knowledge caveat — instead of the pre-fix behavior (URLError timeout, or a truncated answer stopping at the refusal boilerplate). Warm-up → stream → retry pipeline held on a genuine cold boot; no throwaway first question.

**Files:** `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Ollama cold-boot timeout: long-timeout session + retry for the real query

**State:** `swift build` clean, **542/542** tests. No schema change.

**Problem (follow-up):** after a full Mac reboot, the very first Ollama question still showed "The request timed out" (URLSession's `URLError.timedOut`), while follow-ups worked. Two compounding bugs:
- The **warm-up** rode a 300s `warmupSession`, but the **real query** rode the 60s `session` — and worse, `sendPromptAsync` set `request.timeoutInterval = timeout` (60s), which overrides the session config. A large-context prompt after a cold boot can exceed 60s before its first token; streaming only resets the idle timer once tokens begin, so the pre-first-token window could still trip the 60s cap.
- `resolveAsync` only retried *truncated* answers, not transport errors.

**Fix (OllamaResolver):**
- One `generationSession` (request 300s / resource 600s) now serves both the model warm-up and real `/api/generate` calls; `sendPromptAsync` sets `request.timeoutInterval = 300` so the per-request value no longer overrides the session.
- `resolveAsync` retries once on any transport error string (`"Error: …"`) as well as on truncated/refusal-only answers. By the second attempt the model is warm, so the first question after a reboot is no longer a throwaway.

**Files:** `Sources/MeCore/Store/OllamaResolver.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Ollama first-answer truncation: full-paragraph warm-up + auto-retry on weak answers

**State:** `swift build` clean, **542/542** tests. No schema change. Live-verified: warm-up now returns a 533-char paragraph (was a 1-word reply).

**Problem (follow-up):** after round 2 (streaming) the first question no longer timed out, but it returned a *truncated* answer — just the boilerplate refusal ("The database doesn't have this information.") with no follow-through. The identical query on the second attempt returned the full, helpful reply. Cause: the warm-up asked for one word (`num_predict: 2`), so the model's first *sustained* generation was the user's real query — and a freshly loaded model can truncate its very first sustained answer.

**Fix (OllamaResolver):**
- `warmUpModel()` now asks for a real 3–4 sentence paragraph about Ur (`num_predict: 120`), so the model's first sustained generation happens during warm-up, not on the user's question.
- `resolveAsync` retries once automatically when the answer looks truncated: a short (<160 chars) reply that stops at a refusal marker ("does not have this information", "lacks relevant information", etc.). The retry runs on the now-warm model, so the user's first try is no longer a throwaway.

**Files:** `Sources/MeCore/Store/OllamaResolver.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Ollama cold-start, round 2: stream the generation so first answers can't idle-timeout

**State:** `swift build` clean, **542/542** tests. No schema change. Live-verified against a running Ollama (streaming request returns 200 and accumulates the answer).

**Problem (follow-up):** warm-up (previous entry) helped but the first question still timed out ~9/10; the retry worked. Root cause found: `sendPromptAsync` used `"stream": false`. Ollama sends **zero bytes** until the whole answer is generated, so URLSession's `timeoutIntervalForRequest` (an *idle* timeout, 60s) killed any generation that took >60s mid-thought — warm or not. The "second try works" was the giveaway: the model had become resident and/or the response was faster, but the design was inherently racy.

**Fix (OllamaResolver.sendPromptAsync):**
- Switch to `"stream": true` and aggregate tokens line-by-line (NDJSON: `response` chunks until `done == true`), capturing any `error` field. Tokens now arrive continuously, so the idle request timer never fires and arbitrarily long generations succeed.
- Raise `timeoutIntervalForResource` to 600s (the per-token idle time is fine at 60s request timeout; only the total-transfer cap needed raising).
- Error handling returns a clear "Error: …" string on transport/HTTP failure (unchanged contract), and empty responses return nil.
- The sync `resolve` path (stream:false, protocol conformance only — unused by the UI) is left as-is.

**Files:** `Sources/MeCore/Store/OllamaResolver.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Ollama first-query cold-start: warm the model before answering

**State:** `swift build` clean, **542/542** tests. No schema change.

**Problem:** 9/10 first Ollama answers timed out. Root cause: `ensureRunning()` only waits for the *server* (`/api/tags` on port 11434); Ollama cold-loads the model lazily *inside* the first `/api/generate`, and that request carried the normal 60s timeout. The user's first real query silently paid the entire model-load latency.

**Fix (OllamaResolver):** added `prepare()` — the full readiness pipeline used by `QueryView` before any question:
- `ensureRunning()` boots the server if needed (as before).
- `refreshModelName()` re-runs model discovery now that the server is up (init-time discovery runs pre-boot and may have fallen back to the default).
- `warmUpModel()` sends a trivial generation (`"Reply with the single word OK."`, `num_predict: 2`, `keep_alive: 10m`) on a dedicated `warmupSession` with a 300s request / 360s resource timeout. Ollama blocks that call until the model finishes loading, so the cold-start cost is absorbed there — the subsequent real query finds the model resident.
- Returns an `OllamaPrepareResult` (`.ready` / `.serverUnavailable` / `.modelUnavailable`) so `QueryView` can show a specific error (e.g. missing model → "ollama pull llama3.1") instead of a generic timeout.

**QueryView:** `askOllama` now awaits `prepare()`; during model load it shows *"Starting Ollama model (name). First answer may take a moment…"*.

**Note:** model stays loaded for 10 minutes (`keep_alive`), so only genuinely cold starts pay the warm-up.

**Files:** `Sources/MeCore/Store/OllamaResolver.swift`, `Sources/Me/Views/QueryView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Query engine hardening: drop fuzzy guesswork, async Ollama handoff with auto-boot

**State:** `swift build` clean, **542/542** tests (2 new, 11 rewritten as defers-to-Ollama). No schema change, no migration.

**Context (bug):** Query "which city states operated in sumer" answered "Me". Root cause in the live DB: there is a Thing literally named "Me" (Sumerian `me`), and QueryEngine's final fuzzy fallback resolved the *whole sentence* as an entity via substring containment — `query.contains("me")` matched "Me" inside "su**me**r", returning `.thing(Me)`. Because the engine short-circuited with a confident-but-wrong answer, `.noMatch` never fired, so the (good) Ollama fallback never ran. User's framing: users cannot be expected to avoid reserved trigger words; the engine must be conservative and let Ollama answer when unsure.

**Design decision (user-approved boundary):** keep the structured layer (dossiers/lists/counts from crisp patterns), drop the fuzzy guesswork. The Ollama fallback in `QueryView` always ran on `.noMatch` — so dropping fuzzy matchers both removes wrong answers *and* lets the capable LLM handle natural phrasing.

**Dropped from QueryEngine** (deleted methods + dispatch steps): whole-sentence entity resolution (the bug), `matchYesNoQuery` (+ relationship yes/no, entity-type checks), `matchDomainQuery`, `matchEraQuery`, `matchStructuredQuery` (token entity extraction + intent classify), embedding synonym matcher (`bestEmbeddingMatch`/`cosineDistance`, "kids"→children), `matchFallbackQuery` declarative templates + `executeMeasure`, `matchReignQuery`'s description-scan group fallback. Pruned dead helpers (`EntityRef`, `tokenize`, `extractEntity`, `cleanQueryText`, `classifyEntityQuery`, `labeledResults`, `resolveFigureFromTokens`, `resolveFigureByFallback`, `resolveThing` wrapper, etc.). Replaced final resolution with `exactEntityMatch(_:)` — canonical/alternate name equality only, never substring-of-sentence. Kept crisp features working: relations, possessives, listings, gender, counts, reign/duration exact, images, prefix-stripped exact names; extended `matchHowManyQuery` to the natural "how many X did Y have" word order; added missing "creators of " plural prepositional prefix. ~1730 → ~890 lines.

**Ollama engagement (OllamaResolver):** `isReachableAsync()`, `ensureRunning(maxWait:)` (probe → launch `open -a Ollama` → poll up to 25s). Model preference stays: `discoverModel` already prefers llama3.1, falls back to auto.

**QueryView:** `runQuery` no longer wires a blocking sync resolver into the engine. On engine `.noMatch` (or `forceLLM`) it calls `askOllama(bootMessage:)` asynchronously: shows *"Cannot answer query. Booting Ollama for an answer. Please wait…"* with a spinner, ensures Ollama running (booting if needed), then `resolveAsync`; failures show a clear error instead of silently hanging (previously the sync semaphore blocked the main thread).

**Tests:** 2 new regressions (`testWholeSentenceDoesNotResolveEmbeddedShortEntityName`, `testExactThingNameStillResolves`); 11 rewritten to assert `.noMatch` for the removed matchers (`…DefersToOllama` variants); creators + natural how-many still pass.

**Files:** `Sources/MeCore/Store/QueryEngine.swift`, `Sources/MeCore/Store/OllamaResolver.swift`, `Sources/Me/Views/QueryView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Composition decide-gate: Kingship stays at the value layer (HOLD, no escalation)

**State:** Discussion + assessment only — no code changed. **540/540** tests remain green.

**Decision:** Do **not** escalate `Kingship` to a real `@Model KingshipProfile` facet. The composition-by-accessor value layer (steps 1–3 above) has proven sufficient for the Kingship role. User accepted the hold.

**Evidence for holding:**
- Value layer already centralizes display (`reignSpanLabel`), the prose-fallback (`effectiveReignYears`, killing 5 duplicated `reignYears ?? ReignLength.parse` sites), presence semantics, and two clean whole-role writers (`updateKingship`, `adoptMissingKingshipFields`).
- Remaining direct column touches are column-level *by nature*, not gate failures: `ConsistencyEngine` validation arithmetic, `DashboardView` coverage metric (different question: "has listed-reign field" ≠ `kingship == nil`), one-shot migration/import backfills, `FromTextRecognizer` field-level undo.
- **Decisive:** additive-only migrations mean a facet would not slim `Figure` — old columns stay on the row regardless, yielding two synchronized representations (dual-write risk, relationship faulting, extra migration) to buy only one capability the value layer lacks.

**The one thing a facet would buy:** kingship as a `@Query`/`#Predicate` discriminator (query "all figures with a reign" from data). No current feature needs this — king lists identify figures via `source` or in-memory filter.

**Flip triggers (revisit on any):** (1) a feature needs kingship in a `@Query`/live predicate; (2) a second facet (e.g. `DeityProfile`) materializes — then the per-role accessor asymmetry becomes real cost and the hat system should go `@Model` together; (3) per-kind write invariants need one enforcement point (`updateKingship` can already host that in the value layer).

**Files:** `docs/SESSION_LOG.md` (assessment only; composition steps 1–3 stand from earlier entries).

---

### 2026-09-08 — Composition step 3: route clean-fit writers through the `Kingship` facade

**State:** `swift build` clean, **540/540** tests. No schema change, no migration.

**Change:** Added two writer methods to the `Kingship` facade and migrated the write sites whose shape matches them:
- `Figure.updateKingship(reignStartYear:reignEndYear:reignYears:)` — whole-role replace, the single write path for full kingship data. `FigureFormView` (edit + create branches) now routes through it.
- `Figure.adoptMissingKingshipFields(from:)` — adopt-if-nil merge used when collapsing a duplicate into a keeper. `DuplicateMerger`'s three `adoptOptional` reign calls now collapse to one.

**Scoping decision (user-approved):** `FromTextRecognizer` (partial/conditional writes + field-level undo comparing before/after snapshots that don't track `reignYears`) and the migration/import backfills (one-shot start/end-only writes) stay as direct column writers. Forcing them through the whole-role replace setter would clobber fields they must leave alone — not a clean fit, so they remain column-level.

**Next steps:** decide-gate — assess whether the value layer (read facade + two writers) suffices, or escalate to a real `@Model KingshipProfile` facet.

**Files:** `Sources/MeCore/Models/Kingship.swift`, `Sources/Me/Views/FigureFormView.swift`, `Sources/MeCore/Store/DuplicateMerger.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Composition step 2: migrate read sites onto `Kingship` facade

**State:** `swift build` clean, **540/540** tests (3 new). No schema change, no migration.

**Change:** Rolled the `Kingship` facade (from the step-1 entry below) across the read sites, after the user approved folding the prose fallback into the facade (`Kingship.effectiveReignYears`):
- `Kingship.swift` — added `descriptionReignYears` (resolved once by the `Figure.kingship` accessor via `ReignLength.parse` when stored `reignYears` is nil) + computed `effectiveReignYears` (`listedReignYears ?? descriptionReignYears`).
- Migrated call sites, removing the duplicated `reignYears ?? ReignLength.parse(from: figureDescription)` idiom:
  - `FigureDetailView` reign PropertyRow → `figure.kingship?.reignSpanLabel` (replaces inline `switch (reignStartYear, reignEndYear)`).
  - `SKLDatePropagator.DynastyTimeline.totalYears` → `figure.kingship?.effectiveReignYears`.
  - `FigureGroup.GroupAggregationTarget.value(for:)` (`.reignYears`) → `figure.kingship?.effectiveReignYears`.
  - `FigureGroupSmartMembers` extension `.value(for:)` (`.reignYears`) → `figure.kingship?.effectiveReignYears`.
  - `EntityGroupCollectionView.reignEntries` + `.reignDisplay` → `figure.kingship` (listed vs. prose formatting preserved via `listedReignYears`/`descriptionReignYears`).
  - `SumerianKingListView.KingRow.reignLength` → `figure.kingship`.

**Behavior parity notes:** the five prose-fallback sites previously parsed the description only when stored `reignYears` was nil; `Figure.kingship` now resolves exactly that once per access and `Kingship` stays nil when neither stored data nor parseable prose exists. Remaining direct `ReignLength.parse` callers (`SKLDatePropagator` forward/backward chain propagation, `Migration+FigureGroups` backfill writer) are legitimate non-facade uses.

**Next steps (not committed):** writers/forms (step 3 — route `FigureFormView`, `FromTextRecognizer`, `DuplicateMerger` through a facade setter), then the decide-gate (value layer sufficient vs. escalate to `@Model KingshipProfile` facet).

**Files:** `Sources/MeCore/Models/Kingship.swift`, `Sources/Me/Views/FigureDetailView.swift`, `Sources/Me/Views/SumerianKingListView.swift`, `Sources/Me/Views/EntityGroupCollectionView.swift`, `Sources/Me/Views/FigureGroupSmartMembers.swift`, `Sources/MeCore/Models/FigureGroup.swift`, `Sources/MeCore/Store/SKLDatePropagator.swift`, `Tests/MeCoreTests/MeCoreTests+Kingship.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-08 — Composition prototype step 1: `Kingship` accessor facade (MeCore)

**State:** `swift build` clean, **537/537** tests (6 new). No schema change, no migration, no behavior change — pure additive facade layer.

**Change:** First code step of the 2026-09-07 composition plan (composition-by-accessor before any `@Model` facets). Added `Sources/MeCore/Models/Kingship.swift`:
- `Kingship` value struct wrapping the three stored reign columns (`reignStartYear`, `reignEndYear`, `listedReignYears` = `reignYears`) with presence helpers (`hasChronologicalSpan`, `hasListedDuration`) and the reign-span display label previously inlined in `FigureDetailView` (`reignSpanLabel`: "1792–1750 BCE" / "From 2334 BCE" / "To 2270 BCE").
- `Figure.kingship` computed — returns `Kingship?`, non-nil when any reign datum is present. Facade over the god-object's SKL-king role.

**Design notes:** The facade deliberately models the *Kingship role* (presence of reign data), not a `FigureKind` discriminator — no read/write call sites migrated yet (that's step 2), so no behavior changed. New tests cover presence rules, field passthrough, and span-label formatting.

**Next steps (not committed):** migrate read sites onto `figure.kingship` (FigureDetailView reign row is the cleanest pilot — it replaces the inline `switch (reignStartYear, reignEndYear)`), then writers/forms, then the decide-gate (value layer sufficient vs. escalate to `@Model KingshipProfile` facet).

**Files:** `Sources/MeCore/Models/Kingship.swift` (new), `Tests/MeCoreTests/MeCoreTests+Kingship.swift` (new), `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Design discussion: god-object `Figure` vs. composition (base + facets)

**State:** Discussion only — no code, no schema change, nothing migrated. Captured because the user is actively weighing a long-term model refactor and wants the reasoning durable.

**Context:** After a day of view-layer refactors, we discussed whether the single `@Model` `Figure` (one row carrying deity / human / SKL king / primordial / collective semantics via optional fields like `reignYears`, `epithet`, `isConcept`) is a bottleneck worth restructuring. Raised and rejected along the way: a SwiftData **class hierarchy** — under the hood it maps to Core Data entity inheritance, which is a heavyweight store migration, breaks the "additive-only / sacred DB" rule, couples every `@Query [Figure]` + `Relationship.fromFigure` to the hierarchy, and fights the existing data-driven `FigureType` design.

**Where it landed — composition (base figure + facets):**
- Keep a slim `Figure` **card** holding what every entity shares: name, gender, era, epithet, figureType, relationships, alternate names, pantheons, tags, images, citations.
- Attach **optional 1:1 facet models** only for roles that bring their own fields, e.g. `DeityProfile` (domain, cult places, syncretisms) and `Kingship` (reign start/end, reign years, dynastic order). A facet is a separate `@Model` with `@Relationship(inverse:)` back to `Figure`.
- Facets **compose**: Dumuzi the Shepherd = Figure + Kingship + DeityProfile; Enki = Figure + DeityProfile; Alulim = Figure + Kingship; a plain human = bare Figure with `figureType = Human` and no facets.
- Rule of thumb: base = what every entity has; facet = a role that adds attributes. A role that adds no fields is just the base + its `figureType` (e.g. "collective" stays a flag, not a facet).

**Why it's affordable:** SwiftData only allows additive schema changes anyway. The refactor can be done as (1) add new facet `@Model`s with 1:1 inverse relationships (migration-safe), (2) idempotent `Migration.ensure…` backfill from the existing optional columns, (3) leave the wide columns as deprecated mirrors until no caller remains. Store never breaks, no reseed.

**Why it's not urgent:** the god-object has not blocked any feature — the tax is per-change friction (`if let reignYears`, `switch figureType`, ConsistencyEngine reasoning over the sprawl), not capability. Personal tool whose value is the data + tuned workflow. **Trigger to revisit:** when new code keeps writing `if let reignYears` / `switch figureType` (≈7 hats already: deity, SKL king, primordial, collective, hypostasis, biblical, everyday-life), or a feature needs per-kind invariants/validation.

**Recommended order:** prototype as **composition-by-accessor first** — typed facade over the existing model (`figure.kingship` computed returning a `Kingship` value struct, `FigureKind`-driven protocol) captures ~80% of the benefit with zero migration risk. Escalate to real `@Model` facets only if the value layer proves insufficient. User is "brewing" on it; no action committed.

**Files:** none (discussion only). Also logged the day's view refactors (DetailSection, CitationListSection, AssociationLinkPopover shell + rollout, EntitySearch unification) in entries above/below this one.

---

### 2026-09-07 — AssociationLinkPopover rollout to remaining four link popovers

**State:** `swift build` clean, **531/531** tests. No schema change, no behavior change. Pilot (Place detail popovers) user-verified in the running app.

**Change:** Completed the AssociationLinkPopover migration begun in the previous entry:
- `EventDetailView.swift` — `EventPlaceLinkPopover` and `EventThingLinkPopover` now compose the shared shell (their callers keep entity fetch/filter/create; shell owns search + checkmark list chrome). 970 → 944 lines.
- `PlacesSection.swift` — `PlaceLinkPopover` migrated (keeps magnifier + Comments footer).
- `ThingsSection.swift` — `ThingLinkPopover` migrated.
- `EventFigureLinkPopover` (two-step display-name confirm) and `GroupLinkPopover` (Join, no role) remain custom by design.

**Files:** `EventDetailView.swift`, `PlacesSection.swift`, `ThingsSection.swift`, `AssociationLinkPopover.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Shared AssociationLinkPopover shell (pilot: Place detail popovers)

**State:** `swift build` clean, **531/531** tests. No schema change, no behavior change.

**Context:** Third view-reduction step. The initial #3 idea (reuse `SearchSection`) was ruled out after inspection — that component is a pick-once-then-clear `Form` control, whereas the entity link popovers (PlaceFigureLinkPopover, PlaceLinkPopover, PlaceEventLinkPopover, EventPlaceLinkPopover, EventThingLinkPopover, ThingLinkPopover) are a persistent-selection interaction: search → list of not-yet-linked entities with a checkmark on the selection → Role picker (+ optional Comments) → Link/Cancel. User approved building a dedicated generic and rolling out pilot-first.

**Change (pilot — PlaceDetailView only):**
- `Sources/Me/Views/AssociationLinkPopover.swift` (new) — generic `AssociationLinkPopover<Item: Identifiable, Row: View, Footer: View>` shell: search field (optional magnifier), list + selection checkmark, empty state, Divider, caller-supplied footer; explicit init so `@Binding searchText`/`isPresented` precede the two trailing view-builders. Plus a small `LinkCandidateRow` (icon + title + optional subtitle) for the place/event/thing rows.
- `PlaceDetailView.swift` — `PlaceFigureLinkPopover` and `PlaceEventLinkPopover` now compose the shell: caller keeps its own entity fetch/filter/create, shell owns the search+list+checkmark chrome. 884 → 858 lines.
- EventFigureLinkPopover (two-step display-name confirm) and GroupLinkPopover (Join, no role) intentionally remain custom.

**Remaining follow-ups (deferred):** EventDetailView's EventPlaceLinkPopover + EventThingLinkPopover, PlacesSection's PlaceLinkPopover, ThingsSection's ThingLinkPopover — same mechanical migration onto the shell.

**Files:** `Sources/Me/Views/AssociationLinkPopover.swift` (new), `PlaceDetailView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Extract shared DetailSection wrapper across detail views

**State:** `swift build` clean, **531/531** tests. No schema change, no behavior change (additive view-layer refactor).

**Context:** Second view-reduction step. Every detail view hand-rolled the same "`Divider()` + `VStack(spacing:8)` + uppercase caption" shell around its content rows — 12 genuine section blocks across Place/Event/Figure/Thing, several with a trailing add/link button + popover in the header. Event's copy had drifted into mis-indented code (again proof of duplication rot). Property-style blocks (Modern Location / Map / Description) and the already-extracted figure section components (`PlacesSection`, `EventsSection`, `AlternateNamesSection`, etc.) were deliberately left alone — they aren't this shell.

**Change:**
- `Sources/Me/Views/DetailSection.swift` (new) — `DetailSection<Content, Accessory>`: renders `Divider + VStack { HStack { caption; Spacer; accessory }; content }`. Two inits (plain title, and title + `@ViewBuilder accessory`) so callers pass the shell once.
- Converted genuine section blocks to the wrapper:
  - `PlaceDetailView` — Also Known As, Related Places, Events Here, Associated Figures, Tags.
  - `EventDetailView` — Involved Figures, Associated Places, Things, Tags (mis-indentation normalised in the process).
  - `FigureDetailView` — Relationships, Tags.
  - `ThingListView` — Tags.
- Line counts: Place 924→884, Event 1004→970, Figure 1002→990, Thing 986→981 (modest because each conversion adds one indent level; the win is one source of truth for the caption shell + drift removal).

**Files:** `Sources/Me/Views/DetailSection.swift` (new), `PlaceDetailView.swift`, `EventDetailView.swift`, `FigureDetailView.swift`, `ThingListView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Extract shared CitationListSection (kill Place/Event copy-paste)

**State:** `swift build` clean, **531/531** tests. No schema change, no behavior change.

**Context:** Reducing the giant view files. First concrete target: `PlaceDetailView` and `EventDetailView` each carried a **byte-identical** inline "Sources & Citations" block (~40 lines, same icons/layout/delete flow, each with its own `citationToDelete`/`showDeleteCitationConfirm` state + `.alert`). Event's copy had drifted into mis-indentation — live proof the duplication was rotting.

**Change:**
- `Sources/Me/Views/CitationListSection.swift` (new) — self-contained `CitationListSection(citations:)` owning the header, rows, and its own delete-confirm alert, plus `CitationListRow` (doc-text icon + source/location line + note, optional delete). Callers stay thin — no state, no alert.
- `PlaceDetailView.swift` — inline block replaced with `CitationListSection(citations: placeCitations)`; removed dead `citationToDelete`/`showDeleteCitationConfirm` states + `.alert`. 971 → 924 lines.
- `EventDetailView.swift` — same. 1051 → 1004 lines.
- **Not touched:** `FigureDetailView`'s richer figure-specific `CitationsSection` (different UX: always-visible header + add button + filter + empty state) and `FigureCitationsRow` (used by figure detail, quicklook, and query dossiers) — deliberately left since their contract differs. PopupTable's `doc.text` hits are unrelated cell/source icons.

**Files:** `Sources/Me/Views/CitationListSection.swift` (new), `PlaceDetailView.swift`, `EventDetailView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Unify entity search helpers into shared EntitySearch.swift

**State:** `swift build` clean, **531/531** tests. No schema change, no behavior change for event/thing search.

**Context:** Search helpers were inconsistent. `searchFigures`/`FigureSearchResult` lived in their own file and returned a typed result so pickers could show "Name as Alt" when an alternate name matched; `searchPlaces`/`searchEvents`/`searchThings` were bare functions parked at the bottom of the Compare view files, each matching different fields (places: name/modern-location/alt-name; events & things: name/**description**). Only figures and places have `AlternateName` rows (events/things have no aliases). User approved "shared file + typed place result".

**Change:**
- `Sources/Me/Views/EntitySearch.swift` (new) — single home for all four search helpers + the typed result types:
  - `FigureSearchResult` + `searchFigures` + `Figure.matchedAlternateName(for:)` moved verbatim from the deleted `FigureSearchResult.swift` (12 call sites unaffected — filename was never part of the contract).
  - New `PlaceSearchResult` + `searchPlaces` returning typed results (alt-aware, mirrors figure) + `Place.matchedAlternateName(for:)`; place matches now also cover modern location as before.
  - `searchEvents`/`searchThings` unchanged in behavior (name + description), now living in the shared file.
- `PlaceCompareView` — filter maps `searchPlaces(...).map(\.place)`; row shows "Name as Alt" via `Place.matchedAlternateName(for:)` when the query hit an alias (matching FigureCompareView's behaviour).
- `EventCompareView`/`ThingCompareView` — removed their now-duplicated bottom free functions (still resolve to the shared ones).
- `Sources/Me/Views/FigureSearchResult.swift` deleted.

**Files:** `Sources/Me/Views/EntitySearch.swift` (new), `FigureSearchResult.swift` (deleted), `PlaceCompareView.swift`, `EventCompareView.swift`, `ThingCompareView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Split the 4,423-line Migration.swift monolith into domain files

**State:** `swift build` clean, **531/531** tests. Pure file-organization refactor — member inventory verified identical (110 members, none missing/duplicated).

**Context:** `Migration.swift` was a 4,423-line `package struct` holding ~110 idempotent migration routines with no section markers. Any change forced the whole file to recompile and made navigation painful. `Migration` is already extended across files (`HistoricalEventsImport.swift`, `FigureBlurbsImport.swift`), so the `extension Migration` pattern was proven.

**Change:**
- Split into 1 main + 9 domain files along topical boundaries (kept each member and its doc comment intact):
  - `Migration.swift` (~540 lines; keeps the `package struct Migration` decl + role types/collectives basics)
  - `Migration+DeityImports.swift` — deity/alt-name import tranches
  - `Migration+EraChronology.swift` — era order, antediluvian chronology, SKL anchor dates
  - `Migration+SKLAndGenealogy.swift` — parent relations, coverage flags, domain/era enrichment
  - `Migration+FigureGroups.swift` — default groups, kinds, regnal order, reign/epithet backfills
  - `Migration+PantheonsCollectives.swift` — pantheons, divine/human collectives + members
  - `Migration+OraccEpisodes.swift` — ORACC imports, everyday-life episodes/things
  - `Migration+SourcesTags.swift` — relationship/association source backfills, auto tags
  - `Migration+DynastyBoundaries.swift` — dynasty groups, polygon rings/geoJSON
  - `Migration+MaintenanceSplits.swift` — activity-log/users, syncretism dedup, pair splits, genealogy fixes
- **Access change:** the 15 file-scoped `private` static members (`StaticIdentifier`, `listedReignRegex`, `eraTypoMap`, helper funcs, etc.) became `package`. `private` is file-scoped, so helpers shared across the extension files could not stay `private`; `package` matches the surrounding 87 `package static` members exactly.
- Integrity verified programmatically: reconstructing members across all files reproduces the original symbol list 1:1.

**Files:** `Sources/MeCore/Store/Migration.swift` + 9 new `Migration+*.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Split the 10,438-line MeCoreTests.swift monolith into 8 files

**State:** `swift build`/`swift test` clean, **531/531** tests. Pure file-organization refactor — member content verified byte-identical vs a backup (normalizing only the intended access change).

**Context:** `Tests/MeCoreTests/MeCoreTests.swift` was a single 10,438-line, single-`@MainActor final class` monolith (531 tests + 26 private helpers). Navigation and diff review were painful; any change forced the whole file to recompile.

**Change:**
- Split the one class body into 8 files along existing `// MARK:` domain boundaries:
  - `MeCoreTests.swift` (main; keeps the `final class` declaration + QueryEngine/resolution tests)
  - `MeCoreTests+Groups.swift` (group ordering, aggregation, reign/epithet, era links)
  - `MeCoreTests+PantheonsCollectives.swift` (apply/revert, pantheon, divine/human collectives, imports, Lugal/Enki splits)
  - `MeCoreTests+ConsistencyTags.swift` (ConsistencyEngine, repairs, duplicate merger, tags)
  - `MeCoreTests+EventsPopup.swift` (event propagation, popup tables, timeline, SKL dates, auth/activity log)
  - `MeCoreTests+Migration.swift` (migration test suite)
  - `MeCoreTests+Lineage.swift` (LineageTreeLayout + bracket segments)
  - `MeCoreTests+RelationshipManager.swift`
- Each non-main file is `@MainActor extension MeCoreTests { … }` with the same three imports.
- **Access change:** the 26 class-level `private` helpers became internal (removed `private`). Swift `private` members are file-scoped, so helpers shared across the extension files (e.g. `makeContainer`, `count`, `deityType`) could not stay `private` once bodies moved to other files. Internal is the natural test-target access level; no API surface changed.
- Cut points chosen only at clean method/MARK boundaries so no member straddles two files.

**Files:** `Tests/MeCoreTests/MeCoreTests.swift` (now ~2,050 lines) + 7 new `MeCoreTests+*.swift` files, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Deduplicate split-screen compare into generic `EntityCompareView`

**State:** `swift build` clean, **531/531** tests. No schema change, no migration risk.

**Context:** Rolling the figure split-screen compare out to Places, Events, and Things produced four ~85%-identical views (FigureCompareView 114 lines, Place/Event/ThingCompareView 126–131 each). Before adding any fifth entity list, extract the shared shell.

**Change:**
- `Sources/Me/Views/EntityCompareView.swift` (new) — generic `EntityCompareView<Item: PersistentModel, Detail: View, Row: View>`: one implementation of the 1100×700 sheet (header title/subtitle, swap, Close, picker column, left/right panes). Callers inject: the `@Query` item array, title strings, a `name:` accessor, a `filter: ([Item], String) -> [Item]`, and `detail:`/`row:` view-builder closures. The picker already excludes the left item by `persistentModelID` before filtering.
- Rewrote `FigureCompareView.swift`, `PlaceCompareView.swift`, `EventCompareView.swift`, `ThingCompareView.swift` as thin wrappers (~46–53 lines each) that own their `@Query` and supply per-entity closures. No list-view call sites changed.
- Figure compare preserves its alt-name-aware picker ("Name as Alt") by keeping `searchFigures`/`FigureSearchResult` (shared elsewhere) intact and re-deriving the matched-alternate-name display inside the row closure.

**Files:** `Sources/Me/Views/EntityCompareView.swift` (new), `FigureCompareView.swift`, `PlaceCompareView.swift`, `EventCompareView.swift`, `ThingCompareView.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Figure header/toolbar cleanup, Enki/Ninki split, Place Compare

**State:** `swift build` clean, **531/531** tests. JSON validated with `jq`.

**Context:** Ongoing UI + data-curation session. Three threads: (1) consolidate the figure detail controls into the single `DetailToolbar`, (2) fix the combined "Enki and Ninki" primordial pair violating the one-person-per-figure convention, (3) generalise the figure split-screen compare to other entities.

**Change 1 — figure detail controls moved into `DetailToolbar`** (`FigureListView`):
- Compare (split screen) button moved out of `FigureDetailView`'s header into the `DetailToolbar` as a `leadingButtons` entry (`rectangle.split.2x1`).
- Inline "copy name to clipboard" button removed from beside the figure name; `DetailToolbar` gained an optional `copyName: String?` slot that renders the copy icon + transient `checkmark` feedback. Passed `figure.name` from `FigureListView`.
- Removed the duplicate inline "Edit description" button next to the figure name — the `DetailToolbar`'s `square.and.pencil` was already there. Dead `showDescriptionEditor`/`editRichDescription`/`editPlainDescription` state + `DescriptionEditorSheet` presentation removed from `FigureDetailView` (its toolbar keeps its own).
- Header layout (per user spec): two-column header where the second column stacks **name** on line 1, then **gender symbol + FigureTypeBadge (+ Concept pill)** on line 2, then a separated block of the text lines (disambiguation/title/epithet). Badge no longer floats on the right edge.

**Change 2 — split "Enki and Ninki" into two figures:**
- `Migration.splitEnkiNinkiPair(context:)` — idempotent corrective split (precedent: `splitLugalIrraMeslamtaea`). Creates `Enki (Primordial)` (male) and `Ninki` (female), both `Primordial`, links them as **Spouse** in both directions, copies the pair's shared tags (minus `pair`) + Mesopotamian pantheon onto both, then deletes the combined row. Also reconciles a store that already has both split figures but no spouse edge.
- `mesopotamian_deities_import.json` — replaced the single pair entry with the two split figure entries so imports/reseeds never recreate the pair.
- `alt_names_import.json` — removed the obsolete `Enki-Ninki` hyphenated-pair entry.
- Naming/genders/relationship decisions confirmed with user: qualify names in parentheses (`Enki (Primordial)`), Enki male / Ninki female, spouse pair only (no Enlil link), metadata re-tagged on both and pair refs dropped.
- 4 new tests: split-with-metadata, idempotent re-run, link-existing-individuals-without-pair, no-op-when-nothing-present.

**Change 3 — entity compare (split screen), rolled out to all four entity lists:**
- `Sources/Me/Views/PlaceCompareView.swift`, `EventCompareView.swift`, `ThingCompareView.swift` (new) — each mirrors `FigureCompareView`: 1100×700 sheet, left = selected entity, right = second entity or a searchable picker, swap + Close, reuses the entity's own detail view in each pane.
- `PlaceListView.swift`, `EventListView.swift`, `ThingListView.swift` — each gained a `showCompareSheet` state + a `rectangle.split.2x1` `leadingButtons` entry in its `DetailToolbar` + a sheet. Per-entity accent colors: figures `.accentColor`, places `.teal`, events `.orange`, things `.purple`.
- Per-entity pickers search different fields: places by name/modern location/alternate name; events by name/description (shows type icon + date label); things by name/description (shows `cube.box` + description line).
- No schema change, no migration risk; UI-only.

**Files:** `Sources/Me/Views/FigureDetailView.swift`, `FigureListView.swift`, `DetailToolbar.swift`, `ContentView.swift`, `PlaceCompareView.swift` (new), `EventCompareView.swift` (new), `ThingCompareView.swift` (new), `PlaceListView.swift`, `EventListView.swift`, `ThingListView.swift`, `Sources/MeCore/Store/Migration.swift`, `Sources/MeCore/Resources/mesopotamian_deities_import.json`, `Sources/MeCore/Resources/alt_names_import.json`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-07 — Figure Compare (split screen)

**State:** `swift build` clean. No schema change, no migration risk.

**Context:** User wants two figures side by side for direct comparison, triggered from a figure's detail view.

**Change:** New `FigureCompareView` + a Compare button in `FigureDetailView` header.

- `Sources/Me/Views/FigureCompareView.swift` (new) — Full-screen sheet: left pane = primary figure (swappable), right pane = second figure or a searchable picker. Header bar shows a swap button and Close. Uses existing `searchFigures`/`FigureSearchResult` for the picker, reuses `FigureDetailView` directly in each pane. Frame is 1100×700.
- `Sources/Me/Views/FigureDetailView.swift` — New `showCompareSheet` state + a `rectangle.split.2x1` button in the header (next to the edit-description icon), presents `FigureCompareView` as a sheet.

**Design decisions:**
- Trigger: compare button on the detail header (not a new sidebar section). Two figures only for now.
- All data editing (mugshot, description, relationship creation via drag-drop) is available inside each pane through the existing `FigureDetailView` sheets/interactions.
- Symmetric header with "Swap" (swaps left and right figure), Close button and figure name subtitle.

**Files:** `Sources/Me/Views/FigureCompareView.swift`, `Sources/Me/Views/FigureDetailView.swift`.

---

**State:** `swift build` clean, **526/526** tests. BookmarkLayout tests removed (the geometry they tested is gone).

**Context:** User changed the visual form of bookmarks: abandoned the original floating-panel design in favour of simple buttons in the button bar at the top of the screen.

**Change:** Replaced the floating `NSPanel` overlay system with a row of toolbar buttons.

- `Sources/Me/Views/BookmarkOverlay.swift` — Stripped down to `Bookmark` value struct (id/kind/entityID/name, `position` removed) + `@Observable BookmarkStore` (max 5, dedupes via "Remove Bookmark" swap, `isBookmarked`, `remove(entityID:)`) + the environment key. Removed `WindowReporter`, `BookmarkPanelWindow`, and `BookmarkOverlayController`.
- `Sources/Me/Views/BookmarkPanelView.swift` — Now `BookmarkButtonView`: a `Menu` labelled with the entity's icon + name. The menu lists **Open** (navigate) and **Remove Bookmark** (destructive). Replaced the original right-click `contextMenu` because toolbar buttons swallow right-clicks — the user only ever saw the toolbar's own "Icon and Text / Icon Only" customization menu, not the bookmark's context menu. A discrete `Button` + chevron was considered but a single `Menu` with "Open" keeps remove always discoverable.
- `Sources/MeCore/Store/BookmarkLayout.swift` — Deleted (floating-panel geometry no longer used).
- `Sources/Me/Views/ContentView.swift` — Removed `BookmarkOverlayController` state, `WindowReporter` background, and the corner-reorg toolbar button. Added a `BookmarkBarView` toolbar item that renders the bookmarks as a horizontal row of buttons and handles navigate/remove with lazy deleted-entity cleanup.
- `Tests/MeCoreTests/MeCoreTests.swift` — Removed `BookmarkLayoutTests` (5 tests) since `BookmarkLayout` no longer exists. `Bookmark`/`BookmarkStore` live in the `Me` target, not `MeCore`, so they're not unit-testable from `MeCoreTests`.
- `docs/Bookmarks.md` — Rewritten for the toolbar-button design.

**Design decisions:**
- **Toolbar buttons instead of floating panels:** A simple row of `Button`s in the top button bar. No drag, no corner layout, no window resize reorganisation, no above-sheet behaviour needed.
- **Navigation/removal heads the same way** as before: click → `NavigationCoordinator.navigateTo*`, right-click → remove. Deleted-entity cleanup still resolves lazily (synchronously here, in a button action).
- **Row context menus** (Bookmark / Remove Bookmark swap, greyed at 5) are unchanged.

**Files:** `Sources/Me/Views/BookmarkOverlay.swift`, `Sources/Me/Views/BookmarkPanelView.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/Bookmarks.md`. `Sources/MeCore/Store/BookmarkLayout.swift` deleted.

---

**State:** `swift build` clean, **531/531** tests (5 new BookmarkLayout tests). App relaunched (PID 13811); no crash reports.

**Context:** User wanted the ability to bookmark up to 5 entities (figures/places/events/things) as always-visible floating icons on the main window — for quick switching between entities during research. Bookmarks are session-only (non-persistent), float above SwiftUI sheets, and live entirely inside the app window frame.

**Change:** Three new files plus edits to five existing files:

- `Sources/MeCore/Store/BookmarkLayout.swift` — Pure geometry functions (`cornerOrigins(count:contentRect:)`, `clamped(origin:panelSize:within:)`) for the bottom-left corner layout and screen-space clamping, unit-tested in MeCoreTests.
- `Sources/Me/Views/BookmarkOverlay.swift` — `Bookmark` value struct, `@Observable BookmarkStore` (max 5, dedupes via "Remove Bookmark" swap, `setPosition`, `isBookmarked`, `remove(entityID:)`), `BookmarkOverlayController` (owns per-bookmark borderless `NSPanel` child windows at `.floating` level; idempotent `attach(to:)` + `cornerLayout()` + lazy entity-existence resolve on click + teardown on parent `willCloseNotification`), environment key, and `WindowReporter` NSViewRepresentable.
- `Sources/Me/Views/BookmarkPanelView.swift` — Finder "View as icons" style tile (SF Symbol + name, rounded-rectangle thinMaterial), `DragGesture` for clamped repositioning, right-click `contextMenu` with confirmation-dialog delete, click-to-navigate via `NavigationCoordinator`.
- `Sources/Me/Views/ContentView.swift` — `@State BookmarkStore` + `@State BookmarkOverlayController?`, environment injection, `WindowReporter` background to start the controller on the main window, toolbar "bookmark" button to trigger `cornerLayout` (greyed when empty).
- `FigureListView`, `PlaceListView`, `EventListView`, `ThingListView` — Row context menus now carry a toggling "Bookmark"/"Remove Bookmark" item with `Label(systemImage:)`, greyed when full and not already bookmarked.
- `Tests/MeCoreTests/MeCoreTests.swift` — 5 new tests in `BookmarkLayoutTests`: stack order, right-alignment, empty, clamp bounds, exact-fit edge case. 531/531.

**Design decisions (incorporating user feedback):**
- **Architecture:** Per-bookmark borderless `NSPanel` (not SwiftUI overlay) — the only route that satisfies "cannot be obscured by sheets" (spec §Living space). Panel `.floating` level (3) sits above the main window (0) and attached sheets; system modal dialogs would still cover them (accepted).
- **Context menu surface:** List rows only (not detail headers) — one consistent surface across all four entity types.
- **Duplicate handling:** "Remove Bookmark" swap — if the entity is already bookmarked, the menu item swaps to "Remove Bookmark"; no stale duplicates possible.
- **Resize behavior:** Any window resize re-organizes bookmarks to the bottom-left corner (sidebar-width region, right-aligned, bottom→top, alphabetical by name) — per spec §Manipulation, confirmed by user.
- **Persistence:** None (session-only, lost on relaunch) — per spec §Persistence, confirmed by user.
- **Deleted entity → bookmark removed:** Resolved lazily on click via `ModelContext.model(for:)`; doesn't require deletion-hook plumbing.
- **Keyboard shortcuts:** Deferred to a follow-up — spec confirmed this is a later addition.
- **NSWindow.parentWindow → .parent:** `parentWindow` was renamed to `parent` in Swift 3; build-time fix.

**Files:** `Sources/MeCore/Store/BookmarkLayout.swift`, `Sources/Me/Views/BookmarkOverlay.swift`, `Sources/Me/Views/BookmarkPanelView.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/FigureListView.swift`, `Sources/Me/Views/PlaceListView.swift`, `Sources/Me/Views/EventListView.swift`, `Sources/Me/Views/ThingListView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/Bookmarks.md`.

---

### 2026-09-06 — Five childBornBeforeParent complaints fixed via corrective migration

**State:** `swift build` clean, **526/526** tests. App relaunched (PID 10322); live store corrected + verified via sqlite.

**Context:** The 5 remaining date complaints (Data Integrity → childBornBeforeParent) were: Naram-Sin of Akkad (-2280) born before Manishtushu (-2205); Lipit-Enlil (-1874) before Bur-Suen (-1821); Puzur-Suen (-2273) before Hablum (-2135); Jared (-3544) before Mahalalel (-3386); Rashujal (-3749) before Rachujal (-3603). Root causes were mixed: mis-dated kings, a chronologically impossible Father edge, a broken Genesis-5 segment, and a mythical Watcher pair with invented dates.

**Change:** New idempotent migration `Migration.correctAnomalousGenealogy(context:)` (wired after `ensureAntediluvianChronology`): Manishtushu birth -2205→-2305; Lipit-Enlil rebased to -1800/-1790 (after Bur-Suen, matching the DB's consecutive-reign convention); deleted the Hablum→Puzur-Suen Father edge; re-derived Jared (-3321) and Enoch (-3159) from Genesis 5 begetting ages (+65/+162, lifespans 962/365); inserted a `FindingDismissal` for the mythical Rashujal pair; deleted the 5 stale persisted IntegrityFinding rows. Each step fires only while the stale value is present, so user edits always win.

**Files:** `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift` (+ `testCorrectAnomalousGenealogyResolvesChildBornBeforeParentFindings`, and integrity/dismissal models added to the test schema).

**Verification:** New migration test passes (fixture → 5 warnings → corrected date/edge/dismissal/stale-clear assertions, idempotent on rerun, only Rashujal still computes). Full suite 526/526. Live store confirmed: Manishtushu -2305, Lipit-Enlil -1800/-1790, Jared -3321/-2359, Enoch -3159/-2794 (reignStart mirrored), Hablum→Puzur-Suen count 0, dismissal row present, childBornBeforeParent persisted findings 0.

---

### 2026-09-06 — "The daughters of Man" gender-wording false positive fixed (recurrence)

**State:** `swift build` clean, **525/525** tests. App relaunched (PID 9234).

**Context:** User: "It is back... 'The daughters of Man'." The 2026-08-29 fix removed RELATIONAL nouns (sons/daughters) from the gendered-noun sets, which silenced the original flags — but the figure's description since carried the full Genesis 6:1–4 passage (`[6:2] the sons of God saw…`, `[6:4] …the sons of God went in to the daughters…`), and unquoted singular "God" is a self-descriptive masculine noun, so the warning returned.

**Change:** Added "The daughters of Man" to `ConsistencyEngine.genderWordingExemptNames`, extending the documented exemption beyond historical anomalies (Kubaba) to discussion/quotation records (the wording describes the passage, never the figure). Added `testGenderWordingExemptsDaughtersOfMan` mirroring the Kubaba test, including a non-exempt control that still flags.

**Files:** `Sources/MeCore/Store/ConsistencyEngine.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

**Verification:** Gender-wording filter passes; full suite 525/525.

---

### 2026-09-06 — "Nin-Nibru" auto-link verified against live store; alternate spelling seeded

**State:** `swift build` clean, **524/524** tests. Live app relaunched (PID 8793); live store now contains `Ninnibru | Nin-Nibru | Alternate Spelling`.

**Context:** User re-reported the identical "Nin-Nibru"/"Ninnibru" miss a fourth time even after code fixes. Static analysis and seed-data tests always passed, so the fix was verified against the REAL store: a temporary probe opened a copy of the live `Me.store`, built `LinkResolver` from the live figure/place/event/alt names (1,175 candidates), and ran the real description. Output confirmed `Nin-Nibru` resolves to `ninnibru` (variant span) and its target is the Ninnibru figure. The 12:01 launch was already running the fixed binary. So resolution provably works end-to-end against live data.

**Change:** To make the case work through EVERY name-based subsystem (search, backlinks, wiki matching, and the linker's exact pass), and to match the figure's own description ("also romanized as Nin-Nibru"), added `Nin-Nibru` as an Alternate Spelling alternate for Ninnibru in `alt_names_import.json`. Imported idempotently by `ensureAlternateNamesImportExist` (already registered at launch).

**Verification:** `testEnsureAlternateNamesImportExist` now asserts Ninnibru gains Nin-Nibru; `testAutoLinkResolverMatchesNinNibruVariantInRealSeedData` now runs the alternate-names import too (mirroring launch order) and still resolves both spans. jq-validated the JSON. Full suite 524/524.

**Files:** `Sources/MeCore/Resources/alt_names_import.json`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-06 — Variant-spelling auto-link moved to MeCore LinkResolver; stale process was masking it in the running app

**State:** `swift build` clean, **524/524** tests (3 new). App relaunched with the current binary.

**Context:** User re-reported the original variant-spelling miss ("Nin-Nibru" vs registered "Ninnibru") a third time. Static analysis + existing tests always passed, yet the complaint persisted — the running process (`pgrep`) had been launched before the fixes were compiled, so the user kept exercising old code. Also found a real latent bug in the view's variant regex: key alternation was NOT sorted longest-first (the exact regex was), so a short key prefix ("nin") could shadow "ninnibru".

**Change:** Pure name-matching logic moved out of the view into MeCore as `LinkResolver` (`MeCore/Store/LinkResolver.swift`), used verbatim by `LinkifiedDescription.swift`: longest-first alternation for BOTH exact and folded-key regexes (fixes the shadowing), folded variant pass over `FoldedProse` with exact-wins merge. `CandidateSet` now carries `LinkResolver` + `keyToCandidate`; `ParagraphView.runs` consumes resolved spans.

**Verification:** `testAutoLinkResolverMatchesNinNibruVariantInRealSeedData` seeds the real import data and asserts both "Ninnibru" and "Nin-Nibru" resolve to the Ninnibru figure through the actual resolver; `testAutoLinkResolverDoesNotMatchSpaceSeparatedVariants` asserts "Nin Nibru" does not link while "Nin-Nibru" does. Suite 524/524. Relaunched the app so the running binary contains the fix.

**Files:** `Sources/MeCore/Store/LinkResolver.swift` (new), `Sources/Me/Views/LinkifiedDescription.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-06 — Variant-spelling auto-link locked in for figure Ninnibru

**State:** `swift build` clean, **521/521** tests (2 new).

**Context:** User pointed at the figure "Ninnibru" as the concrete case: no alternate names registered, yet its own description reads "Ninnibru, also romanized as Nin-Nibru, …". The mirror pass from the earlier session already covers this, but it lived (untestable) inside the Me target.

**Change:** Extracted the folded-prose core into a new `MeCore/Store/FoldedProse.swift` (`FoldedProse`): lowercase + diacritic-strip + hyphen/apostrophe/dot strip with whitespace folded to one space, keeping every surviving char's original range so regex hits map back to the original UTF-16 span. `LinkifiedDescription.swift` now uses it (the private `LinkifiedMirror`/`buildLinkifiedMirror`/`mirrorOrigRange` are gone). The linker is otherwise unchanged: exact-name pass wins overlaps; variants append; space-separated "Nin Nibru" stays unmatched.

**Verification:** `testVariantProseFoldingMapsNinNibruSpellingBackToFigureNinnibru` runs the exact real description through the key regex and asserts both "Ninnibru" and "Nin-Nibru" resolve and map to their original spans; `testVariantProseFoldingPreservesWordBoundaries` asserts "Ninnibru" links while "Nin Nibru" does not. Full suite 521/521. Confirmed `LinkedDescription` is used by all detail views (`FigureDetailView:480` etc.).

**Files:** `Sources/MeCore/Store/FoldedProse.swift` (new), `Sources/Me/Views/LinkifiedDescription.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-06 — Ambiguous-alias warning exempts deliberately shared aliases (epithets, titles, logographic readings)

**State:** `swift build` clean, **522/522** tests (2 new).

**Context:** User pushed back on the Data Integrity warning `The name "Bel" is attached to multiple figures: Ashur, Marduk.` — rightly so: "Bel" ("Lord") is an epithet/title, and in Assyria it referred to Ashur while in Babylon to Marduk. Then again with `The name "Mer" is attached to multiple figures: Ishkur, Wer.` — "Mer" is the logographic reading of dIM, the storm-god sign, deliberately attached to both Ishkur and Wer (they are the same god). Only spelling variants are expected to belong to exactly one figure.

**Change:** `ConsistencyEngine.checkAmbiguousAliases` now skips Epithet, Translation, and Logographic Reading name types in addition to Syncretism (the existing exemption). A shared spelling e.g. "Ninsi'anna"/"Dup" across figures still flags as `.ambiguousAlias`; a shared title "Bel"/"Malka" or a shared sign reading "Mer" no longer warns.

**Verification:** `testAmbiguousAliasRuleSkipsEpithetAndTranslationNames` (Bel on Ashur+Marduk and a translated title exempt; a real spelling duplicate still flagged) and `testAmbiguousAliasRuleSkipsLogographicReadingNames` (Mer on Ishkur+Wer with Ishkur's row typed Logographic Reading; a real duplicate still flagged). Full suite 522/522.

**Files:** `Sources/MeCore/Store/ConsistencyEngine.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-06 — Description auto-linking now matches variant spellings

**State:** `swift build` clean, **518/518** tests (1 new). View-layer change only; no store edits.

**Context:** User flagged that a description spells "Nin-Nibru" while the registered figure is "Ninnibru", and the auto-linker ignores the variant (no click-through, no link). The auto-linker in `LinkedDescription` built its candidate regex exclusively from exact figure/place/event names and `<AlternateName>` strings — `\bNinnibru\b` can never match "Nin-Nibru".

**Change:** `Sources/Me/Views/LinkifiedDescription.swift` now runs a second matching pass over a folded *mirror* of each paragraph: lowercase, diacritic-stripped, punctuation-stripped exactly like `DuplicateMerger.normalizationKey` (hyphens, dashes, apostrophes, dots dropped; whitespace folded to a single space — so a real space between words stays a different name). A `keyRegex` built from the candidate keys runs on the mirror, matches are mapped back to the original UTF-16 span (surrogate-safe index map), the exact-name pass wins any overlap, and the link targets the canonical entity. Handles "Nin-Nibru"→Ninnibru, "Eanasir"/"Ninsianna"→hyphenated/apostrophe canonicals, "Meslamtaea"→Meslamta-ea, "Istaran"→Ištaran, etc.

**Verification:** New `testNormalizationKeyEquatesVariantSpellings` pins the equivalence rule (hyphen/diacritic/case/apostrophe variants equate; genuine spaces and possessives do not, so no false links like "Nin Nibru" → Ninnibru). Full suite 518/518.

**Files:** `Sources/Me/Views/LinkifiedDescription.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-06 — "Lugal-irra and Meslamta-ea" split into two twin figures

**State:** `swift build` clean, **516/516** tests (3 new). No store edits live yet — split fires at next launch.

**Context:** User noticed a recent import (the Mesopotamian deities JSON) had added the twin pair "Lugal-irra and Meslamta-ea" as a *single* figure. Contrary to their curation rule — twins are always two separate figures — the merged row duplicated the already-existing ORACC "Lugalirra" (pk 336) and swallowed "Meslamta-ea" (which had no individual figure at all).

**Decision:** Agreed with the user. A merged pair contradicts the figure-keyed model: dossiers, lineage trees, alternate names, associations, images, queries and consistency checks all operate on an individual; the pair was a dead-end row with zero links. Twins are richer as two figures plus a Twin edge.

**Changes:**
1. `Migration.splitLugalIrraMeslamtaea(context:)`: idempotent, additive-where-possible. Reuses the ORACC "Lugalirra" figure (creates it + "Lugal-irra" spelling alt-name if absent), creates "Meslamta-ea" (Deity, Male, Underworld domain, gatekeeper/Gemini description, "Meslamtaea" spelling alt-name), fetch-or-creates a `Twin` RelationshipType, adds a single canonical Twin edge (Lugalirra → Meslamta-ea), and deletes the now-empty merged import row (approved by user; no links on it). Also ensures Twin type + edge when both individuals already exist but no pair row remains (fresh-DB convergence). Registered in `ContentView` after `ensureBidirectionalRelationshipConsistency`.
2. **First launch showed the twin relationship twice on each brother's card.** Root cause: the initial migration created a *mirrored* edge pair (both directions), and the card lists every matching row. Symmetric types are meant to be a single canonical edge — `addRelationship` always creates one, and `relationshipDirectionPrefix` phrases the incoming direction from the other card via the `reverseName` ("Twin") / gender logic. Fixed by collapsing to one edge: the migration now deletes the reciprocal if a mirrored pair exists, and `Twin` was *not* added to `ensureBidirectionalRelationshipConsistency`'s bidirectional set so no launch re-mirrors it (unlike Spouse/Consort/Ally, which are mirrored there — a deliberate exception since those were already double-displaying and the user only flagged twins).
3. `mesopotamian_deities_import.json`: replaced the single pair entry with two individual entries ("Lugalirra", "Meslamta-ea") so a future import can never re-create the merged row.

**Verification:** Five related tests (split/delete, missing-Lugalirra creation, no-pair convergence, mirrored-pair collapse, idempotency). Full suite 517/517. `jq` validated the JSON.

**Files:** `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/MeCore/Resources/mesopotamian_deities_import.json`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-06 — Event ↔ Figure links made bidirectional (Bur-Sagale eclipse fix)

**State:** `swift build` clean, **513/513** tests (2 new for the button path + repair migration). No store edits live yet — repair fires at next launch.

**Context:** User linked figure "Bur-Sagale" to "The eclipse of Bur-Sagale" via the event detail "Link figure" popover, but the link only half-applied: the event detail showed the figure while (a) the figure's Events section stayed empty, and (b) the "no figures/places linked" warning in Data Integrity (ConsistencyEngine) and the Dashboard persisted.

**Root cause:** `EventDetailView`'s `EventFigureLinkPopover.linkFigure` called `RelationshipManager.addEventFigureAssociation(..., alsoLinkInvolvedFigures: false, dedupe: false)`. The explicit `false` created only the `EventFigureAssociation` row and deliberately did not append the figure to `event.involvedFigures` (nor the event to the inverse `figure.events`). Live DB proof: association pk 24 (event 123 ↔ figure 642) existed, but `Z_14INVOLVEDFIGURES` had no row for figure 642. Because `EventsSection` lists an event on a figure's card only via `$0.involvedFigures.contains`, the figure-side never updated, and both consistency checks only consult `involvedFigures` (DashboardView:82 and ConsistencyEngine.checkEventWithNoLinks:700 ignore `figureAssociations`). The flag was set explicitly in commit d8ba918 (the commit that introduced the popover); the parameter's default is `true`.

**Also found:** 19 of 20 `EventFigureAssociation` rows in the live DB had no matching `Z_14INVOLVEDFIGURES` row (only assoc pk 13, event 8 Founding of Eridu → figure 98, was consistent). Many well-known links (Deluge/Ziusudra, Great Flood/Enki, Bull of Heaven) were affected. This is a latent inconsistency introduced over time by popover links, not a Bur-Sagale-specific bug — hence the backfill.

**Changes:**
1. `RelationshipManager.addEventFigureAssociation`: when `alsoLinkInvolvedFigures` is true, now pushes the figure into `event.involvedFigures` **and** the event into `figure.events` (previously only the inverse `figure.events` was touched). This makes the new-link path fully bidirectional.
2. `EventDetailView.removeFigure`: was an `if/else` — with an association it deleted only the assoc row, otherwise only removed from `involvedFigures`. Now always removes from **both** `involvedFigures` and the association, so removal works after the dual linkage.
3. `Migration.repairInvolvedFiguresFromAssociations(context:)`: additive/idempotent backfill — for every `EventFigureAssociation` whose figure is missing from its event's `involvedFigures`, appends it (and appends the event to `figure.events`). Registered in `ContentView` right after `convertYaleCulinaryTabletsEventToThing`, so it fires on next launch for the existing DB.

**Verification:** New tests `testRelationshipManagerEventFigureAssociationWithoutInvolvedFiguresKeepsAssociationEvenIfNotVisible`, `testRepairInvolvedFiguresFromAssociations`, plus existing `testRelationshipManagerEventFigureAssociationLinksInvolvedFigures` already asserts the default bidirectional path. 513/513 pass. `swift build` clean.

**Files:** `Sources/MeCore/Store/RelationshipManager.swift`, `Sources/Me/Views/EventDetailView.swift`, `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-06 — Yale Culinary Tablets reclassified from Event to Thing

**State:** `swift build` clean, **511/511** tests (2 new). No store edits — conversion fires at next launch.

**Context:** User flagged the imported "Yale Culinary Tablets" (live event pk 103, type "Daily Life", Old Babylonian ~1730) as a bad classification: the tablets are physical objects, not a happening, so they belong in Things rather than the event timeline.

**Changes:**
1. **`ensureEverydayLifeEpisodes`** no longer lists the Yale Culinary Tablets in the episode array — it can never be re-created as an Event (fresh or existing DB).
2. **`ensureEverydayLifeThings`** (new) seeds curated everyday-life Things check-by-name (description + source + ThingType "Text") — the tablets' home going forward.
3. **`convertYaleCulinaryTabletsEventToThing`** (new) converts a pre-existing Event into a Thing: carries over name/description/richDescription/source, types it "Text", drops the auto-generated dangling citation (`ensureEventCitations` artifact, name+`.event` match), then removes the Event. Idempotent and never overwrites a user-created Thing; both new migrations registered in `ContentView` right after `ensureEverydayLifeEpisodes`.
4. Docs: `NEXT_SESSION_HANDOFF.md` item 7 annotated as replaced by a Thing.

**Verification:** updated everyday-life counts (9 events, 27 stickies, "eight imports + user's own"); `testEverydayLifeThingsSeedsYaleCulinaryTablets` (seeds Text-typed Thing, no Event, idempotent) and `testExistingYaleEventConvertedToThing` (event removed, citation dropped, fields carried over, idempotent). Full suite 511/511.

**Files touched:** `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/NEXT_SESSION_HANDOFF.md`, `docs/SESSION_LOG.md`.

---

### 2026-09-06 — Recurring figure duplicates (diacritic variants): importer resurrected ASCII spellings every launch

**State:** `swift build` clean, **509/509** tests (1 new). No store edits (fixes apply at next launch).

**Context:** User reported three more recurring duplicates after the Atra-Hasis Source fix: `Ninšar`/`Ninsar`, `Ištaran`/`Istaran`, `Ninsi'anna`/`Ninsianna` (DB pks 292/640, 327/639, 335/638). They reappeared every launch after being merged via the deduper.

**Root cause (same resurrection pattern as Atra-Hasis):** `mesopotamian_deities_import.json` uses ASCII names (`Istaran` figures[1], `Ninsar` figures[78], `Ninsianna` figures[79]), while the surviving keepers after a deduper merge are the diacritic figures (`Ištaran`, `Ninšar`, `Ninsi'anna`). `Migration`'s JSON importers guarded against re-import with `name.lowercased()` **exact** matches, so end of merge the keeper names never matched the ASCII file names and the importer re-created the ASCII variants next launch. This pattern existed in **five** importers (`ensureDeitiesImportExist`, `ensureMissingDeitiesImportExist`, `ensureMesopotamianDeitiesImportExist`, `ensureDemonsImportExist`, `ensureCuratedNamesImportExist`).

**Key insight:** `NameDuplicateCheck.normalizedKey` (letters/digits only) is **not** diacritic-insensitive ("Ištaran" keeps `š`); the deduper's `DuplicateMerger.normalizationKey` (`.diacriticInsensitive` folding + punctuation strip) is the correct group key — the same key the deduper uses must be the key the importers use, so a merged-away variant can never be re-imported.

**Changes:**
1. **`DuplicateMerger.normalizationKey`** promoted `private` → `package static` (documented as the canonical name-grouping key).
2. **All five JSON figure importers** now: (a) build `existingNames` from `DuplicateMerger.normalizationKey`, (b) filter `toImport` with `DuplicateMerger.normalizationKey($0.name)`, (c) sticky-note membership checks use the same key. ASCII import names now correctly resolve to existing diacritic figures → skipped.

**Verification:** new `testEnsureMesopotamianDeitiesImportSkippedByDiacriticVariant` (pre-inserts diacritic figures, runs importer, asserts no ASCII variant duplicated). Full suite 509/509. Python checked all three pairs fold to identical keys via `normalizationKey`.

**Files touched:** `Sources/MeCore/Store/DuplicateMerger.swift`, `Sources/MeCore/Store/Migration.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-06 — Recurring "Atra-Hasis" duplicate: merged Source resurrected every launch

**State:** `swift build` clean, **508/508** tests (1 new). No store edits (fixes apply at next launch).

**Context:** User reported a recurring duplicate — the de-duper kept showing an "Atrahasis"/"Atra-Hasis" pair that reappeared after every merge. Initial hypothesis (seeder, figure) was wrong on both counts: `seedIfEmpty` only runs on an empty store, and the figure "Atrahasis" (pk 309) is a user/import-created Human, distinct from canonical Ziusudra — not a dup.

**Root cause (loop):**
1. The pair is **Sources**: canonical "Atrahasis" (pk 10, full description) vs. stub "Atra-Hasis" (pk 97, blank), which the deduper's `normalizationKey` groups because hyphens are stripped.
2. The stub is auto-created by `Migration.ensureAssociationSources`/`ensureRelationshipSources`, which matched Sources by **exact case-insensitive name** (`byName[name.lowercased()]`). The free-text seed strings use "Atra-Hasis" (hyphenated) so the canonical "Atrahasis" (no hyphen) never matched.
3. ZEVENTEVENTASSOCIATION pk 2 carried `source="Atra-Hasis"` → `sourceRef=97`. `DuplicateMerger.mergeSources` re-pointed citations/attachments/relationships/popup tables/cells, but **skipped the seven association tables' `sourceRef`**. After the merge, pk 97 was deleted, EEA.sourceRef nullified, and on the next launch `ensureAssociationSources` saw the nil ref + "Atra-Hasis" text and re-created the stub. Infinite resurrection loop.

**Changes:**
1. **`DuplicateMerger.mergeSources`** now re-points `sourceRef` from the duplicate to the keeper across all seven association types (EventEvent, EventPlace, FigurePlace, PlacePlace, ThingFigure, ThingPlace, ThingEvent) — mirroring what `mergeEvents`/`mergePlaces` already do for their FKs.
2. **`ensureRelationshipSources` + `ensureAssociationSources`** now build their Source lookup with `NameDuplicateCheck.normalizedKey` (letters/digits only) instead of `lowercased()`, so "Atra-Hasis" matches the canonical "Atrahasis" and no stub is ever spawned again.

**Verification:** new `testDuplicateMergerMergeSourcesRePointsAssociationSourceRefs` (EEA + FPA re-pointed to keeper, duplicate deleted). Full suite 508/508.

**Files touched:** `Sources/MeCore/Store/DuplicateMerger.swift`, `Sources/MeCore/Store/Migration.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-06 — Enmetena birth-era corrupted by description-derived era migration

**State:** `swift build` clean, **507/507** tests (3 new). Store change: 1 row repaired at next launch (`Enmetena.birthDate.era` → "Early Dynastic Period", `figure.era` relinked).

**Context:** Data Integrity flagged *"Birth date references era \"Lagash who defeated Umma and restored the border channel\", which does not match any Era in the database."* The live row (pk 613) had `ZERA` = the full description sentence and a **nil** `figure.era` link. The JSON source (`historical_events_a.json:4`) is correct: `era: "Early Dynastic Period"`.

**Root cause (migration bug, not data):** `ensureHistoricalEventsImportExist` imported Enmetena with `figure.era` → "Early Dynastic Period" but left `birthDate.era` empty. On a later launch, `Migration.ensureFigureEraLinks` (Migration.swift:1732) derives an era name from any `"Ruler of …"` description prefix. For SKL figures that remainder *is* the era ("Ruler from the Second dynasty of Kish…"); for Enmetena the description is prose, so the whole sentence became `birthDate.era`, and since no Era matches, the migration then **nilled the correct era link**. `birthEraNameFromDescriptionIfEmpty` wrote the garbage name unconditionally; `resolveEraTarget` fell back to a description-derived nil and clobbered the link.

**Changes:**
1. **Guard** — `ensureFigureEraLinks` rewritten: `reconcileBirthEraString` only writes a description-derived era name when it resolves to a known Era (not before), and clears a provably auto-derived garbage string (one that exactly equals the description-derived name but matches no Era key). `resolveEraTarget` now uses an alias-aware `eraByKey` (maps "Before the Flood"→"Age of the Watchers", "Guthian rule"→"Gutian rule"). `eraName(fromDescription:)` made `package` (reused by importer).
2. **Repair** — `ensureHistoricalEventsImportExist` now stamps `birthDate.era = king.era` (+ link) at creation, and a new `reconcileImportedKingEra` restores the era from the authoritative JSON for existing kings whose current value is empty or matches the auto-derived garbage. Idempotent; never overrides user-typed values.

**Verification:** 3 new tests (`testEnsureFigureEraLinksDoesNotWriteUnmatchedDescriptionAsEra`, `testEnsureFigureEraLinksClearsAutoDerivedGarbageEraString`, `testHistoricalEventsImportRepairsAutoDerivedGarbageEra`). Full suite 507/507.

**Files touched:** `Sources/MeCore/Store/Migration.swift`, `Sources/MeCore/Store/HistoricalEventsImport.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-05 — Watchdog `Task` bug: inherited main actor, never fired

**State:** `swift build` clean. No store changes.

**Context:** User reported a hang shortly after the watchdog landed. No `Me_hang_*.spin` existed despite the watchdog being live in the running binary (verified by symbols) and `/usr/bin/sample` working. Root cause: `Task {}` created inside `applicationDidFinishLaunching` inherited the main actor (macOS 26 SDK marks `NSApplicationDelegate` `@MainActor`), so `checkStall()` ran on the main thread it was supposed to monitor. During a block it never executed; after unblocking, the queued ping blocks flushed and refreshed `lastHeartbeat` before `checkStall` could inspect it — the stall was never observed.

**Change:** `MainThreadWatchdog.start()` now uses `Task.detached(priority: .utility)`, running the loop off the main actor. Also lowered `stallThreshold` from 5s → 3s to catch shorter hangs.

**Verification:** `swift build` clean. Requires app relaunch to activate.

**Files touched:** `Sources/Me/MainThreadWatchdog.swift`.

---

### 2026-09-05 — Determinative-dot false positive in name-variant consistency check

**State:** `swift build` clean, **504/504** tests (1 new). No store changes.

**Context:** Data Integrity flagged *"Description writes \"Nin-MAR\"; the registered name is \"Ninmar\". Auto-linking misses variant spellings."* The figure is registered as **Nin-MAR.KI** (aliases *Ninmar*, *Ninmarki* — `alt_names_import.json:702-718`) and its own description opens "Nin-MAR.KI (reading uncertain)…". `isWordChar` in `ConsistencyEngine.checkNameVariants` treated `.` as a word boundary, so the alias key `ninmar` matched the prefix of the collapsed text `ninmarki…`, the end-boundary saw a non-word char (`.`) and accepted, and the truncated span "Nin-MAR" was flagged as a misspelling.

**Change:** `Sources/MeCore/Store/ConsistencyEngine.swift` — `.` only counts as a word boundary at the start/end of a word. A `.` bounded by letters/digits on both sides (the determinative dot "Nin-MAR.**KI**", "Eridu.**KI**" etc.) is treated as word-interior, so the name is matched whole and an exact canonical spelling stays silent.

**Verification:** full suite 504 pass, including new `testNameVariantRuleTreatsDeterminativeDotAsWordInterior`. Existing boundary rules (Anu∈Anunnaki, Puzur-Suen≠Su'en, Ur(Ur III≠Urur) unaffected.

**Files touched:** `Sources/MeCore/Store/ConsistencyEngine.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-05 — Main-thread watchdog for intermittent figures-list freeze

**State:** `swift build` clean, **503/503** tests. Diagnostic tooling only — no store changes, no migrations.

**Context:** User reported an intermittent freeze where the Figures list renders but cannot be scrolled or selected; sometimes recovers on its own, sometimes requires relaunch, and can be days apart. On-demand `sample` capture is impractical for such a rare event (no automatic hang reports exist in `~/Library/Logs/DiagnosticReports/`). Suspected mechanisms under discussion: main-thread save churn during launch migrations (`ContentView` runs the whole 40+-step chain on the main actor, `ContentView.swift:219-263`) and/or live `AgentService` saves re-triggering `@Query` observers → full `rebuildRows()` across all 605 figures.

**Changes:**
1. `Sources/Me/MainThreadWatchdog.swift` — new passive background watchdog. A `.utility` Task pings the main queue every 1s (recording heartbeats under lock); if the main thread fails to respond for >5s (after ≥3 warm-up heartbeats, and >5 min since the last capture), it spawns `/usr/bin/sample <pid> 5 -file` and writes a hang report to `~/Library/Logs/DiagnosticReports/Me_hang_<timestamp>.spin`.
2. `Sources/Me/AnunnakiApp.swift` — `MainThreadWatchdog.shared.start()` called from `applicationDidFinishLaunching`.

**Verification:** `swift build` clean; tests still 503/503. Next step once a report exists: read the hung stack to find the blocking call, then fix root cause (likely coalescing `rebuildRows()` or offloading the migration chain from the main actor).

**Files touched:** `Sources/Me/MainThreadWatchdog.swift` (new), `Sources/Me/AnunnakiApp.swift`.

---

### 2026-09-05 — Duplicate figure merge: Asalluhi → Asarluhi (variant spellings)

**State:** `swift build` clean, **503/503** tests (2 new). Additive + idempotent data migration; applies on next app launch. No reseed, no data destroyed.

**Context:** Consistency checker flagged "Asaralimnuna" as an ambiguous alias shared between figures Asalluhi (pk 245, old seed-era) and Asarluhi (pk 407, created later by the missing-deities import by exact-name match). These are *variant transliterations of the same god* (Eridu's incantation god, son of Enki, equated with Marduk) — a genuine duplicate figure, not a syncretism like Nergal/Erra. `DuplicateMerger.findGroups` cannot pair them (normalization only strips punctuation, not "ll" vs "rl"), so a targeted migration was needed.

**Changes (newest first):**
1. `Migration.deduplicateAsalluhiAsarluhi` (Sources/MeCore/Store/Migration.swift) — merges Asalluhi into Asarluhi via `DuplicateMerger.mergeFigures`, then reconciles to a single canonical mother (Damkina over Ninhursag) and drops the self-referencing "Asarluhi" alternate that folds in from the duplicate. No-op when only one figure exists (current seed only has Asarluhi, so fresh installs are unaffected).
2. Registered in `ContentView` migration list (before `ensureCanonicalDeityFamilies`, so the family fixer still sees the single keeper this launch).

**Verification:** new tests `testDeduplicateAsalluhiAsarluhiMergesAndKeepsCanonicalMother` and `testDeduplicateAsalluhiAsarluhiIsIdempotent`; full suite 503 pass.

**Files touched:** `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-05 — Nergal/Erra syncretism: re-type "Irra", document parallel cult survival

**State:** `swift build` clean, **501/501** tests (2 new). Additive + idempotent data migration; applies on next app launch via ContentView migration list. No reseed, no data destroyed.

**Context:** Consistency checker flagged "Irra" as an ambiguous alias shared between Erra and Nergal. Discussion with the user clarified the theology: Erra and Nergal are consubstantial — Erra's cult ran in parallel for centuries (Erra Epic, 8th c. BC; Sargon II) before the name settled as an aspect of Nergal. Deleting Erra was rejected; both figures stay, and the identification is modeled as a Syncretism (shared aliases typed Syncretism are exempt from duplicate/ambiguity detection, mirroring the existing Asarluhi/Marduk convention).

**Changes (newest first):**
1. `Sources/MeCore/Resources/alt_names_import.json` — Nergal's "Irra" re-typed from `Epithet` to `Syncretism` with note *"Variant spelling of Erra; the Erra identification is treated as completed for lookups."* (Erra's own "Irra" stays `Alternate Spelling`.)
2. `Migration.alignNergalErraSyncretism` (`Sources/MeCore/Store/Migration.swift`) — idempotently re-types any existing live-DB Nergal "Irra" epithet to Syncretism and adds an identical sticky note to Nergal and Erra documenting the parallel cult survival. Guarded (only touches exact name match, only when type is Epithet, deduped sticky text).
3. Registered in `ContentView` migration list (after `removeOrphanedKittumNigginaAltNames`).

**Verification:** new tests `testAlignNergalErraSyncretismReTypesIrra` and `testAlignNergalErraSyncretismIsIdempotent`; full suite 501 pass; `jq --exit-status .` on the JSON.

**Files touched:** `Sources/MeCore/Resources/alt_names_import.json`, `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-04 — Historical events tranche + missing-description blurbs

**State:** `swift build` clean, **499/499** tests (2 new). Additive, idempotent imports; applies on next app launch via ContentView migration list. No reseed, no data destroyed.

**Changes:**
1. **Historical events tranche (69 events + 40 kings):** `Sources/MeCore/Resources/historical_events_{a,b,c}.json` — documented events Early Dynastic → fall of Nineveh (612 BCE): battles, destructions, foundations, political upheavals, the 763 BCE Bur-Sagale eclipse; each with approximate BCE date, description, source string, involved figures by name, optional city. Kings (Sargon of Akkad, Rimush, Naram-Sin, Ashurnasirpal II, Sargon II, Esarhaddon, Nabopolassar, …) auto-created only when absent, era-linked where a matching dynasty exists. `Migration.ensureHistoricalEventsImportExist` (Sources/MeCore/Store/HistoricalEventsImport.swift) fetches by name, links to existing EventTypes/figures/places, and sticks an "IMPORTED — needs review" note on every new row. **Caveat recorded:** items whose dynasty eras don't exist (Larsa, Kassite, Middle-Assyrian ~1300–1076 BCE) import dated but era-less — they won't pin to a timeline lane until those era rows are added (possible follow-up).
2. **Empty-description backfill (20 figures):** `figure_blurbs.json` + `Migration.ensureMissingFigureDescriptions` fill only blank `figureDescription`s, keyed by exact name, idempotent. 12 got substantive blurbs (Muati verified via Wikipedia: spouse of Nanaya, later conflated with Nabu); 8 obscure An = Anum/minor entries got honest attestation-style one-liners rather than invented detail. Meshka flagged as near-unknown.
3. Timeline-event UX follow-up from prior commit: added chip-like hover feedback to event markers then **reverted on request** (didn't look good) — no code left.

**Verification:** new tests `testHistoricalEventsImportIsAdditiveAndIdempotent` (≥60 events, ≥30 kings, no dup on second run) and `testEnsureMissingFigureDescriptionsFillsOnlyBlanks`; full suite 499 pass.

**Files touched:** `Sources/MeCore/Resources/{historical_events_a,b,c.json, figure_blurbs.json}`, `Sources/MeCore/Store/{HistoricalEventsImport.swift, FigureBlurbsImport.swift}`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

---

### 2026-09-04 — Timeline: pre-flood linear axis, BCE tick labels, event placement pass

**State:** `swift build` clean. View-layer only; no schema/data impact. Timeline header fix from earlier this session is in `583a8c5`.

**Changes (newest first):**
1. **Event placement pass in historical swimlanes (`TimelineBase.historicalSwimlane`)** — post-flood lane events previously printed bottom-centered at each event's year with a fixed 80pt box and no collision handling: same-year events overprinted into unreadable blobs and sat half-in/half-out of the lane. Now: events are sorted by year and greedily packed bottom-up into rows (≥92pt horizontal separation), drawn inside a reserved bottom band (12pt clearance, row height 30) so they never straddle the lane edge; the figure-chip cloud is centered in the upper region (`chipCloudHeight`) and the lane only grows vertically when event rows require it, so chips/reign bars/events can't overlap; events whose year maps outside the drawn axis are skipped.
2. **Pre-flood axis made strictly linear (`TimelineAxis.linear`)** — the mythological pre-flood timeline used `minimumWidth` (per-era min visual width), which stretched the short Creation/Watchers eras and made the 50k-year ruler read as "450k…400k…350k…300k [huge gap] 250k". New `TimelineAxis.linear(minYear:maxYear:pointsPerYear:)` maps every year to a fixed number of points; `TimelinePreView` now uses it, so ticks are evenly spaced and short eras render as narrow lanes (their chips still scroll inside the era's rail). Post-flood/SKL timeline untouched.
3. **Axis year labels suffixed with " BCE"** (`TimelinePreView.preFloodAxisHeader`) — the standalone "BCE" overlay sat at top-leading and collided with the first tick (450,000, centered at x=0), printing through it; a floating marker also sat 1–2px off the number baseline. Labels are now single strings ("450,000 BCE" …) with runtime-measured half-widths and clamped centers so no label hangs off either frame edge.

**Follow-ups parked in `docs/TODO.md` ("Timeline semantics & pre-flood rethink"):** events invisible in pre-flood rows (mythological-timed lanes pass `events: []`); era-name↔content mismatch ("Creation" holds the pantheon, not the cosmogony); decide framing of the Sitchin-style deep-time BCE ladder; name eras only after events drive meaning.

**Files touched:** `Sources/Me/Views/TimelineBase.swift`, `Sources/Me/Views/TimelinePreView.swift`, `docs/TODO.md`.

---

### 2026-09-04 — Timeline header layout fix

**State:** `swift build` clean. Single-file change, no schema/data impact.

**Changes (newest first):**
1. **Timeline header alignment bug (root cause):** `TimelineContainerView`'s outer `VStack(spacing: 0)` used the default `.center` cross-axis alignment. The header block hugs content (narrower than the window), so it was being *centered* — drifting right by half the unused width (single digits at large window sizes, hence a persistent "~7–8px off" report that changed with window size). Fixed by pinning `VStack(alignment: .leading, spacing: 0)` (Sources/Me/Views/TimelineView.swift:15).
2. Header restructured to three left-aligned rows sharing the timeline content's exact left inset (**20pt**, matching `.padding(.horizontal, 20)` in `TimelinePreView`/`TimelinePostView`): row 1 = "Timeline" title, row 2 = Pre-Flood/Post-Flood segmented picker + "Reign bars" checkbox (post only), row 3 = figure-type legend chips. Rows use consistent vertical padding (5pt) + 12pt above/below the block; removed the forced 220pt picker width and `.fixedSize`.
3. Verified the timeline swimlanes' inset is 20pt (`TimelinePreView.swift:58`, `TimelinePostView.swift:51`); header now uses the same value so title/filters align flush with the lane content at every window width.

**Blind-layout lesson:** several attempts to eyeball SwiftUI alignment from code alone missed the centering bug. In-app offscreen `ImageRenderer` snapshots to `/tmp` work even without Screen Recording permission — but this model cannot interpret images, so pixel alignment still had to be closed via reasoning + user measurement. Worth promoting: when a SwiftUI block "looks centered/drifting a few px," check the enclosing stack's default cross-axis alignment before touching paddings.

**Files touched:** `Sources/Me/Views/TimelineView.swift`.

---

### 2026-09-04 — Demons/curated import shipped + Apple Style Guide pass

**State:** All work uncommitted (layered on the prior uncommitted tree). `swift build` clean, **497/497** tests, no `--reseed`, user DB untouched apart from intended additive imports.

**Changes (newest first):**
1. **Apple Style Guide audit + fixes** — user-facing text pass across `Sources/Me/Views` (~540 Text + 95 Button literals sampled) against the ASG/HIG:
   - Era terminology unified to **BCE** (was mixed "BC" vs "BCE/CE"): `FigureDetailView` reign row, `SumerianKingListView`, `SumerianDynastyMapView` now "…BCE" (timeline + date editor already used BCE/CE).
   - "Tap a node to inspect" → "Click…" (`NetworkGraphView`; macOS uses click).
   - Removed ASCII `...` from search-field placeholders ("Search Wikipedia", "Search figures", …) and progress/status labels ("Searching Wikipedia", "Loading article", "Looking up X", "Ollama is processing"); Query box placeholder → `Try "what do we know about Enki?"`; menu-style `…` untouched.
   - Empty-state punctuation: stripped trailing periods from lone fragments ("No adds yet", "No duplicate names found", …); normalized em-dash empties to two sentences ("No images yet. Import a statue photo.").
   - All-caps micro-labels → sentence case: "Epithet" (detail keeps `.textCase(.uppercase)` visual), "Value"/"Comment"/"Sources" (popup table), "Source image"/"Preview" (mugshot).
   - Replaced ~60 Latin "e.g. " prefixes: field prompts now show the bare example (`prompt: Text("5500")`), unlabeled fields use "such as …"; help/grammar fixes ("Figures use…", curly apostrophes/quotes).
   - Misc: "Backup & Restore" → "Backup and Restore"; dropped 📌 from "Stickies" label; curly apostrophe in MapPreview empty state.
2. **Demons + curated import root-cause** — both JSONs were silently failing to decode: `SeedDataRoot` requires non-optional keys; files were missing `"things": []` (and had a stray `"stickyNotes"` key). Added decode-error logging temporarily to find it, then removed. 15 demons + 20 curated names now import with "IMPORTED — needs review" stickies; Demon FigureType created via fetch-all-and-check (dropped a fragile `#Predicate` check).

**Files touched (style pass):** `Sources/Me/Views/{NetworkGraphView, FigureDetailView, SumerianKingListView, SumerianDynastyMapView, ImportView, PopupTableFormView, EntityReportSheet, QueryView, GroupsSection, EntityGroupsSection, FigureGroupFormView, FigureImageGallery, FromTextHistorySheet, CitationsSection, ContentAttributionFormView, LineageTreeView, DuplicateMergeView, MugshotSheet, FigureFormView, PopupTableView, FigureDetailInfoView, BackupSheet, StickyNoteListView, MapPreview}.swift` plus the ~20 files touched by the `e.g.` sweep (TypeSettingsView, SourceListView, DictionaryListView, AlternateNameListView, PlaceFormView, EventFormView, EraListView, ThingFormView, PlaceDetailView, AssociationsView, PlacesSection, VersionListView, MissionControlView, FigureGroupListView).

**Open (unchanged):** duplicate-deity-row dedupe migration; review of 59 spill-over entries; demons/curated entries pending user review of descriptions/stickies.

---

### 2026-09-03 → 2026-09-04 — Session save (dashboard tile, alt-name sweeps, integrity fixes)

**State:** All work uncommitted (deity/alt imports + view tweaks layered on the prior uncommitted tree). `swift build` clean, **497/497** tests passing, no `--reseed`, user DB untouched apart from the intended additive imports.

**Work completed this stretch (newest first):**
1. **Data-integrity row selectable highlight** — clicking a finding row now selects/highlights it (accent tint); inline Fix/Dismiss/⋯ buttons unaffected. User chose "just selectable highlight" over navigate-on-click.
2. **Data-integrity collapsible polish** — the category headings were already individually collapsible; added **persisted collapse state** (`dataIntegrityCollapsedCategories` in UserDefaults, restored on appear) + a **Collapse All / Expand All** toolbar button so the page can be folded in one click.
3. **Orphaned alt-name cleanup** — root-caused the "Alternate name 'Niĝgina' not linked" integrity warning: it referred to a *legacy orphan* row (pk 137, unlinked `Niĝgina` syncretism + sibling orphan `Kittum` translation, pk 138), distinct from the correctly-linked `Niggina` (pk 318) on Kittum that search resolves. Added `Migration.removeOrphanedKittumNigginaAltNames` (targeted by name + unlinked, so no other rows touched) + test. Orphans now `[]`.
4. **Dashboard Figures tile (2-column)** — split into left (icon, figure count, "Figures") / right (`textformat.abc` icon, alias count, "aliases"); left column right-aligned, right column left-aligned, 20pt spacing each side of the vertical divider; alias label bumped caption→callout. `figureAliasCount` = figure-attached AlternateNames only (excludes 9 place + orphans). Live: 547 figures / 253 aliases.
5. **Alternate-name sweep part 2** — Ningishzida (+7 grounded rows) + systematic pass over the 196 zero-alias divine figures: batched Wikipedia exintro leads, auto-flagged 49 with alias info, curated **+45 rows across ~30 figures** (Kumarbi→Kumurwe/Kumarwi/Kumarma, Kittum→Niggina, Nungal→Manungal/Belet-balati, Pinikir variants, Ashnan→Ezina, Wer→Mer/Ber/Iluwer, Inshushinak "Lord of Susa", Ninegal→Belet Ekallim, Anunitu→Ishtar of Akkad, Zababa→Zamama…). Deliberately excluded cross-figure conflicts and disambiguation-page noise. Live: **316 alt names / 160 figures** (from 264/131).
6. Earlier same session: grounded deity import (186 figures in file; DB 370→547) + first alt-name run + orphan cleanup; all logged below.

**DB-truth lesson reinforced:** dedup/attach must check the *live* `ZFIGURE`/`ZALTERNATENAME` (+ alias map), not seed-derived name lists; the live store diverges (Dumuzi the Shepherd vs seed Dumuzi; duplicate deity rows `Istaran`/`Ištaran`, `Gibil`/`Girra`, `Mushdamma`/`Musdamme`, `Haya`/`Haia`, etc. still pending a merge task).

**Files touched:** `Sources/Me/Views/DataIntegrityView.swift`, `Sources/Me/Views/DashboardView.swift`, `Sources/MeCore/Resources/alt_names_import.json`, `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`, `docs/TODO.md`.

**Open (unchanged):** duplicate-deity-row dedupe migration; demons/monsters FigureType decision (spill-over bucket); optional god-list name-only bulk file; review of 59 spill-over entries.

---

### 2026-09-03 — Alternate-name sweep part 2 (Ningishzida + systematic flag-based pass)

**Context:** User noticed Ningishzida's card showed no aliases although Wikipedia lists several — correct: the earlier alt run covered only 61 figures. Confirmed DB had 196 divine figures with zero aliases.

**Changes:**
1. Ningishzida: 7 grounded rows (Ninĝišzida transliteration, Ningizzida syllabic, Gishbanda 'little tree', name-translation, underworld/innkeeper epithets, Dumuzi syncretism from laments).
2. Systematic sweep: fetched exintro leads for the 196 zero-alias divine figures (batched MediaWiki API), auto-flagged 49 whose leads mention alias-type info, curated **45 more rows across ~30 figures** (Kumarbi→Kumurwe/Kumarwi/Kumarma, Kittum→Niggina, Nungal→Manungal/Belet-balati, Pinikir's four variants, Ashnan→Ezina, Wer→Mer/Ber/Iluwer, Inshushinak 'Lord of Susa', Ninegal→Belet Ekallim, Anunitu→Annunitum/Ishtar of Akkad, Zababa→Zamama, …). Deliberately skipped: cross-figure conflicts (e.g. Ninsun→Gula), disambiguation-page noise (Shara, Simut, Saggar, Haia), and deities whose leads carry no alias info.

**Verify:** alt import file now covers 81 figure-entries; live DB alternate names **264 → 316** across **160 figures**; migration idempotent test green; full suite **496/496**; build clean; no reseed.

**Files touched:** `Sources/MeCore/Resources/alt_names_import.json`, `docs/SESSION_LOG.md`. Sweep scripts under `/var/folders/.../T/opencode/deity_import/` (`fetchleads.py`, `review_leads.md`, `flags.md`, `sweep3.py`).

---

### 2026-09-03 — Alternate-name curation run (bynames, equivalents, hypostases)

**Context:** User admitted initial alternate-name collection was inaccurate and asked for a separate run. Scope chosen: proportional across the pantheon (majors deep, minors 1-3) with local hypostases included as syncretism/epithet rows. Grounded authoring (Wikipedia canonical-list alt cells + byname scholarship); no fabrication — only names confidently attested.

**Changes:**
1. Authored `ALT1`/`ALT2` tables (data scripts in `/var/folders/.../T/opencode/deity_import/altdata_part1.py`, `altdata_part23.py`) keyed by exact live-DB figure names: 61 figures, ~155 candidate rows.
2. Assembly-time pruning (`altgen.py`): dropped alt rows that (a) collide with an existing *separate* figure (e.g. Sulpae→Pabilsag, Nergal→Erragal — those are duplicate-figure cases for a future dedupe task, not alt links), (b) already exist in the store, (c) target figures not in store. Result: **77 new rows across 51 figures**.
3. New resource `Sources/MeCore/Resources/alt_names_import.json` — bespoke `[{figure, alternates:[{name, tradition, nameType, note}]}]` array.
4. `Migration.ensureAlternateNamesImportExist` (Migration.swift, after the deity import) — decodes, resolves figure by exact name, dedupes on (figure, name, tradition), inserts `AlternateName`s. Registered in `ContentView.task`.
5. Test `testEnsureAlternateNamesImportIsAdditiveAndIdempotent` (asserts ≥20 rows + Ashur gains "Assur" + no dup on rerun).

**DB-truth discoveries:** live store diverges from seed names (Dumuzi stored as "Dumuzi the Shepherd"; some seed deities absent); duplicate deity rows pre-exist (`Istaran`/`Ištaran`, `Mushdamma`/`Musdamme`, `Misharu`/`Mīšaru`, `Kittu`/`Kittum`, `Ninsar`/`Ninšar`, `Haya`/`Haia`, `Asalluhi`/`Asarluhi`, `Gibil`/`Girra`, `Sud`, `Nintu`/`Nintur`, `Sherida`, `Lugalirra` + pair) — flagged as a future merge/dedupe item.

**Verify:** in-memory tests green; full suite **496/496**; `swift build` clean; relaunched → live DB alternate names **187 → 264** (131 figures covered). No reseed.

**Files touched:** `Sources/MeCore/Resources/alt_names_import.json` (new), `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-03 — Broad Mesopotamian pantheon import (web-grounded)

**Context:** User learned the attested Mesopotamian pantheon numbers 3,000–3,600 names (mostly bare god-list entries from *An = Anum*), found the DB's ~85 deities "severely lacking", and asked for a significant grounded import. Chose **broad & grounded (~600+)** with **web-grounding** (no name-only rows; minimum = name + gender + domain).

**Reality check surfaced:** the grounded ceiling is far below 600. Wikipedia's canonical *List of Mesopotamian deities* (fetched raw, 252 KB wikitext, parsed with a custom script) contains ~221 rows covering essentially every deity modern scholarship can describe. The remaining thousands are attestations with no published substance. User accepted this and approved importing the real inventory.

**Changes:**
1. New `Sources/MeCore/Resources/mesopotamian_deities_import.json` — now **186 figures** in `SeedDataRoot` shape (all non-optional keys incl. `things: []`; the older `deities_import.json`/`missing_deities_import.json` lack `things` and no longer decode against current `SeedDataRoot`). Tranche A: 129 deities parsed from the Wikipedia list, deduped vs the 87 seed-derived divine names, enriched with curated gender/domain + trimmed sourced descriptions (5 Primordial; ~90 Sumero-Akkadian; ~30 Hurrian/Elamite/Kassite absorbed gods). Tranche B (+57): deities with standalone articles absent from the list page (Ninlil, Gibil, Ishum, Ninkarrak, Ninti, artisan deities, underworld entourage, local/ANE gods), authored from extracts/knowledge and DB-verified.
2. `Migration.ensureMesopotamianDeitiesImportExist` (Migration.swift, after `ensureMissingDeitiesImportExist`) — additive + idempotent, name-filtered vs live store, registered in `ContentView.task` (after line 248). No sticky markers (129 sticky notes would flood).
3. `docs/deity_spillover_bucket.json` — 59 researched-but-not-imported entries with reasons (alias-of-existing, hypostasis/epithet, monster/demon — no FigureType, group collective, spurious/biblical, non-deity, insufficient gender/domain). Kept, not discarded, never imported name-only.
4. New test `testEnsureMesopotamianDeitiesImportIsAdditiveAndIdempotent`.

**Key DB-discovery along the way:** the live store diverges from the seed-derived name set (e.g. stores Dumuzi as "Dumuzi the Shepherd", lacks Ninlil/Gibil/Uttu/Tashmetum that the seed JSON lists). Dedup must check the **live ZFIGURE ZNAME** (+ alias map), not seed files.

**Verification:** JSON `jq`-validated; in-memory migration test passes; **495/495** suite green; `swift build` clean. App relaunched → user DB went **370 → 490 → 547** figures; 186/186 import-file names confirmed present via sqlite. No reseed; data additive only.

**Files touched:** `Sources/MeCore/Resources/mesopotamian_deities_import.json` (new), `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/deity_spillover_bucket.json` (new), `docs/SESSION_LOG.md`. Parser/authoring scripts left in `/var/folders/.../T/opencode/deity_import/` (parse_wiki.py, author.py, author2.py, summaries.json) for future tranches.

**Open:** creatures/demons still need a FigureType decision before any import; optional god-list name-only bulk file remains intentionally unbuilt.

---

### 2026-09-02 → 2026-09-03 — Session save (end of working stretch)

**State:** Everything below is **uncommitted** in the working tree (48 modified files + new untracked `Sources/Me/Views/DetailWidth.swift`, `Sources/MeCore/Store/RelationshipManager.swift`, `Sources/MeCore/Store/LineageTreeLayout.swift`, plus `Package.swift`). `swift build` clean and `swift test` **494/494 passing** at end of session. No `--reseed` was ever run; user DB untouched.

**Work completed this stretch (all logged below, newest first):**
1. **RelationshipManager** landed + all 16 view call sites migrated onto it (annotated-side convention enforced by construction).
2. **Keys-not-strings**: the 7 association models gained `sourceRef: Source?` + `Source` inverse arrays; `Migration.ensureAssociationSources` backfills idempotently.
3. **Architectural 4B** marked resolved — `ConsistencyEngine.runAll` is the single validation API.
4. **LayoutManager 3A → `@DetailWidth` property wrapper** (`Sources/Me/Views/DetailWidth.swift`): centralizes the 10 per-view `<entity>DetailWidth` keys/defaults into `DetailWidthSlot`; all 10 list views migrated from `@AppStorage("...DetailWidth")` to `@DetailWidth(.slot)`. `ResizableDivider` usage (MissionControlView) still binds via `$detailWidth`.
5. **Compile-time work**: `Package.swift` debug-only `-debug-time-function-bodies`; then point-1 "small `body`s" refactor across ContentView, PlaceDetailView, EventDetailView, FigureListView, FigureGroupListView, FigureDetailView, EntityGroupCollectionView (reignTower→`ReignBarRow`), PopupTableView. Worst bodies: 2.7s/2.4s/1.36s/1.36s → sub-500ms each, most under 100ms.

**Open / unresolved at save:**
- Doc items **3A** (critique doc not yet marked done for the `@DetailWidth` consolidation) and the **"ParentCoupleSheet: add source picker"** TODO remain open.
- Compile-time: remaining hotspots are list-view `.sheet`/`.alert` modifier tails (~150–450ms, largely irreducible) and secondary ~150ms bodies (e.g. `EntityGroupCollectionView` top body). Points 3–5 (avoid conditional-modifier type splits, bounded generics for any future form-consolidation, `AnyView` pragmatism) not yet actioned.
- **Planned review**: user intends to visually smoke-test the refactored render paths (figure/place/event detail panels, group text-block rows, reign bars, comparison-table grid, figure-list selection) and review the accumulated diffs before further work.

**Files touched this stretch:** see the per-item entries below (Views/*, MeCore Models/Store, Package.swift, AGENTS.md, docs/*).

---

### 2026-09-02 → 2026-09-03 — LayoutManager (arch. weakness 3A) consolidated via `@DetailWidth`

**Context:** Review-doc item 3A ("Scattered Width Management Pattern") claimed each list view hand-manages its own `@AppStorage("<entity>DetailWidth")` key. Verified against code: **true** — 10 keys + defaults, though mostly lightweight (most views have the `ResizableDivider` call commented out and only apply `.frame(width: detailWidth)`; only MissionControlView actively resizes).

**Decision:** user chose the property-wrapper design over the doc's literal `LayoutManager` EnvironmentObject. Rationale: the views legitimately want *independent* widths (a single shared value would over-couple), `@AppStorage` is the established idiom, and a wrapper gives the DRY win with one-line churn per view and zero environment-injection plumbing across ~10 list views + sheets.

**Change:** new `Sources/Me/Views/DetailWidth.swift` — `enum DetailWidthSlot` (10 cases: dictionary/era/event/figure/figureGroup/missionControl/place/skl/source/thing) owning `key`, `defaultValue` (320 default; 380/390/480 overrides), and `defaultRange` (200...800); `@propertyWrapper struct DetailWidth` wrapping `@AppStorage` with `wrappedValue` + `projectedValue: Binding<Double>` (so `ResizableDivider(width: $detailWidth)` keeps working). All 10 views migrated: `@DetailWidth(.slot) private var detailWidth`. Keys unchanged → existing persisted widths survive.

**Verify:** `swift build` clean; `swift test` 494/494.

**Files touched:** `Sources/Me/Views/DetailWidth.swift` (new), `Sources/Me/Views/{DictionaryListView,EraListView,EventListView,FigureGroupListView,FigureListView,MissionControlView,PlaceListView,SourceListView,SumerianKingListView,ThingListView}.swift`.

**Note:** critique doc 3A not yet marked done — pending this entry; TODO not yet updated.

---

### 2026-09-03 — Point-1 refactor, continued (PopupTableView)

**Context:** Last scheduled item before a review checkpoint: split `PopupTableView.body` (the comparison-table grid, ~297ms).

**Change:** Extracted the outer `VStack`'s children into computed properties — `headerSection` (title/description/source), `gridOrEmpty` (the deep `if columns.isEmpty` empty-state vs. nested-vertical+horizontal-`ScrollView` grid with column resize / header-height / cell bindings), and `footerBar` (close + scale handle + reset). `body` is now a thin layout shell + the modifier tail.

**Result:** `body` cost moves into `gridOrEmpty`, now isolated at 192ms (the residual is inherent to the nested-scroll grid, no longer conflated with the rest of the view).

**Verify:** `swift build` clean; `swift test` 494/494 pass.

**Files touched:** `Sources/Me/Views/PopupTableView.swift`.

**Checkpoint:** 9 files touched across the compile-time refactor sessions (ContentView, PlaceDetailView, EventDetailView, FigureListView, FigureGroupListView, FigureDetailView, EntityGroupCollectionView, PopupTableView, Package.swift). Remaining hotspots are list-view `.sheet`/`.alert` modifier tails (~150-450ms, largely irreducible) plus a few ~150ms secondary bodies. Pausing for review as agreed.

---

### 2026-09-03 — Point-1 refactor, continued (FigureListView, FigureGroupDetailView, FigureDetailView, reignTower)

**Context:** Continued applying "small `body`s" down the type-check ranking measured earlier. All changes purely structural; `swift build` clean + 494/494 tests after each.

**Changes:**
- `FigureListView.body` (was 675ms): split the `HStack` into `leftPane` (list column incl. header/filters/list) and `detailPane` (detail panel + toolbar). body → ~451ms (residual is the `.sheet`/`.onChange`/`.alert` modifier tail); `leftPane` 54ms.
- `FigureGroupDetailView.body` (was ~539ms): split the `ScrollView` VStack into `headerSection`, `actionsBar`, `membersSection` (the big ordered/alphabetical drag-drop spine `if/else`), `subgroupsSection`. body → 24ms.
- `FigureDetailView.body` (was ~312ms): extracted the content VStack into `contentStack`. body → 153ms (modifier tail), `contentStack` 66ms.
- `EntityGroupCollectionView.reignTower` (was ~290ms): extracted the per-row bar (GeometryReader + gradient + shadow + reveal animation) into a new `private struct ReignBarRow` taking plain values + an `onHover` closure; `formattedNumber` widened `private` → `fileprivate static` so the row can reuse it. `reignTower` → 82ms.

**Mechanics:** same scripted verbatim-move approach; the recurring prefix/suffix off-by-one (a duplicated `var body: some View {` line) was caught and fixed each time before measuring.

**Verify:** `swift build` clean; `swift test` 494/494 pass.

**Files touched:** `Sources/Me/Views/{FigureListView,FigureGroupListView,FigureDetailView,EntityGroupCollectionView}.swift`.

**Remaining known hotspots (decreasing):** `EntityGroupCollectionView` top-level body ~158ms, `PopupTableView.body` ~297ms, plus the various list-view modifier tails (~150-450ms each) which are largely irreducible `.sheet`/`.alert` chains. Stopped here for a review checkpoint.

---

### 2026-09-03 — Compile-time diagnosis + point-1 refactor (split large `body`s)

**Context:** User reported no visible output from the `-debug-time-function-bodies` timing flag added to `Package.swift` (debug-only). Explanation: the output goes to stdout and only appears when files actually recompile — fully incremental builds print nothing. Demonstrated via forced recompiles.

Then drove a full measurement pass (clean rebuild → 124k timing lines) to rank actual type-check hotspots, and applied "point 1" (small `body`s) to the four worst offenders.

**Diagnosis tooling:** `Package.swift` now defines `compileTimingSettings` = `-Xfrontend -debug-time-function-bodies` applied to Me + MeCore in `.debug` config only.

**Aggregate per-file type-check cost (top):** ContentView 32.7s, EntityGroupCollectionView 28.7s, PlaceDetailView 25.7s, EventDetailView 17.8s, AssociationsView 13.7s, FigureGroupListView 11.6s, FigureDetailView 9.7s. (Note: totals include duplicated reporting across build stages.)

**Worst single `body`s → after refactor (single-function type-check ms):**

| body | before | after | split into |
|---|---|---|---|
| `ContentView.body` (200) | 2669 | 6 | `seedingView`, `mainView`, `sidebarContent`, `detailContent` |
| `PlaceDetailView.body` (59) | 2385 | 475 | `contentStack` + 10 section props (header, properties, alternateNames, relatedPlaces, events, figures, images, tags, groups, citations) |
| `EventDetailView.body` (59) | 1355 | 229 | `contentStack` + 13 section props (backButton, header, stickies, properties, description, attributions, involvedFigures, citations, places, things, images, tags, groups) |
| `TextBlockRow.body` (EntityGroupCollectionView) | 1361 | 192 | promoted locals to computed props (`textAlignment`, `frameAlignment`, `controlsVisible`); split `titleBar`, `contentBlock`, `footnotesBlock` |

Each section prop now type-checks in isolation (typically < 50ms); the residual cost in the detail views' `body` is the irreducible alert/sheet modifier chain.

**Mechanics:** the refactors were done with throwaway Python slice/dedent scripts (verbatim block moves, no transcription), each followed by manual brace-seam fixes at the `prefix`/`suffix` boundaries (a duplicate `var body`/struct-close can slip in). No behavior change; new hotspots that surface after splitting (`EntityGroupCollectionView.reignTower` at 290ms, and the 800ms aggregate sidebar bodies of FigureListView etc.) remain for a later pass.

**Verify:** `swift build` clean; `swift test` 494/494 pass after each refactor.

**Files touched:** `Sources/Me/Views/{ContentView,PlaceDetailView,EventDetailView,EntityGroupCollectionView}.swift`, `Package.swift`.

---

### 2026-09-02 — Architectural weakness 4B marked resolved (centralized data checks)

**Context:** The review-doc item "4B. Lack of Global Build Validation Hook" claimed there was no single internal API validating all models before runtime. The user pointed out the centralized data checks already solve it.

Review of ground truth: `Sources/MeCore/Store/ConsistencyEngine.swift` is a **single internal validation API** — `package enum ConsistencyEngine` with a pure, side-effect-free `runAll(figures:relationships:alternateNames:events:eras:places:imageAssets:sources:popupTables:)` entry point (`ConsistencyEngine.swift:903`) covering every `@Model` kind via 24 check kinds across text-signal (pronoun/gendered-noun/gender-wording), role-gender, parent-cycle, relationship-consistency (bidirectional mismatch, self-edges, duplicate edges, missing spouse links), completeness (stub figures, missing types/descriptions, unlinked events, coordinate-less places), temporal logic (death-before-birth, reign-outside-lifespan, child-born-before-parent), and integrity (orphaned aliases/images, URL-less sources, AI-draft tables) families. It's consumed by `DataIntegrityView`'s scan (`DataIntegrityView.swift:528`), which additionally filters per-kind on `ConsistencyCheckSettings`.

**Changes:** `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` — 4B marked ✅ with the write-side/read-side distinction (DuplicateMerger + Migration backfills = structural fixers; ConsistencyEngine = read-side oracle, reusable by any future CI or pre-launch validation step). `docs/TODO.md` — added the resolved item.

No source changes, no tests needed (ConsistencyEngine rules are already unit-tested).

**Files touched:** `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md`, `docs/TODO.md`.

---

### 2026-09-02 — Keys-not-strings: association source attribution promoted to `Source?`

**Context:** User pushback on architectural weakness 2A — "Relations by String should never happen again. I would mark that as sloppy design." The `Relationship` entity had `sourceRef` since 2026-08-15, but all 7 association models were still writing source attribution as a free-text `source: String`. This session eliminated string-keyed relations from every association call site.

**Changes:**
- **Models (7):** `FigurePlaceAssociation`, `PlacePlaceAssociation`, `EventPlaceAssociation`, `EventEventAssociation`, `ThingFigureAssociation`, `ThingPlaceAssociation`, `ThingEventAssociation` each gained `sourceRef: Source?` (optional, migration-safe) alongside the string.
- **`Source`:** 7 new annotated `.nullify` inverse arrays — `figurePlaceAssociations`, `placePlaceAssociations`, `eventPlaceAssociations`, `eventEventAssociations`, `thingFigureAssociations`, `thingPlaceAssociations`, `thingEventAssociations`.
- **`RelationshipManager`:** the 7 association `add*` methods take `sourceRef: Source?` and push into the corresponding `Source` array via the annotated side (same as `addRelationship`).
- **Forms:** all Add forms with a `SourcePickerView` now pass `sourceRef: selectedSource` alongside the display string (AssociationsView ×4, ThingListView ×3, EventFormView ×2). Edit forms preselect via `assoc.sourceRef` first and, on save, detach from the old Source's array and attach to the new one (mirroring `EditRelationshipForm`).
- **Backfill:** `Migration.ensureAssociationSources` — one pass per association type, reusing `primarySourceName` (first comma segment, ≥3 chars) + exact-lowercase-key match, creating a coarse Source for unknown names; additive + idempotent, never re-points. Wired into ContentView launch after `ensureRelationshipSources`.
- **Tests:** +3 — `testRelationshipManagerAssociationsLinkSource` (all 7 kinds link sourceRef + annotated inverse), `testEnsureAssociationSourcesBackfillsEachTypeAndIsIdempotent` (case-insensitive match, both directions verified, single Source row), `testEnsureAssociationSourcesCreatesCoarseSourceForUnknownName`. **494 tests pass.**

**Decisions:**
- Entity-metadata provenance strings (`Figure.source`, `Place.source`, `Event.source`, `Thing.source`, `FigureImage.source`) are *not* relational joins and are out of scope — they describe where the record came from, not what it points to. Promote only if entity-level source filtering is wanted.
- The free-text `source` string is retained on all rows as a display/legacy mirror per the codebase pattern (never the join).

**Files touched:** `Sources/MeCore/Models/{FigurePlaceAssociation,PlacePlaceAssociation,EventPlaceAssociation,EventEventAssociation,ThingFigureAssociation,ThingPlaceAssociation,ThingEventAssociation,Source}.swift`, `Sources/MeCore/Store/{RelationshipManager,Migration}.swift`, `Sources/Me/Views/{AssociationsView,ThingListView,EventFormView,ContentView}.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/{ARCHITECTURAL_WEAKNESSES_CRITIQUE,TODO,SESSION_LOG}.md`, `AGENTS.md` (convention already stated; reinforced).

---

### 2026-09-02 (follow-up) — View call sites migrated onto RelationshipManager

**Context:** Pass 2 of architectural weakness 1A. The `RelationshipManager` service (previous entry) had landed with tests; the last step was converting every manual `context.insert(...)` + multi-array-append pattern in the views onto the manager so the annotated-side linking convention can't be sidestepped at call sites.

**Changes (manager-first refactor across 16 view files + one store file):**
- **Figure↔Figure:** `RelationshipListView.commit/save`, `FigureDetailView` drop-relationship confirm + `upsertParent` (the manager's `fetchOrCreateType` replaced the old manual fetch-or-create helper, which became non-optional and the `guard let` went away) + `AddCitationSheet`.
- **Figure↔Place:** `PlacesSection.createAssociation`, `PlaceDetailView` figure-link, `AssociationsView` AddFigurePlaceAssociationForm.
- **Place↔Place / Event↔Event / Event↔Place:** `AssociationsView` AddPlacePlace/AddEventEvent/AddEventPlace forms, `PlaceDetailView` event-link, `EventDetailView` event-place, `EventFormView` place-selections (rebuild path now collects manager-created rows into a local array then assigns once).
- **Event↔Figure:** `EventDetailView.linkFigure` (was already skipping involvedFigures; kept `alsoLinkInvolvedFigures: false`).
- **Thing links:** `ThingListView` AddThingFigure/Place/Event forms + group membership, `EventDetailView` thing-event, `ThingsSection.createAssociation`.
- **Groups/Pantheons:** `FigureGroupListView.syncMembers` + `addAllMatching`, `FigureGroupFormView` toAdd loop (aliases threaded via `displayName:`), `GroupsSection.createAssociation`, `PlaceDetailView`/`ThingListView` group membership, `PantheonsSection` add + alias-set.
- **Leaves:** `AlternateNameListView`, `SourceListView.addAttachment`, stickies in Figure/Place/Event/Thing detail, `ImportService.createCitation` (returns the manager's row).
- **Dead code removed:** `GroupMemberItem.makeAssociation()` and `FigureGroupFormView.makeAssociation(for:)` (only callers were the migrated loops).

**Manager API refinement:** the roleType params (`figurePlaceRoleType`, `placePlaceRoleType`, `eventPlaceRoleType`, `eventEventRoleType`, `eventFigureRoleType`, `thingFigureRoleType`, `thingPlaceRoleType`, `thingEventRoleType`) were relaxed from non-optional to `?` to match the data model's optional role properties — this let association rows whose role may be nil (a legitimate state) flow through the manager as a drop-in. Dedupe for nil-role rows on the role-scoped joins (`PlacePlaceRoleType.associations`, `EventEventRoleType.associations`) falls back to a full-fetch pair match so unreasoned links still dedupe correctly. Role append uses `if let roleType { ... }`.

**Verify:** `swift build` clean; `swift test` **491 tests, 0 failures** (unchanged count — no behavioral change, just routing; the 14 manager tests still cover the annotated-side linkage).

**Files touched:** 16 view files under `Sources/Me/Views/` (RelationshipListView, FigureDetailView, AssociationsView, PlaceDetailView, PlacesSection, EventDetailView, EventFormView, ThingListView, ThingsSection, GroupsSection, PantheonsSection, FigureGroupListView, FigureGroupFormView, GroupMemberItem, AlternateNameListView, SourceListView), `Sources/MeCore/Store/RelationshipManager.swift`, `Sources/MeCore/Store/ImportService.swift`, `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md`, `docs/TODO.md`.

---

### 2026-09-02 — RelationshipManager service lands (architectural weakness 1A)

**Context:** Picked up recommendation 1A from `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md`: the "Bidirectional Relationship Anti-Pattern" — developers must remember that every SwiftData link must be established by appending through the side annotated with `@Relationship(inverse:)`, or the plain-side assignment silently leaves the property `nil`. The recommendation was a high-level **`RelationshipManager`** service to make inserts + appends atomic, type-safe, and readable.

**Changes:** New `Sources/MeCore/Store/RelationshipManager.swift` (`package struct`, holds a `ModelContext`). Every add method inserts the row, links it through the correct annotated sides, and returns the row (`@discardableResult`) with a `dedupe: Bool = true` default (compares `persistentModelID`s, returns the existing row). Coverage:
- `addRelationship(from:to:relationshipType:source:sourceRef:isPreferred:groupID:)` → appends to `Figure.outgoingRelationships`, `RelationshipType.relationships`, `Source.relationships`.
- `addFigurePlaceAssociation`, `addPlacePlaceAssociation`, `addEventPlaceAssociation`, `addEventEventAssociation`, `addEventFigureAssociation` (also mirrors into `Event.involvedFigures`/`Figure.events` via the annotated side, guarded against duplicates).
- `addThingFigureAssociation` / `addThingPlaceAssociation` / `addThingEventAssociation` (thing/entity/role-type arrays).
- `addGroupMember` (handles figure/place/event/thing members, dedupe compares member IDs across the four kinds), `addPantheonMembership` (links the `FigurePantheonAssociation` join row AND the plain m2m via annotated `Figure.pantheons.append(pantheon)`).
- Leaves: `addAlternateName` (figure/place), `addStickyNote` (figure/place/event/thing), `addTag`, `addCitation`, `addAttachment`.
- Fetch-or-create helpers: `relationshipType(named:)` + `figurePlaceRoleType` / `placePlaceRoleType` / `eventPlaceRoleType` / `eventEventRoleType` / `eventFigureRoleType` / `thingFigureRoleType` / `thingPlaceRoleType` / `thingEventRoleType`, backed by a private generic `first<M: PersistentModel>(where:)` fetch.
- `save() throws` convenience. No auto-save inside adds — call sites keep transaction control. Internal `push` helpers (`inout [M]`, `inout [M]?`) keep optional-array appends (`figure.pantheonAssociations`, `event.figureAssociations`) uniform.

**Tests:** 14 new `// MARK: - RelationshipManager` tests verify both-sides linkage + row counts (the whole point of the annotated-side fix), dedupe (incl. `dedupe: false`), sourceRef linking, optional-array appends, group/pantheon membership, alternate-name/sticky/tag/citation/attachment leaves, fetch-or-create idempotency, and a `save()` round-trip on a disk container. One interesting catch: `testRelationshipManagerPantheonMembership` failed on the plain m2m `Pantheon.figures` until `addPantheonMembership` also pushed the pantheon into annotated `Figure.pantheons` — the join row alone does NOT populate the m2m.

**Also:** marked 1A as ✅ in `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` with a follow-up note to migrate view call sites onto the manager.

**Verify:** `swift build` clean; `swift test` **491 tests, 0 failures** (477 + 14 new).

**Files touched:** `Sources/MeCore/Store/RelationshipManager.swift` (new), `Tests/MeCoreTests/MeCoreTests.swift`, `docs/ARCHITECTURAL_WEAKNESSES_CRITIQUE.md`.

---

### 2026-09-02 (follow-up) — Mini lineage trunk anchored to the parent-pair midpoint

**Context:** User reported (mini lineage tree) that when the father is known but the mother is unknown, the vertical trunk to the inspected figure hangs off-center — originating at/near the Unknown-Mother chip — instead of from the middle of the "connection line" (the `—` between the two parent chips). The big lineage tree's engine was already ruled correct: `LineageTreeLayout` reproduces the exact scenario with the trunk at the couple midpoint, and that case is now locked in a regression test (`testLineageTreeLayoutTrunkOriginatesAtCoupleMidpoint`, covering both-unknown / father-known / mother-known).

**Root cause:** `MiniLineageView`'s `connectorPiece` is a plain *centered* child of the column `VStack`, so its x is pinned to the row's center-of-mass. With equal-width chips (both parents unknown) the row center coincides with the chip midpoint; with a real `ParentChipView` father + narrower `? unknown mother` chip it sags toward the mother.

**Changes:** the trunk is now anchored to the dash itself. `pairDash` (the `—` `Text`) reports its `midX` through a `PreferenceKey` (`ParentPairDashCenterKey`) in a named coordinate space; the column reports its own center (`LineageColumnCenterKey`); `parentTrunk` = `connectorPiece.offset(x: pairDashCenter − columnCenter)`. Since the dash sits between the two chips with equal (8pt) spacing, its center is by construction the parent-pair midpoint, so the trunk now hangs from the middle of the connection line in every configuration — including the both-unknown case (offset ≈ 0, unchanged) and when the Alt-couples button adds trailing asymmetry. Grandparents connector untouched.

**Why not structural:** embedding the dash + trunk + chevron as one column between the chips would be shift-free but changes vertical alignment/sizing of the parent row; the offset approach preserves the existing vertical layout exactly and only relocates the trunk horizontally (`.offset` relocates drawing, not layout).

**Verify:** `swift build` clean; `swift test` **477 tests, 0 failures** (476 + 1 new regression test).

**Files touched:** `Sources/Me/Views/MiniLineageView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-09-02 — Lineage tree geometry extracted into testable MeCore engine

**Context:** The user found it disturbing that the lineage tree view — the source of many past display bugs — had zero automated test coverage. Pushing back on "views are hard to test" as an excuse, I established (and this session implements) that the lineage tree's hard part was never SwiftUI rendering: tree building, card-frame layout, and bracket-segment geometry are deterministic math over the figure/relationship models. The pure logic is now extracted into a MeCore engine and unit-tested; the view became a thin drawing pass-through.

**Finding (TODO #2 opened/closed along the way):** `FigureCardView`'s `coordinateSpace`/`onPositionChange` plumbing — the subject of the open "Lineage lines: consider PreferenceKey approach" item — turned out to be **dead code**. No caller ever passed either parameter (`LineageTreeView` computes everything itself via `Canvas`; `FigureLineageExplorer`/`MiniLineageView` never supply frames). There was nothing fragile left to convert; the plumbing was removed instead.

**Changes:**
- New `Sources/MeCore/Store/LineageTreeLayout.swift` — a `package enum` (mirroring the `SKLDatePropagator`/`SKLTimelineLayout` pattern) holding the pure logic ported verbatim from `LineageTreeView`, operating on the real `Figure`/`Relationship`/`RelationshipType` models:
  - Types: `LineageEntry`, `LineageTreeData` (entries/levels/parentToChild), `LineageLayout` (nodeLayouts/figureAltCounts/canvas), `LineageSegment` (Equatable), `Metrics` (geometry constants with `.standard` defaults matching the old view).
  - `buildTreeData(center:relationships:generationsAbove:generationsBelow:collapsedNames:)` — entry building incl. unknown-parent placeholders, share-a-figure dedup, collapse handling.
  - `computeLayout(data:metrics:)` — card frames, child-subtree trunk alignment, canvas sizing/recentering.
  - `bracketSegments(data:layout:metrics:)` + `segmentsForBracket(parentFrames:childFrames:branchBarOffset:marriageGap:)` — pure line-segment geometry (marriage bar, trunk, branch bar, drop lines).
  - `preferredPartner(of:relationships:)`, `partnerCount(of:relationships:)`, `isUnknownParentName(_:)`.
- `LineageTreeView.swift` — deleted the ~370 lines of ported logic and all private geometry constants; now calls the engine (`metrics = LineageTreeLayout.Metrics.standard`) and strokes the returned `[LineageSegment]` in `drawBrackets`. Drawing (colors, badge, mugshot) and interaction (tap/hover/hit-test on `nodeLayouts`) unchanged.
- `FigureCardView.swift` — removed the dead `coordinateSpace` + `onPositionChange` + `GeometryReader` frame-reporting (also dropped the `.onChange(of: frame)`).
- **14 new tests** (`// MARK: - LineageTreeLayout` + `// MARK: - Lineage bracket segments` in `MeCoreTests.swift`): generation structure, preferred-partner/alt-count, trunk alignment (exhaustive over every parent→children link), no-overlap within a generation, couple-card adjacency, vertical generation spacing, canvas bounds, descendant-side Unknown-Mother placeholder, ancestor-side Unknown-couple placeholder, collapse stops expansion both directions, `isUnknownParentName`, exact bracket geometry for a couple and a single parent, and end-to-end bracket invariants on a real tree (marriage bar + drop lines + axis-alignment).

**Key decisions:** the engine operates on the real SwiftData models rather than a model-light view-projection, so the tested code is byte-for-byte the production path (placeholder `Figure` instances created inside `buildTreeData` stay un-inserted, exactly as at runtime). Geometry constants are injectable via `Metrics` so tests can adjust canvases later; firing placeholders/`PersistentIdentifier` in the test fixture is done by inserting real figures into an in-memory container (mirrors the app). The `PreferenceKey` refactor is unnecessary — connector lines come from computed layout, not rendered-frame lookup.

**Verify:** `swift build` clean. `swift test`: **476 tests, 0 failures** (462 prior + 14 new).

**Files touched:** `Sources/MeCore/Store/LineageTreeLayout.swift` (new), `Sources/Me/Views/LineageTreeView.swift`, `Sources/Me/Views/FigureCardView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/TODO.md`.

---

### 2026-09-01 (evening) — Collectives feature, skip-login dev switch, lineage gating

**Context:** Continuing after the dynasty-ordering fix. The user wanted to track the peoples/nations of Mesopotamia (Akkadians, Assyrians, Hittites, …) — "collectives" distinct from individual figures. Debated modeling options (figure-with-type vs subclassing vs Thing); settled on **Figures with a dynamic FigureType**, the same pattern the existing "Divine Collective" (Anunnaki/Igigi) already uses. Also asked for a dev-only login bypass.

**Changes:**
- `Migration.ensureCollectives`: creates "Human Collective"/"Mixed Collective" types, a top-level **"Collectives"** sidebar group, and 10 collective figures (Sumerians, Akkadians, Gutians, Amorites, Babylonians, Assyrians, Elamites, Hurrians, Kassites, Hittites) with descriptions, domains, and era links; folds existing divine collectives (Anunnaki, Igigi) into the group.
- `Migration.ensureCollectiveMembers`: seeds 35 key rulers across the thin collectives + links them to their collective via a new **"Member of"** relationship type; also links 53 pre-existing figures (SKL kings, Isin kings, Kültepe merchants) to their collectives.
- `Migration.ensureCollectiveAlternateNames`: 23 cross-cultural aliases (Akkadeans, Amurru/Martu, Hatti/Nesites, …).
- `Migration.ensureCollectiveTerritory`: new **Homeland/Capital/Territory** `FigurePlaceRoleType`s, creates Hattusa/Washukanni/Dur-Kurigalzu, links 22 collective↔place associations.
- **Skip-login dev hack** (`@AppStorage("skipLogin")`, default off): ContentView auto-signs-in as the first user after migrations; toggle in App Settings → Development.
- **Lineage gating**: "Show in Lineage Tree" is now disabled (not hidden) for collectives — a collective has no family relationships, so the lineage tree showed a meaningless lone node. Disabled in the Figures-list context menu, the green-tree detail-toolbar button (added `isEnabled` to `ToolbarButton`), and QueryView's "Show Lineage" (added a plain `figureTypeName` value to `FigureDossier` to avoid faulting in body).
- Committed + pushed as `b004536` (34 files; also swept in the user's prior uncommitted text-block-attribution work per user request).

**Key decisions:** collectives are figures (not a new model) — the type is a data-level flag, so a future dedicated model would be an additive migration; roles (Homeland/Capital/Territory) are dynamic `FigurePlaceRoleType` rows, not enum changes; "Member of" relationship category `membership` is deliberately excluded from lineage trees (family only).

**Verify:** `swift build` clean; 450 tests pass (added tests for each migration). Manual: relaunch → "Collectives" appears in the sidebar History section; collective pages show members, aliases, and homeland/capital places.

**Files touched:** `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/AppSettingsView.swift`, `Sources/Me/Views/FigureListView.swift`, `Sources/Me/Views/QueryView.swift`, `Sources/Me/Views/DetailToolbar.swift`, `Sources/MeCore/Store/DossierBuilder.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `AGENTS.md` (debugging lesson), `docs/SESSION_LOG.md`.

### 2026-09-01 — Dynasty sidebar ordering: root cause was the view, not the data

**Context:** User reported the "Dynasties" sidebar entry not matching the post-flood timeline sequence (first appeared alphabetical, then out-of-order). Three data-layer fixes were applied and each was declared "fixed" — but the user kept seeing the wrong order. Lesson: the cause was never the data; it was the **view**.

**Root cause (finally):** Clicking "Dynasties" opens `EntityGroupCollectionView`, whose `mixedItems` sorts members+subgroups **alphabetically by name** unless `group.sortMode == .ordered`. The "Dynasties" group had `sortMode == .alphabetical` (the model default), so its 20 dynasty subgroups rendered as "Dynasty of Adab, Dynasty of Akkad, …" regardless of correct `orderIndex` values. The sidebar *disclosure* row (`SidebarGroupRow`) sorts by `(orderIndex, name)` and was already correct — the mismatch was the group *page*.

**Changes:**
- `Migration.ensureDynastyGroups`: (1) syncs each subgroup's `FigureGroup.orderIndex` to its linked `Era.orderIndex` (subgroups were created with a sequential counter, not the era's ruling order); (2) broadened the era filter to the full SKL ruling block (`First dynasty of Kish` → `Dynasty of Isin`) so the two non-"dynasty"-named eras ("First rulers of Uruk", "Gutian rule") get subgroups too; (3) reconciles the legacy "Sumerian King List" tree (adds missing dynasties, renames typos like "Fouth…"/"rhird…", syncs order); (4) sets the "Dynasties" group's `sortMode = .ordered` so its page lists dynasties chronologically.
- `ContentView` + `AppSettingsView`: `@AppStorage("skipLogin")` dev hack — when on, launch auto-signs-in as the first user, bypassing `LoginView`. Default off.
- Tests: added `testEnsureDynastyGroupsIncludesFullSKLRulingBlock` (20 eras in ruling order + `sortMode == .ordered`) and `testEnsureDynastyGroupsRepairsLegacyTreeToRulingOrder`; updated `testEnsureDynastyGroupsLinksErasAcrossOtherTrees` for rename behavior. 442 pass.

**Lesson promoted to AGENTS.md:** new "Debugging Data-Versus-View Mismatches" section — a "sorted alphabetically" symptom is a view-layer signature (name-based sort, e.g. `sortMode`); trace the exact view before touching data.

**Files touched:** `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/AppSettingsView.swift`, `Sources/Me/Views/LoginView.swift` (env key, read-only), `Tests/MeCoreTests/MeCoreTests.swift`, `AGENTS.md`.

### 2026-08-30 — Source description field upgraded to rich text

**Context:** `Source` had no `richDescription`, so its description field was edited with a plain `TextEditor` and displayed as plain text.

**Change:**
- Model: `Source` gained `richDescription: Data?` (optional, migration-safe) + init param defaulting to nil.
- `SourceFormView`: the Description `TextEditor` is now `RichTextEditorSection(richData: $richDescription, plainText: $sourceDescription)` (same toolbar-equipped editor used by Figure/Place/Event/Thing forms); load/save round-trips `richDescription`.
- `SourceDetailView`: description renders via `LinkedDescription(text:richData:)` so RTF and inline entity links display when present.

**Files touched:** `Sources/MeCore/Models/Source.swift`, `Sources/Me/Views/SourceListView.swift`.

**Verification:** `swift build` clean. `swift test`: 440 tests, 0 failures.

---

### 2026-08-30 — Comparison-table source references: numbered footnote keys

**Context:** The in-cell source references rendered as full `Source: <name>` footnotes under every cell value, which got messy and unreadable in the grid. User chose the "numbered footnote key" option: cells show a small superscript number, the full references live once in a footnote block under the table.

**Change:**
- `CellView` now takes `sourceNumbers: [Int]` instead of `[CellSourceEntry]`; renders a superscript `¹`-style marker (comma-joined, `.caption2`, `baselineOffset(4)`) after the value. Tooltip lists the footnote numbers.
- `PopupTableView` computes `tableFootnotes` in row-major order (attributes × columns, first appearance wins), each unique `name — location` source numbered once; `footnoteNumbers(for:)` maps a cell's sources to their numbers. The table-wide header source is not numbered (already stated in the header).
- Footnote block added *inside* the vertical `ScrollView`, right under the grid (Divider + `N` `Source: <name>` rows reusing `SourceFootnoteView`), so it scrolls with content. `tableNaturalContentSize` includes `footnoteBlockHeight` so the window can enclose it when the table is short.
- Removed the now-unused `CellSourceFootnote`/`sourceFootnotes` from `CellView`.

**Files touched:** `Sources/Me/Views/PopupTableView.swift`.

**Verification:** `swift build` clean. `swift test`: 440 tests, 0 failures.

---

### 2026-08-30 — All detail-view associations deletable with confirmation

**Context:** Place↔Place got delete-with-confirm in the place detail view, but many other association types shown in the right-side detail panels either had no delete button at all or deleted without confirmation. User asked for every association shown in the Figure/Place/Event (and Thing) detail views to be removable from there, with confirmation.

**Change:**
- **Figure detail:** `PlacesSection` gained an optional `onDelete` on `FigurePlaceAssociationRow` + confirmation alert; `ThingsSection` existing trash now goes through a confirm alert; `GroupsSection` (figure↔group) added trash + confirm (needed a new `@Environment(\.modelContext)`); `EventsSection` added a trash button per event removing the figure from the event (deletes `EventFigureAssociation`, removes from `involvedFigures`) + confirm; `PantheonsSection` menu-toggle removal now routes through a confirm alert; tags (`TagTokenView` gained optional `onRemove`) + citations + attributions all confirm before deleting.
- **Place detail:** Events Here rows (delete `EventPlaceAssociation`), Associated Figures chips (delete `FigurePlaceAssociation`), groups, tags, citations, attributions — all with confirmation alerts.
- **Event detail:** figure removal now confirms; Associated Places (`EventPlaceAssociation`), Things (`ThingEventAssociation`), tags, citations, attributions, groups (confirmation before depropagation) — all with confirmation.
- **Thing detail (`ThingListView`):** attributions and groups now confirm (figure/place/event association rows already had confirm via `onDeleteAssociation`).
- **Shared:** `ImageGallery` and `AllImagesGallery` image deletion now confirm (the file is deleted too). `EntityGroupsSection` gained a plain `onRemove` hook (for confirmation) alongside `onRemoveWithDepropagation`.

**Files touched:** `Sources/Me/Views/FigureDetailView.swift`, `PlacesSection.swift`, `ThingsSection.swift`, `GroupsSection.swift`, `EventsSection.swift`, `PantheonsSection.swift`, `FigureDetailInfoView.swift`, `PlaceDetailView.swift`, `EventDetailView.swift`, `ThingListView.swift`, `EntityGroupsSection.swift`, `FigureImageGallery.swift`, `TagEditorView.swift`, `CitationsSection.swift`.

**Verification:** `swift build` clean. `swift test`: 440 tests, 0 failures.

---

### 2026-08-30 — Source references aligned with the free-text footnote layout

**Context:** The canonical source-reference footnote in free-text blocks (`TextBlockRow`) is `[book.and.wrench teal] Source: <name> (click to see, note: may open browser window)`. The table-wide source reference (header + "Inheriting table" line in the cell editor) and the in-cell source marker (bare `*`) didn't share that layout.

**Change:**
- Added shared `SourceFootnoteView` (icon + "Source: <name>" + optional URL link) in `PopupTableView.swift`; the table header now renders the table's source through it (URL from `table.sourceRef?.url`), and the cell editor's empty-source state shows "No source recorded" (tertiary) or `SourceFootnoteView` with the table source's URL instead of "Inheriting table (X)".
- Replaced the in-cell `*` marker in `CellView` with the same footnote layout: the cell now stacks a trailing-aligned `SourceFootnoteView` (one per source, `name — location`) under the value. `CellView` takes `sources: [CellSourceEntry]` instead of a `hasOwnSource` bool; tooltip help lists the source names. `CellSourceEntry` gained a `url` field, populated in `loadCell` from the linked `Source` row (`cell.cellSources[i].sourceRef?.url`, legacy `cell.sourceRef?.url`); `saveSources` already re-runs `loadCells()` so saved entries pick up URLs.

**Files touched:** `Sources/Me/Views/PopupTableView.swift`.

**Verification:** `swift build` clean. `swift test`: 440 tests, 0 failures.

---

### 2026-08-30 — Popup table cell editor: dropdown/field order + inheritance label

**Context:** In `CellEditPopover`, the source-picker dropdown sat *below* the location entry field; and after removing a table-wide source, a cell with no own sources still claimed "Inheriting table source" — misleading when the table has no source at all.

**Change:**
- Swapped the SOURCES input order in `CellEditPopover`: the source **dropdown + add button now come first**, followed by the Location entry field (pick the source, then optionally note the location).
- Fixed the inheritance label: when the cell has no sources and the table source is empty, it now shows "No source recorded" (tertiary) instead of "Inheriting table source"; "Inheriting table (X)" only shows when a table source actually exists. Verified against the live store — the affected table had an empty `ZSOURCE`, so the model was fine; it was purely a display claim.

**Files touched:** `Sources/Me/Views/PopupTableView.swift`.

**Verification:** `swift build` clean. `swift test`: 440 tests, 0 failures.

---

### 2026-08-30 — Content attribution on text blocks (TODO item 8)

**Context:** `GroupTextBlock` prose had no way to carry provenance — `ContentAttribution` only linked to Figure/Place/Event/Thing. User explicitly wanted attribution to stay **optional** (own prose, no source).

**Change:**
- Model: `ContentAttribution` gained `groupTextBlock: GroupTextBlock?` (migration-safe optional, forward unannotated side); `GroupTextBlock` gained annotated inverse `@Relationship(deleteRule: .nullify, inverse: \ContentAttribution.groupTextBlock) contentAttributions: [ContentAttribution]?` — matches the Figure/Place/Event/Thing pattern. No `Migration.swift` backfill needed (optional attribute, no existing rows need values).
- `ContentAttributionFormView`: optional `groupTextBlock:` param. When non-nil it runs in text-block mode — no Entity section at all (the parent is already the text block), the Property dropdown offers only "Summary" / "Full text", and `canSave` requires only a non-empty content preview. Save/load set `attribution.groupTextBlock`.
- `GroupTextBlockSheet`: new Attributions section (reuses `ContentAttributionSection`) with add/edit/delete driving the form as a nested sheet; content wrapped in a ScrollView, sheet height 620 → 760. Attributions remain fully optional — Save never requires one.
- `TextBlockRow`: right-aligned attribution footnote under the prose — `book.and.wrench` icon + "Source: <name>" + (when the attribution or its source has a URL) a `Link("(click to see, note: may open browser window)")`; the link is omitted when no URL exists. The footnote data is a plain value struct (`TextBlockAttributionFootnote`) loaded off the render path into `@State`, so no `@Model` relationship is faulted in `body`. **Reactivity fix (two rounds):** the footer initially didn't update after adding an attribution — a `.task(id: block.persistentModelID)` runs once per row appearance and never re-fires (the id doesn't change). The collection view now bumps `textBlockRevision` via `.onChange(of: editingTextBlock)` (fires when the sheet closes) and the row keys its task on `"\(block.persistentModelID)-\(attributionRevision)"`. **Round 2 bug:** the SKL "Sumerian King List" group renders via `EntityGroupCollectionView` (it has subgroups), and the target text block lived inside a subgroup ("First dynasty of Kish"), rendered by `EntityGroupTreeNode`. The main-body `EntityGroupTreeNode` call site did NOT forward `attributionRevision` (only the recursive call did), so subgroup text blocks never re-ran their task — verified against the live store via sqlite (`ZGROUPTEXTBLOCK` pk 6 → group 18 → parent group 3, attribution pk 419 linked to block 6). Fixed by forwarding `attributionRevision: textBlockRevision` at the main call site. The filter compares by `persistentModelID` rather than model-object `==`, because a second context returns a different instance for the same row (`PersistentIdentifier` is stable across contexts — verified by test; model identity is not).
- `ContentAttributionFormView` text-block mode refinement: Entity section removed entirely (the parent is the text block; no entity to pick); Property dropdown offers only "Summary" / "Full text".
- Tests: `testGroupTextBlockAttributionRoundTrip` (block↔attribution link, source round-trip, no figure/place/event/thing) + `testGroupTextBlockAttributionIsOptional` (zero-attribution block valid, `.nullify` on block delete leaves the attribution detached) + `testGroupTextBlockAttributionFormSavePath` (disk container, second-context fetch proving `persistentModelID` survives a save/reload round trip).

**Files touched:** `Sources/MeCore/Models/ContentAttribution.swift`, `Sources/MeCore/Models/GroupTextBlock.swift`, `Sources/Me/Views/ContentAttributionFormView.swift`, `Sources/Me/Views/EntityGroupCollectionView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/TODO.md`.

**Verification:** `swift build` clean (only pre-existing warnings). `swift test`: 439 tests, 0 failures.

---

### 2026-08-29 — Rich-text cell value editor (like the comment editor)

**Context:** Cell value in `CellEditPopover` was a plain `TextEditor`; user wanted the same rich-text (toolbar) editing as the comment sheet.

**Change:**
- Model: `PopupTableCell` gained optional `richValue: Data?` (RTF) alongside `value`; `RichTextEditor` keeps the two in sync. Optional for migration safety.
- `PopupTableView`: `cellRichValues` state + `richValueBinding`/`saveRichValue` mirror the comment path; loaded/cleared in `loadCell`/`loadCells`. `CellEditPopover` now uses `RichTextEditorSection(richData: $richValue, plainText: $value)` (B/I/U, font panel, strip); popover frame bumped to 460×560 to fit the toolbar. Cell display and all value logic still read the plain `value`.

**Files touched:** `Sources/MeCore/Models/PopupTableCell.swift`, `Sources/Me/Views/PopupTableView.swift`.

**Verification:** `swift build` clean. `swift test`: 437 tests, 0 failures.

---

### 2026-08-29 — Draggable header-row height on comparison tables

**Context:** Column headers were locked to the content row height (120pt), so a table like "Enki vs. Enlil" had a comically tall header. User wanted the first-row (header) height adjustable "like column widths".

**Change:**
- Model: `PopupTable` gained optional `headerHeightRaw: Double?` (+ `headerHeight` accessor defaulting to `PopupTable.defaultHeaderHeight` = 48; nil stored when exactly 48). Optional for lightweight-migration safety, so existing tables immediately get the compact default.
- View (`PopupTableView`): header `GridRow` now uses `headerHeight` instead of `rowHeight`; added a full-width horizontal resize bar (`Rectangle` with `gridCellColumns(columns.count + 1)`) just under the header row with a vertical `DragGesture` (`headerHeightGesture`) that clamps 28...200 and persists via `table.headerHeight` on release. Bar shows a faint divider, accent on hover/drag, with `.help` tooltip. `tableNaturalContentSize` accounts for `headerHeight`.

**Files touched:** `Sources/MeCore/Models/PopupTable.swift`, `Sources/Me/Views/PopupTableView.swift`.

**Verification:** `swift build` clean. `swift test`: 437 tests, 0 failures.

---

### 2026-08-29 — Gender-wording exemption for Kubaba (female "king")

**Context:** Integrity check flagged Kubaba/Kug-Bau as wrong gender because she is recorded as a "king" of Kish. This is historically correct — she was the only woman on the Sumerian King List, and "king" is her genuine title. User: "The woman was a king... Room for an exception."

**Change:** `ConsistencyEngine.genderConflict` now returns nil (skips the gender-wording check) for figures whose normalized own-name keys match a documented exemption set `genderWordingExemptNames` (["Kug-Bau", "Kubaba", "Kugbau"]). Because the check is keyed off `ownKeys` (already passed by both the engine and the `FigureFormView` live hint), the exemption suppresses both the integrity finding and the editing-time hint. Any non-exempt female figure described as "king" is still flagged. Added `testGenderWordingExemptsKubaba`.

**Files touched:** `Sources/MeCore/Store/ConsistencyEngine.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

**Verification:** `swift build` clean. `swift test`: 437 tests, 0 failures.

---

### 2026-08-29 — Ambiguous-alias check suppressing syncretism names

**Context:** Integrity check flagged the alternate name "ASARLUHI" as attached to multiple figures ("ASALLUHI" and "MARDUK"). This is a known syncretism: the seed marks `Asarluhi` with `nameType: "Syncretism"` ("Sumerian deity absorbed into Marduk"). A syncretism name is INTENDED to span the syncretized deities, so flagging it as an ambiguous/duplicate alias is a false positive (it's a `.warning`, not an error).

**Change:** `checkAmbiguousAliases` in `ConsistencyEngine` now skips alternate names whose `nameType == .syncretism`, since those exist precisely to link multiple syncretized gods. Real duplicate aliases (non-syncretism) are still flagged. Added `testAmbiguousAliasRuleSkipsSyncretismNames`.

**Files touched:** `Sources/MeCore/Store/ConsistencyEngine.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

**Verification:** `swift build` clean. `swift test`: 436 tests, 0 failures.

---

### 2026-08-29 — Gendered-noun false positive on relational/collective mentions

**Context:** Data-integrity checks flagged a female collective ("Daughters of Men") because its text mentions masculine words ("gods", "sons"). User: "The fact that males are mentioned does not make it incorrect. It underlines that the parser is not very strong."

**Change:** `ConsistencyEngine`'s gendered-noun rule was too eager — it counted ANY gendered noun, including kinship/relational terms (`mother`, `father`, `son`, `daughter`, `brother`, `sister`, `wife`, `husband`, `widow`), which describe OTHER people in a figure's story. Restricted `feminineNouns`/`masculineNouns` to **self-descriptive** nouns only (`goddess`, `queen`, `priestess` / `god`, `king`, `priest`, `prince`). Relational terms no longer trigger on their own; the existing mixed-wording skip (both genders present → ambiguous → silent) is preserved, so "goddess + king" still isn't flagged. Whole-word tokenization already excluded plurals.

**Also:** `testGenderedNounRuleUsesWholeWords` was failing not from the rule but from a too-broad test filter — `consistent` matched an unrelated `figureWithoutType` info finding; it now filters `.kind == .genderedNoun`. Added `testGenderedNounIgnoresRelationalKinshipNouns`.

**Files touched:** `Sources/MeCore/Store/ConsistencyEngine.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

**Verification:** `swift build` clean. `swift test`: **435 tests, 0 failures** (the previously pre-existing failure is resolved).

---

### 2026-08-29 — Per-cell comments on comparison tables

**Context:** User collects notes on individual comparison-table cell contents and wanted to (1) enter/store them and (2) view them in the table.

**Change (final design — dedicated comment sheet):**
- Model: added optional `comment: String?` to `PopupTableCell` (+ init param). Optional for lightweight-migration safety per convention.
- Storage: `commentBinding`/`saveComment` in `PopupTableView` mirror the existing value pattern (get from `cellComments` dict, set → `ensureCell` + save). Loaded in `loadCells`/`loadCell`.
- Viewing: `CellView` shows a tappable `note.text` glyph as a Button when a comment exists, plus a `.help` tooltip with the comment text; the glyph opens a dedicated `CommentEditorSheet`. Clicking the rest of the cell still opens the value/source `CellEditPopover`.
- Editor: `CommentEditorSheet` is a separate, roomy sheet (640×460) that reuses the app's `RichTextEditorSection` (NSTextView + AppKit toolbar: B/I/U, font panel, strip) so comments support rich text like other editors. To store it, `PopupTableCell` gained a `richComment: Data?` (RTF, optional for migration safety) alongside `comment`; `richCommentBinding`/`saveRichComment` mirror the plain-text path. The comment is NOT crammed into `CellEditPopover` (which stays value + sources only, 440×480).
- Tests: `testPopupTableCellCommentRoundTrip` (persist round-trip).

**Files touched:** `Sources/MeCore/Models/PopupTableCell.swift`, `Sources/Me/Views/PopupTableView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`.

**Note:** the emoji state cells (from the prior entry) also got a feedback pass — removed the accent pill/background and padding, shrank the emoji to 40pt, and centered it.

**Verification:** `swift build` clean. `swift test`: 434 tests, 1 pre-existing unrelated failure (`testGenderedNounRuleUsesWholeWords`); new tests `testPopupTableCellCommentRoundTrip` and `testEnsureComparisonStateEmoji` pass.

---

### 2026-08-29 — Comparison-table state emoji (rendering + data migration)

**Context:** User maintains a "Mesopotamian City Matrix" comparison table where city states are "friendly"/"neutral"/"hostile". Wanted big emoji icons for these states.

**Change — rendering:** `CellView` in `PopupTableView.swift` detects a standalone emoji value (non-ASCII, not the `—` placeholder) and renders it large (56pt) and centered with a soft accent pill: 🤝 green, 😐/😑 yellow, ⚔️/😠/🔥 red, default accent otherwise. Non-emoji text stays the normal smaller layout. Render-only — no data touched.

**Change — data:** Real state text lives in cell `value`s, so a rendering change alone showed nothing. Added idempotent launch migration `Migration.ensureComparisonStateEmoji(context:)` (check-by-name on "Mesopotamian City Matrix"; converts a cell whose ENTIRE trimmed value equals a state word, case-insensitive, to 🤝/😐/⚔️; leaves emoji, non-state text, empty/nil cells and other tables untouched; never double-applies). Wired into `ContentView`'s migration chain after `ensureCellSourceLinksExist`. Applies automatically on next app launch.

**Files touched:** `Sources/Me/Views/PopupTableView.swift`, `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift` (+`testEnsureComparisonStateEmoji`).

**Verification:** `swift build` clean. `swift test`: 433 tests, 1 pre-existing unrelated failure (`testGenderedNounRuleUsesWholeWords`); new test `testEnsureComparisonStateEmoji` passes (covers convert, case-insensitivity, leave-untouched, unaffected-table, idempotency).

---

### 2026-08-29 — Comparison-table resize de-jittered (subpixel widths + sheet-fit fight)

**Context:** Follow-up to the sheet re-sizing work above. User reported the column resize was "jittery and jerky", then, after rounding, that a small nudge "auto resizes back to a previous size, like the size is cached", then that pressing the handle (click-to-drag) "snaps back". Final request: keep drag smooth, but on release the sheet must resize to enclose the table.

**Root causes found (two, independent):**
1. **Subpixel widths** — `liveColumnWidths`/`columnWidth(for:)` fed the `Grid` raw fractional `translation.width`, so columns/rows flipped between pixel alignments every drag frame on retina (the jitter). Fixed by snapping every grid dimension (`columnWidth`, `rowHeaderWidth`, `rowHeight`) to whole points via `.rounded()`.
2. **Sheet tracking the grid content size** — the window was being re-fitted to the (changing) grid extent on every drag frame, so it chased the pointer (jitter) and snapped on release. Grow-only fit in the first fix round didn't help because the per-frame re-fit was SwiftUI re-sizing the sheet from the content's ideal size, and the manual `fitHostWindowToTable` was fighting/undoing it.

**Kept solution:**
- During the drag the content frame is pinned to a `@State tableSize` (never updated mid-gesture), so the window is rock-steady; the grid scrolls inside the fixed frame.
- On release (`columnResizeGesture.onEnded`, `gridScaleGesture.onEnded`, `resetGridScale`, and `.onAppear`) `fitHostWindowToTable()` recomputes `tableNaturalContentSize` and sets **both** `tableSize` (the SwiftUI frame) and the sheet `NSWindow` frame (`setFrame`) from the **same clamped value**, so SwiftUI content-frame and AppKit window-frame can never disagree — that remove the fight/snap. Width and height both grow and shrink, floored at 700×400, capped at `parent.frame.width - 36` / `- 36`.
- Kept `WindowAccessor` + `hostWindow`; removed the transient intermediate design that had dropped the fit entirely (a fixed `idealWidth/maxWidth` frame) because that never re-fit on release.

**Files touched:** `Sources/Me/Views/PopupTableView.swift`.

**Verification:** `swift build` clean. `swift test`: 432 tests, 1 pre-existing unrelated failure (`testGenderedNounRuleUsesWholeWords`). User-tested: smooth drag, no mid-drag movement, sheet re-fits to enclose the table on release. "YES!!"

---

### 2026-08-29 — Comparison-table grows within the app window (sheet re-sizing)

**Context:** After column resize + grid scale shipped, user noted the table is "horizontally limited to its fixed size" — dragging a column wider could never grow the frame. Discussed the cause: the table presents as a macOS `.sheet`, and a sheet is capped at the width of its parent (the main app window). User clarified: growth within the app window is fine; it need not exceed it. Also asked not to move the table to a separate window ("I like the looks of the sheet").

**Change taken (and reverted):** Prototyped moving `PopupTableView` out of the `.sheet` into a dedicated `WindowGroup(id: "table-grid", ...)` with a `TableGridViewWindow` loader (mirroring the quicklook-window pattern) and `.windowResizability(.contentSize)` so the window auto-grows with content. Updated all three presentation sites (`PopupTableListView`, `FigureListView`, `FigureDetailView`) to `openWindow(...)` and `PopupTableView` to `dismissWindow`. Build/tests green — but **reverted wholesale** when the user confirmed the sheet should stay and only grow intra-window.

**Change kept — sheet re-sizes itself to the table:**
- Root cause: SwiftUI sizes a sheet once at presentation from the content's ideal size; a `ScrollView([.horizontal,.vertical])` fills its proposal, so ideal size never changes as columns widen → the sheet looked fixed. Also the header's `.frame(maxWidth: .infinity)` pinned the sheet full-width anyway; removed it so width is content-driven.
- Added `WindowAccessor` (`NSViewRepresentable`) that reports the hosting `NSWindow`; `PopupTableView` keeps it in `@State hostWindow`.
- `fitHostWindowToTable()` resizes the sheet window (`setContentSize`) to the table's natural size, called from `columnResizeGesture` and `gridScaleGesture` (change + end) and once in `.onAppear` after layout. Natural size is computed from current state: `rowHeaderWidth + Σ columnWidth(for:) + spacing*columns + 2` wide, `rows*rowHeight + spacing*(rows-1) + 2 + verticalChrome` tall. Width capped at `parent.frame.width - 36` (scrollbar inside the sheet takes over past that); floors at the sheet's 700×400 minimum. Height only grows (never shrinks below current height); width freely grows *and* shrinks.
- **Try 2 (reverted):** measured the grid with a `GridMeasuredSizeKey` `PreferenceKey` + `.background(GeometryReader)` inside the ScrollView to drive the fit — the measured size reported a constant viewport width (never tracked the drag), so neither grow nor shrink worked. Reverted to the deterministic formula, which tracks correctly.
- **Known rough edges (deferred per user):** re-sizing is a little jittery during fast drags — polish later.

**Files touched:** `Sources/Me/Views/PopupTableView.swift` (fit logic, `WindowAccessor`, header `maxWidth` removal, gesture hooks). Presentation reverts touched `AnunnakiApp.swift`, `PopupTableListView.swift`, `FigureListView.swift`, `FigureDetailView.swift` — all back to `.sheet`, net no change.

**Verification:** `swift build` clean. `swift test`: 431 tests, 1 pre-existing unrelated failure (`testGenderedNounRuleUsesWholeWords`). User-tested: growth works, shrink works at "an acceptable level", jitter deferred.

---

### 2026-08-28 — Comparison-table layout control: drag-to-resize columns + whole-grid scale

**Context:** User asked for more layout flexibility in comparison tables (column widths, cell alignment), then chose to go straight for drag-to-resize columns. After testing, asked for whole-grid proportional resizing ("change table width, and also height") — a corner handle that scales every column and row uniformly. The core structural problem: figures-mode tables have no column entity — columns are shared `Figure`s — so per-column widths must live per-table.

**Changes made:**
- **New model `PopupTableColumnLayout`** (`Sources/MeCore/Models/PopupTableColumnLayout.swift`) — `@Model` with `table`, `figure?`, `column?`, `width: Double?`. Exactly one of figure/column set; nil width = table default. All optional → additive lightweight migration, no reseed. New entity is empty by design (no seed backfill needed).
- **`PopupTable` storage API** — `columnLayouts` `@Relationship` (cascade, inverse `\PopupTableColumnLayout.table`, set via annotated side per convention). Helpers: `columnLayoutWidth(forFigure/forColumn:)`, `setColumnLayoutWidth(_:forFigure/forColumn:context:)` (find-or-create, overwrite), `removeFigureColumnLayouts(context:)`, `removeFigureColumnLayouts(except:context:)`, `removeStringColumnLayouts(context:)`.
- **`PopupTableView` resize UX** — column widths now come from a live `liveColumnWidths` dict during drag + `persistedColumnWidths` precomputed in `.onAppear` (no model reads in body). Each header cell is a `ZStack(alignment: .trailing)` holding a `ColumnResizeHandle`: a 10pt-wide drag target pinned to the trailing edge, drawing a 1pt separator rule (accent 3pt while active). `DragGesture.onChanged` clamps 60–560 and reflows the grid live; `.onEnded` persists via the model API. Default width stays 180 (same as before).
- **`PopupTableFormView` cleanup** — `removeStringColumns` → `removeStringColumnLayouts`; `removeFigureColumns` → `removeFigureColumnLayouts`; `syncFigureColumns` → `removeFigureColumnLayouts(except:currentFigureIDs)` so de-selected figures lose their layout rows.
- **Whole-grid scale (corner handle)** — `PopupTable.gridScaleRaw: Double?` (optional, migration-safe; nil = 1.0) with a `gridScale: CGFloat` computed accessor that stores nil when exactly 1.0. `GridScaleHandle` grip pinned to the grid's bottom-trailing corner (drags with scroll): diagonal drag scales a uniform factor (0.5–2.0, rounded to 2 decimals), clamped live, persisted on release; double-click resets to 100%. Column widths are stored as *design points* (180 default) and multiplied by the scale at render, so columns and rows scale proportionally and a resized column still scales. Scale-aware clamping: column-drag min/max (60–560 design pt) scale with the grid. Row header (160pt) and row heights (120pt) scale too.
- **Schema registration** — `PopupTableColumnLayout.self` added to app schema (`AnunnakiApp.sharedContainer`) and all four test schemas (main `MeCoreTests` helper + 3 real-store diagnostic copy schemas). `gridScaleRaw` needs no registration (plain optional property, lightweight migration).

**Key decisions:**
- Width stored per (table × figure|column) — never on the shared `Figure` itself, so a deity's width in one table doesn't bleed into another.
- Live-drag in `@State`, persist only on gesture end (no SwiftData save per mouse move; no jump on release because the final value stays in `liveColumnWidths` and is also merged into `storedColumnWidthPoints`).
- Re-drags compose correctly: each gesture computes from the current effective width, not from 180+translation, so the column never snaps back.
- Grid scale in *design points*: stored widths are unscaled "table points"; render multiplies by scale. Starting a scale drag clears `liveColumnWidths` so every column recomputes from stored×scale (no stuck absolute widths).
- Handle lives at the header's trailing edge (10pt hit area); no `NSCursor` changes (per convention).
- Cell alignment (left/center/right) explicitly deferred — the `PopupTableColumnLayout` entity is the natural home for an alignment field later.

**Verification:** `swift build` clean. `swift test`: 431 tests, 1 pre-existing unrelated failure (`testGenderedNounRuleUsesWholeWords`). 7 new tests: figure-width round-trip, column-width round-trip, unset-defaults-nil + overwrite, cascade delete, `removeFigureColumnLayouts(except:)`, grid-scale defaults-to-one, grid-scale round-trip (stores nil at 1.0).

**User-test follow-ups (same session):**
- **Jittery column resize fixed.** Root cause: `DragGesture.Value.translation` is *cumulative* from gesture start, but `onChanged` computed `effectiveWidth + translation` where `effectiveWidth` already included prior translations — each mouse event stacked the whole accumulated distance, causing runaway/jittery growth. Fix: capture the start width once into `dragStartWidths[columnID]` on first change, then add only the cumulative translation. The grid-scale gesture was already correct (fixed `scaleAtGestureStart` + cumulative delta).
- **Header glyph clutter removed.** String-column headers dropped the `textformat` SF glyph ("Tt" — the "letters" in front of the label). Figure-column headers shrunk their mugshot/initial-chip from 32pt to 18pt and tightened spacing/padding so narrow columns keep the label as the majority of the header.
- **Grid-scale handle moved out of the grid.** The bottom-trailing overlay blocked the last cell. Moved the `GridScaleHandle` into the footer bar, to the right of the Close button, with a live percentage readout ("115%"). Gesture/reset (double-click) unchanged.
- **Modifier-driven per-axis scaling.** Uniform scale alone made tables "unbalanced" (rows too tall, shrinking them also shrank columns). Split the single scale into two independent factors: `columnScale` (applies to column widths + row-header width; reuses existing `gridScaleRaw` column) and new `rowScale` (`rowScaleRaw` — columns/rows independently adjustable, 0.5–2.5, nil stored at 1.0). The footer handle's drag honors modifiers captured at gesture start: plain drag = both axes, **⇧ = width only**, **⌃ = height only**. Footer readout now shows both ("120% × 90%"). Existing single-axis 8-30 sensitivity unchanged per-axis.
- **Column-resize grab geometry.** Handle was an invisible 10pt strip trailing-aligned inside each header Grid-row cell: (a) the strip sat entirely *left* of the visible divider line, so users aimed at the line/a bit right of it and missed; (b) as a Grid sibling, the next column's header could sit on top of any overflow. Attempt 1 — a dedicated `.overlay(alignment: .topLeading)` HStack over the whole header row with a 16pt trailing strip* rendered invisible (overlay geometry over the padded/backgrounded grid didn't land where intended); reverted. **Attempt 2 (kept): the strip lives back inside the header cell** (proven to render), widened to 18pt with the grab zone ending exactly at the column's right edge so the boundary line itself is inside the hit area — no more "aim a few pixels left". The accent hint fills the whole strip on hover/drag.
- **Resize "handler thinks it's in the wrong position" (~60px).** Two contributing causes, both fixed: (1) `ColumnResizeHandle`'s body content was only the 2pt rule, so inner `ZStack` was 2-3pt wide and the outer `.frame(width:)` *centered* it — the visible line drifted ~9pt off the strip edge and, after a resize changed track positions, the visible marker and the true column/body-boundary disagreed (reads as a large aim offset). Fixed by preceding the rule with an **unconditional `Color.clear` anchor** so the rule pins to the strip's trailing edge and always coincides with the column boundary and the body gridlines. (2) `onEnded` left the final width in `liveColumnWidths`, so post-drag geometry was re-derived from stale state instead of the freshly persisted width; now `onEnded` writes `storedColumnWidthPoints`, persists, then **clears `liveColumnWidths`** (`columnWidth` falls back to `stored*scale`, which equals the same number). Strip also widened 18→24pt for a more forgiving target.
- **Resize-grip jitter round 2 (vertical scale + column drag "unworkable").** Root cause: the resize handles MOVE as the geometry changes mid-drag, and the default `.local` coordinate space re-measures `DragGesture.Value.translation` against the moving view — injecting phantom translation (exactly the tongue-in-cheek "works great then came back" class of bug). Fixes: (1) both gestures now use `DragGesture(minimumDistance: 0, coordinateSpace: .global)` so translation is pure pointer movement in window space and immune to handle reflow; (2) grid-scale rounding to 2 decimals moved from live-drag into `persistGridScale` only — live drag keeps full precision (no stepped jumps); (3) the double-tap reset (which competed with the drag in gesture arbitration) replaced with a dedicated circular reset button in the footer (disabled at 100%).

**Files touched:** `Sources/MeCore/Models/PopupTableColumnLayout.swift` (new), `Sources/MeCore/Models/PopupTable.swift`, `Sources/Me/Views/PopupTableView.swift`, `Sources/Me/Views/PopupTableFormView.swift`, `Sources/Me/AnunnakiApp.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-08-27 — Source ↔ comparison-table cell linking (lenient match + display)

**Context:** User reported that a cell reference to "An=Anum" in the "Agricultural and hydrological deities" table did not show up under the Source. Root cause was twofold: the `SourceDetailView` had no section listing citing table cells at all, and the cell name "An=Anum" did not exactly match the Source row "Lexical God List An = Anum (Tablet IV)", so no link was ever made.

**Changes made:**
- `Source.bestMatch(forCandidate:among:)` — shared lenient matcher. Exact normalized match (case/hyphen/space/punctuation-insensitive) wins; otherwise containment (sk.contains(candidateKey) || vice versa) with a ≥3-char candidate guard, shortest (most specific) name wins. So "An=Anum" → "Lexical God List An = Anum (Tablet IV)".
- `PopupTableCell.addCellSource` — now uses `Source.bestMatch` instead of exact case-insensitive name equality.
- `Migration.ensureCellSourceLinksExist` — additive/idempotent back-link of existing free-text `CellSource`s (sourceRef == nil) to matching Source rows via the annotated `Source.cellListSources` side. Registered in ContentView after `ensureAnAnumGodListSourceExists`.
- `SourceListView.SourceDetailView` — new `TableCellsSection` listing citing comparison-table cells (from both legacy `popupTableCells` and multi-source `cellListSources`), showing table name, attribute, column/figure, and location, deduplicated by `persistentModelID`.

**Verification:**
- 3 new tests: `testCellSourceLenientMatchLinksVariantNameToSourceRow`, `testBestMatchPrefersExactThenShortestContaining`, `testEnsureCellSourceLinksMigrationBackLinksExistingFreeTextCells`.
- Full suite: 424 tests, 1 pre-existing unrelated failure (`testGenderedNounRuleUsesWholeWords`). Build succeeds.

**Files touched:** `Sources/MeCore/Models/Source.swift`, `Sources/MeCore/Models/PopupTableCell.swift`, `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/SourceListView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`, `docs/SESSION_LOG.md`.

---

### 2026-08-26 — Data Integrity overhaul: 13 new checks + redesigned results UI

**Context:** User wanted the database in "mint condition." Added 13 new consistency/completeness checks across 5 categories, a dynamic bidirectional relationship fixer, and redesigned the scan results page.

**Changes made:**

*ConsistencyEngine — 13 new checks added:*
- **Relationship consistency (3):** `bidirectionalMismatch` (Spouse/Consort/Sibling/Ally/Enemy one-directional), `selfReferentialEdge` (any from→to same figure), `duplicateEdge` (same from→to→type twice)
- **Data completeness (4):** `figureWithoutType`, `figureWithoutDescription`, `eventWithNoLinks`, `placeWithoutCoordinates`
- **Temporal logic (3):** `deathBeforeBirth`, `reignOutsideLifespan`, `childBornBeforeParent`
- **Data integrity (3):** `orphanedAlternateName`, `orphanedImageAsset`, `sourceWithoutURL`
- Added `places`, `imageAssets`, `sources` parameters to `runAll()` (backward-compatible defaults)

*Migration.swift — `ensureBidirectionalRelationshipConsistency`:*
- Scans all Spouse/Consort/Sibling/Ally/Enemy edges; if X→Y exists but Y→X does not, creates the reverse link preserving source/sourceRef/groupID. Wired into ContentView launch chain after `ensureCanonicalDeityFamilies`.

*DataIntegrityView.swift — Redesigned results page:*
- Title now shows "Data Integrity on <date>" with scan timestamp
- Summary line: "N issues detected. See details below."
- Results grouped into 6 collapsible sections by category: Structural, Relationship Consistency, Content Consistency, Data Completeness, Temporal Logic, Data Integrity
- Each section has chevron toggle, count badge, and "No issues detected" for clean categories
- Removed separate "Find Duplicates…" button — duplicate detection now runs inline with Scan
- Duplicate name rows show Merge button that opens DuplicateMergeView sheet
- "No duplicate names found" message when no duplicate issues exist
- `@State collapsedSections: Set<String>` for collapsible state

*TODO.md — All 13 items marked complete:*
- Relationship consistency (3/3), Data completeness (4/4), Temporal logic (3/3), Data integrity (3/3)

**Key decisions:**
- Bidirectional check covers only inherently-mutual types (Spouse, Consort, Sibling, Ally, Enemy) — not Father/Mother which are directionally correct
- Child-born-before-parent only flags when both child and parent have known birth years
- Reign-outside-lifespan checks both start-before-birth and end-after-death independently
- Orphaned images check all four entity arrays (figures/places/events/things), not just figures
- Collapsible sections use a simple `Set<String>` toggle — no persistence across launches

**Verification:** `swift build` clean, `swift test` — 411 tests, 1 pre-existing failure (`testGenderedNounRuleUsesWholeWords`).

---

### 2026-08-26 — Dynamic Spouse link detection + Data Integrity for missing spouses

**Context:** User ran Data Integrity scan and saw 15+ missing Spouse relationship warnings. Previous approach hardcoded specific couples; user wanted a fully dynamic solution.

**Changes made:**
- **Sources/MeCore/Store/Migration.swift** — Rewrote `ensureCanonicalDeityFamilies`:
  - Removed hardcoded `missingSpousePairs` list and manual Enki→children loop.
  - New dynamic logic: builds parent maps (child→mothers, child→fathers) from all Mother/Father edges, detects every couple with a shared child but no Spouse link, and creates the missing link automatically. Covers seed data, deity imports, and runtime-created relationships.
  - Added `StaticIdentifier` helper struct (order-insensitive pair hashing for set membership) — same pattern as in ConsistencyEngine.
  - Kept Asarluhi mother-reassignment (Ninhursag→Damkina) as special case.
- **Sources/MeCore/Store/ConsistencyEngine.swift** — Added `missingSpouseLink` case to `ConsistencyFinding.Kind` and `checkMissingSpouseLinks` check function: detects couples with shared children but no Spouse relationship at scan time. Wired into `runAll()`. Added `import SwiftData` and `StaticIdentifier` helper struct.
- **Sources/Me/Views/DataIntegrityView.swift** — No changes needed (severity handled generically via `.info`).

**Key decisions:** Fully dynamic approach means no future maintenance when new figures/relationships are added — the migration and the scan both auto-detect. The migration runs at launch; the scan runs on-demand from Data Integrity.

**Verification:** `swift build` clean, `swift test` — 411 tests, 0 failures.

---

### 2026-08-26 — Missing Sumerian deities import + duplicate detection

**Context:** User requested research on Sumerian/Mesopotamian deities not yet in the database. Cross-referenced 228 existing figures (seed_data + deities_import + Migration hardcoded) against known deity lists. Produced a new import file and handled duplicate detection.

**Changes made:**
- **Web research**: Searched Wikipedia, mifologia.com, and other sources for missing deities. Collected name, alternate names (Sumerian/Akkadian/Babylonian), title, domain, gender, description for 30+ candidates.
- **Cross-reference**: Checked all 30 candidates against existing database (seed_data.json, deities_import.json, Migration.swift). Found 4 duplicates:
  - Ki → already an alt name of Ninhursag in seed_data
  - Erra → already an alt name of Nergal in seed_data
  - Asarluhi → already an alt name of Marduk in seed_data
  - Bau → same as Kug-Bau (existing seed figure)
- **Sources/MeCore/Resources/missing_deities_import.json**: Created with **27 new figures** + 54 alternate names (Lahmu, Lahamu, Mummu, Damkina, Dagan, Nanshe, Ninkasi, Nuska, Namtar, Nungal, Gibil, Enbilulu, Geshtu-E, Uttu, Ninshar, Belili, Ninmug, Gula, Tashmetum, Tishpak, Ishum, Ninmalki, Sul-pa-e, Damu, Lisin, Mamitu, Bau).
- **Sources/MeCore/Store/Migration.swift**: Added `markPreExistingSyncretisms(context:)` — adds sticky notes "FROM 26-08-2026 IMPORT" to existing figures that had duplicate deity names (Ninhursag/Ki, Nergal/Erra, Marduk/Asarluhi, Kug-Bau/Bau, Damkina). Idempotent, additive only.
- **Sources/Me/Views/ContentView.swift**: Added migration call after `ensureOraccDeityImports`.

**Key decisions:** User wants to review the import file before wiring it up to auto-import. Descriptions contain relationship hints (e.g., "herald of Nergal") but these are text only — actual Relationship entries must be added manually during vetting. No figures deleted from DB under any circumstances.

**Verification:** `swift build` clean, `swift test` — 411 tests, 0 failures. JSON validated.

---

### 2026-08-26 — Tests for SKLDatePropagator and Migration (items 10 + 11)

**Context:** SKLDatePropagator.swift had 0% test coverage; Migration.swift had ~15%. Wrote comprehensive tests for both as TODO items 10 and 11.

**Changes made:**
- **Tests/MeCoreTests/MeCoreTests.swift**: Added ~770 lines of new tests:
  - **ReignLength parsing** (7 tests): `reigning for`, `reigned` without `for`, `ruled for`, `possibly reigning`, comma in numbers, empty description, no reign info
  - **SKLDatePropagator** (18 tests): empty input, era grouping, explicit birth/death dates, BCE extraction from description, BCE without reign keyword ignored, `(short)` suffix, BCE at end of description, forward propagation from anchor, backward propagation from anchor, chain breaks on missing reign length, empty era → "Antediluvian", sort by era order, unknown era sorts last, `ComputedReign.display`, `DynastyTimeline.totalYears`, `DynastyTimeline.startBCE/endBCE`
  - **Migration.ensureCoverageExemptFlags** (3 tests): sets exempt for eligible types, skips already-exempt, idempotent
  - **Migration.ensureSKLDomain** (4 tests): backfills from title, does not overwrite existing, unknown title no-op, all dynasty titles
  - **Migration.fixAllyIcon** (3 tests): updates handshake → person.2.fill, no-op for correct icon, does not touch other types
  - **Migration.extractAlternateNamesFromDescriptions** (5 tests): creates alt names, cleans description, skips empty, skips no match, idempotent
  - **Migration.ensureCommanderFigureTypeExists** (4 tests): creates if missing, reuses existing, reassigns Watcher chiefs, reverts non-commander names
  - **Migration.ensureArchangelsExist** (3 tests): creates 7 archangels, skips existing, creates Archangel FigureType
  - **Migration.ensureMissingCommanderFiguresExist** (3 tests): creates Hermani+Yehadiel, skips existing, creates Commander relationships from Samyaza
  - **Migration.ensureDumuziFamilyExists** (4 tests): creates Duttur, creates parent relationships, idempotent, skips already-linked
  - **Migration.removeAutoGeneratedStickies** (2 tests): removes "Missing " prefix stickies, idempotent

**Verification:** `swift build` succeeds, `swift test` — 411 tests, 0 failures (10s)

---

### 2026-08-25 — About panel icon fix and File > New menu wiring

**Context:** Two quick UI fixes: (1) the standard About panel showed a generic folder icon instead of the app icon; (2) the auto-generated File > New menu items (from multiple `WindowGroup` scenes) were broken/useless, user wanted them to actually open creation forms.

**Changes made:**
- **Custom About command** (`Sources/Me/AnunnakiApp.swift`): `CustomAboutCommand` replaces `.appInfo` with `orderFrontStandardAboutPanel(options:)` explicitly passing the `.applicationIcon` loaded from `Bundle.module` (icns or png fallback), app name, version, and credits string.
- **File > New menu items** (`Sources/Me/AnunnakiApp.swift`): `CommandGroup(replacing: .newItem)` adds four items — New Figure (⌘N), New Place (⇧⌘N), New Event (⌥⌘N), New Thing (⌃⌘N) — each posting a typed `Notification.Name`.
- **ContentView listeners** (`Sources/Me/Views/ContentView.swift`): four new `@State` bools + `.onReceive` handlers + `.sheet(isPresented:)` modifiers for the creation forms (`FigureFormView`, `PlaceFormView`, `EventFormView`, `ThingFormView`).
- **Notification.Name extensions**: added `.showNewFigure`, `.showNewPlace`, `.showNewEvent`, `.showNewThing` alongside existing `.showBackupSheet`.

**Verification:** `swift build` clean. About panel shows app icon; File menu shows four working "New ..." items with distinct keyboard shortcuts, each opening the corresponding creation sheet.

---

### 2026-08-25 — Associations filter, table typography, and the comparison-table popover editor

**Context:** Three threads in one session: (1) user spotted two suspicious "Ur" associations and had no way to filter the five association tabs; (2) readability bump requested for comparison tables ("over the full board: title, description, cell content"); (3) thread 2 surfaced a long-standing editing bug — bullet-point cell values can't be entered because the inline editor commits on Return — which escalated into a full redesign of how table cells are edited.

**Changes made:**
- **AssociationsView filter** (`Sources/Me/Views/AssociationsView.swift`): shared search field beside the tab picker; `matchesFilter` (case-insensitive contains) runs over BOTH endpoint names, role name, display name, and source for each tab's rows via per-tab `filtered*` computed properties; dedicated "No associations match …" empty state distinct from the no-data state. Typing "Ur" isolates Ur-involving rows regardless of which side of the pair it sits on.
- **PopupTableView font bumps**: title `.title3→.title2`, description `.body→.title3`, cell display text AND edit fields `.body→.title3`.
- **Multiline editing saga (4 iterations, user-tested each):** single-line TextField commits on Return (no Shift+Return escape hatch on macOS) → `TextField(axis:.vertical)` STILL commits on Return under macOS Tahoe 26.5 → raw `TextEditor` in the cell worked for newlines but exposed truncation at the fixed 180×120 frame → dynamic content-driven row heights (newline-aware line estimate, 120–480pt cap) worked but user rejected it: live height reflow made scrolling jittery. **Final design: keep fixed cells, move detail+editing into popovers.**
- **Popover editor consolidation:** clicking ANY cell (empty ones too) opens `CellEditPopover` (440×380): attribute+column header, full-height title3 `TextEditor` bound to the existing live-saving `cellBinding` (per-keystroke `saveCell`), SOURCE picker (inherit-table option, saves immediately via new `saveSource` helper reusing `ensureCell`), Done button; Esc/outside click dismisses. Removed entirely: the global Edit/Done toggle + grid-wide inline editors, the right-click Edit/Clear-Source context menu (source management absorbed by the picker — "None"/inherit clears), and the old `TableCellEditor` sheet (~90 lines).

**Key decisions:** Overview-in-grid / detail-on-demand beats adaptive cells — stable layout outweighs showing everything at once; every click opens an EDITABLE popover (no read-only mode — flagged to user, lock toggle available if accidental edits become a problem); macOS lesson recorded: on macOS 26, `TextField(axis:.vertical)` still submits on Return — `TextEditor` is the only reliable multiline control.

**Verify:** `swift build` clean after each iteration; full suite **357/357 tests pass** (UI-only changes, no model/schema edits).

**Files touched:** Sources/Me/Views/AssociationsView.swift; Sources/Me/Views/PopupTableView.swift; docs/SESSION_LOG.md.

---

### 2026-08-24 — Users, login, and activity log (steps 1–5 of 5)

**Context:** User identified the two main missing features: user registration/login and an activity/change log. Requirements clarified: simple name+password registration stored in the existing SwiftData DB (no backend — "planning ahead" for multi-user despite being a single-user app); the log tracks per-user activities and therefore requires the user concept. User also asked that add/update/delete user facilities exist "at some stage" (deferred — candidate home: App Settings).

**Plan (agreed up front, one change per step):** 1) `User` model + `AuthService` → 2) Login/register UI gating launch → 3) `ActivityLogEntry` + `ActivityLogger` → 4) wire CRUD paths → 5) Activity Log view.

**Changes made:**
- **Step 1** — New `User` @Model (`Sources/MeCore/Models/User.swift`: name, salted SHA256 hash via CryptoKit, createdAt, lastLoginAt). New `AuthService` (`Sources/MeCore/Store/AuthService.swift`): register (name ≥2, password ≥4, case-insensitive unique enforced in code), login (whitespace-trimmed, updates lastLoginAt), hasAnyUser. Salt = 16 stdlib-random bytes base64. Registered in app schema (`AnunnakiApp.swift`) and test schema. Two build errors fixed en route: `#Unique` needs macOS 15 (removed; service-level uniqueness instead), and `#Predicate` can't call `.lowercased()` on properties (small-N in-memory filter via `findUser`). 7 unit tests.
- **Step 2** — `UserSession` (@Observable, MeCore/Store) holds currentUser; injected into the environment under key `\.userSession` (pattern matches NavigationCoordinator). New `LoginView` (`Sources/Me/Views/LoginView.swift`): centered form; first run (no users) shows registration only with welcome copy; afterwards login + link to register mode; inline error text; real app icon; SecureField password (+confirm). ContentView flow is now seed → login → main UI. Logout lives in App Settings' new "Account" section ("Signed in as …" + Log Out button). Known limitation flagged: secondary WindowGroups (Quicklook, Lineage Explorer, etc.) bypass the gate.
- **Step 3** — New `ActivityLogEntry` @Model + `ActivityAction` enum (`created/updated/deleted` with displayLabel): userName (string attribution, deliberately NOT a relationship so the audit trail survives user deletion — tested), action rawValue string, entityType, linkedEntityName, details, timestamp. `ActivityLogger.record(action:entityType:entityName:details:context:session:)` falls back to "(unknown)" without a session. **Crash lesson:** naming a property `entityName` SIGABRTs SwiftData (`swift_dynamicCastFailure`) even in trivial tests — root-caused from `~/Library/Logs/DiagnosticReports/*.ips`, renamed to `linkedEntityName` (matches Citation's precedent). Convention promoted to AGENTS.md along with the macOS-15 `#Unique` rule.
- **Step 4** — Wired logging at every core CRUD point: all four forms (Figure/Place/Event/ThingFormView) log created+updated beside their existing `RecentEditStore.trackEdit`; list-view deletions (Figure/Place/Event/ThingListView) and EntityGroupCollectionView's deleteSelected log deleted — recorded BEFORE `modelContext.delete` (faulting rule). Known gaps: SKL/Enoch deletions, sub-entity edits, Wikipedia-import & From-Text bulk creation.
- **Step 5** — New sidebar item "Activity Log" (Housekeeping section, `list.bullet.clipboard` icon). `ActivityLogView` (@Query reverse-timestamp): search field, Action filter picker, User filter picker (distinct names), trash button clears the whole log; rows show colored action icon (green/orange/red), "user Action Entity (Type)", optional details line, date+time columns; empty states distinguish no-data vs no-matches.

**Verify:** `swift build` clean after each step; full suite **350/350 tests pass** (346 pre-existing + 7 auth + 4 activity − 7 net accounting: final count 350).

**Files touched:** Sources/MeCore/Models/User.swift, ActivityLogEntry.swift; Sources/MeCore/Store/AuthService.swift, UserSession.swift, ActivityLogger.swift; Sources/Me/Views/LoginView.swift, ActivityLogView.swift; Sources/Me/Views/{ContentView,AppSettingsView,FigureFormView,PlaceFormView,EventFormView,ThingFormView,FigureListView,PlaceListView,EventListView,ThingListView,EntityGroupCollectionView}.swift; Sources/Me/AnunnakiApp.swift; Tests/MeCoreTests/MeCoreTests.swift; AGENTS.md (2 new conventions); docs/SESSION_LOG.md.

**Follow-ups:** user management UI (add/update/delete users); cover remaining mutation paths (import, From-Text, SKL/Enoch deletes, relationship/citation edits); secondary-window auth gating; password change/reset.

**Follow-up (same day) — key-based log attribution + account deactivation:** User rejected name-string-only referencing: prefer a key relation, keep the audit trail via *deactivation* instead of deletion (soft delete). Redesign: `User` gains `isActive: Bool?` (optional per migration rule; `isAccountActive` treats nil as active) + inverse relationship `activityLogEntries: [ActivityLogEntry]?`; `ActivityLogEntry.user: User?` (`deleteRule: .nullify`). `userName` kept as a frozen snapshot written at log time — `displayUserName` prefers the live user, falls back to snapshot if link is nullified by a hard delete. Relationship established only via the annotated side (`user.activityLogEntries?.append(entry)`) per convention. Login now throws typed errors (`.invalidCredentials`, `.accountDeactivated`) so the login screen can say "account deactivated"; new guard `.lastActiveAdmin` blocks deactivating the final active account (UI disables the button too). App Settings gains a "User Management" section: all users listed with Active/Deactivated badge, last-login line, Deactivate/Reactivate buttons; footer explains soft-delete policy and points to the login screen's register link for creating accounts. New idempotent migration `Migration.ensureActivityLogUserLinks(context:)` backfills `user` links for entries created under the old name-string scheme (only when exactly one case-insensitive name match exists), wired into ContentView's launch block. 3 tests added (deactivation blocks login + reactivate restores, last-active guard, legacy-link backfill incl. orphan entries). 353/353 green.

**Follow-up (same day) — admin role + admin-side account creation:** User wanted accounts created from inside the app ("admin-side") rather than only on the login screen. `User` gains `isAdmin: Bool?` (nil = false via `isAdministrator`). New invariant migration `Migration.ensureFirstUserIsAdmin(context:)`: while a store has ZERO administrators, the earliest-created user is promoted — guarantees the store is never admin-less (deliberately re-fires if someone demotes the last admin; tested). `AuthService.createUser(name:password:isAdmin:actor:context:)` gates registration: open only before any user exists (first-run), otherwise requires an admin actor (`register` itself stays open but is now called by UI only in first-run). Authorization model: `deactivate`/`reactivate` require an admin actor and add `.cannotDeactivateSelf`; `.lastActiveAdmin` retained as defense-in-depth. LoginView lost its "Create a new account" toggle link — post-setup, the login screen offers login only (registration hole closed); first-run still auto-shows registration. App Settings User Management now visible to admins only: user rows show Admin badge + Active/Deactivated + relative last login, Deactivate disabled for self/last-active, and an "Add Account…" sheet (name, password+confirm, Administrator toggle) with inline validation errors. 4 new/updated tests (self-guard, last-active chain with reactivation recovery, non-admin rejection incl. createUser authorization, admin-less-store invariant). 357/357 green.

### 2026-08-23 — Integrity work queue + consistency engine hardening (full day)

**Day summary:** Started as scan triage + repair migrations, grew into the Data Integrity screen becoming the app's curation cockpit. Commit index (chronological): `521d705` repair misgendered edges + period eras → `35e891f` self-parent click-to-Fix, deterministic labels → `688e252` content-consistency engine (8 rules) → `6d65160` pronoun ≥2 threshold (Dumuzi FP) → `346144d`/`c45ccbc` persistent work queue after user rejected dismissals-only design → `cd30a29` era pickers replace free text → `91b7974` copy-name button → `cf8f76f` nameVariant rule → `9696a3d` third-party-mention veto (Ninkasi FP) → `5d3c7e4` punctuation-fusion fix (Urur FP) → `d58a412` hyphen-split fix (Yarlaganda/"Su'en" FP), noun-message gender fix, Open navigation → `bf58838` row Actions menu (edit description inline, wizard, copy text). Test count 317 → 330. Debugging lesson of the day: copying only `Me.store` misses recent writes living in the `-wal` sidecar — always copy `.store` **and** `-wal`/`-shm` together.

### 2026-08-23 — First real scan triaged; repairs + period eras prepped

**Context:** The user ran Data Integrity on their live DB (~30 findings). Triage against a read-only copy (`/var/folders/.../T/opencode/triage.store`) confirmed: 4 genuine role-gender edges (two "Mother" edges hanging on the male Uras PK 52 — tradition gives Ninsun/Ninisina the goddess Uraš as mother; Rachujal ♀ typed Father of Rashujal ♂, plus a bogus self-Mother edge), 3 event-era labels with no matching Era entity (Old Assyrian / Old Babylonian / Neo-Assyrian Periods), 3 stubs (`Enbi-Ishtar`, `Lamech`, `Mesh-ki-ang-Nanna II` — the last likely an accidental duplicate of SKL king Mesh-ki-ang-Nanna), zero ambiguous aliases. SQL can't do word-boundary pronoun checks — the app scan stays authoritative there.

**Changes made:**
- `521d705` — `Migration.ensureConsistentParentRoles(context:)`: (1) re-points Mother→Ninsun/Ninisina edges from the male Uras (matched by normalized name + gender + "Dilbat" title) to his female namesake, only when exactly one exists; (2) re-types Rachujal—Father→Rashujal to Mother. The self-referential Rashujal edge is deliberately untouched — deleting user rows is never automatic. Guard-fires-without-namesake tested.
- Same commit — `Migration.ensureHistoricalPeriodEras(context:)`: check-by-name creation of Old Assyrian (−2000..−1750), Old Babylonian (−1894..−1595), Neo-Assyrian (−911..−609) as Era lanes 31–33. **Critical catch:** `fixEraOrderIndices`'s else-branch bumps unlisted post-flood eras by +1 *every launch* (infinite drift), so all three names are registered in its map too. Wired both migrations into ContentView after `ensureEverydayLifeEpisodes`. 5 new tests.

**Key decisions:** Repairs are surgical (exact name+gender+title conditions), never blind re-pointing; content stubs are left to the user (Lamech might be Enoch-tradition Lamech — authoring that description is a curation call); duplicate merging stays in the DuplicateMerger UI.

**Verify:** build clean; **322/322 tests pass** (+5). On next launch: Uras/Rachujal edges repaired, three period eras appear as timeline lanes, era-reference findings clear; remaining manual items: delete the Rashujal self-edge, resolve Mesh-ki-ang-Nanna II duplicate, enrich two stubs.

**Follow-up (same morning) — `35e891f`:** Self-parent edges moved from advisory to the click-to-Fix pattern (DataIntegrityView detects them directly and deletes on button press; engine findings for self-loops filtered out to avoid double-reporting — mutual A↔B pairs stay advisory). Two nondeterminism bugs surfaced by test flakiness: cycle-pair labels now use sorted endpoint names, ambiguous-alias findings pick the most frequent spelling (alphabetical tie-break). 322/322 green.

**Follow-up (same morning) — `6d65160`:** First real false positive: Dumuzi (male) flagged for "…consort of Inanna. Sent to the underworld as her substitute." — the lone "her" refers back to Inanna, not the subject. Coreference resolution is out of scope; instead the pronoun rule now requires **≥2 opposite-gender pronoun tokens** (genuinely misgendered text repeats itself; a single backward reference usually points at the named other person). Gendered-noun rule unchanged (nouns are unambiguous). Regression test with the exact Dumuzi wording. 323/323 green.

**Follow-up (same morning) — `346144d`:** Findings now persist. New `FindingDismissal` @Model (kindRaw|entityKey signature, added to schema — lightweight migration, table starts empty); `DataIntegrityScanStore` (ObservableObject singleton) holds scan results so they survive sidebar navigation (ContentView recreates views per selection, killing @State). Every issue and finding row gets a Dismiss button → persisted dismissal suppresses that exact flag on future scans; "Clear Dismissals (n)" header button restores them. 323/323 green.

**Follow-up (same morning) — `c45ccbc`:** User rejected the dismissals-only persistence as counter-intuitive: closing the app must NOT lose the queue. Redesigned to the user's exact flow: scan writes results into a new `IntegrityFinding` @Model table (the work queue); rows survive relaunches and navigation; rows leave only via Fix, Dismiss, or an explicit new Scan. On relaunch, Fix buttons are relinked by re-detecting the problem live (signature match) — already-repaired-but-not-dismissed rows stay visible with Dismiss only. `ConsistencyFinding.Severity` gained a String rawValue for storage. 323/323 green.

**Follow-up (same morning) — `cd30a29`:** User called free-text era entry iffy (typo = silent link failure) and disliked needing a birth year. Free-text Period fields replaced by pickers over existing eras (names snapshotted off-render per the macOS 26 faulting rule): MythologicalDateEditor gains `showsPeriodField` and a menu picker (with "(not in era list)" fallback for legacy strings); FigureFormView gets a standalone Period section in the birth step bound to `birthDate.era` — deliberately that string, because Migration reconciles `figure.era` from it every launch (figure.era is derived data), and it works with zero dates. Save path unchanged (`Migration.era(named:)`). Event form still has its own era text field — candidate for same treatment later. 323/323 green.

**Micro (same morning) — `91b7974`:** Copy-name-to-clipboard button in the FigureDetailView header, superscript position after the name (borderless `doc.on.doc`, flips to green checkmark ~1.5 s via NSPasteboard).

**Follow-up (same morning) — `cf8f76f`:** New `nameVariant` consistency rule (user request): descriptions mentioning a figure/alias with collapsed spelling ("Enbiishtar" vs "Enbi-Ishtar") get flagged with the registered form — sloppy spellings break auto-linking, which matches exact names. Implementation: separator-collapsed scan over NameDuplicateCheck.normalizedKey buckets (first-letter), word-boundary checks against the ORIGINAL string (so "Anu" never fires inside "Anunnaki", possessives like "Inanna's" never flag), keys <4 chars and keys shared by several distinct spellings (homonyms) skipped. 3 tests. 326/326 green.

**Follow-up (same morning) — `9696a3d`:** Second pronoun false positive (Ninkasi ♀: "he/him" refers to Enki ♂, named in her description). Added a third-party-mention veto: `genderConflict` takes a `mentionIndex` (normalizedKey→Gender via new package `mentionGenderIndex(figures:)`, conflicting-gender homonyms → .unknown = never veto) and stays silent for pronoun AND gendered-noun rules when the text mentions another figure of the conflicting direction (whole-token sequence matching, up to 4 tokens — handles multi-word/hyphenated names). `ownKeys` excludes the figure's own names so self-mentions can't veto; runAll builds per-figure ownKeys incl. aliases. FigureFormView live hint loads the same index off-render so form and scan agree. Tests: Ninkasi regression, homonym-ambiguity guard, existing no-mention fixtures unchanged. 328/328 green.

**Follow-up (same morning) — `5d3c7e4`:** nameVariant false positive on Lu-Enlilla: "…Third Dynasty of Ur (Ur III period…" — the scanner's multi-token joining fused the two adjacent "Ur" tokens across the parenthesis into key "urur", matching the registered SKL king Urur. Reproduced offline against a fresh read-only store copy + python window simulation (registry had no other candidate; ZERA1/ZERA empty ruled out unknownEra). Fix: matched spans must consist only of letters/digits/space/hyphen/apostrophe — any other punctuation between joined tokens rejects the occurrence. Regression test with the exact sentence. Kug-Bau finding (female SKL "king") discussed and dismissed by user as historically legitimate. 329/329 green.

**Follow-up (same morning) — `d58a412`:** Yarlaganda false positive decoded via the persisted queue itself: earlier store copies missed a 1.9 MB WAL sidecar — copying .store + -wal + -shm together revealed all 11 queued findings, incl. «Yarlaganda writes "Suen"; registered is "Su'en"». Root cause: boundary check treated '-' as non-word, so "Puzur-Suen" split into bare "Suen" which collided with god Su'en. Hyphens and apostrophes now count as word-interior for boundaries. Also fixed: gendered-noun messages stated the WRONG gender ("expected" vs actual parameter mix-up), and Figure-kind findings gained an Open button that navigates to the entity via NavigationCoordinator (DataIntegrityView now takes optional coordinator; ContentView special-cases it in the detail chain like other coordinator views). Queue triage showed mostly real wins: Atra-Hasis/Atrahasis ×2, "Tura -Dagan" spacing typo, En-shag/Enshag. 330/330 green.

**Follow-up (same morning) — `bf58838`:** Queue rows became actionable (user request — avoid view-switching): every row gets an ellipsis Actions menu; Figure rows add "Edit Description…" (reuses DescriptionEditorSheet via new QueueDescriptionEditor wrapper that buffers rich/plain state and commits onSave) and "Open Edit Wizard…" (FigureFormView sheet), plus "Copy Finding Text" everywhere (NSPasteboard). Existing Open/Dismiss/Fix buttons unchanged. Note: rows stay in queue after edits until dismissed or rescanned. 330/330 green.

**Micro (same morning) — duplicate search consolidated:** The global-toolbar "find duplicates" button was the odd one out now that Data Integrity is the housekeeping home. Entry point moved into the Data Integrity header ("Find Duplicates…" bordered button next to Scan, opening the unchanged DuplicateMergeView sheet); ContentView loses the toolbar item, its state, and its sheet. Duplicate-name search remains an on-demand tool, NOT part of scan() — it's interactive merging, not advisory findings.

**Bugfix (same morning) — `f9e6fa6`:** Mystery Source "d" decoded. Not seeding: a typo'd free-text `source` string `"d"` on ONE relationship (Lugalbanda Father→Dumuzi the Shepherd) was being materialized into a bare Source row by `ensureRelationshipSources` on every launch. Deleting the row only nullified `sourceRef` (deleteRule .nullify) while the string survived → resurrection loop. Fix, three layers: `primarySourceName` now rejects sub-3-char names (no future junk string can spawn a source); new `Migration.ensureJunkSourceStringsCleaned` blanks sub-3-char source strings (detaching via the annotated side) and deletes pure machine debris (name <3 chars + all metadata empty + zero citations/attachments/relationships — anything with real content is never touched); wired BEFORE `ensureRelationshipSources` in ContentView so junk strings are inert before materialization. 3 tests (debris deleted + no resurrection on rescan; sources with metadata/refs kept; legit 3-char abbreviations like "SKL" untouched). 333/333 green. On next launch the user's "d" row disappears for good and rel 156's source field reads empty.

**Micro (same morning) — `de85632`:** Source library list was unsorted (`@Query` with no descriptor — raw row order). Now sorted alphabetically case-insensitive via a `sortedSources` computed property using `localizedCaseInsensitiveCompare`; @Query's macro doesn't take a comparator argument, so sorting happens at view level (fine for library-sized lists).

**Feature (same morning) — `2ed11b3`:** Comparison tables gained sources at BOTH levels (user refined an initial "per cell" choice once they realized some tables draw everything from one work): `PopupTable.source/sourceRef` (optional, migration-safe) is the table-wide default; `PopupTableCell.source/sourceRef` overrides per cell. `setSourceText` helpers on both match EXISTING Source rows case-insensitively and never create (lesson applied from the "d" resurrection bug); links established via new annotated sides on Source (`popupTableCells`, `popupTables`, both .nullify). UI: source field in the table form; table source shown as doc.text label in grid header + detail panel; double-click any grid cell opens a compact Value+Source editor sheet (placeholder shows the inherited default, hint line explains inheritance); cells with their OWN source get a small doc.text badge top-trailing. saveCell refactored to shared ensureCell so double-click can materialize empty cells for editing. 3 tests (case-insensitive link without creation + detach-on-clear, table link independence + inert unmatched text, repointing moves between rows). 336/336 green.

**Follow-up (same morning) — `dafa269`:** User rejected free-text entry for the new source fields — both became menu Pickers over the Source library ("None" / "Inherit table (X)" zero-option + alphabetically sorted names, `availableSourceNames` keeps a legacy unmatched value selectable so nothing is silently dropped). Selection feeds the same `setSourceText` path, so linking/detaching behavior is unchanged. 336/336 green.

**Micro (same morning) — `c2ea326`:** Thin Divider between table description and table-wide source in the comparison-table grid header (shown only when both exist).

**Micro (same morning) — `45b3682`:** ~5px vertical padding around the grid header's source label so it breathes between the divider above and the grid below.

**Micro (same morning) — `f5bb82d`:** 5px gap between the description text and that divider (it sat too tight).

**Feature (same morning) — `7250a33`:** Context-menu parity across list screens. Inventory showed 4 of 9 entity lists had row context menus (Figure/Place/Event/Thing) while Era, Source, Dictionary, Figure Group, and Comparison Table rows had none. All five now mirror their detail toolbar exactly: Edit + Delete (confirm-alert flows set selection first so the existing presenting: alerts fire; Source and Comparison Table keep their immediate-delete behavior; Comparison Table also gets "Open Grid"). Detail panels deliberately stay context-menu-free per user decision — right-click lives on list rows only. 336/336 green.

**Feature (same morning) — `5b16f5e`:** New `aiDraftTable` consistency rule completing the Gemini-workflow loop: flags any comparison table whose table-wide source OR individual cells match AI-draft markers (`isAIDraftSourceName` on normalized keys: gemini/aigenerated/chatgpt/claude/llm), reporting unsourced-cell coverage ("N of M cells have no individual source yet" / "All M cells carry their own source"). Info severity, entityKind "Comparison Table". `runAll` gained a defaulted `popupTables:` parameter so existing callers/tests compile unchanged; DataIntegrityView passes the fetch. 3 tests (table-wide + counts, real-source negative incl. runAll path, cell-only citation with full-coverage branch). 339/339 green. One test-assertion bug caught during verification: expected "1 of 2 unsourced" where both cells were sourced — engine was right, assertion fixed to the all-covered branch.

**Style (same morning) — `76aeda9`:** Cell editor sheet (double-click) looked squished: its Form drew a grouped inset box flush against the dividers/edges. Rebuilt in the DescriptionEditorSheet house style — plain VStack with 16pt header padding, uppercase caption labels, rounded-border value field, labelsHidden picker, content area with horizontal+vertical padding, padded button row; height trimmed to 300 to kill dead space.

**Micro (same morning) — `1b6d283`:** Cell editor margins nudged +5px all around (header/buttons 16→20pt, content horizontal→20pt) per user's look-and-feel pass.

**Interaction change (same morning) — `6dc1656`:** User rejected double-click as the cell-editor trigger — "seldom, if anywhere in the app, a thing". Grid cells now open the editor via right-click context menu (Edit Value & Source…), plus a destructive Clear Source entry when the cell has its own source. Double-tap gesture removed; badge help text updated to "right-click to edit"; inline Edit-mode typing unchanged. Consistent with the list-row context menus everywhere else. 339/339 green.

**Style (same morning) — `afa1406`:** Corner doc.text badge replaced by a footnote-style bold superscript `*` directly after the value text (user picked it from four options; "the icon looks very lost there"). Marker only renders on non-empty values with their own source; tooltip moved to the whole cell. 339/339 green.

**Micro (same morning) — `9470a32`:** Source asterisk bumped one font notch, footnote→subheadline, after user called it "truly tiny".

### 2026-08-23 — Content-consistency engine in Data Integrity

**Context:** The user asked for dataset-consistency rules beyond duplicate names, citing the Uraš gender/description mismatch as the motivating example. Discovery: a **DataIntegrityView** already existed (Housekeeping → Data Integrity, born silently inside commit `105a43a` on 2026-08-18 with no commit-message or session-log trace — the user did not remember it) hosting four structural group checks with one-click fixes. It became the host for content rules.

**Changes made:**
- `688e252` — New `Sources/MeCore/Store/ConsistencyEngine.swift`: pure static rules over fetched arrays returning `ConsistencyFinding` (kind/severity/entity/message), no mutation, fully unit-testable. Eight rules: (1) pronoun-vs-gender — flags only when ALL pronouns point opposite ("she/her" on a Male); mixed text stays silent; whole-word tokens so "history"/"here" never count; (2) gendered-noun-vs-gender — goddess/queen/priestess/wife/mother/daughter/sister/widow vs god/king/priest/husband/father/son/brother/prince as exact words ("goddess" never leaks "god", "kingdom" never counts "king"); (3) relationship-role-vs-gender — Father/Husband/Brother expect male, Mother/Wife/Sister female; parent roles bind FROM only, spouse/sibling roles bind both endpoints; son/daughter omitted (ambiguous direction); (4) parent cycles — self-parentage and mutual A↔B pairs among father/mother/parent edges (index-pair scan visits each unordered pair once; Creator self-creation deliberately allowed); (5) death-before-birth date inversion; (6) era-reference typos — birth/death/event era strings not matching any Era name via `NameDuplicateCheck.normalizedKey` (info-level); (7) ambiguous aliases — same normalized alternate name attached to 2+ figures; (8) stub figures — bare-name records with no description/domain/relationships/events/places and not coverage-exempt (info).
- `Sources/Me/Views/DataIntegrityView.swift` — Scan now also runs `runAll`; findings render in a "Content Consistency (n)" section below structural issues (orange = warning, blue = info); empty-state requires both lists clear.
- `Sources/Me/Views/FigureFormView.swift` — Live hint on the Description step: while typing, `genderConflict(gender:title:figureDescription:)` shows the same bold-orange warning inline, so the Uraš class of mistake is caught at entry time.
- `Tests/MeCoreTests/MeCoreTests.swift` — 8 rule tests incl. negative cases (mixed text skipped, substring safety, Creator exemption, valid era passes).

**Key decisions:** Findings are advisory only — no auto-fixes for content (human judgment required), unlike structural issues that keep their Fix buttons. Mixed-signal texts are deliberately silent. Son/daughter role genders skipped pending a direction convention.

**Verify:** `swift build` clean; **317/317 tests pass** (+8). 

### 2026-08-22 — Everyday-life episodes, duplicate-name safety, confidence qualifier, Save Now, launch-crash fix

**Context:** A multi-feature session. It began with the plan to import ten curated everyday-life episodes (Ea-nasir's complaint tablet, Schooldays, the Kültepe family letters, Ashurnasirpal II's banquet, etc. — plan worked out with the user and parked in `docs/NEXT_SESSION_HANDOFF.md`) as a counterweight to the mythological corpus. Along the way: a real launch crash surfaced from the user's live database, the user requested a way to express hedged claims, asked for a mid-wizard save button, tested duplicate handling and asked for louder warnings — and confirmed via scholarship that an apparent "duplicate" was actually two legitimate deities.

**Changes made (chronological):**
- `c36fd11` (owed line from earlier) — Fixed missing alternate row colors in the Type Settings lists.
- `e020f51` — **Confidence qualifier on figure-place associations**: nested `enum Confidence { possible, disputed }` (+ `label`), optional `confidence` property on `FigurePlaceAssociation` (String-raw Codable enum optional, same pattern as `Citation.entityType`); Picker (Asserted/possible/disputed) in Add + Edit forms in `AssociationsView.swift`; rows in `FigureDetailInfoView.swift` show italic "(possible)" / orange italic "(disputed)" suffixes; 2 roundtrip/default tests. Nil = plainly asserted.
- `4167b00` — **Launch crash fix**: user hit `EXC_BREAKPOINT` in `Dictionary.init(uniqueKeysWithValues:)` at `Migration.ensureAntediluvianChronology` (Migration.swift:626/628) because their DB legitimately contains **two figures named "Uras"** colliding in `seedNameKey`. Both dictionaries now build with `uniquingKeysWith: { first, _ in first }`. Diagnosed against a read-only copy of the live store (`/var/folders/.../T/opencode/Me_diag.store`); regression test `testAntediluvianChronologyToleratesDuplicateFigureNames`.
- User-side data correction (no code): scholarship confirms two distinct deities named Uraš (male patron god of Dilbat; female earth personification, consort of An). The two DB rows had their **genders swapped relative to their own text**; the user corrected both via the UI and declined a PK-display feature for distinguishing homonyms.
- `52f1ea2` — **Save Now button** in `WizardContainer.swift`: new `showSaveNow: Bool = true` parameter renders "Save Now" left of "Next" on every step except the last, gated by the same `canGoNext`, calling the same `onSave` (all five wizards benefit — forms save purely from accumulated `@State`, so mid-wizard saving is safe).
- `eb3018c` — **Flaky test fix**: `testAddEventWithPropagationCreatesFiguresAndPlacesAndThings` failed ~50% because it grabbed `.first` of the unordered `figureAssociations` array, sometimes hitting the event-marker association (`propagatedFromEventName == nil`, by design — FigureGroup.swift:516–518). Product behavior was correct; the assertion is now order-independent (`filter { $0.event == nil }.allSatisfy { $0.propagatedFromEventName == "The Flood" }`).
- `1ed7e8f` — **Duplicate-name warnings + dictionary hardening**: new `Sources/MeCore/Store/NameDuplicateCheck.swift` (`normalizedKey` = lowercase alphanumeric-only; `warning(candidate:existingNames:)` → sorted comma-joined matches or nil) wired as a non-blocking orange warning under the name field of all five create/edit forms (Figure, Place, Event, Thing, Era — each excludes self via `persistentModelID`). All remaining `uniqueKeysWithValues` sites hardened to first-wins uniquing: SumerianKingListView:18, SumerianDynastyMapView:143, PlaceDetailView:~371, FigureGroupFormView:671, PopupTableFormView:236, plus five SeedData type maps. 2 helper tests. Per user feedback the warning was then bumped to bold callout size with a filled triangle and the name field's text tints orange while a collision is detected ("in your face", still never blocking).
- `c6471f7` — **Everyday-life episodes import** (the session's original goal): `Migration.ensureEverydayLifeEpisodes(context:)` creates get-or-create EventType "Daily Life" (cup.and.saucer.fill / 0D9488), six places (Ur, Nippur, Babylon, Assur, Kanesh, Kalhu — coordinates included), twelve Human figures (Ea-nasir, Nanni, Gimil-Ninurta, Mayor of Nippur, Taram-Kubi, Innaya, Lamassi, Pushu-ken, Zizizi, Imdi-ilum, Ishtar-bashti, Ashurnasirpal II), ten events with curated descriptions and sources, Started At/Ended At place roles on the two letter-corpus episodes and Occurred At elsewhere, four relationships (Taram-Kubi=Spouse=Innaya, Lamassi=Spouse=Pushu-ken, Imdi-ilum Father→Zizizi, Ishtar-bashti Mother→Zizizi), and twelve FigurePlaceAssociations (Resident Of / Ruler). Wired into ContentView after `ensureAntediluvianChronology`. Matching uses `NameDuplicateCheck.normalizedKey` across figure names AND alternate names, event names, and place names — user data always wins. 3 tests: creates-all (counts + role spot-checks), idempotent double-run, skip-user-data (pre-existing "Ea Nasir" with different spacing suppresses the import *and* receives the episode's involvement link instead).

**Key decisions:**
- Names are deliberately NOT unique anywhere — legitimate homonyms exist (the two Uraš deities proved it). Duplicate warnings are informational only, never blocking; hard uniqueness would break imports and user freedom.
- Hedged claims ("possibly had a temple in Nippur") are expressed via the association-level confidence qualifier rather than prose notes or a claims model; nil means asserted. VersionManager export deliberately does not carry `confidence` yet.
- The episodes import uses plain `involvedFigures` (not EventFigureAssociation — that role-type table is never seeded) and no sticky notes: this is curated content, not imported material needing review flags.
- Crash-class lesson reinforced: any `[K: V]` built from user-mutable names must use `uniquingKeysWith` — there are now zero `uniqueKeysWithValues` call sites left in the codebase.

**Verify:** `swift build` clean; **309/309 tests pass** (301 → 309: +2 confidence, +1 antediluvian tolerance, +2 NameDuplicateCheck, +3 episodes). Launch-crash scenario reproduced against the copied store before the fix; the migration now completes on it.

### 2026-08-22 — ORACC cross-check: import of 7 missing deities

**Context:** The user supplied the ORACC AMGG list of deities (oracc.museum.upenn.edu/amgg/Listofdeities, 43 articles) and asked for a cross-check against the database. Comparison ran against a **copy** of `Me.store` (live store never touched): 106 divine-type figures + 144 alternate names. Result: ~34 covered (incl. standard pairs An/Anu, Enki/Ea, Iškur/Adad…), 4 romanization-only differences (Baba=Bau, Nidaba=Nisaba, Ninisinna=Ninisina, Ninsumun=Ninsun), 2 alias-covered (Erra→Nergal, Ninlil→Sud), and **7 missing outright**: Gula/Ninkarrak, Dagan, Damu, Girra, Ninsi'anna, Tašmetu, Lugalirra.

**Changes made:**
- `Sources/MeCore/Store/Migration.swift` — New `ensureOraccDeityImports(context:)`: creates the 7 deities (title/domain/description/gender from domain knowledge; `source` = "ORACC AMGG"), each with an unresolved sticky note **"IMPORTED FROM ORACC"**, plus 6 alternate names (Ninkarrak, Dagon→Hebrew Bible form, Bilgi, Ninsianna, Tashmetu ASCII, Lugal-irra). Get-or-creates the "Deity" FigureType if absent (star.fill / 007AFF, matching SeedData).
- `Sources/Me/Views/ContentView.swift` — Migration added to the launch sequence after `ensureMesopotamianPantheons`.
- `Tests/MeCoreTests/MeCoreTests.swift` — 3 tests: creates all 7 with stickies + aliases; idempotent double-run; skips when the name already exists as a figure (user data untouched, no stray alias).

**Key decisions:**
- Import via the established idempotent launch-migration layer — never direct SQL against the live store.
- Skip rule checks figure names *and* alternate names case-insensitively; anything pre-existing wins and receives nothing.
- Eras deliberately left unassigned — consistent with the same-day decision that era membership stays derived, never hand-set at entry time.
- Erra and Ninlil stay aliases for now (defensible identifications); promotion to standalone figures can be a later call.

**Verify:** `swift build` clean; 301 tests pass. Manual: next launch creates the 7 figures (visible in Figures list, Deity filter); each carries the yellow-style sticky "IMPORTED FROM ORACC" on its detail page.

### 2026-08-22 — Docs reorganization: AGENTS.md slimmed, all docs moved into `docs/`

**Context:** AGENTS.md had grown to 1,899 lines / ~230 KB — 93% of it session log (73 entries, some appended past the Hard Constraints/Interaction Guidelines headings). The user approved three moves: (1) archive the whole session log into a dedicated file (same precedent as the 2026-08-05 TODO split), (2) promote durable lessons buried in old entries into Coding Conventions, (3) move all documents into a `docs/` folder except AGENTS.md.

**Changes made:**
- `docs/SESSION_LOG.md` — NEW. All 73 session entries moved verbatim from AGENTS.md, stable-sorted newest-first. Historical path references inside entries left as written.
- `AGENTS.md` — 1,899 → ~170 lines. The Session Log section is now a pointer to `docs/SESSION_LOG.md`; Debugging Visual Layout Issues / Hard Constraints / Interaction Guidelines restored as clean top-level sections; Important Files updated to `docs/…` paths.
- `AGENTS.md` — New **"SwiftUI & SwiftData pitfalls"** subsection under Coding Conventions, promoting recurring log lessons: never fault `@Model` inside `body` on macOS 26; empty observed arrays before cascade deletes inside a transaction; `.onChange` compares ID collections; `.position()` overlays render unconditionally; sheets don't work from Canvas overlays; extract complex bodies for the type-checker; no `NSCursor.push()/pop()`; search-field styling; unit tests can't reproduce SwiftUI+SwiftData coexistence crashes (`~/Library/Logs/DiagnosticReports/*.ips` is ground truth); macOS 26 `allowsSave:` rename.
- Moved into `docs/`: TODO.md, PRE-FLOOD-TIMELINE.md, TIMELINE.md, ATTRIBUTED_PROPERTIES.md, FigureGroups.md, dynasties.md, plus the gitignored personal docs ARCHITECTURAL_WEAKNESSES_CRITIQUE.md and PRODUCT_WEAKNESSES.md (`.gitignore` paths updated). README.md and CONTRIBUTING.md stay in root — GitHub only renders them from root/`.github`.
- Stale old `docs/TODO.md` deleted (June-era architecture-improvements list, all items done, referenced pre-MeCore paths like `Sources/Store/`); the live root TODO took its place at `docs/TODO.md`.
- `Sources/MeCore/Store/Migration.swift` — doc-comment path reference updated to `docs/PRE-FLOOD-TIMELINE.md`.

**Key decisions:**
- README.md/CONTRIBUTING.md stay in root: GitHub convention outweighs folder tidiness.
- Session-log path mentions are historical records — intentionally not rewritten.
- Future sessions append entries here, at the top, and promote recurring lessons into AGENTS.md instead of re-explaining them.

**Verify:** `grep -c '^### 2026' docs/SESSION_LOG.md` == 74 (73 archived + this one); root holds only AGENTS.md/README.md/CONTRIBUTING.md; no dangling references to moved filenames outside historical entries; `swift build` clean.

**Follow-up — era membership stays derived, no picker (same day, decision only).** While reviewing the model, the agent proposed adding an explicit era picker to the figure form / a members list on EraDetailView. The user declined: it would force figuring out each figure's era at data-entry time — another step in the path whose speed is priority #1. **Decision: do NOT add manual era-assignment UI.** Era association remains derived (seed data, launch migrations like `ensureAntediluvianChronology`, and the birth/death-date era strings via `FigureFormView`). Future sessions should not re-propose this; if era triage ever becomes painful, revisit as an automatic suggestion, not a required field.

### 2026-08-20 — Pre-flood timeline: antediluvian chronology + canonical era order

**Context:** The user observed the Pre-Flood timeline "can hardly be called a timeline" — chips were laid in horizontal rails by insertion order, era lanes stacked by `orderIndex` with no time scale, and times appeared only as tiny captions on 3 of 5 eras. Investigation confirmed: no pre-flood figure had a date (`birthDate.sortValue == Int.min` for all), and the antediluvian epoch's seed band (−241,200 → −28,000) used the SKL's 241,200-year total as a *year* rather than a *duration*. The user approved: **back-propagate the eight antediluvian kings from the flood anchor** (their reign lengths are canonical and must not be adjusted), then order the mythological eras around the earliest anchored date and move figures to match. Full reasoning in `PRE-FLOOD-TIMELINE.md` (new — AGENTS.md stays lean).

**Changes made:**
- `Sources/MeCore/Store/Migration.swift` — New `ensureAntediluvianChronology(context:)`: (1) sets the six pre-flood era date bands (Age of the First Gods −450k→−300k, Creation −300k→−280k, Creation of Mankind −280k→−275k, Age of the Watchers −275k→−269.2k, Antediluvian Period −269.2k→−28k, Great Flood unchanged) but only while the era still holds the legacy seed value or is undated; (2) writes the eight kings' computed spans (Alulim −269,200→−240,400 … Ubara-Tutu −46,600→−28,000, `dateSource == .computed`) only where `birthDate.startYear == nil`; (3) moves figures to their approved eras (primordial gods → Age of the First Gods; great gods → Creation; archangels → Age of the Watchers; Alulim + Dumuzi the Shepherd → Antediluvian Period), updating both `figure.era` and the `birthDate.era`/`deathDate.era` strings so `ensureFigureEraLinks` keeps them next launch; each move only fires while the figure sits in the legacy era; (4) sets the antediluvian succession `orderIndex` (Alulim 0 … Ubara-Tutu 7, Ziusudra 8). `fixEraOrderIndices` pre-flood map renumbered: Age of the First Gods=0, Creation=1, Creation of Mankind=2, Age of the Watchers=3, Antediluvian Period=4 (Great Flood stays 7, preserving the `< 7` / `>= 7` pre/post-flood split).
- `Sources/Me/Views/ContentView.swift` — `Migration.ensureAntediluvianChronology` added to the launch sequence after `ensureComputedSKLDates`.
- `PRE-FLOOD-TIMELINE.md` — NEW. Full reasoning: the eight SKL reigns sum to 241,200 years → anchored epoch −269,200 → −28,000; era sequence rationale; figure reassignment list; data problems fixed (Alulim unassigned/invisible, Dumuzi the Shepherd mis-filed, Ziusudra ordered first); which dates are derived vs. invented placeholders.
- `Tests/MeCoreTests/MeCoreTests.swift` — 9 new tests: era date bands + idempotency + never-clobber-user-edits, king dates + no-overwrite, figure moves (+birth-era string + idempotency), succession order, `fixEraOrderIndices` new pre-flood sequence (flood stays at 7). Updated the prior `fixEraOrderIndices` test to the new map. **281 tests pass; `swift build` clean.**

**Follow-up — pre-flood time axis + era boundary lines (same day).** The user asked why the eras weren't bordered vertically like post-flood; the answer was structural (pre-flood had no time axis to anchor lines to). Redesigned `TimelinePreView` to mirror the post-flood look: new `SwimlaneMode.mythologicalTimed(minYear:pointsPerYear:)` in `TimelineBase.swift` lays each era's tinted bar at its proportional x-extent on a shared axis (linear over the full −450,000 → −28,000 span, ~1600pt wide) with the chip rail inset to start at the era's left edge; `TimelinePreView` gained a BCE axis header (50k-year ticks) and full-height vertical boundary lines at every era start/end (deduped via a `Set<Int>`, matching the post-flood grid overlay pattern). Chips stay in scrollable rails — they can't be pinned to years (the great gods are undated and their eras are too narrow for positioned chips), which the user accepted ("doesn't need to be pixel-accurate"). `swift build` clean; 281 tests pass (one pre-existing order-dependent flake in `testAddEventWithPropagation…` passes in isolation).

**Key decisions:**
- The antediluvian kings' dates are **derived** (reign-sum back-propagation anchored at the flood), not invented; the earlier era bands are **explicitly documented placeholder spans** so every pre-flood band shows a date.
- Every write is guarded: era bands only corrected from legacy/undated values, king dates only where nil, figure moves only from the legacy era — user edits made later always win (sacred-data rule, idempotent).
- `birthDate.era` must stay in sync with `figure.era` because `ensureFigureEraLinks` re-resolves from that string on every launch.
- `fixSKLFigureOrder`/`ensureComputedSKLDates` don't touch the antediluvian era (seed keys it under "Antediluvian", DB figures use "Antediluvian Period"), so the migration's sequence/dates survive.

**Verify:** `swift build` clean; 281 tests pass. Manual: relaunch — Pre-Flood timeline now shows (top→bottom) Age of the First Gods → Creation → Creation of Mankind → Age of the Watchers → Antediluvian Period, each with a date caption; the eight kings are in SKL order and hovering a chip shows its computed reign span; Alulim and Dumuzi the Shepherd are present.

**Relevant files:**
- `PRE-FLOOD-TIMELINE.md` — Added
- `Sources/MeCore/Store/Migration.swift` — Updated (`ensureAntediluvianChronology`, `fixEraOrderIndices` map)
- `Sources/Me/Views/ContentView.swift` — Updated (launch sequence)
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-20 — Sequence-driven post-flood timeline: SKL as source of truth

**Context:** The post-flood timeline still misrepresented the dynasties even after the era-date backfill: (1) rulers within a dynasty rendered in scrambled **insertion** order — `figuresInEra` sorts by `birthDate.sortValue`, and First dynasty of Kish's 23 kings are all undated (`Int.min`), so the stable sort preserved the DB's scrambled PK order (Zuqaqip, Zamug, Melem-Kish, Enmebaragesi, Babum, Kullassina-bel, Jushur, Etana…); (2) dated rulers **escaped their dynasty band** — Dynasty of Mari's kings carry computed dates (−1927…−1850) that contradict the era's −2350→−2300 slot, so chips were placed 400+ years outside the band; (3) the stale live-DB dynasty `orderIndex` values (509–528, vs the seed's canonical 11–30) made dynasty rows sort wrong. The user approved a **sequence-driven** approach: the SKL is the only source of truth for dynasty order and ruler succession; dates become "couleur locale". Decisions locked in via clarifying questions: **keep seed date windows** for dynasty bands (overlap allowed), **equal spacing** for ruler chips (reign-proportional rejected), and the proposed `Dynasty` entity was dropped — Era remains the model.

**Changes made:**
- `Sources/MeCore/Store/SKLTimelineLayout.swift` — NEW. Three pure `package static` helpers: `isDynastyEra(_ figures:)` (any figure's `source` contains `"Sumerian King List"`, matching the compound-string convention e.g. Etana's `"Sumerian King List; Sumerian mythology"`), `dynastyOrderedFigures(_:)` (sorted by `(orderIndex, name)` — orderIndex is the SKL reign sequence, name is the tie-break), `dynastySlotCenters(count:spanYears:)` — equal slots `Int((i+0.5)/n * span)` across the band, `n==1 → [span/2]`, clamps ≥ 1.
- `Sources/Me/Views/TimelineBase.swift` — `EraSwimlaneRow.historicalSwimlane` (line ~214) branches on `SKLTimelineLayout.isDynastyEra`: dynasty eras place `dynastyOrderedFigures` at equal slots across the era's own band (`eraStart + slots[i]`, `x = (year - minYear) * ppy + chipWidth / 2`); the existing exact-date + estimate logic is preserved for non-dynasty eras. `chipLayouts.sort { $0.x < $1.x }` retained.
- `Sources/MeCore/Store/Migration.swift` — `fixEraOrderIndices` (line ~482) extended with a `dynastyOrderIndex` map (First dynasty of Kish=11 … Dynasty of Isin=30, per seed_data.json); matching eras get canonical values; pre-flood names unchanged; unlisted eras `>= 9` keep the `+1` shift. Idempotent (only writes changed values).
- `Sources/Me/Views/ContentView.swift` — explicit `Migration.fixEraOrderIndices` call added to the launch sequence (after `ensureSKLDomain`), so it runs reliably even though the seed path also invokes it.
- `Tests/MeCoreTests/MeCoreTests.swift` — 9 new tests: `isDynastyEra` (incl. compound-source + empty), `dynastyOrderedFigures` (scrambled PK order → SKL sequence; name tie-break), `dynastySlotCenters` (n=23/span=400 → 8…391 with midpoint 200; n=1 → span/2; count=0 clamp; n=3/span=100 → 16/50/83), `fixEraOrderIndices` renumbering (509→11, 528→30), pre-flood/unknown-era stability, idempotency. **272 tests pass; `swift build` clean.**

**Key decisions:**
- The SKL's ruler **sequence** is authoritative for dynasty timelines; its reign **lengths/dates** are not. Dynasty bands keep the seed's conventional date windows (overlap allowed — e.g. the two Kish dynasties legitimately abut), and ruler chips are evenly spread across that band regardless of computed dates, so no ruler can ever land outside its dynasty.
- `dynastyOrderedFigures` uses `(orderIndex, name)` — the era's per-dynasty sequence counter — exactly the ordering `applyRegnalOrder`/`fixSKLFigureOrder` already enforce, so the timeline and the group pages agree on ruler succession.
- The renumbering is additive + idempotent per the sacred-data rule (name→index map, only writes changes); the stale 509–528 values were simply never canonical.
- `ensureComputedSKLDates` keeps writing computed dates (still used by figure detail + Dynasty Map) and is out of scope for the timeline fix; the mythological pre-flood timeline is untouched.
- Equal spacing (not reign-proportional) is a deliberate visual choice — the timeline shows dynasty membership and succession, not reign length.

**Verify:** `swift build` clean; 272 tests pass. Manual: relaunch — the migration renumbers dynasty eras on first run; the Post-Flood timeline shows First dynasty of Kish's 23 kings in SKL order (Jushur→Aga) spread across 2900–2500, Dynasty of Mari's rulers inside their −2350→−2300 band (no chips at −1927), and the Eras list / dynasty group ordering now use 11–30.

**Relevant files:**
- `Sources/MeCore/Store/SKLTimelineLayout.swift` — Added
- `Sources/Me/Views/TimelineBase.swift` — Updated (`historicalSwimlane`)
- `Sources/MeCore/Store/Migration.swift` — Updated (`fixEraOrderIndices`)
- `Sources/Me/Views/ContentView.swift` — Updated (launch sequence)
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-19 — Second dynasty of Kish timeline overlap: era-date backfill from seed

**Context:** The user reported the timeline showing the Second dynasty of Kish "running 2900–2700 BCE", which overlaps the First dynasty of Kish's timeframe and "seems impossible". Investigation proved the span wasn't stored anywhere: the `Era` rows for **all** dynasties in the live DB had NULL dates (verified via `ZERA.ZSTARTYEAR`/`ZENDYEAR`), the figures had NULL dates, and neither seed copy had anchors for either Kish dynasty. The 2900–2700 BCE window was the timeline's **estimation heuristic** (`EraSwimlaneRow.historicalSwimlane` in TimelineBase.swift:232-241): undated eras default `eraStart = era.startDate.startYear ?? minYear` (−2900, the post-flood timeline start) and `eraEnd = eraStart + 200` (−2700), so every undated dynasty's chips land in the same first-200-years window — both Kish dynasties appeared to occupy 2900–2700.

**Root cause:** The seed_data.json has carried correct per-dynasty date ranges since before the live DB was first seeded (First Kish −2900→−2500, First Uruk −2800→−2350, First Ur −2600→−2500, Awan −2500→−2400, Second Kish −2500→−2400, … Isin −2017→−1794). But the live DB's `Era` rows were created before those dates existed in the seed, and no migration ever backfilled them — so all dynasty eras sat at "unknown" and the timeline estimation invented overlapping spans. The propagator couldn't fix it: Second Kish's 7 mythological reigns sum to 1,737 years, so anchoring figures would produce an absurd span.

**Changes made:**

- `Sources/MeCore/Store/Migration.swift` — New `ensureEraDatesFromSeed(context:)` (after `ensureSKLAnchorDates`): reads seed_data.json, and for every seed era with a non-nil `startDate.startYear`, finds the DB era by exact name and writes `startDate`/`endDate` from the seed **only when the DB era's `startDate.startYear` is nil** — additive + idempotent, never overwrites user-entered era dates. This backfills all dynasty eras at once (Second Kish → −2500→−2400, its conventional slot after Awan), so the timeline stops inventing the 2900–2700 overlap.
- `Sources/Me/Views/ContentView.swift` — `Migration.ensureEraDatesFromSeed` added to the launch sequence right after `ensureSKLAnchorDates`.
- `Tests/MeCoreTests/MeCoreTests.swift` — 4 new tests: `testEnsureEraDatesFromSeedBackfillsSecondDynastyOfKish` (−2500/−2400 anchor, approximate), `testEnsureEraDatesFromSeedBackfillsAllDatedDynastyEras` (5 dynasties all filled), `testEnsureEraDatesFromSeedIsIdempotent`, `testEnsureEraDatesFromSeedNeverOverwritesExistingDates`. **263 tests pass; `swift build` clean.**

**Key decisions:**
- The fix is a **seed→DB era-date backfill** (matching the Gutian/anchor migration family) rather than a bespoke Second-Kish rule — the seed is the canonical source, every dynasty era gets its correct chronological slot, and no figure/description edits are needed.
- Era dates stay on the `Era` rows only; figures remain undated (Second Kish's 1,737-year mythological reign sum makes figure-level propagation meaningless). The timeline's estimation then spreads each dynasty's chips across its own correct era span instead of the shared first-200-year window.
- Post-flood timeline bounds are unchanged after backfill (First Kish starts −2900 = the previous fallback min; Isin ends −1794 = the fallback max), so the fix repositions dynasty rows without resizing the overall timeline. Pre-flood mythological eras also gain their seed date labels (e.g. Age of the First Gods −450,000→−300,000) — a visual improvement, not a regression.

**Verify:** `swift build` clean; 263 tests pass. Manual: relaunch — the migration backfills era dates on first run; the Post-Flood timeline now shows Second dynasty of Kish in its own 2500–2400 BCE band (after Awan), no longer overlapping First Kish's 2900–2500 band.

**Relevant files:**
- `Sources/MeCore/Store/Migration.swift` — `ensureEraDatesFromSeed` added
- `Sources/Me/Views/ContentView.swift` — launch sequence
- `Tests/MeCoreTests/MeCoreTests.swift` — 4 new tests

### 2026-08-19 — Gutian rule timeline: anchor + computed dates backfill

**Context:** All 18 Gutian-rule rulers in the live DB had NULL birth/death dates (`ZSTARTYEAR`/`ZENDYEAR` empty) — the Gutian dynasty was the one SKL dynasty without an anchor, so `SKLDatePropagator` returned all-nil. The user approved anchoring the dynasty start at ~2200 BCE (per Wikipedia's "Gutian rule began around 2200 BCE").

**Changes made:**

- `Sources/MeCore/Resources/seed_data.json` + `Sources/Me/Resources/seed_data.json` — Appended `c. 2200–2194 BC` to **Inkishush's** `figureDescription` (first Gutian king, orderIndex 0, 6-year reign). `ensureSKLAnchorDates` picks it up on the next launch and appends the range to the DB description; the propagator anchors at Inkishush and forward-propagates the entire dynasty.
- `Sources/MeCore/Store/Migration.swift` — New `seedNameKey(_:)` helper (lowercase + hyphen-stripped) for seed↔DB name matching, applied to three lookups so seed `Apilkin` matches DB `Apil-kin`:
  - `ensureSKLAnchorDates` (name lookup)
  - `ensureSKLGutianReignLengths` (name lookup — now also era-aware so the seed's Gutian `Puzur-Suen` can never touch the DB's Kish `Puzur-Suen`)
  - `fixSKLFigureOrder` (name lookup — now also era-aware via a new `expectedOrderEra` map, same collision guard)
- `Sources/Me/Views/ContentView.swift` — Moved `Migration.enrichSKLData` and `Migration.ensureComputedSKLDates` to **after** `Migration.fixSKLFigureOrder` in the launch sequence, so the propagator sees Apil-kin's corrected `orderIndex` (10) on the first run instead of the old 0.
- `Tests/MeCoreTests/MeCoreTests.swift` — 3 new tests: `testFixSKLFigureOrderFixesHyphenatedName` (Apil-kin → orderIndex 10), `testEnsureSKLGutianReignLengthsFixesHyphenatedName` (suffix `(Listed reign: 3 years.)` appended to the hyphenated DB figure), `testEnsureComputedSKLDatesPropagatesFullGutianDynastyFromAnchor` (all 19 seed kings get computed dates, contiguous chain, `dateSource == .computed`, last end -2072 = 2200 − 128 total reign-years). 259 tests pass; `swift build` clean.

**Verified on the live DB** (backup at `/var/folders/.../T/opencode/Me.store.bak` before launch): all 18 Gutian figures now have `ZSTARTYEAR`/`ZENDYEAR` populated (Inkishush −2200→−2194 … Tirigan −2119→−2079), `ZDATESOURCE = 'computed'`, `Apil-kin` orderIndex fixed 0→10 with the `(Listed reign: 3 years.)` suffix. Dynasty of Akkad dates untouched.

**Key decisions:**
- The anchor lives on the **seed** (like every other anchored dynasty) rather than a bespoke migration — `ensureSKLAnchorDates` already existed, so this is purely a data edit + the name-matching robustness the `Apilkin`/`Apil-kin` spelling split exposed.
- Reordering the launch sequence matters because `ensureComputedSKLDates` only writes dates where `birthDate.startYear == nil` — a first-run wrong-order computation would have persisted.
- Era-awareness in `fixSKLFigureOrder`/`ensureSKLGutianReignLengths` guards against the seed's cross-era name collision (`Puzur-Suen` exists in both Kish and Gutian eras); the DB's single `Puzur-Suen` (Kish, orderIndex 15) is untouched, and the Gutian `Puzur-Suen` row itself is left uncreated (known data gap, additive-only policy).

**Relevant files:**
- `Sources/MeCore/Resources/seed_data.json`, `Sources/Me/Resources/seed_data.json` — Inkishush anchor
- `Sources/MeCore/Store/Migration.swift` — `seedNameKey`, era-aware lookups in `ensureSKLAnchorDates`/`ensureSKLGutianReignLengths`/`fixSKLFigureOrder`
- `Sources/Me/Views/ContentView.swift` — propagator migrations after `fixSKLFigureOrder`
- `Tests/MeCoreTests/MeCoreTests.swift` — 3 new tests

### 2026-08-17 — SKL ordering fix + title-only text block visibility

**Part 1 — SKL figure ordering (source matching).** Four SKL kings (Etana, Gilgamesh, Lugalbanda, Urukagina) had `orderIndex=0` instead of their correct positions (12, 36, 41, 44). Root cause: their `source` field contained compound strings like `"Sumerian King List; Sumerian mythology"` which failed the exact `==` match in `SeedData.swift:530` and `Migration.fixSKLFigureOrder:1220`. Fixed by changing to `.contains("Sumerian King List")` in both locations. Verified: Etana now gets `orderIndex=12` with `reignYears=1560`. On existing DBs, `fixSKLFigureOrder` migration auto-corrects on next launch. 244 tests pass.

**Part 2 — Title-only text block visibility.** Text blocks with a title but empty body/summary rendered as near-invisible slivers in `EntityGroupCollectionView`. `TextBlockRow` renders title + `RichTextDisplay` which returns `EmptyView` for empty text; the card had `.padding(10)` + subtle `Color(.textBackgroundColor).opacity(0.6)` background, but without body content the card was too thin to notice. Fixed by adding `.frame(minHeight: 32)` to `TextBlockRow` in `EntityGroupCollectionView.swift:1167`. The manager spine (`FigureGroupListView`) was unaffected — text blocks appear there with reorder arrows and drag-and-drop. 244 tests pass.

**Relevant files:**
- `Sources/MeCore/Store/SeedData.swift:530` — `.contains()` fix for seed orderIndex
- `Sources/MeCore/Store/Migration.swift:1220` — `.contains()` fix in `fixSKLFigureOrder`
- `Sources/Me/Views/EntityGroupCollectionView.swift:1167` — `minHeight: 32` on `TextBlockRow`

### 2026-08-16 — Dynasties as mixed-type groups + single-word domain tags

**Part 1 — Single-word domain tags.** The tag cloud surfaced fragment "tags" like `steward and scribe`, `and the underworld`, `associated with farming and fertility` — sentence fragments produced by `TagEngine.domainTags`, which had kept each comma-separated piece of a figure's `domain` prose whole (only literal `"and"`/`"of"`/`"the"` phrases were dropped). The user wanted single words. `domainTags` now splits each phrase into words and strips a stopword set (`and, the, of, with, associated, related, …`), so `"associated with farming and fertility"` → `farming` + `fertility`, `"and the underworld"` → `underworld`. Curated multi-word tags (traditions like "sumerian king list", type names like "divine collective", era names) are untouched — they flow through other paths.

**Part 2 — Re-tag pass.** The old fragment tags were already persisted by `Migration.ensureAutoTags`, which only tags empty entities. New `Migration.ensureRefinedDomainTags` (Migration.swift) computes the legacy phrase set vs. the new single-word set per figure and removes exactly the obsolete fragment links, backfilling the refined words — surgical, idempotent, never touches curated tags, never deletes shared `Tag` rows. Wired into the launch sequence after `ensureAutoTags`.

**Part 3 — Dynasties as groups.** The user wanted to register the SKL dynasties as groups so events (and places) could attach to them alongside kings, leveraging the mixed-type group system. New `Migration.ensureDynastyGroups` (Migration.swift) creates a top-level **"Dynasties"** group (kind `.skl`, published, History section) with one subgroup per dynastic `Era` row ("First dynasty of Kish", "Dynasty of Akkad", …). Each subgroup auto-populates its **kings** (figures whose `Figure.era` points to that era) ordered by reign succession via `applyRegnalOrder`, plus **events** whose `event.era` string matches the era name; **places** are left for the user to add by hand. Additive + idempotent: only missing groups/members created; existing subgroups, manual additions, and user ordering never overwritten. Wired into the launch sequence after `ensureSKLRegnalOrder`.

**Part 4 — Per-dynasty era map.** The user asked for a historical map on each dynasty page, focused on the dynasty's time and area. This reused the dynasty map's existing OHM machinery: new `FigureGroup.era: Era?` (migration-safe optional, inverse `Era.groups` — bare `@Relationship` on the Era side per the circular-reference rule) links a group to the era it pages; `ensureDynastyGroups` now sets it on every subgroup (existing ones included, still additive/idempotent). New `GroupEraMapView` (Me layer) embeds `DynastyHistoricalMapView` on any group page whose `era` is set (rendered right after the header in `EntityGroupCollectionView`): it computes the era's span from the group's king members via `SKLDatePropagator.compute` and feeds the midpoint ISO year to the OHM `filterByDate` (same `dynastyDateString` logic), draws the group's place members as markers (capital heuristic = place whose name appears in the era name), and inherits the shared App Settings presentation keys (historical theme/language/label size/startup zoom).

**Part 5 — "I do not see a map": always-on basemap + legacy-tree era backfill.** The user launched and reported no map. Diagnosis via the live store (`ZFIGUREGROUP.ZERA`): the migration *had* linked eras — but only in the new "Dynasties" tree. The live DB also holds the legacy pre-Groups-era **"Sumerian King List"** top group (typographical subgroup names like "Fouth dynasty of Uruk", "The rhird dynasty of Uruk") whose subgroups had **no era links**, so they rendered no map. Additionally, `GroupEraMapView` only rendered the OHM map when the group had **place members** — and the dynasty subgroups had none (places are added by hand), so even the correct tree showed only the "no placed members" hint box instead of a map. Two fixes:
- `SumerianDynastyMapView.swift` — `DynastyHistoricalMapView` gained `defaultCenter: (Double, Double)?` and `mapHTML` no longer bails on an empty `places` array: it centers on the capital → first place → default center (falls back to Mesopotamia 44.4/33.3), and the empty-marker `setCapital`/`focus` calls are already no-ops. `updateNSView` reloads when the default center changes (component-wise compare).
- `Migration.ensureDynastyGroups` — after the "Dynasties" pass, a second pass links `sub.era` for **any** subgroup in **any** tree whose normalized name matches a dynasty era (lowercased + trim + strip leading "the "), only when `sub.era == nil` — additive, idempotent, never touches user-created era links. The 2 typo'd legacy subgroup names stay unmatched (no rename without consent).
- `GroupEraMapView` — now **always** renders `DynastyHistoricalMapView` (bare OHM basemap, date-filtered to the dynasty midpoint) even with zero place members, plus a small caption hint ("No placed members yet. Add places to this group to mark them on this historical map.").

**Changes made:**
- `Sources/MeCore/Store/TagEngine.swift` — `domainTags` rewritten (single words + stopword set + dedup).
- `Sources/MeCore/Store/Migration.swift` — `ensureRefinedDomainTags` + `legacyDomainTagPhrases`; `ensureDynastyGroups` (now also links `sub.era` within its own tree AND backfills eras across other trees via `normalizedGroupName`).
- `Sources/Me/Views/ContentView.swift` — Both new migrations added to the launch sequence.
- `Sources/MeCore/Models/FigureGroup.swift` — `era: Era?` relationship (annotated side).
- `Sources/MeCore/Models/Era.swift` — inverse `groups: [FigureGroup]?` (bare `@Relationship`).
- `Sources/Me/Views/GroupEraMapView.swift` — Added.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Renders `GroupEraMapView` after the header when `group.era != nil`.
- `Sources/Me/Views/SumerianDynastyMapView.swift` — `DynastyHistoricalMapView` + `mapHTML` support empty `places` via `defaultCenter`.
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated `domainTags` expectations + 3 new TagEngine tests; 2 new `ensureRefinedDomainTags` tests; 2 new `ensureDynastyGroups` tests (creation/idempotency/mixed membership + era linkage + inverse `era.groups`, manual-subgroup preservation + era link on existing subgroup); 1 new cross-tree test (`testEnsureDynastyGroupsLinksErasAcrossOtherTrees` — exact match, "the "-prefix match, typo left untouched, inverse populated, no members auto-added). 227 tests pass; `swift build` clean.

**Key decisions:**
- Single words for auto-derived domain tags; curated multi-word tags preserved (they're proper nouns/fixed terms, not fragments).
- The re-tag pass removes only names that no longer survive the new engine, so curated single-word tags and shared `Tag` rows are safe; it's idempotent and a no-op after the first run.
- Dynasty groups follow the Book-of-Enoch page pattern (top-level + subgroups) so the sidebar stays clean; `.skl` kind makes the regnal-ordering machinery apply to the whole chain.
- The tag-cloud rotation/width experiment from earlier in the session was fully reverted to HEAD per the user ("revert back to where we were before starting this experiment").
- The era→group link (not name matching) drives the map, so it survives renames and generalizes: attaching an era to *any* group gives it a time-focused map.
- The map reuses the dynasty map's date-filter + capital-focus machinery verbatim; the only new pieces are the era link and the wrapper view.
- A dynasty subgroup with no place members still shows the historical basemap (a map is the point, not markers); the "add places" hint is a caption, never a map substitute.
- The era backfill matches by normalized name across all trees so the legacy "Sumerian King List" subgroups get maps too; typo'd names ("Fouth…", "rhird…") are left alone — the user can rename those to link them.

**Part 6 — Dynasty boundaries: draw-on-map prototype + author-drawn territories.** The user asked "can you draw on the map, like in a separate layer?" and specified the real goal: **drawing the boundaries of the dynasty on the historical map**. Two halves:

**6a — The freehand draw tool** (prototype, as designed):
- `Sources/MeCore/Models/Era.swift` — `boundaryGeoJSON: String?` (migration-safe optional; GeoJSON Polygon JSON string). No migration needed — it's an optional new attribute, and only set when the user draws.
- `Sources/Me/Views/SumerianDynastyMapView.swift` — `DynastyHistoricalMapView` gained required params `boundaryGeoJSON: String?`, `drawMode: Bool`, `onBoundaryDrawn: (([[Double]]) -> Void)?` (all must be passed explicitly — Swift 6.3.1's memberwise init omits defaulted stored properties). `makeNSView` registers a `boundaryDrawn` message handler; `updateNSView` applies `setDrawMode` when the toggle flips and resets it on reload. `mapHTML` adds a GeoJSON `boundary` source + fill/line layers (dynasty color, fill-opacity 0.22) and a dashed `boundary-preview` line source; `setBoundary(ring)` swaps the polygon; draw mode disables pan/zoom, captures mousedown/mousemove/mouseup into a ring with a live dashed preview, and posts `boundaryDrawn` (a `[[Double]]` ring) back to Swift. Boundary sources/layers are created in `setupBoundary()` inside `onLoad` (MapLibre throws if layers are added before the style loads); empty GeoJSON defaults to an empty FeatureCollection.
- `Sources/Me/Views/GroupEraMapView.swift` — ZStack overlay with a **"Draw boundary"** toggle button (MapZoomButtons-style, top-leading; becomes "Finish boundary" while active), an orange "drag to outline" hint caption, and a red **Clear boundary** button when a boundary exists. On `onBoundaryDrawn` it closes the ring (first point appended — spec-valid GeoJSON) and serializes `{"type":"Polygon","coordinates":[ring]}` into `era.boundaryGeoJSON`, saves, and auto-toggles draw mode off. The full dynasty map shows the era's boundary read-only (era looked up by `selectedDynasty.name`).

**6b — Author-drawn territory polygons** (the user, after trying the tool: "haha, I was hoping you could do the drawing :-)"): the assistant authored plausible historical territory polygons for all 20 SKL dynasty eras by hand (georeferenced to the seed's city coordinates; verified point-in-polygon for each dynasty's capital), stored as `Migration.dynastyBoundaryRings` (normalized era name → `[[Double]]` lon/lat ring) and written into `era.boundaryGeoJSON` once by `Migration.ensureDynastyBoundaries` (additive + idempotent, nil-checked so the user's own drawings always win; runs at launch after `ensureDynastyGroups`). Akkad covers north to Assur + west to Mari; Ur III reaches Susa; Awan/Hamazi/Gutian hug the Zagros; city-state dynasties are tight rings around their capitals. `polygonGeoJSON(ring:)` closes the ring at serialization.

**6c — "No borders appear": the Akkad test-draw.** The user reported "Looking at dynasty of Akkad and no borders appear" and asked whether it was a zoom/viewport issue. Diagnosis via the live store: Akkad's stored ring had **32 vertices, was unclosed, and spanned only 0.02° of latitude** — a degenerate horizontal sliver, invisible at any zoom. The user confirmed they had drawn a quick square just to test the draw tool; the prototype `saveBoundary` saved the raw unclosed ring, and `ensureDynastyBoundaries`' nil-check preserved that test-draw instead of the authored territory (every other dynasty matched the authored rings). Fixes:
- `Sources/MeCore/Store/Migration.swift` — `ensureDynastyBoundaries` now **repairs invalid stored rings**: a stored boundary is only honored if it's a closed, non-degenerate polygon (closed ring, ≥ 4 points, shoelace area > 0.001 deg², **and min bounding-box axis ≥ 0.4 deg**); anything else (legacy unclosed test-draws, degenerate slivers, **closed dots/thick-lines**) is replaced by the authored territory. New `decodedRing(from:)` / `ringAreaSq(_:)` / `ringMinAxisDegrees(_:)` helpers + `sliverMinAxisDegrees = 0.4`. Since `saveBoundary` now closes rings, a genuine user drawing is always closed → never repaired; the 0.4° axis floor only ever catches dot/line test-draws (the smallest authored ring spans 0.70°).
- `Sources/Me/Views/GroupEraMapView.swift` — `saveBoundary` **closes the ring** (appends the first point) before serializing, so freehand draws produce spec-valid GeoJSON and render correctly.
- `Sources/Me/Views/SumerianDynastyMapView.swift` — boundary lines thickened for visibility: `boundary-line` 2.5 → **4 px** (opacity 0.95), `boundary-preview-line` 2 → **3 px**. The **modern (MapKit) map now renders the boundary too**: new `selectedBoundary` decodes the era's Polygon ring into `[CLLocationCoordinate2D]` and `legacyMapPanel` draws a `MapPolygon` (fill 0.22 dynasty color, 4 px stroke) — borders show on both map versions.
- `Tests/MeCoreTests/MeCoreTests.swift` — `testEnsureDynastyBoundariesRepairsDegenerateTestDraw` (unclosed sliver replaced by the 14-vertex closed authored Akkad ring with real vertical extent). `testEnsureDynastyBoundariesNeverOverwrites` still passes (closed ring preserved). Later the user relaunched and reported "no, no boundary" again: they had **re-drawn a fresh closed 31-vertex sliver** (lat 32.91→32.96, min-axis 0.046°) with the new closing `saveBoundary`; the then-repair (closure + area) preserved it. Added `testEnsureDynastyBoundariesRepairsClosedSliver` (closed horizontal sliver → authored Akkad ring) and the min-axis sliver check. **234 tests pass; `swift build` clean.**

**Key decisions:**
- The boundary lives on the **era** (not the group) so it's shared by every page that pages that era and survives the legacy/new-tree duplication.
- Boundaries are author-drawn once as static data, then owned by the user: the draw tool/clear button let them refine any dynasty. The "never overwrite" promise now has one carve-out: **a stored ring that isn't a real polygon is invalid** — unclosed rings (invalid GeoJSON per spec) *and* closed dots/thick-line slivers (extent under 0.4° on either axis, i.e. smaller than the smallest authored dynasty territory by a wide margin) are repaired to the authored territory, while any genuine closed region-shaped user drawing is preserved forever. The 0.4° floor was validated against every authored ring (smallest min-axis 0.70° = First dynasty of Ur) and the live DB (Akkad's sliver 0.046°; all other 19 dynasties ≥ 0.80°).
- Draw mode deliberately disables pan/zoom so the gesture is unambiguous; draw is a toggle (not click-to-enter), with a cancel path via the same button.
- Prototype = one polygon per era; multiple shapes, undo, and edit are follow-ups if the user likes the feel.

**Verify:** `swift build` clean; 234 tests pass. Manual: relaunch → the launch migration replaces Akkad's stored test-sliver with the authored territory, so Akkad's dynasty page + the Dynasty Map show the full border (thick line, tinted fill) on both Historical and Modern; the draw tool still works and now produces closed polygons.

**Relevant files:**
- `Sources/MeCore/Store/TagEngine.swift`, `Sources/MeCore/Store/Migration.swift`, `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/EntityGroupCollectionView.swift`, `Sources/Me/Views/GroupEraMapView.swift` (new), `Sources/MeCore/Models/FigureGroup.swift`, `Sources/MeCore/Models/Era.swift`, `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-15 — Mixed-type groups: `entityType` demoted to a soft classification

**Context:** A `FigureGroup` could only hold members of its declared `entityType` — so a curated dossier like "Atrahasis" (gods, tablets, places, events, prose) could never mix kinds, and the event "Creation of Mankind" couldn't join any group. The user asked: make a group an aggregation page that can hold figures, places, events, things, text blocks, and subgroups freely. Decision after a full survey of enforcement points: `entityType` stays as a **soft classification** controlling only sidebar placement, figure-only chrome (reign tower/hero stats, Enoch/SKL/Flood dedicated views, aggregation targets), and smart-rule scope — never membership. Smart groups stay type-scoped (a mixed group is manual-only).

**Changes made:**

- `Sources/Me/Views/EntityGroupsSection.swift` — Removed the `entityType` filter (was line 16) and the stored `entityType` property; the section now takes only `associations` + `onCreateAssociation`.
- `Sources/Me/Views/EventDetailView.swift`, `ThingListView.swift`, `PlaceDetailView.swift` — Dropped the `entityType:` argument at the `EntityGroupsSection` call sites (the association-creation closures were already polymorphic via `FigureGroupAssociation(event:/thing:/place:)`).
- `Sources/Me/Views/FigureDetailView.swift` — `GroupLinkPopover.allGroups` no longer filters `.figure`; a figure can join any group.
- `Sources/Me/Views/FigureGroupFormView.swift` — Member picker candidates = figures + places + events + things (name-sorted); "Members Are" picker relabeled "Group Type" with a help tooltip stating classification-only semantics (sidebar/smart/summaries) and that any kind can be added; search placeholder + empty text generic ("Search members…", "No members selected"); `memberCountLabel` generic ("N selected"); **removed `selectedMemberAliases.removeAll()` from `onChange(of: entityType)`** (type change no longer wipes selection); `memberID(_:of:)` is now polymorphic `memberID(_:)` (figure ?? place ?? event ?? thing); removed now-unused `loadedEntityType`.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `spineItems(for:)` uses a polymorphic if-let chain over `assoc.figure/place/event/thing` instead of `switch group.entityType`; search placeholder + empty-state text use `group.memberPluralLabel`.
- `Sources/Me/Views/FigureGroupListView.swift` — Both empty-state texts ("No X in this group") use `group.memberPluralLabel`.
- `Sources/Me/Views/ContentView.swift` — `SidebarGroupRow.subgroups` no longer filters by `entityType`, so a figure group's event/thing subgroups still nest in the sidebar; per-type sidebar sections + dedicated kind-view dispatch (`.enoch`/`.skl`/`.flood`, figure-only) unchanged.

**Design decisions:**
- `entityType` is now purely descriptive: sidebar section placement (History for figure-classified, "X Groups" for others), figure-only chrome (`reignEntries`/`heroStats`/`reignTower`/`aggregatedReign` guards, `applyRegnalOrder`, smart-rule builder), and dedicated kind views. It never constrains which entities can be associated.
- Smart groups stay type-scoped: `effectiveMemberItems`/`liveMatchIDs` still switch on `entityType` (a smart group's rule matches only its own kind), so a mixed group must be manual. The manual path (`sortedAssociations.compactMap(GroupMemberItem.init(association:))`) was already polymorphic.
- `syncMembers`/`BulkAddMembersSheet`/`applyRegnalOrder` stay type-scoped per the above.
- No model changes: `FigureGroupAssociation` was already polymorphic; `GroupMemberItem`/`MixedItem` already cover all four kinds; `FigureGroup.memberPluralLabel` (exists) reused for generic texts.

**Verify:** `swift build` clean; 207 tests pass. Manual: edit the "Atrahasis" group → "Group Type" picker stays on Figures but the member picker lists every figure/place/event/thing; add "Creation of Mankind" → it appears in the group page with an event row; the sidebar still places the group in History.

**Relevant files:**
- `Sources/Me/Views/EntityGroupsSection.swift`, `EventDetailView.swift`, `ThingListView.swift`, `PlaceDetailView.swift`, `FigureDetailView.swift` — Updated
- `Sources/Me/Views/FigureGroupFormView.swift` — Updated
- `Sources/Me/Views/EntityGroupCollectionView.swift`, `FigureGroupListView.swift`, `ContentView.swift` — Updated

### 2026-08-15 — Source-discriminated lineage, Step 2: badges, filter, contradiction display

**Context:** The long-planned "source-discriminated lineage" idea (see the 2026-06-22 design note) finally shipped in two steps. Step 1 (model + migration) linked each `Relationship.source` free-text string to a `Source` entity (`Relationship.sourceRef: Source?` + `Source.relationships` inverse + `Migration.ensureRelationshipSources`), wired into the ContentView launch sequence after `ensureSKLRegnalOrder`; `swift build` was green. This session delivered **Step 2 — the read-side UI**: source badges on every relationship row, a per-source filter on all four lineage views, and source-labeled contradiction lists in the alternatives popovers. The demo: Enki's tree filtered to "Enuma Elish" collapses to `Anu → Enki → Marduk`; unfiltered, the alternatives popovers show "Enuma Elish" vs "Sumerian texts" side by side.

**Changes made:**

- `Sources/Me/Views/SourceBadgeView.swift` — NEW. Reusable capsule badge (small `book.closed` icon + source name, `.secondary` tint on `Color.secondary.opacity(0.12)`); clicking opens the source URL via `NSWorkspace` when `url` is non-empty; `.help(url ?? name)`.
- `Sources/MeCore/Models/Relationship.swift` — Added `package var sourceDisplayName: String` (entity-backed `sourceRef?.name` when non-empty, else the legacy `source` string) and `package var sourceURL: String?` (non-empty `sourceRef?.url` only). Moved here (not the Me layer) so MeCore tests can exercise them.
- `Sources/Me/Views/FigureDetailView.swift` — `RelationshipGroupRow` and `AlternativeRelationRow` (the row inside the `+N` alternatives popover) now render `SourceBadgeView` instead of the bare source text — this is the figure detail's contradiction display.
- `Sources/Me/Views/RelationshipListView.swift` — `RelationshipRowView` source text replaced with `SourceBadgeView`.
- `Sources/Me/Views/MiniLineageView.swift` — New `@State sourceFilter` + `availableSources`/`filteredRelationships`/`filteredAllRelationships` computed pools. `couples` (via `buildCouples`) and the grandparent lookups read the **filtered** pools. A compact source-filter `Menu` capsule ("All sources" / per-source) appears above the tree only when `availableSources.count > 1`. `AltCouplesButton` rows gain a per-couple `SourceBadgeView` (from `ParentCouple.sourceLabel` = father/mother relationship source).
- `Sources/Me/Views/LineageTreeView.swift` — Same `sourceFilter` pattern; `filteredRelationships` feeds `collectAncestors`, `collectDescendants`, `preferredPartner`, `partnerCount`, `alternativePartners`. Filter `Menu` sits in the header next to `FigureTypeLegend`. `alternativePartners` now returns `[(figure: Figure, source: String?)]` (dedup by id, first source wins) and `AlternativePartnersSheet` renders a `SourceBadgeView` per partner row.
- `Sources/Me/Views/FigureLineageExplorer.swift`, `LineageExplorerWindow.swift` — Same `sourceFilter` + `filteredRelationships` substitution across all relationship reads (parents/children/grandparents/grandchildren/spouses/consorts/siblings/co-parents); filter `Menu` in each header (shown only when >1 distinct source).
- `Tests/MeCoreTests/MeCoreTests.swift` — 7 new tests: case-insensitive resolve to an existing Source ("Adapa myth" → seeded "Adapa Myth", no new Source), coarse Source creation for unknown names (`.ancientText`), first-comma-segment handling ("Enuma Elish, Babylonian texts" → "Enuma Elish"), king-list type detection (`.kingList`), idempotency (second run creates nothing), never re-points an existing `sourceRef`, and `sourceDisplayName`/`sourceURL` fallback behavior. 206 tests pass.

**Design decisions:**
- The filter slices the relationship **pool** before any resolution (couples, generation rows, partners) rather than post-filtering rendered nodes — so `isPreferred`-within-pool semantics and Unknown-parent placeholders behave consistently per source.
- Filter `Menu` only renders when the pool has >1 distinct source (Enki yes, a single-source figure no clutter).
- `AlternativePartnersSheet` keeps figure dedup by `PersistentIdentifier` but attaches the first relationship's source as a label — the tree's contradiction surface without changing `FigureCardView`'s figure-only `alternatives` API.
- The quicklook window (`FigureQuicklookView`) groups relationships by type and keeps only `[Figure]`, so its rows stay source-free (secondary surface; the figure-detail sidebar is the canonical one). The `FigureDossier` relationship lists are figure-based too and intentionally left for Step 4's source-aware query answers.
- `Relationship.sourceDisplayName`/`sourceURL` live in MeCore so the fallback logic is unit-tested; the UI badge is a thin renderer.

**Verify:** `swift build` clean; 206 tests pass. Manual: run the app on the existing DB — the migration creates coarse `Source`s only for `Inanna's Descent`, `Sumerian hymns`, `Sumerian mythology`, `Sumerian texts`, `Babylonian texts`; everything else links to existing seeded sources. Open Enki → Relationship rows show book-icon badges; the `+N` alternatives popover lists e.g. "Enuma Elish" vs "Sumerian texts" badges; the mini-lineage source menu set to "Enuma Elish" collapses the tree to Anu → Enki → Marduk. Same menu in the Lineage Tree / explorer windows.

**Relevant files:**
- `Sources/Me/Views/SourceBadgeView.swift` — Added
- `Sources/MeCore/Models/Relationship.swift`, `Sources/Me/Views/FigureDetailView.swift`, `Sources/Me/Views/RelationshipListView.swift`, `Sources/Me/Views/MiniLineageView.swift`, `Sources/Me/Views/LineageTreeView.swift`, `Sources/Me/Views/FigureLineageExplorer.swift`, `Sources/Me/Views/LineageExplorerWindow.swift`, `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-15 — Startup re-seeding bug: case-sensitive reconciliation guards recreate merged entities

**Context:** The user de-dupped "Bad-Tibira" (duplicate-finder detected it), but the duplicate kept coming back on every launch. Investigation confirmed the suspicion: the app's seed-reconciliation migrations run at **every launch** and recreate any seed entity whose *exact* name is absent. The seed stores `Bad-tibira` (lowercase); the user's keeper was `Bad-Tibira` — so the next launch saw `"Bad-tibira"` missing, re-created it from seed, and the pair returned. Both rows existed in the live DB (pk 31 `Bad-Tibira` = user data with richer modern location; pk 92 `Bad-tibira` = seed copy with seed coords).

**Root cause:** Every `existingNames`/`figureByName`/`placeByName`/`existingEventNames` guard in `Migration.swift` matched case-sensitively (e.g. `Set(allPlaces.map(\.name))`, `figureByName[$1.name]`). Any variant spelling a user creates (case difference, hyphen vs space) survives the guard as "absent" and gets re-seeded.

**Changes made (`Sources/MeCore/Store/Migration.swift`):**
- **`ensureMissingCitiesAndAssociations`** — `existingPlaceNames`/`placeByName`/`figureByName` now key on `name.lowercased()`; creation guard + association lookups (figure-place, place-place, event-place) use the lowercased key.
- **`ensureSKLEventsAndFigures`** — `figureByName`/`placeByName` lowercased; figure/place/event creation guards + involved-figure/event-place lookups lowercased.
- **`ensureDeitiesImportExist`** — `existingNames` lowercased; `targetNames`/`rootExistingNames` compared lowercased; `toImport` filters by lowercased name.
- **`ensureDumuziFamilyExists`** — `existingNames` lowercased; "Duttur" check + Enki/Dumuzi/Geshtinanna lookups case-insensitive.
- **`ensureParentRelationshipsExist`** — `figureByName`/`figureByName2`/`existingNames` lowercased; `getOrCreateFigure` + relDef lookups case-insensitive.
- **`ensureMissingCommanderFiguresExist`**, **`ensureArchangelsExist`**, **`ensureDivineCollectives`**, **`ensureImportedDeityRelationships`** — same lowercase normalization (figure name sets/maps + relationship target lookups).
- All changes are **additive + idempotent**: no existing row is renamed, deleted, or overwritten; the guards now simply *see* case-variant entities as already-present.

**Design decisions:**
- Keying on `name.lowercased()` (not full normalization) keeps the change minimal and consistent — matches the DuplicateMerger's own case-insensitive grouping.
- Purely creation-guard changes; update-only paths (e.g. `ensureSKLAnchorDates` figure lookup for description editing) left exact-match.
- `ensureEnochDataExists` (SeedData.swift) left as-is per user request — its Mount Hermon sentinel-only guard is a separate, user-accepted risk.

**Tests:** 3 new tests: `testEnsureMissingCitiesAndAssociationsSkipsCaseVariantPlace`, `testEnsureMissingCitiesAndAssociationsCreatesMissingPlace` (46 seed places), `testEnsureSKLEventsAndFiguresSkipsCaseVariantFigureAndPlace`. 199 tests pass; `swift build` clean (2 pre-existing unused-variable warnings in `ensureParentRelationshipsExist`).

**Verify:** `swift build` + `swift test` green. Manual: run the app on the existing DB — `Bad-tibira` is no longer re-created on launch; the two existing rows (pk 31/92) remain until the user re-merges them once more, after which the duplicate stays gone (user wants the survivor named `Bad-tibira`).

**Relevant files:**
- `Sources/MeCore/Store/Migration.swift` — Updated
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-14 — Map markers open a place detail sheet (drop the popup, keep the map)

**Context:** On the Dynasty Map, clicking a place showed only a tiny name popup (MapLibre `.setText` popover on the historical map; nothing at all on the modern map), while the sidebar offers full place detail. The user called the popup "silly" and asked for click-to-open. A first attempt navigated the sidebar to the Places list — but the user rejected that: the map was replaced by the list, exactly what they wanted to avoid ("the full details should appear alongside, not replace the map"). Final behavior: clicking a place opens a **sheet** with the full `PlaceDetailView`, mirroring the ruler-click pattern (figure quicklook sheet) — the map stays visible underneath.

**Changes made:**
- `Sources/Me/Views/SumerianDynastyMapView.swift`:
  - **Historical map**: `DynastyHistoricalMapView` gained `onPlaceSelected: (Int) -> Void`. Its `Coordinator` is now `NSObject, WKScriptMessageHandler`; `makeNSView` builds the web view with a `WKUserContentController` registering `placeClicked`. The JS replaced `.setPopup(...).addTo(map)` with an `addEventListener('click')` that posts the marker index through `window.webkit.messageHandlers.placeClicked` (guarded so it no-ops outside WKWebView). The callback is refreshed on every `updateNSView`, and the index resolves against the parent's live `allPlaces`.
  - **Modern map**: `Marker`s replaced with `Annotation(coordinate:content:label:)` + custom dot-and-label marker (colored circle + name pill, capital bold/dynasty-colored) carrying an `.onTapGesture` → `openPlace(place)`. `MapSelection` was rejected: it's macOS 15+ and the app targets macOS 14.
  - **Place detail sheet**: new `@State detailPlace: Place?`; `openPlace(_:)` sets it (was `coordinator?.navigateToPlace`). A second `.sheet(item: $detailPlace)` presents `PlaceDetailView(place:)` in a `NavigationStack` with a Close toolbar button (`minWidth: 560, minHeight: 500`), next to the existing `detailFigure` quicklook sheet.

**Design decisions:**
- `MapSelection<PersistentIdentifier>` binding was the first choice (native pin look + native selection) but is `@available(macOS 15.0)` — the project still builds against macOS 14, so it was abandoned rather than `@available`-gated.
- The custom annotation mirrors the historical map's dot + label aesthetic, giving both map versions a consistent marker language (and the capital highlight is preserved via dynasty color + semibold weight).
- Popup removed entirely; the place detail sheet replaces it, so there is no transient callout/flash.
- **No sidebar navigation** — the map is never left; `PlaceDetailView` is reused as-is (editing affordances intact), keeping behavior consistent with the figure quicklook sheet.

**Verify:** `swift build` clean (no warnings); 196 tests pass (UI-layer change). Manual: Dynasty Map → Historical mode, click any city dot → a sheet opens with that place's full details; the map stays visible behind it. Same for Modern mode (click the dot+label marker). Close returns to the map. No popup and no sidebar jump.

**Relevant files:**
- `Sources/Me/Views/SumerianDynastyMapView.swift` — Updated

### 2026-08-14 — Dynasty map presentation settings (theme, language, label size, modern style, date filter)

**Context:** Follow-up to the startup-zoom settings. The user asked what other map parameters could be surfaced (colors, fonts, languages); research showed OHM supports per-language `name:<lang>` label fields (incl. `grc`, `la`), four style themes, and a date-filter plugin. The user approved implementing them all; colors were deliberately deprioritized.

**Changes made:**
- `Sources/Me/Views/SumerianDynastyMapView.swift` — New file-scope setting enums shared with AppSettingsView: `HistoricalMapTheme` (historical/railway/woodblock/japaneseScroll → style URL), `HistoricalMapLanguage` (en/fr/de/es/ar/grc/la → `name:<lang>` IETF tags), `MapLabelSize` (small 9/medium 11/large 14 px), `ModernMapStyle` (standard/hybrid). Six new `@AppStorage` keys: `dynastyMapModernStyle`, `dynastyMapModernMuted`, `dynastyMapHistoricalTheme`, `dynastyMapHistoricalLanguage`, `dynastyMapLabelSize`, `dynastyMapDateFilter` (default false).
- Modern map: `modernMapStyle` computed property — `.hybrid(...)` or `.standard(emphasis: .muted)` when enabled; every variant passes `pointsOfInterest: .excludingAll, showsTraffic: false` (decluttered basemap; applies immediately, live via `@AppStorage`).
- `DynastyHistoricalMapView` gained `theme/language/labelSize/dateString`; `mapHTML` reworked:
  - Style URL from theme; the three alternate themes load pinned jsDelivr (`@openhistoricalmap/map-styles@0.9.8/dist/<theme>/<theme>.json` — verified live; sprite/glyphs are absolute URLs so any origin works).
  - Loads `@openhistoricalmap/maplibre-gl-dates@1.3.0` (adds `map.filterByDate`); on `styledata` snapshots each layer's filter, then applies language + date + label size.
  - Language: for every layer whose `text-field` expression references `name`, sets `['coalesce', ['get', 'name_<lang>'], ['get', 'name']]`.
  - Date filter: `dynastyDateString` = midpoint of the dynasty's `startBCE`/`endBCE` formatted as ISO year (negative BCE zero-padded to 4 digits, e.g. `-2850`); `setDate()` on load + every dynasty switch; when off/empty it restores the snapshot filters (the plugin has no reset API, so we snapshot + restore ourselves — idempotent).
  - Label size: `.place-label` font-size driven by `--place-label-size` CSS var; `applyLabelSize()` scales base size with zoom (clamped 0.8–1.8).
- `Sources/Me/Views/AppSettingsView.swift` — Dynasty Map section extended: modern style picker, "Quiet modern basemap" toggle (shown only for standard), theme picker, label-language picker, label-size picker, experimental date-filter toggle.

**Design decisions:**
- Historical-map settings apply on the next view open (captured in `makeNSView`/`updateNSView`, which early-return when the places signature and focus token are unchanged); modern-style settings are live.
- Date filter is OFF by default: OHM coverage of deep-past (2nd–4th millennium BCE) eras is sparse, so the map can look near-empty for the early dynasties until the user opts in.
- Filter reset is handled by snapshotting original layer filters on `styledata` and restoring before each `filterByDate` — makes repeated dynasty switches idempotent and survives style reloads.
- Label scale anchors at the previous default: zoom 5 → scale 1.0 (medium = 11px, the old hardcoded size), so defaults reproduce the prior look.

**Verify:** `swift build` clean; 196 tests pass (UI-layer change). Manual: App Settings → pick Historical theme "Woodblock"/"Japanese Scroll", language "Ancient Greek", Large labels, enable the date filter; reopen Dynasty Map in Historical mode and switch dynasties — theme/language/labels change on reopen, era filtering fades later features; modern map honors Standard/Hybrid + Quiet toggle immediately.

**Relevant files:**
- `Sources/Me/Views/SumerianDynastyMapView.swift` — Updated
- `Sources/Me/Views/AppSettingsView.swift` — Updated

### 2026-08-14 — App Settings (Housekeeping) + dynasty map startup zoom settings

**Context:** The user noticed the historical (OpenHistoricalMap) dynasty map opens at a lower zoom than the modern (MapKit) one — the historical map hardcoded `zoom: 5` in its MapLibre init *and* in the `focus()` call on dynasty switch, while the modern map's `onAppear`/`onChange` flew to the capital at span 3 (≈ zoom 6). The user asked for runtime settings to fix the mismatch. Decision: start the app's runtime-settings story with a new **Housekeeping** sidebar section → **App Settings**, holding the two startup zoom settings.

**Changes made:**
- `Sources/Me/Views/ContentView.swift` — New `SidebarSection.housekeeping` ("Housekeeping", rendered as the last sidebar section) and `NavigationItem.appSettings` ("App Settings", `gearshape` icon); destination `AppSettingsView()`.
- `Sources/Me/Views/AppSettingsView.swift` — NEW. Grouped `Form` with "Dynasty Map" section: two `@AppStorage` sliders — `dynastyMapModernStartupZoom` (default 6.0) and `dynastyMapHistoricalStartupZoom` (default 5.0), range 2–10 step 0.5, with formatted value + caption per row.
- `Sources/Me/Views/SumerianDynastyMapView.swift`:
  - Reads both settings via `@AppStorage`.
  - Modern map: extracted `focusModernMap()` (capital at the setting-derived span, region center fallback) used by both `.onAppear` and `.onChange(of: selectedDynastyIndex)`, replacing the hardcoded span-3 focus.
  - New `span(for zoom:)` convention: `zoom 5 → span 6`, `zoom 6 → span 3` (the two previously hardcoded values), so the default 6.0 reproduces the old modern behavior.
  - Historical map: `DynastyHistoricalMapView` gained `startupZoom: Double`, threaded through `mapHTML` (`zoom: <setting>`) and the dynasty-switch `focus(...)` call; default 5.0 reproduces old behavior.

**Design decisions:**
- Defaults reproduce the pre-existing effective behavior (modern 6.0 ≈ span 3 on open; historical 5.0), so nothing changes until the user adjusts them; the two sliders make the mismatch visible and alignable.
- The setting drives *every* camera move within a map version (initial + dynasty-switch focus), not just startup — one "standard zoom" per map version, so raising historical to 7 doesn't pop back to 5 on dynasty switch.
- Only the dynasty map consumes these today; the single-place `MapWebView` keeps its hardcoded zoom 5 (it's a different map, not a "map version").
- Settings live in the sidebar per request (not in the map header); the existing Modern/Historical segmented toggle stays in the header.

**Verify:** `swift build` clean (one pre-existing unrelated warning in LinkifiedDescription.swift); 196 tests pass. Manual: sidebar → Housekeeping → App Settings → drag both sliders; reopen Dynasty Map in each style and switch dynasties — the camera respects the per-style zoom.

**Relevant new/removed files:**
- `Sources/Me/Views/AppSettingsView.swift` — Added

**Relevant files:**
- `Sources/Me/Views/ContentView.swift`, `Sources/Me/Views/SumerianDynastyMapView.swift` — Updated

### 2026-08-14 — Object Graph zoom smoothness pass

**Context:** The user reported zoom (wheel + pinch) was "extremely jerky" — touching the mouse risked losing the view. Two root causes in `NetworkGraphView.swift`:

1. **Flat per-event scroll zoom** — the `scrollWheel` monitor applied a constant `1.15` factor per event (`scrollingDeltaY > 0 ? 1.15 : 1/1.15`). A single wheel notch / trackpad flick emits many events, so `1.15^n` exploded to the 0.2–5.0 clamp in one gesture. It also swallowed scroll events **app-wide** (any window, any region), so scrolling the sidebar while the graph was open zoomed the graph.
2. **Compounding pinch zoom** — `MagnificationGesture().onChanged { scale = scale * value }`. SwiftUI's magnification `value` is cumulative from gesture start, so multiplying the already-mutated `scale` each update compounded quadratically and direction-reversals behaved erratically (the classic pinch bug).
3. **Center-anchored zoom** — zoom was anchored at canvas center, so zooming in made the node under the cursor fly off-screen ("losing the view").

**Changes made:**
- Zoom is now **proportional to the scroll delta**: `applyZoom(exp(pixels * 0.015))` where `pixels = hasPreciseScrollingDeltas ? scrollingDeltaY : scrollingDeltaY * 10` — a notch ≈ +16%, small flicks zoom proportionally instead of runaway.
- Scroll monitor is **gated to the canvas**: `cursorIsOverCanvas(_:)` converts `event.locationInWindow` (bottom-left) into window top-left coordinates via `contentView.bounds.height` and tests against a tracked `canvasGlobalFrame` (`geo.frame(in: .global)`), updated in `canvasArea.onAppear`/`.onChange(of: size)`. Scrolls outside the canvas pass through (`return event`) instead of zooming the graph.
- Zoom is **anchored at the cursor**: `applyZoom(_:at:)` also adjusts `offset` so the graph point under the mouse stays fixed — the node you're pointing at stays put while zooming in/out.
- Pinch fixed by capturing the **gesture-start scale** (`pinchStartScale`), computing `start * value` (not `scale * value`), pausing the simulation during pinch and resuming on end if temperature allows (mirrors the drag behavior).

**Verify:** `swift build` clean; 196 tests pass (UI-layer change). Manual: wheel-zoom over a node — the node under the cursor stays centered; a full wheel notch steps ~16% instead of snapping to 5×; scrolling the sidebar while the graph is open no longer zooms it; pinch zooms smoothly both directions.

**Relevant files:**
- `Sources/Me/Views/NetworkGraphView.swift` — Updated

### 2026-08-14 — Dashboard data-coverage audit for all four entity types

**Context:** Following the Object Graph performance pass, the user asked what other tools could analyse the dataset; the answer included the Dashboard's Data Coverage audit, which was **figures-only**. The user approved extending it in both directions: the 8 new figure dimensions (fields added since the audit was written) AND coverage for Places, Events, and Things.

**Changes made:**
- `Sources/MeCore/Models/Place.swift`, `Event.swift`, `Thing.swift` — Added `coverageExempt: Bool?` and `coverageReviewedAt: Date?` (migration-safe optionals, mirroring `Figure`).
- `Sources/Me/Views/DashboardView.swift`:
  - `coverage` replaced a 7-field tuple with a `FigureCoverage` struct; 8 new dimensions: Missing Type (`figureType == nil`), Missing Reign Years (`reignYears == nil`), Missing Epithet, Missing Mugshot (`mugshotImage == nil`), Missing Pantheon (`pantheons.isEmpty`), Missing Alternate Names, No Images, Missing Attribution (`(contentAttributions ?? []).isEmpty`).
  - New `PlaceCoverage` (description / modern location / coordinates / type), `EventCoverage` (description / date / type / involved figures), `ThingCoverage` (description / type) computed properties, all filtering `coverageExempt != true`.
  - `CoverageBlock` generalized from `[Figure]` to `CoverageBlock<Entity: PersistentModel>` with a `name: (Entity) -> String` closure and `id: \.persistentModelID`.
  - `dataCoverageSection` now renders four group headers (Figures / Places / Events / Things) via a generic `coverageBlocks(dims:total:totalLabel:name:markAll:markOne:)` builder; Dismiss All / Dismiss work per entity type via concrete closures.
  - `auditSummary` counts auto-exempted + manually-reviewed across all four entity types.

**Design decisions:**
- `coverageExempt`/`coverageReviewedAt` were added to Place/Event/Thing so the same Dismiss mechanism (mark reviewed once, never re-audit) applies uniformly; the existing auto-exempt-by-type migration stays figures-only (kings/deities noise mostly lives in figures).
- The generic `CoverageBlock` needed a `name` closure because `PersistentModel` has no `name` requirement.
- `markAll`/`markOne` are concrete per call site (not type-erased) because `coverageExempt` isn't on the `PersistentModel` protocol — an existential `(any Collection<PersistentModel>) -> Void` can't mutate the flag.

**Verify:** `swift build` clean; 196 tests pass (UI-layer change, no MeCore logic to test). Manual: Dashboard → Data Coverage now lists missing-description/modern-location/coordinate/type for places, missing-date/type/figures for events, missing-description/type for things; Dismiss All and per-item Dismiss persist `coverageExempt` + `coverageReviewedAt`.

**Relevant files:**
- `Sources/Me/Views/DashboardView.swift` — Updated
- `Sources/MeCore/Models/Place.swift`, `Event.swift`, `Thing.swift` — Updated

### 2026-08-14 — Object Graph performance pass

**Context:** The user reported the Object Graph ("network") getting "very slow" — ~320 nodes with an O(n²) repulsion force simulation running at 60fps until temperature cooled to 0.01 (~25s), plus per-frame linear scans for edges and per-render degree recomputation. Approved a performance pass.

**Changes made (`Sources/Me/Views/NetworkGraphView.swift`):**
- **Grid/monopole repulsion** — `ForceEngine.applyGridRepulsion` replaces the O(n²) all-pairs loop: nodes bucketed into `cellSize = 90` cells; exact pair repulsion inside a cell; a coarse monopole (cell centroid × member count) for far cells. O(n · cells) per tick instead of O(n²). `tick()` now returns the step's `maxSpeed` (`@discardableResult`).
- **Motion-based early stop** — new `@State staticTicks`; `tick()` stops the simulation after 40 consecutive ticks below `maxSpeed < 0.5`, so a settled layout halts in ~0.7s instead of running the full cooling schedule. Temperature-based stop retained as a backstop.
- **Cached degrees** — `connectionDegrees` is now `@State` populated in `rebuildGraph()` (was a computed property recomputed on every render/radius lookup); `radius(for:)` is a dict read.
- **Value-based rebuild triggers** — `.onChange(of: figures.map(\.persistentModelID))` (same for places/events/relationships/associations) replaces `.onChange(of: figures)` etc., so identity-preserving edits (renames, description changes) no longer tear down and rebuild the graph. Rebuilds only fire on structural changes.
- **Position carryover** — `rebuildGraph()` snapshots old node positions keyed by `PersistentIdentifier` into `oldPositions` and seeds new nodes from it; `initializePositions(size:)` now circles only `.zero`-position nodes (so newly added nodes join the existing layout instead of everything snapping back to a fresh circle). Selection is preserved across rebuilds by `persistentModelID`. Rebuild also resets `engine.temperature = 1.0`, resumes the simulation, and clears `staticTicks`.
- **resetLayout()** — now zeroes every position/velocity and unpins nodes *before* re-circling (previously re-circled on stale positions, so it did nothing after the first run).
- **Canvas edge rendering** — builds a `nodeByID: [UUID: GraphNode]` once per render pass for O(1) edge endpoint lookups; removed the now-unused `nodeWithID(_:)` linear scan.

**Design decisions:**
- Monopole approximation only affects far cells (>= 1 cell away); intra-cell repulsion stays exact, so the layout quality is essentially unchanged while the per-tick cost drops by ~an order of magnitude.
- Carryover on rebuild keeps a data entry in the graph visually stable — new nodes drift in and the simulation re-settles locally instead of the whole graph jumping to a fresh circle.
- Early stop is motion-based rather than temperature-based because temperature only reflects the cooling schedule, not actual settledness; a frozen layout (e.g. nodes pinned during a drag) stops promptly.
- Renames/description edits intentionally don't rebuild (identity unchanged); node names refresh on the next structural change or view reopen.

**Verify:** `swift build` clean (no warnings); 196 tests pass. Manual: open Object Graph — simulation settles in ~1–2s and pauses itself; add a figure via From-Text while the graph is open → new node appears and joins the existing layout; select a node then rename it in the side panel → no full re-layout; Reset Layout restores a fresh circle.

**Relevant files:**
- `Sources/Me/Views/NetworkGraphView.swift` — Updated

### 2026-08-13 — Figures list crash after merge: value-based rows (completed in resumed session)

**Context:** After the duplicate merger / DuplicateMergeView work, merging duplicates while the Figures list was visible crashed the app on macOS 26.5. Same fault class as the 2026-08-09 group-deletion crash: a merge deletes a duplicate `Figure` (and its relationships/join rows) and saves; the live `@Query figures` in `FigureListView` updates; the list re-renders its rows, and a row that still references the deleted figure faults `persistentBackingData` mid-`NSHostingView.layout()` → `EXC_BREAKPOINT`/`_assertionFailure`. The previous DuplicateMergeView fix already precomputed the sheet's rows; the sidebar Figures list was still rendering live models.

**Interrupted session note:** This fix was designed and documented during the 2026-08-13 evening session (crash reports `Me-2026-08-13-230946.ips` = DuplicateMergeView `Event.name` fault, already fixed at 23:11; `Me-2026-08-13-232017.ips` = `FigureRow.body` → `Figure.gender` fault) but the session was shut down before the code was written — the working tree did not compile (`MugshotView` already called the then-missing `FigureIconCircle(color:icon:size:)` init). This entry was completed in the resumed session: implemented, built clean, 196 tests pass.

**Fix (value-based snapshot rows):**
- `Sources/Me/Views/FigureListView.swift` — The list no longer renders live `Figure`s. A private `FigureRowDisplay` struct (id, name, disambiguation, domain, typeName/color/icon, genderSymbol, isConcept, hasUnresolvedSticky, birthDateLabel, isRed, mugshot) is snapshotted off the render path by `rebuildRows()` (reads models in `.task`/`.onChange`, never in `body`). `filteredFigures`/`groupedFigures`/`redFigureIDs` became `filteredRows`/`groupedRows` over `[FigureRowDisplay]`; `FigureRow` renders only `display` values. `selectedFigure` resolves the live model only if its id is still in the snapshot (a deleted figure drops out and the detail panel closes instead of faulting).
- Rebuild triggers: `.task` (initial), `.onChange(of: figures.map(\.persistentModelID))` (any add/remove — covers merge/FromText/delete), `.onChange(of: selectedDynastyGroup?.persistentModelID)` (dynasty red highlight), and `.onChange` of the three sheet-presentation states (`showingAddSheet`, `editingFigure`, `showDescriptionEditor`) so edits that change only properties (not the ID set) still refresh. `rebuildRows()` also clears `selectedFigureID` when the selection vanished.
- `Sources/Me/Views/FigureDetailInfoView.swift` — `FigureIconCircle` gained an `init(color:icon:size:)` (stored color/icon) so the mugshot fallback doesn't need a live `FigureType`.
- `Sources/Me/Views/MugshotHover.swift` — New plain-value `MugshotHoverData` (imageURL, cropRect, identification, fallbackColor/icon) + `MugshotHoverValueModifier` + `View.mugshotHover(_:MugshotHoverData?, ...)` overload; the model-based modifier is unchanged for other callers. `MugshotView` got a value-based `init(imageURL:cropRect:size:fallbackColor:fallbackIcon:identification:)`.

**Design decisions:**
- The snapshot is rebuilt only on change triggers, so the body is pure value-driven; a row can never fault a deleted figure during the layout pass that follows a merge's save.
- `figures.map(\.persistentModelID)` (not `figures`) as the `.onChange` value — comparing IDs is safe (metadata, no fault) and fires deterministically on the query update after a merge deletes + saves.
- Mugshot hover data is pre-resolved into the snapshot (image `fileURL`, crop rect, identification, fallback color/icon) so list rows keep working with the hover-reveal portraits.

**Verify:** `swift build --no-incremental` clean; 196 tests pass. Manual: Figures sidebar open → merge two duplicates from the toolbar sheet → no crash, list re-renders without the duplicate, detail panel (if it was showing the duplicate) closes.

**Relevant files:**
- `Sources/Me/Views/FigureListView.swift`, `Sources/Me/Views/MugshotHover.swift`, `Sources/Me/Views/MugshotView.swift`, `Sources/Me/Views/FigureDetailInfoView.swift` — Updated

### 2026-08-13 — Duplicate entity merger (find + merge duplicates)

**Context:** The user wanted a way to find and merge duplicate entities ("Ninurta" vs "ninurta" accumulated from Add-from-Text and Wikipedia imports). Chosen design: a name-based duplicate finder (case-insensitive, per-entity-kind) plus a merge that re-points every link to the keeper, folds the duplicate's owned content into the keeper, and deletes the duplicate — all inside a transaction with observed arrays emptied before deletion (macOS 26 safety pattern from the 2026-08-09 group-deletion fix).

**Changes made:**
- `Sources/MeCore/Store/DuplicateMerger.swift` — NEW. `DuplicateGroup` (kind + name + candidate ids, keeper-first) and `DuplicateMerger`:
  - `findGroups(in:)` — buckets entities by trimmed-lowercased name per kind (Figure/Place/Event/Thing), returns only groups with >1 member, sorted by kind then name. Kinds never mix (a figure "Babylon" and place "Babylon" are not a merge group).
  - `mergeFigures` — re-points outgoing/incoming `Relationship`s (deleting keeper- or self-referencing ones); folds alternate names, place/thing/group associations (dedup by target+role), stickies, images, tags, events, pantheons, pantheon/group/content attributions; re-points `Event.figureAssociations`; adopts era, mugshot, and empty scalar fields (`adoptString`/`adoptOptional` — keeper values always win). Empties all observed arrays then deletes the duplicate, all in `context.transaction` + `save`.
  - `mergePlaces` — folds figure/event/thing associations + alternate names + groups + stickies + images + tags + attributions, re-points `PlacePlaceAssociation`s (deleting self-loops), adopts modern location/description/source/coords/type.
  - `mergeEvents` — folds figure (EFA)/place/thing associations + tags + images + stickies + groups + attributions, re-points `EventEventAssociation`s (deleting self-loops), adopts description/era/source/type/date.
  - `mergeThings` — folds figure/place/event associations + images + tags + stickies + groups + attributions, adopts description/source/type.
- `Sources/Me/Views/DuplicateMergeView.swift` — NEW. Sheet UI: grouped duplicate cards per name, radio-style keeper selection per group, "Merge N into keeper" button, per-member linked-data summary (relationship/place/event/group/mugshot counts), status banner, Refresh + Done.
- `Sources/Me/Views/ContentView.swift` — NEW toolbar button (`person.crop.circle.badge.plus`, "Find and merge duplicate entities") + `.sheet(isPresented: $showDuplicateMergeSheet)`.
- `Tests/MeCoreTests/MeCoreTests.swift` — 11 new tests: case-insensitive grouping, kind isolation (no figure/place cross-merge), single-entry skip, relationship re-pointing (incl. self-relationship deletion), owned-content folding (names/places/tags/stickies/groups/pantheons/images), field adoption (empty keeper) + keeper-wins, place PPA re-pointing, event EFA/EEA re-pointing, thing association folding, EFA re-pointing from mergeFigures. 196 tests pass.

**Design decisions:**
- The keeper is user-chosen per group (default first-found); merging is a deliberate per-group action, not bulk.
- Re-pointing happens on the model relationship arrays (per the 2026-06-27 SwiftData convention) and via whole-store passes for the un-owned join tables (`Event.figureAssociations`, `PlacePlaceAssociation`, `EventEventAssociation`).
- Dedup when folding (same target + role for associations, same name + tradition for alternate names) so a keeper already linked to the same thing doesn't get a double entry.
- `adoptString`/`adoptOptional` copy duplicate values only into empty/nil keeper fields — the keeper is never overwritten. Nullify-deleted orphans (e.g. a folded association whose other side was the duplicate) are left to their existing delete rules.
- The merger lives in MeCore (unit-testable, no AppKit); the sheet is the only Me-layer piece.

**Verify:** `swift build` clean; 196 tests pass. Manual: add two same-named figures (or run `swift run Me --reseed` on a throwaway DB), open the duplicate-merge sheet from the toolbar, pick a keeper, Merge → duplicate gone, its relationships/names/places/groups now on the keeper.

**Relevant new/removed files:**
- `Sources/MeCore/Store/DuplicateMerger.swift` — Added
- `Sources/Me/Views/DuplicateMergeView.swift` — Added

**Relevant files:**
- `Sources/Me/Views/ContentView.swift`, `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-13 — DuplicateMergeView crash: faulting models inside the SwiftUI body

**Problem:** Opening the duplicate-merge sheet crashed the app on macOS 26.5 (`EXC_BREAKPOINT` / `_assertionFailure` inside SwiftData, from `DuplicateMergeView.detail(for:id:)` → `Event.name.getter`). The stack showed the fault happening **inside `ForEachChild.updateValue()` during an `NSHostingView.layout()` render transaction** — i.e. the body faulted a model's persisted property mid-layout, hitting the same macOS 26 SwiftData assert-on-fault-in-live-render class as the 2026-08-09 group-deletion crash.

**Fix:** `Sources/Me/Views/DuplicateMergeView.swift` — decoupled the view from live model access. The body no longer touches any `@Model`. A `load()` (called from `.task` and Refresh/merge) resolves every `PersistentIdentifier` → plain-value `DuplicateMemberDisplay`/`DuplicateGroupDisplay` structs (title/subtitle/ids only) once, off the render path; the body renders only those value structs. Merge still resolves keeper/duplicate models, but inside the button action (not during a view update). `detail(for:)` now returns nil for unresolvable ids (skipped rather than shown as "?").

**Lesson:** On macOS 26, never fault a `PersistentModel`'s properties from inside a SwiftUI `body` (incl. helper funcs called by the body during `ForEach` render). Precompute display values into plain structs in a non-render path (`load()`/`.task`/button actions) and keep the body pure value-driven.

**Verify:** `swift build` clean; 196 tests pass. Manual: open the duplicate-merge sheet on a DB with duplicate events (e.g. a double "The Flood") — no crash; rows show precomputed summaries.

**Relevant files:**
- `Sources/Me/Views/DuplicateMergeView.swift` — Updated

### 2026-08-13 — Mugshots everywhere: hover-reveal portraits

**Context:** With a growing image + mugshot collection, the user wanted portraits available across the app "without making the screens too crowded" — chosen pattern: **hover-reveal only**. A reusable modifier shows a circular mugshot popover over any figure-bearing surface; figures without a mugshot render exactly as before (no hover machinery at all). Also fixed a jerky-crop bug in the mugshot sheet.

**Changes made:**

- `Sources/Me/Views/MugshotHover.swift` — NEW. `MugshotHoverModifier` (figure, `size`, `arrowEdge`, optional `onHover` forward for callers that already track row hover, e.g. group-member link highlighting). Gate: only applies `.onHover` + `.popover` when `figure.mugshotImage != nil`. `extension View.mugshotHover(_:size:arrowEdge:onHover:)`.
- `Sources/Me/Views/FigureCardView.swift` — Lineage tree cards get `.mugshotHover(figure, size: 140, arrowEdge: .bottom)` (popover below the card; coexists with the existing +N alts popover).
- `Sources/Me/Views/FigureListView.swift` — `FigureRow` gets `.mugshotHover(figure)` (sidebar figure list).
- `Sources/Me/Views/SumerianKingListView.swift` — `KingRow` gets `.mugshotHover(figure)`.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `MemberRow` restructured: `let row = Button(...)` then conditional — figures with a mugshot use `.mugshotHover(figure, size: 120, onHover: onHoverLink)` (forwards the hover so the inline-link highlight still works); all other entity types keep the plain `.onHover`. Removed the inner `.onHover` from the HStack chain.
- `Sources/Me/Views/LinkifiedDescription.swift` — `InlineEntityLink` now fetches the figure via `modelContext.model(for: candidate.targetID) as? Figure` and shows a 120pt mugshot popover (arrow `.bottom`) when hovering a figure mention that has a mugshot; non-figure links unchanged.
- `Sources/Me/Views/MugshotSheet.swift` — Fixed jerky drag: both `moveGesture` and `resizeGesture` previously applied the cumulative `value.translation` on top of the already-mutated `crop` each frame (compounding movement). Added `@State moveStart`/`resizeStart` anchoring each drag to its start value; resize also recomputes center/size from the start rect.

**Follow-up (same day):**
- Sidebar figure rows (`FigureRow`, `KingRow`) switched to `arrowEdge: .leading` — popover now appears at the row's left (where it meets the sidebar) instead of the far right.
- `LineageTreeView` (the main tree) draws cards inside the Canvas, so `FigureCardView`'s popover never applied there. Added a hover-reveal overlay in the tree: `rightClickFigureID` (already tracked via `onContinuousHover`) + `layout.nodeLayouts` frame → a 140pt `MugshotView` positioned below the hovered card (above when near the canvas bottom edge), `.allowsHitTesting(false)`. Also clears `rightClickFigureID` on hover `.ended` (previously stale, which also let right-click menus target the last-hovered figure after leaving). `FigureLineageExplorer`/`LineageExplorerWindow` keep the `FigureCardView` popover.

**Design decisions:**
- Popover-on-hover (not inline thumbnails) keeps every list/card/prose layout pixel-identical — zero crowding, and popover is native macOS with automatic placement.
- The `.onHover` forward hook keeps the group-member "linked entity" accent highlight working on top of the mugshot popover — the two hover behaviors compose instead of the modifier shadowing the row's own `onHover`.
- Inline links pop only for figure mentions with a mugshot — place/event mentions and figures without portraits stay plain text (no empty popovers, no hover noise while scanning prose).

**Verify:** `swift build` clean; 185 tests pass. Manual: hover a figure row in the sidebar / SKL / group members / lineage card / an in-prose figure mention → circular mugshot appears near it; figures without mugshots show nothing on hover.

**Relevant new/removed files:**
- `Sources/Me/Views/MugshotHover.swift` — Added

**Relevant files:**
- `Sources/Me/Views/FigureCardView.swift`, `FigureListView.swift`, `SumerianKingListView.swift`, `EntityGroupCollectionView.swift`, `LinkifiedDescription.swift`, `MugshotSheet.swift` — Updated

### 2026-08-13 — Text block summary + expand (scannable story pages)

**Context:** Group text blocks render full prose, which is heavy to scan when a group page holds many blocks. The user wanted an optional *summary* shown by default with a "Show full text…" toggle beneath it revealing the full block inline. Implemented per the TODO item (proposed 2026-08-12).

**Changes made:**
- `Sources/MeCore/Models/GroupTextBlock.swift` — Added `summary: String?` + `summaryRichText: Data?` (both optional, migration-safe; init params with `nil` defaults). Nil or empty summary keeps the existing always-full-text behavior.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `TextBlockRow` now branches on `hasSummary` (non-empty plain summary): when present it renders the summary (primary foreground, via `RichTextDisplay`) with a "Show full text…"/"Hide full text" caption button (per-row `@State showFullText`) revealing the full prose below; the toggle uses `withAnimation`. Summary and full text both honor alignment/max-width framing. No summary → current full-text rendering unchanged.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `GroupTextBlockSheet` gained a "Summary" editor (`RichTextEditorSection` bound to `summaryRichText`/`summary` state) above the "Full text" editor; save writes both fields. Sheet enlarged 520×420 → 560×620 to fit the two editors. Shared by the collection view and the group manager (`FigureGroupListView`), so both get the summary field.
- `Tests/MeCoreTests/MeCoreTests.swift` — `testGroupTextBlockSummaryRoundTrip` (persist + fetch round-trip, nil-rich default, plain block defaults nil). 180 tests pass.

**Key design decisions:**
- Empty-string summary counts as "no summary" — clearing the field restores the full-text fallback exactly.
- Per-row `@State` matches the TODO ("simple `@State` per row"); expansion state is not persisted (the stretch goal).
- Summary renders in `.primary` (it's the scannable entry point), full text stays `.secondary` — same hierarchy as a heading vs body.
- No auto-suggest from full text (stretch goal, deliberately deferred).

**Relevant files:**
- `Sources/MeCore/Models/GroupTextBlock.swift` — Updated
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Updated
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated

### 2026-08-13 — Inline-link breadcrumbs: reading context, not target

**Problem:** Clicking an inline entity link (e.g. "Ninurta" in an Atrahasis text block on a group page) called `navigateToFigure/Place/Event` with the default `recordHistory: true`, pushing a breadcrumb named after the *target*. That crumb is a no-op (the sidebar is already on the target), so the trail couldn't return the user to where they were reading — the group page / text block.

**Fix:** Reading-context breadcrumb, mirroring the collection view's existing "Open in Sidebar" pattern (push the group crumb, then navigate with `recordHistory: false`):
- `Sources/Me/Views/LinkifiedDescription.swift` — New `InlineLinkGroupContext` (`groupID`/`groupName`) + `inlineLinkGroupContext` environment key. `InlineEntityLink.navigateInSidebar` now pushes a crumb for the reading group page (`.figureGroups` item), then navigates to the target with `recordHistory: false`.
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Sets `.environment(\.inlineLinkGroupContext, …)` for its `group` so all links rendered on the page (header description, text blocks, expanded-subgroup prose, and the inline detail panel's bios) get the reading-context crumb.

**Design decisions:**
- The context is the *currently displayed page* (`EntityGroupCollectionView.group`), so links in an inline-expanded subgroup's text blocks push the top-level page (correct — that's where the user is reading), while a subgroup opened as its own page pushes that subgroup.
- `pushHistory`'s last-entry dedupe keeps repeated link clicks from stacking duplicate group crumbs.
- Separate-window contexts (quicklook/timeline/report, no `navigationCoordinator`) are unchanged — they still open the `entity-report` window.

**Verify:** `swift build` clean; 180 tests pass. Manual: on a group page, click an inline link → sidebar jumps to the target and the trail shows the group page; clicking it returns to where you were reading.

**Relevant files:**
- `Sources/Me/Views/LinkifiedDescription.swift` — Updated
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Updated
- `TODO.md` — Item marked done

### 2026-08-13 — Inline links preview in the group panel (no sidebar nav, no breadcrumbs)

**Context:** The breadcrumb fix (below) made sense while links left the page, but on a group page the user pointed out the "back link is not correct" — and reasoned that since the follow-up content renders in the sidebar detail panel while the main window stays put, there is *no navigation at all*, so breadcrumbs are factually unnecessary. The sidebar switch + reading-context crumb was replaced with an in-place preview.

**Changes made:**
- `Sources/Me/Views/LinkifiedDescription.swift` — `InlineLinkGroupContext` gained `onOpenEntity: (EntityKind, PersistentIdentifier) -> Void`. `InlineEntityLink.navigateInSidebar` now calls it (instead of `navigateToFigure/Place/Event`) when a group context exists. Non-group sidebar contexts keep the original navigate-with-recordHistory:true behavior; separate windows still open `entity-report`.
- `Sources/Me/Views/EntityGroupCollectionView.swift`:
  - `@State selectedMemberID: PersistentIdentifier?` → `@State detailItem: GroupMemberItem?` (holds the actual entity reference, so the panel can show *any* type, not just the group's own entity type).
  - Removed `selectedFigure/selectedPlace/selectedEvent/selectedThing` fetch-helpers; added `openLinkedEntity(kind:id:)` (fetch by `PersistentIdentifier`, set `detailItem`), `deferSelect` resolves any figure/place/event/thing id, and file-scope `memberItem(from: MixedItem) -> GroupMemberItem?` converts row items.
  - `.environment(\.inlineLinkGroupContext, …)` now passes the `onOpenEntity` handler (captures `self`; only touches `@State`/`@Environment`).
  - `detailPanel` renders whichever entity type `detailItem` is (FigureDetailView / PlaceDetailView / EventDetailView / ThingDetailView); the toolbar's Edit/Delete buttons are only shown when `isMember(item)` (the entity is an actual member of the group) — so a link-previewed cross-type entity can be edited but not deleted from this panel.

**Design decisions:**
- Follow-up content shown in the group's right-hand panel, main content unchanged → no breadcrumb needed because the user never left. Deliberate "Open in Sidebar" context-menu affordance still exists for when the user *wants* to leave the page.
- Delete is gated on group membership to keep the preview a read-mostly surface; edit stays available for any previewed entity.
- Cross-type links now work for the first time (a figure mention inside a place group previews the FigureDetailView).

**Verify:** `swift build` clean; 180 tests pass. Manual: on a group page, click an inline link → the right panel shows that entity's detail, the group page does not change, no breadcrumb appears; close the panel to resume reading.

**Relevant files:**
- `Sources/Me/Views/LinkifiedDescription.swift` — Updated
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Updated
- `TODO.md` — Item rewritten

### 2026-08-13 — Mugshots: designated portrait per figure (prototype)

**Context:** The user's long-standing idea — most Mesopotamian figures have no portrait, but plenty of statue photos online are croppable to a mugshot; not every figure needs one. Agreed design: the mugshot is a *derived crop of an existing image*, plus a record of *how the statue was identified* (since most Mesopotamian statues are anonymous). Prototyped end-to-end.

**Changes made:**
- `Sources/MeCore/Models/Figure.swift` — `mugshotImage: ImageAsset?` (`@Relationship(deleteRule: .nullify, inverse: \ImageAsset.mugshots)`), `mugshotCropRect: String?` (normalized `"x,y,w,h"`), `mugshotIdentification: String?` (tier: `inscribed` / `conventional` / `hypothetical` / `unknown`). All optional → lightweight migration.
- `Sources/MeCore/Models/FigureImage.swift` — new inverse array `ImageAsset.mugshots: [Figure]`.
- `Sources/MeCore/Models/ImageCropRect.swift` — NEW normalized-crop value type with `encoded()`/`init?(encoded:)`/clamping (`package`, unit-tested). The crop is metadata — the statue photo stays whole, the mugshot is rendered by cropping on the fly.
- `Sources/Me/Views/MugshotView.swift` — NEW. `MugshotImageLoader` (CGImageSource thumbnail + `cgImage.cropping(to:)`, bounded pixel size; plus an in-memory `crop(_:cropRect:)` for live previews) and `MugshotView` (circular masked crop, falls back to the type-icon `FigureIconCircle`, reloads on image/crop change).
- `Sources/Me/Views/MugshotSheet.swift` — NEW. Set/edit/remove: choose from the figure's linked images or import a new one (fileImporter → Images dir, appended to `figure.images`), a `MugshotCropEditor` (drag-to-position + corner-handle resize of a circular crop over the statue, dimmed outside with eoFill path), live circular preview, identification-tier picker, source/attribution text field (writes into the image's `source` if empty).
- `Sources/Me/Views/FigureDetailView.swift` — header portrait replaced with a `MugshotView` + pencil-overlay button opening the sheet; `.sheet(isPresented: $showMugshotSheet)`.
- `Sources/Me/Views/FigureDetailInfoView.swift` — shared `FigureHeaderView` (covers dossiers + quicklooks) now renders the mugshot.
- `Tests/MeCoreTests/MeCoreTests.swift` — 5 new tests (crop full/round-trip/clamp, mugshot fields round-trip incl. inverse, nullify on image delete). 185 pass.

**Design decisions:**
- **Save the crop, not a cropped file** — normalized rect metadata on the figure; the original statue photo is never duplicated, so attribution context and zoom-in stay intact, and re-cropping is a one-string edit.
- **Identification tier is a first-class value** — Mesopotamian statuary is mostly anonymous; `inscribed` (Gudea's named statues) vs `conventional` (Hammurabi stele) vs `hypothetical` (museum-label guess) vs `unknown` is the scholarly honesty the domain needs. Shown as a tooltip on the mugshot.
- Relationship set via the annotated side: `figure.mugshotImage = image` (the `@Relationship(inverse:)` lives on `Figure.mugshotImage`).
- `ImageCropRect` lives in MeCore so encode/decode/clamp are unit-testable without AppKit.

**Known follow-ups (in TODO.md):** mugshot in list rows (`MemberRow`) / `FigureCardView` / `SumerianKingListView`; `sourceURL` + license on `ImageAsset`; Wikimedia Commons fetch via `WikiClient`; "set as mugshot" affordance in `FigureImageGallery`.

**Verify:** `swift build` clean; 185 tests pass. Manual: figure detail → tap portrait (or pencil overlay) → Mugshot sheet → pick/import a statue photo → drag/resize the crop circle → pick identification tier → Set Mugshot; header shows the circular crop; Remove Mugshot clears it.

**Relevant new/removed files:**
- `Sources/MeCore/Models/ImageCropRect.swift` — Added
- `Sources/Me/Views/MugshotView.swift` — Added
- `Sources/Me/Views/MugshotSheet.swift` — Added

**Relevant files:**
- `Sources/MeCore/Models/Figure.swift`, `Sources/MeCore/Models/FigureImage.swift` — Updated
- `Sources/Me/Views/FigureDetailView.swift`, `Sources/Me/Views/FigureDetailInfoView.swift` — Updated
- `Tests/MeCoreTests/MeCoreTests.swift` — Updated
- `TODO.md` — Item added (marked done with follow-ups)

### 2026-08-12 — Group wizard: alias not persisted on remove-then-re-add

**Problem:** User added Ninhursag to an Atrahasis group member list and wanted the membership to display "Ninhursag as Mami" (Mami = her AlternateName). The association's `displayName` stayed empty even after remove-then-re-add in the group wizard. All memberships created outside the wizard (Bulk Add / Sync / the figure's Groups popover) never set a display name.

**Root cause:** `FigureGroupFormView.syncMembers` computed `toAdd = newIDs.subtracting(existingIDs)` against the **pre-removal** `group.figureAssociations`. Remove-then-re-add in one wizard session left the member id in `existingIDs`, so the association was neither deleted nor recreated — the retained association silently kept its stale empty `displayName`, and the `"Mami"` value in `selectedMemberAliases` was never written to any model.

**Fix:** `syncMembers` now also writes `assoc.displayName` from `newAliases` for **retained** existing members (those whose id is in `newIDs`), before computing `toAdd`. Alias capture is no longer add-only: re-toggling an existing member with a matching search term updates the membership alias in place.

**Notes:**
- The wizard toggle still treats clicking an already-checked member as a *removal* — a single accidental click on an existing member deletes the membership on Save. Unchanged (removal semantics preserved); user should uncheck then re-check.
- Verified the user's data via sqlite: "Mami" AlternateName present on Ninhursag; `ZFIGUREGROUPASSOCIATION.ZDISPLAYNAME` empty (the Ziusudra→"Noah" row was the only populated alias in the DB).

**Tests:** 175 pass; `swift build` clean. No new tests (the fixed logic lives in a SwiftUI view, not MeCore).

**Relevant files:**
- `Sources/Me/Views/FigureGroupFormView.swift` — Updated (`syncMembers` writes aliases to retained members)

### 2026-08-12 — Alternate names sorted alphabetically in display views

**Problem:** The "Also Known As" lists rendered `figure.alternateNames` in SwiftData insertion/arrival order (the relationship array preserves insertion order), so names like Ki, Nintu, Hathor, Ninmah, Mami appeared in the order they were added rather than alphabetically. The dedicated `AlternateNameListView` manager already sorted (`filteredNames.sorted { $0.name < $1.name }`), but the three figure-side display sites did not.

**Changes made:**
- `Sources/MeCore/Models/Figure.swift` — Added `sortedAlternateNames` computed property (case-insensitive sort by name; stored array untouched).
- `Sources/Me/Views/FigureDetailView.swift` — `filteredAlternateNames` now sorts (both the empty-filter and filtered paths).
- `Sources/Me/Views/FigureQuicklookView.swift` — "Also Known As" section uses `figure.sortedAlternateNames`.
- `Sources/Me/Views/QueryView.swift` — FigureDossier "Also known as" uses `dossier.figure.sortedAlternateNames`.
- `Tests/MeCoreTests/MeCoreTests.swift` — `testSortedAlternateNamesAlphabetical` (insertion order ≠ alphabetical; asserts case-insensitive result). 176 tests pass.

**Relevant files:**
- `Sources/MeCore/Models/Figure.swift`, `Sources/Me/Views/FigureDetailView.swift`, `Sources/Me/Views/FigureQuicklookView.swift`, `Sources/Me/Views/QueryView.swift`, `Tests/MeCoreTests/MeCoreTests.swift`

### 2026-08-12 — Auto-linked entity mentions in descriptions

**Context:** Reading a figure's bio (e.g. Ninhursag's, which references the Atrahasis epic) the prose was "dead text" — mentions like Enki, Mami, Atrahasis weren't navigable. User chose: inline prose auto-links (word-boundary, in-text), opening the entity dossier window (EntityLink's `entity-report` window).

**Changes made:**
- `Sources/Me/Views/LinkifiedDescription.swift` — NEW. Three pieces:
  - `LinkedDescription` — drop-in container: RTF `RichTextDisplay` when `richData` present, else `LinkifiedTextView` for plain text.
  - `LinkifiedTextView`/`LinkifiedParagraph` — builds a vocabulary from `fetchAll()` of figures/places/events **plus their AlternateNames** (so "Mami" links to Ninhursag); matches whole words case-insensitively with a longest-first regex alternation; renders plain text as word tokens and matches as `InlineEntityLink` buttons; splits paragraphs on `\n`; falls back to plain `Text` when a paragraph has no matches. Skips stopwords/common nouns (`an`, `as`, `king`, `goddess`, …) and names < 2 chars.
  - `WrappingTextFlow` — custom `Layout` that wraps children like wrapped prose lines (needed because Button spans can't live inside a single SwiftUI `Text`).
  - `InlineEntityLink` — plain-style Button, accent + underline-on-hover, pointing hand, opens `entity-report` window.
- Wired `RichTextDisplay` → `LinkedDescription` at the bio sites: `FigureDetailView`, `FigureDescriptionView` (covers `FigureQuicklookView` + QueryView figure dossier), `PlaceDetailView`, `EventDetailView`, `ThingListView` (thing detail), `QueryView` place/event/thing dossiers, `TimelinePostView`. Left untouched: `EraDetailView` (uses `.lineLimit(6)` — incompatible with the wrapping layout), group descriptions, text blocks, sticky notes.

**Design decisions:**
- Navigation via `EntityReportRequest` window (like `EntityLink`) — no sidebar-coordinator plumbing, works in every context. The "History" sidebar section is a UI grouping, not an entity, so it can't be a link target.
- Longest-first alternation so a multi-word event name ("Gilgamesh Builds the Walls of Uruk") wins over its parts; `\b` boundaries keep "Enki." linking only "Enki".
- Plain paragraphs with no matches render as normal `Text` (full SwiftUI fidelity); only paragraphs with matches use the wrapping layout.

**Verify:** `swift build` clean; 176 tests pass (existing suite; matching logic validated by scratch script, see below). Manual: Ninhursag bio → "Enki"/"Mami"/"Atrahasis" underlined on hover, click opens dossier.

**Relevant new/removed files:**
- `Sources/Me/Views/LinkifiedDescription.swift` — Added

**Relevant files:**
- `Sources/Me/Views/FigureDetailView.swift`, `FigureDetailInfoView.swift`, `PlaceDetailView.swift`, `EventDetailView.swift`, `ThingListView.swift`, `QueryView.swift`, `TimelinePostView.swift` — Updated

### 2026-08-12 — Inline entity links navigate the sidebar (breadcrumb back-track)

**Motivation:** The auto-linked prose opened an `entity-report` window. That's nice for background windows but the dossier can look messy, and the user wanted a back-track affordance. Since `NavigationCoordinator` already has `navigateToFigure/Place/Event(id:name:)` (which push a breadcrumb + switch sidebar selection), the links can reuse it.

**Changes made:**
- `Sources/Me/Views/NavigationCoordinator.swift` — Added `NavigationCoordinatorKey` (EnvironmentKey) + `EnvironmentValues.navigationCoordinator: NavigationCoordinator?` (default nil).
- `Sources/Me/Views/ContentView.swift` — `.environment(\.navigationCoordinator, coordinator)` on the `NavigationSplitView`.
- `Sources/Me/Views/LinkifiedDescription.swift`:
  - `MentionCandidate` gained `targetID: PersistentIdentifier` (captured from the figure/place/event — alternate names point at their owner's ID).
  - `Run.link` now carries the matching `candidate` alongside the `EntityReportRequest`.
  - `InlineEntityLink` reads `@Environment(\.navigationCoordinator)`; when present it calls `coordinator.navigateTo<Kind>(candidate.targetID, name: candidate.targetName)` — the sidebar list switches to that entity and the breadcrumb trail lets the user walk back. When absent (separate windows: quicklook/timeline/report), it falls back to `openWindow(id: "entity-report")`.

**Design decisions:**
- Optional environment, not a parameter: the links are rendered by deep leaf views reachable from many windows and only the main window owns a coordinator. Environment propagates it exactly where it exists, and `nil` elsewhere keeps the old separate-window behavior automatically.
- Alternate-name links (e.g. "Mami" → Ninhursag) navigate to the canonical entity and use its real name as the breadcrumb label.
- No communication change in the separate-window contexts — they were already using `EntityReportRequest`, which still works.

**Verify:** `swift build` clean; 176 tests pass. Manual: in a sidebar figure bio, click an inline entity name → sidebar jumps to that figure with a breadcrumb; click another → second breadcrumb; click the trail to go back. Same links inside a quicklook/timeline/report window still open the separate report window.

**Relevant files:**
- `Sources/Me/Views/NavigationCoordinator.swift` — Updated
- `Sources/Me/Views/ContentView.swift` — Updated
- `Sources/Me/Views/LinkifiedDescription.swift` — Updated

### 2026-08-12 — Auto-linked text in group pages

**Context:** Following the entity-bio auto-linking work, the user wanted the same inline entity highlighting in the other free-text snippets — specifically the text blocks and descriptions that live inside figure/entity group pages.

**Changes made:**
- `Sources/Me/Views/EntityGroupCollectionView.swift` — `TextBlockRow` and `GroupDescriptionDisplay` now render `LinkedDescription` instead of `RichTextDisplay` (same `text`/`richData`/`stripForegroundColor` API). Max-width + alignment framing unchanged.
- `Sources/Me/Views/FigureGroupListView.swift` — Group-manager description row also uses `LinkedDescription`.

**Design decisions:**
- No new code: `LinkedDescription` is already a drop-in for `RichTextDisplay`, and since group pages render inside the main window, the `navigationCoordinator` environment value is present — so these links get sidebar navigation + breadcrumbs automatically, with the separate-window fallback only where no coordinator exists.
- `EraDetailView` figure bio still uses `RichTextDisplay` (deliberately — `.lineLimit(6)` conflicts with the wrapping layout; see 2026-08-12 auto-link entry).

**Verify:** `swift build` clean; 176 tests pass.

**Relevant files:**
- `Sources/Me/Views/EntityGroupCollectionView.swift` — Updated
- `Sources/Me/Views/FigureGroupListView.swift` — Updated

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

### 2026-07-22 — Fix post-flood era bars: avoid conditional views and .opacity() inside ZStack

**Problem:** Colored era background bars (`eraBar`) in the post-flood timeline were invisible. Debug diagnostics confirmed `hasValidDates=true` and correct coordinate computation. The bars rendered correctly only when placed unconditionally in the ZStack without `.opacity()` or `if`/`if let` wrapping.

**Root cause:** SwiftUI conditional views (`if`, `if let`) and the `.opacity()` modifier applied to views with `.position()` inside a `ZStack` wrapped in `AnyView` rendered at zero visual presence. The views existed in the tree but were not visible, even with `.opacity(1)` and `hasValidDates=true`. This appears to be a SwiftUI bug specific to local-scope computed properties used in `.opacity()` or conditional blocks within this view hierarchy.

**Fix:** Compute coordinates at function level (outside the ZStack). Always render `eraBar` and life bars unconditionally — no `if`, no `if let`, no `.opacity()`. Each figure's per-element `if let` inside `ForEach` is safe since it operates on individual data, not the entire rendering block.

**Lesson:** Never use `.opacity()` with local computed Bool variables or `if` conditionals on entire sub-views when using `.position()` inside a `ZStack` + `AnyView` combo. Always render views unconditionally and let per-element checks control visibility.

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

### 2026-07-18 — Fix lineage line coordinate mismatch

**Problem:** Lines drawn by `Canvas` appeared at wrong positions relative to figure cards. The `GeometryReader` in `FigureCardView` reported frames via `.frame(in: .named(coordinateSpace))`, but the named coordinate space was applied to the view *after* `.padding(40)`, while the `Canvas` drew relative to the ZStack's own top-left (inside the padding). This caused a 40pt offset — the GeometryReader coordinates included the padding offset, but the Canvas drawing did not.

**Root cause:** `.coordinateSpace(name: "tree")` was applied to the ScrollView's content (after `.padding(40)`), so the named space origin was 40pt away from the ZStack's origin. The Canvas draws at (0,0) relative to its own bounds (the ZStack), but `geo.frame(in: .named("tree"))` reported coordinates relative to the padded view's top-left.

**Partial fix:** Moved `.coordinateSpace(name:)` from the ScrollView content (after padding) to the ZStack returned by `lineageContent`. Both the Canvas and the GeometryReader are children of this ZStack, so they now share the exact same coordinate origin. This fixed the initial static rendering — lines now appear at correct positions on first load.

**Known remaining issue:** Lines are still visually wrong when clicking figures to recenter. The `nodePositions` dictionary accumulates stale entries from previous renders, and the Canvas `.id(nodePositions.count)` key doesn't invalidate correctly when positions change (only when count changes, not when values update). Lines become a "utter mess" after a few clicks.

**Relevant files:**
- `Sources/Me/Views/LineageTreeView.swift` — moved `.coordinateSpace` to ZStack inside `lineageContent(for:)`
- `Sources/Me/Views/FigureLineageExplorer.swift` — same fix
- `Sources/Me/Views/LineageExplorerWindow.swift` — same fix

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

### 2026-06-23 — Enoch Archangels backfill

**Problem:** Archangels section missing in EnochView for existing databases. `ensureTypesExist` gates FigureType creation on `figureTypeCount == 0`, so types added later (Archangel, Igigi, Commander) are never backfilled. `ensureEnochDataExists` early-returns if Mount Hermon exists, preventing any archangel creation.

**Fix:** Added `Migration.ensureArchangelsExist(context:)` — creates the Archangel FigureType if missing (same pattern as `ensureCommanderFigureTypeExists`), then creates the 7 archangel figures (Michael, Gabriel, Uriel, Raphael, Raguel, Saraqael, Remiel) by name if absent. Called at the top of `ensureEnochDataExists` before the Mount Hermon guard, so it runs on every launch.

**Lesson:** Any entity or type added to `seed_data.json` after the first public build needs a `Migration.swift` backfill for existing databases. Never rely solely on the fresh-seed path.

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
