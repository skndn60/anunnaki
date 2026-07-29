Here's the flow:
1. Model: Figure has groupAssociations: [FigureGroupAssociation], FigureGroup has figureAssociations: [FigureGroupAssociation]. The join entity FigureGroupAssociation stores figure, group, and a note string. True many-to-many.
2. Adding a figure to a group — three paths:
- FigureDetailView: + button → GroupLinkPopover → search groups, pick one, optional note, "Join" → creates FigureGroupAssociation and appends to both sides.
- FigureGroupFormView: Step 2 (Figures) → multi-select from all figures → syncFigures() diffs old vs new and creates/removes associations.
- Bulk Add / Sync: In FigureGroupDetailView, you can filter by figure type/domain/name and add all matches. Optionally save as a GroupMemberFilter rule, then hit "Sync" later to catch newly added figures.
3. Default groups (via Migration.ensureDefaultFigureGroups): 6 groups created on first launch (Divine Council, Sumerian Pantheon, Akkadian/East Semitic, Book of Enoch, Primordial Beings, SKL Kings). Three have auto-sync filters that match on domain or figureType — but that's just convenience; the actual membership is still through association rows.
4. Membership display: FigureDetailView shows a "Groups" section listing all group associations. FigureGroupListView's detail panel lists members with clickable names that navigate to the figure in the sidebar.