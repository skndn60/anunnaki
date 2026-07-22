# Agent Import Review Queue

## Goal
Convert raw agent-collected Wikipedia/Wikidata data into curated database entities through a human-in-the-loop review process.

## Data Sources (per datum)
- **Wikipedia article text** (`extract`) — free-text description
- **Wikidata QID** (`wikidataId`, optional) — structured typed properties
- **Categories list** (`categories`, optional) — heuristic type hints

## Extraction Strategy

### With Wikidata QID (high confidence)
Fetch `wikidata.org/wiki/Special:EntityData/{QID}.json` → map typed properties to schema fields:

| Wikidata Property | Schema Field |
|---|---|
| P31 (instance of) | entity type hint |
| P21 (sex/gender) | Figure.gender |
| P22 (father) | Relationship (Father) |
| P25 (mother) | Relationship (Mother) |
| P26 (spouse) | Relationship (Spouse) |
| P40 (child) | Relationship (Child) |
| P27 (country) | Place hint |
| P106 (occupation) | domain hint |
| P18 (image) | FigureImage hint |

No external packages — plain `URLSession` fetch of `entityData.json`.

### Without QID (medium/low confidence)
- Parse categories for type hints: "Mesopotamian deities" → Figure, "Sumerian cities" → Place, etc.
- Fallback: user manually fills all fields.

## UI: Review Queue Tab (in Mission Control)

```
┌──────────────────────────────────────────┐
│  Mission Control                          │
│  ┌──────────┬────────────┬──────────────┐ │
│  │ Agents   │ Review     │ Blind Spots  │ │  ← tabs
│  ├──────────┴────────────┴──────────────┤ │
│  │ Pending datums (filter: All/Figure/   │ │
│  │ Place/Event, search by title)         │ │
│  │                                       │ │
│  │ ┌────────────┬──────────────────────┐ │ │
│  │ │ list       │ Proposal card        │ │ │
│  │ │            │                      │ │ │
│  │ │ • Enlil    │ Title: Enlil         │ │ │
│  │ │ • Nippur   │ Type: Figure ▾       │ │ │
│  │ │ • Gilg. epic│ Dom: wind/air       │ │ │
│  │ │            │ Gen: male            │ │ │
│  │ │            │ Desc: [prefilled]    │ │ │
│  │ │            │                      │ │ │
│  │ │            │ [Approve] [Edit] [Rej]│ │ │
│  │ └────────────┴──────────────────────┘ │ │
│  └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

### Proposal Card
- **Suggestion header**: icon + "Figure: Enlil" with confidence badge (🟢 high / 🟡 medium / 🔴 low)
- **Pre-filled fields**: name, description, type picker, gender picker, domain text field
- **Source info**: Wikipedia link, acquired date, agent name
- **Actions**: Approve (insert as-is), Edit & Approve (opens FigureFormView/etc. pre-filled), Reject (discard datum)

### Post-approval
- Entity created in main store with `source = "agent: {agentName}"`
- `CollectedDatum` marked `isImported = true` (new field or separate processed flag)
- Non-destructive — approved datums are not deleted, only flagged

## Implementation Phases

### Phase 1 (smallest buildable piece)
- New "Review" tab in MissionControlView (segmented picker: Agents / Review / Blind Spots)
- Proposal card with hardcoded fields (name, description, type, gender)
- Approve creates Figure with those fields
- Edit opens FigureFormView pre-filled
- Reject deletes the datum
- No Wikidata parsing yet

### Phase 2
- Wikidata entity fetch on datum with QID
- Auto-map properties to proposal fields
- Type hinting from categories

### Phase 3
- Batch operations (approve all / reject all visible)
- Sorting and filtering by agent, type, date
- Undo (recently approved)
