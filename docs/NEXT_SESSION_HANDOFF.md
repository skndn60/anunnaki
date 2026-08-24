# Next-session handoff: everyday-life episode import

Approved plan (user said "you can add all the stories"): import 10 well-attested
everyday-life episodes via a new idempotent launch migration
`Migration.ensureEverydayLifeEpisodes(context:)` in `Sources/MeCore/Store/Migration.swift`,
modeled exactly on `ensureOraccDeityImports` (check-by-name skip, get-or-create types,
normalized-name matching so "Ea Nasir" matches "Ea-nasir" — user ALREADY added Ea-nasir
themselves). Wire after `ensureOraccDeityImports` in ContentView.swift (~line 225).
No sticky notes needed (curated content, not flagged imports). Use plain
`involvedFigures` (not EventFigureAssociation) matching Enoch seed precedent;
EventPlaceAssociation with seeded roles ("Occurred At", "Started At", "Ended At").

## Get-or-create types
- EventType "Daily Life" (icon cup.and.saucer.fill, colorHex 0D9488)
- FigureType "Human" exists in defaults (person.fill, 34C759) — fetch-or-create anyway
- PlaceType "City" same

## Get-or-create places (none of these are seeded)
- Assur (Qal'at Sherqat, Iraq; 35.4566, 43.2607)
- Kanesh (Kültepe, near Kayseri, Turkey; 38.8522, 35.6339)
- Kalhu (Nimrud, Iraq; 36.0983, 43.3317)

## Figures to create if missing (all Human type, birth/death MythologicalDate.unknown)
Ea-nasir (skip if user's version exists), Nanni, Gimil-Ninurta, Mayor of Nippur,
Taram-Kubi (f), Innaya, Lamassi (f), Pushu-ken, Zizizi (f), Imdi-ilum,
Ishtar-bashti (f), Ashurnasirpal II.
Bonus (idempotent, pattern from ensureMissingCitiesAndAssociations):
spouse links Taram-Kubi↔Innaya, Lamassi↔Pushu-ken; parents Imdi-ilum+Ishtar-bashti→Zizizi;
FigurePlaceAssociations "Resident Of"/"Ruler Of".

## The 10 events (name → year(neg=BCE)/era, figures, places, source string)
1. Complaint Tablet to Ea-nasir → -1750 Old Babylonian; [Ea-nasir, Nanni]; Ur Occurred At;
   "UET V 81, British Museum"
2. Schooldays → -2000 OB; none; Nippur; "S. N. Kramer, JAOS 69 (1949); CDLI P268190"
3. Poor Man of Nippur → -1500 approx; [Gimil-Ninurta, Mayor of Nippur]; Nippur;
   "Sultantepe copy c. 701 BCE; Gurney, Anatolian Studies 5 (1955)"
4. Taram-Kubi's Letters Home → -1860 Old Assyrian; [Taram-Kubi, Innaya];
   Assur Started At + Kanesh Ended At; "Kültepe letters; C. Michel, Women of Assur and Kanesh"
5. Lamassi's Textile Rebuttal → -1860 Old Assyrian; [Lamassi, Pushu-ken]; Assur;
   same source
6. Zizizi's Angry Parents → -1860 Old Assyrian; [Zizizi, Imdi-ilum, Ishtar-bashti];
   Assur Started At + Kanesh Ended At; "Letter TCL 20 154; C. Michel"
7. Yale Culinary Tablets → -1730; none; no place; "YBC 4644 et al.; J. Bottéro"
8. Farmer's Instructions → -1800 OB; none; Nippur; "Bendt Alster, The Instructions of Šuruppak"
9. Dialogue of Pessimism → -1000; none; Babylon; "British Museum K.34113 (KAR 158)"
10. Ashurnasirpal II's Banquet at Kalhu → -879 Neo-Assyrian (approx=false);
    [Ashurnasirpal II]; Kalhu; "Banquet Stele"

## Tests (mirror ORACC tests at MeCoreTests.swift ~3801)
creates-all / idempotent double-run / skips pre-existing figure named "Ea Nasir"
(different spacing — tests normalized matching) + pre-existing event name untouched.

## Also owed next session
SESSION_LOG entry must include the deferred striping-fix line (commit c36fd11,
TypeSettingsView zebra rows) plus this feature. User confirmed striping fix works.
