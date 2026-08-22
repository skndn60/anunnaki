# Pre-Flood Timeline — Design & Reasoning

Date: 2026-08-20

## The problem

The Pre-Flood timeline (Timeline → Pre-Flood) never mentioned time:

- Chips were laid in horizontal rails sorted by `birthDate.sortValue` — which is
  `Int.min` for every pre-flood figure, so ordering was just insertion order.
- Era lanes were stacked by `orderIndex` (sequential order only), not positioned
  on any time scale; lane widths did not reflect duration.
- Only 3 of the 5 visible eras carried dates (`Age of the First Gods`,
  `Creation of Mankind`, `Antediluvian Period`); `Creation` and
  `Age of the Watchers` had none. Where dates existed they appeared only as a
  tiny tertiary caption under the era title.

So the view was a *catalog grouped by mythological epoch*, not a timeline.

## The data that makes it calculable

The Sumerian King List gives the eight antediluvian kings and their reign
lengths. These are mythological but canonical — we did not invent them and there
is no scholarly reason to adjust them:

| # | King | City | Reign (years) |
|---|------|------|---------------|
| 1 | Alulim | Eridu | 28,800 |
| 2 | Alalngar | Eridu | 36,000 |
| 3 | En-men-lu-ana | Bad-tibira | 43,200 |
| 4 | En-men-gal-ana | Bad-tibira | 28,800 |
| 5 | Dumuzi the Shepherd | Bad-tibira | 36,000 |
| 6 | En-sipad-zid-ana | Larak | 28,800 |
| 7 | En-men-dur-ana | Sippar | 21,000 |
| 8 | Ubara-Tutu | Shuruppak | 18,600 |

Sum: **241,200 years** — matching the canonical SKL total ("eight kings ruled
241,200 years, then the flood swept over").

## The anchor: back-propagate from the flood

The flood is the boundary and the only well-defined point. `The Great Flood`
era is anchored at −28,000 BCE. Back-propagating each reign (each king's reign
ends where the next begins) gives every king a concrete span:

| King | Reign span (BCE) |
|------|------------------|
| Alulim | −269,200 → −240,400 |
| Alalngar | −240,400 → −204,400 |
| En-men-lu-ana | −204,400 → −161,200 |
| En-men-gal-ana | −161,200 → −132,400 |
| Dumuzi the Shepherd | −132,400 → −96,400 |
| En-sipad-zid-ana | −96,400 → −67,600 |
| En-men-dur-ana | −67,600 → −46,600 |
| Ubara-Tutu | −46,600 → −28,000 |

So the **Antediluvian Period = −269,200 → −28,000 BCE** exactly.

> Note: the previous seed value (−241,200 → −28,000) used the 241,200-year total
> as if it were a *year*, not a *duration*. The correct start is the first king's
> first year: −269,200. This is what the migration corrects.

## The era sequence

Reasoning backward from the earliest anchored date (−269,200):

1. **Age of the First Gods** — the primordial generation (Apsu, Tiamat, Anshar,
   Kishar, Nammu, Anunnaki, Igigi). The "first gods" are the pre-creation cosmic
   elements. Band: −450,000 → −300,000.
2. **Creation** — the creation of the cosmos by the primordial gods (the great
   gods are the actors and result of that creation, which is why they sit here
   rather than with the primordial generation). Band: −300,000 → −280,000.
3. **Creation of Mankind** — humans made by the gods; Adapa the first human.
   Band: −280,000 → −275,000.
4. **Age of the Watchers** — the rebel watchers descend to earth (Book of Enoch);
   the archangels belong to this narrative. Band: −275,000 → −269,200.
5. **Antediluvian Period** — the eight kings at the computed dates above,
   + Ziusudra (the flood survivor, last).
6. **The Great Flood** — −28,000 → −27,000 (the pre-flood/post-flood boundary;
   shown at the top of the Post-Flood timeline).

### Date bands for the mythological eras

Only the antediluvian kings have *derived* dates. The bands for
`Age of the First Gods`, `Creation`, `Creation of Mankind`, and
`Age of the Watchers` are **deliberate placeholder spans** — sequential and
non-overlapping so that every band on the pre-flood timeline shows a date, but
they are theological framing, not scholarship. If these ever get real
underpinnings, they should be revised.

## Figure reassignments (user-approved)

The era names and their contents were crossed. Corrected:

- **→ Age of the First Gods**: Kishar, Tiamat, Apsu, Nammu, Anshar, Anunnaki,
  Igigi (moved out of `Creation` — these are the true "first gods").
- **→ Creation**: An, Enlil, Enki, Ninhursag, Nanna, Utu, Inanna, Marduk, Nabu,
  Nergal, Ereshkigal, Ningal, Sarpanit, Sud, Antu, Haia, Ningikuga, Ninurta,
  Ninsun (moved out of `Age of the First Gods` — the great gods of the created
  world). Mushdamma, Ishkur, Uraš were already in `Creation` and stay.
- **→ Age of the Watchers**: Michael, Gabriel, Uriel, Raphael, Raguel, Saraqael,
  Remiel (the archangels, moved out of `Creation` — they belong to the watchers
  narrative).
- **→ Antediluvian Period**: Alulim (previously unassigned to any era — which is
  why he was invisible on the timeline) and Dumuzi the Shepherd (previously
  mis-filed under `Age of the First Gods`; he is one of the eight kings).

## Data problems fixed along the way

- **Alulim had no era** — invisible on the timeline.
- **Dumuzi the Shepherd was misplaced** in `Age of the First Gods` as if he were
  only the shepherd god; he is also the fifth antediluvian king (reign 36,000).
- **Ziusudra was ordered first** (orderIndex 0) within the antediluvian era; he
  is the flood survivor and must come last (orderIndex 8).
- The antediluvian succession order was scrambled; the canonical SKL sequence
  (Alulim → … → Ubara-Tutu, then Ziusudra) is now enforced.

## Implementation

`Migration.ensureAntediluvianChronology(context:)` (Migration.swift) runs on
every launch (ContentView launch sequence, after `ensureComputedSKLDates`). It:

1. **Era date bands** — sets the six pre-flood bands above, but *only* while the
   era still holds the legacy seed values (or is undated). A user who later
   edits an era's dates manually is never clobbered.
2. **King dates** — writes the computed birth/death spans above, *only* where
   `birthDate.startYear` is nil, and marks them `dateSource == .computed`.
   User-entered king dates are never overwritten.
3. **Figure moves** — reassigns figures to their approved eras (updating both the
   `era` link and the `birthDate.era`/`deathDate.era` strings, which is what
   `ensureFigureEraLinks` resolves on the next launch). Each move fires *only*
   while the figure sits in the legacy (wrong) era, so a later user move wins.
4. **Succession order** — sets the antediluvian kings' `orderIndex` to the
   canonical SKL sequence (Alulim 0 … Ubara-Tutu 7, Ziusudra 8).

`fixEraOrderIndices` now numbers the pre-flood eras: Age of the First Gods=0,
Creation=1, Creation of Mankind=2, Age of the Watchers=3, Antediluvian Period=4
(Anunnaki on Earth=5 and Antediluvian=6 remain as empty leftovers, filtered out
because they have no figures). `The Great Flood` stays at 7 so the pre-flood
(`orderIndex < 7`) / post-flood (`orderIndex >= 7`) split is unchanged.

## Principles honored

- **Sacred data**: no reseeding, no deletions; every write is guarded so user
  edits made after the migration take precedence.
- **Idempotent**: a second run is a no-op.
- **Computed vs. invented**: the antediluvian kings are *derived* (sum of reign
  lengths, anchored at the flood); the earlier era bands are *invented
  placeholders* and documented as such above.