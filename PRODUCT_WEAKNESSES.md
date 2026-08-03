# Product-Level Weaknesses & Strategy Critique (Anunnaki/Me)

This is a critique of **Me as a product** — what makes it weak, hard to grow, or risky for a single maintainer. It complements `ARCHITECTURAL_WEAKNESSES_CRITIQUE.md` (code-level debt). Unlike the code critique, these are about the value proposition, the data, and the path from a personal tool to something that justifies continued investment.

**Context that anchors this critique:** Me is a *personal hobby project* — no commercial goals, not for sale. Its origin is the developer's long fascination with the Anunnaki/Sumerian civilization combined with bewilderment at the sheer volume of figures and places involved, and the absence of any tool to organize that material and make it more accessible. A secondary motive is staying connected to AI/LLM tooling. That means "niche audience" is not a risk to be mitigated and there is no growth target — the weaknesses below are about *personal* usefulness, durability, and the AI-facing surface, not market viability.

Baseline for this review (2026-08-03): 207 figures, 46 places, 67 events, 30 eras, 14 sources, 114 relationships in seed data. ~90 views. No external dependencies. Single-user macOS app.

---

## 1. The cold-start problem (data volume)

**The app's value is proportional to its data, but the data starts near zero and grows by manual entry.**

- Seed data covers ~207 figures — a solid core (28 deities + 134 SKL kings), but Mesopotamian mythology is thousands of named figures, places, texts, and events deep. The database must be populated before the app is useful for real research, not just browsing.
- Every new entity is currently a multi-field form (FigureFormView is a 3-step wizard). Even with Add-from-Text, the ceiling on "figures added per sitting" is low because the parser is single-entity-centric.
- **Progress so far (this is the good news):** the Wikipedia import, Wikidata import, and Add-from-Text parser are all deliberate countermeasures. Add-from-Text alone collapses "create figure + 3 relationships + 1 place link" into one paste.

**Remaining gaps:**
- No bulk ingestion from a prepared file (CSV/JSON of many entities at once). The parser reads prose but not spreadsheets.
- No web search→paste flow inside the app (you still paste from a browser manually).
- No mechanism to *discover* what's missing (no "gaps report": which deities/places/events are referenced but not yet in the DB).

---

## 2. Single-user, single-machine data is trapped

**The knowledge base lives in one SQLite store on one Mac, with no path out.**

- No export to a portable format (the backup is a raw store snapshot — recoverable only by Me itself).
- No import of another researcher's data; no sharing; no collaboration. For a mythology research tool, being unable to exchange data sets is a real ceiling.
- If the user moves to a new machine, they must copy the store file manually (backup/restore exists, but it's file-based, not sync).

**Mitigations that exist:** store-level backup/restore (2026-08-02). That protects against loss, not against sharing or portability.

**Options (not started):**
- JSON/CSV export of entities + relationships (lossless codec is hard — 30+ models — but a lossy read-oriented export for archiving is cheap).
- iCloud/CloudKit sync so the DB survives machine transitions.

---

## 3. Contradictory traditions are not modeled as first-class

**Mesopotamia's power is that it preserves multiple, often contradictory traditions (Enuma Elish vs Atra-Hasis vs the SKL). Me currently merges them into one flat web.**

- `Relationship.source` is free text; lineage views render all relationships as if they were one coherent genealogy. The "Lineage source discriminator" TODO has been open since 2026-06-22.
- Contradictions (X is father of Y in one text, Z is father of Y in another) can't be surfaced — a user can't ask "what does the Atra-Hasis tradition say about X's parentage?"
- This is arguably the app's *most distinctive* potential feature (no other tool treats mythological contradictions as data) — and currently its weakest spot.

**Progress so far:** parental couples (`groupID`) collapse per-text variants into alternatives, and the `isPreferred` flag picks a default. But source discrimination is still absent.

---

## 4. Curation and verification burden falls entirely on one person

**Every claim is hand-entered and never re-verified.**

- No provenance workflow: the ContentAttribution model (2026-07-30) tracks *which source backs which property*, which is great — but it's opt-in and manual; most fields have no attribution.
- No validation: nothing checks that a citation points at a real Source, or that two figures with the same name are actually the same entity.
- The "never reseed" hard constraint (correctly, for data safety) means data corrections are one-way patches; there's no diff/audit of what's changing.

---

## 5. Niche-audience risk (neutral, not a threat)

**Sumerian/Mesopotamian mythology knowledge management is a narrow domain — but this project is explicitly personal and non-commercial.**

- The number of people who (a) care about structured Mesopotamian mythology, (b) are technical enough to run a SwiftPM app, and (c) want desktop-only local storage is very small.
- Because there is no goal to sell or grow an audience, this is not a risk to manage. It does, however, determine the strategy: no ecosystem, no contributors, no external pressure on data accuracy, and full maintenance cost falls on one person.
- **The real consequence of niche = personal is a *stance*: make it maximally useful to the developer.** That makes data-entry speed the #1 lever, and makes the AI/LLM-facing surface (natural language querying, Add-from-Text, import) a first-class feature rather than a garnish.

---

## 6. No feedback loop on data quality or usage

- No telemetry or usage tracking (good for privacy, but the maintainer can't see what's actually used vs ignored).
- No way to know if the natural-language QueryEngine is answering real questions or silently missing them (`noMatch` results aren't collected).
- No error/blank-state analytics in the 90+ views.

---

## Suggested priorities (if continued)

1. **Data-entry speed** (attacks #1 + #4): bulk paste of many entities, multi-figure Add-from-Text, missing-entity gap detection. This is the highest-leverage work — every other weakness is downstream of having more data. It is also what makes the app a *daily-driver organizer* for one person, which is the whole point.
2. **Source-discriminated lineage** (attacks #3): turn `Relationship.source` into a real Source relationship and add a source filter to lineage views. This is the app's distinctive feature and it's dormant.
3. **Export/portability** (attacks #2): at minimum a read-oriented JSON export; ideally CloudKit sync later.
4. **Attribution nudging** (attacks #4): make ContentAttribution cheap to fill (auto-attach source when importing/parsing).

---

## Rejected / de-prioritized deliberately

- **Expanding beyond mythology** — the domain focus is the app's identity; and since there is no commercial/audience goal, there is no reason to broaden scope.
- **Telemetry** — privacy posture is a feature for this audience.
- **Cross-platform** — SwiftUI/SwiftData lock-in makes this a macOS app; the cost isn't justified for a personal tool.
- **Multi-user collaboration server** — way beyond scope; portability is the attainable subset.
- **Monetization / distribution** — not a goal (see context above).
