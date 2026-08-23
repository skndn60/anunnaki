# Anunnaki — Session Log

Chronological record of working sessions: context, changes made, key decisions, verification, files touched. **Newest first — append new entries at the top.**

AGENTS.md holds only durable reference material. When a lesson from an entry proves recurring, promote it into AGENTS.md's Coding Conventions instead of relying on this history being re-read.

Entries below were moved verbatim from AGENTS.md on 2026-08-22 (same pattern as the 2026-08-05 TODO split). Path references inside entries are historical and were intentionally left as written.

---

### 2026-08-23 — First real scan triaged; repairs + period eras prepped

**Context:** The user ran Data Integrity on their live DB (~30 findings). Triage against a read-only copy (`/var/folders/.../T/opencode/triage.store`) confirmed: 4 genuine role-gender edges (two "Mother" edges hanging on the male Uras PK 52 — tradition gives Ninsun/Ninisina the goddess Uraš as mother; Rachujal ♀ typed Father of Rashujal ♂, plus a bogus self-Mother edge), 3 event-era labels with no matching Era entity (Old Assyrian / Old Babylonian / Neo-Assyrian Periods), 3 stubs (`Enbi-Ishtar`, `Lamech`, `Mesh-ki-ang-Nanna II` — the last likely an accidental duplicate of SKL king Mesh-ki-ang-Nanna), zero ambiguous aliases. SQL can't do word-boundary pronoun checks — the app scan stays authoritative there.

**Changes made:**
- `521d705` — `Migration.ensureConsistentParentRoles(context:)`: (1) re-points Mother→Ninsun/Ninisina edges from the male Uras (matched by normalized name + gender + "Dilbat" title) to his female namesake, only when exactly one exists; (2) re-types Rachujal—Father→Rashujal to Mother. The self-referential Rashujal edge is deliberately untouched — deleting user rows is never automatic. Guard-fires-without-namesake tested.
- Same commit — `Migration.ensureHistoricalPeriodEras(context:)`: check-by-name creation of Old Assyrian (−2000..−1750), Old Babylonian (−1894..−1595), Neo-Assyrian (−911..−609) as Era lanes 31–33. **Critical catch:** `fixEraOrderIndices`'s else-branch bumps unlisted post-flood eras by +1 *every launch* (infinite drift), so all three names are registered in its map too. Wired both migrations into ContentView after `ensureEverydayLifeEpisodes`. 5 new tests.

**Key decisions:** Repairs are surgical (exact name+gender+title conditions), never blind re-pointing; content stubs are left to the user (Lamech might be Enoch-tradition Lamech — authoring that description is a curation call); duplicate merging stays in the DuplicateMerger UI.

**Verify:** build clean; **322/322 tests pass** (+5). On next launch: Uras/Rachujal edges repaired, three period eras appear as timeline lanes, era-reference findings clear; remaining manual items: delete the Rashujal self-edge, resolve Mesh-ki-ang-Nanna II duplicate, enrich two stubs.

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
