# Timeline — Improvement Plan

## Completed

- [x] **#4 — Swimlane layout with BCE-scaled axis**
  Eras are stacked vertically as swimlanes (rows). "Deep Time" eras (no meaningful BCE dates) use a horizontally scrollable chip layout. "Historical" eras (from ~-2900 BCE onward) share a proportional BCE axis at 4pt/year with decade/century ruler ticks. Figures are positioned at their birth-year x-coordinate.

- [x] **Deep time vs historical split**
  Added a `> -10000` year threshold to prevent mythological date numbers (e.g., -450,000) from distorting the BCE scale and causing figure overlaps.

## To Do

- [ ] **#3 — Lifespan bars for figures with actual BCE dates**
  Replace fixed-width chips with horizontal bars spanning from birth year to death year. Figures without BCE dates remain as chips.

- [ ] **#2 — Event markers on timeline**
  Overlay event icons at their date position within the swimlane. Events have `MythologicalDate` with `era` and `year` fields.

- [ ] **#1 — Clickable chips → figure detail popover/detail**
  Tapping a figure chip opens a popover or navigates to the figure's detail view.

- [ ] **#5 — Mythological/historical mode toggle**
  Segmented control to switch between the existing swimlane view and a dedicated historical BCE-scaled view.

- [ ] **#6 — Figure type filter chips**
  Toggle Primordial / Deity / Semi-Divine / Human visibility.

- [ ] **#7 — Search/filter text field**
  Highlight or filter figure chips by name match.

- [ ] **#8 — Breadcrumb navigation from figure chips**
  Clicking a chip navigates to that figure's detail view, consistent with the app's list-detail pattern.
