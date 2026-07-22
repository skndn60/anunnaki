# Architectural Weaknesses & Technical Debt Critique (Anunnaki/Me)

This document synthesizes a critical review of the codebase architecture and development patterns observed in `agents.md`. The following "weaknesses" are framed as areas of complexity or manual effort required to maintain consistency, serving as high-priority technical debt items for future refactoring efforts.

---

## 🧱 1. Data Modeling & Persistence Challenges (The "SwiftData Boilerplate Tax")

The use of SwiftData is robust, but the way it's utilized adds significant overhead and risk in manual data linking.

### A. The Bidirectional Relationship Anti-Pattern
*   **Issue:** Developers must remember that setting bidirectional relationships *must* occur via the side annotated with `@Relationship(inverse:...)` (e.g., `type.relationships.append(rel)`). Failing to follow this results in silent data loss (`nil`).
*   **Risk:** High risk of developer error, increasing the cognitive load for new contributors and slowing development velocity when linking entities.
*   **Recommendation:** Implement a high-level **`RelationshipManager` service/utility class**. This wrapper should encapsulate all necessary inserts and appends (e.g., `tryFigurePlaceAssociation(figure: Place: roleType:)`), making data linking atomic, type-safe, and far more readable than manual updates.

### B. The Migration Burden
*   **Issue:** Any time a new model or core enum is added after the initial seeding, it requires creating an explicit `Migration.swift` backfill function (`ensureTypesExist(context:)`). This process is critical but semi-manual and brittle.
*   **Risk:** Slows down feature parity for *all* entities because every addition requires coordinated schema/seeding updates across multiple files.
*   **Recommendation:** Refactor the seeding mechanism to use an `[Entity: TypeMetadata]` **Registry Map**. The seed function should iterate over this map, calling generalized detection and backfilling logic (`ensureTypeExists(T, context:)`) for common resources *before* running specific entity seeds.

## 🧩 2. Architectural Ambiguity (The "Source" Problem)

Relying on free-text strings to maintain data integrity is the single largest structural weakness.

### A. Brittle Discriminator: `Relationship.source`
*   **Issue:** Using a plain `String` property (`relationship.source`) in the `Relationship` entity to differentiate source traditions (e.g., "Enuma Elish", "Atra-Hasis") is fundamentally fragile. Typographical variations or rephrasing will break search and filtering mechanisms.
*   **Risk:** Data integrity collapse risk; inability to reliably query relationships by specific canonical sources.
*   **Critical Next Step (High Priority):** This must be elevated from a string field to an **actual Many-to-Many relationship (`@Relationship`) with the `Source` model.** This requires significant refactoring but guarantees referential integrity.

## 🖥️ 3. State Management & View Complexity

The pattern used for persistent UI state, while effective, is verbose and prone to repetitive maintenance across views.

### A. Scattered Width Management Pattern
*   **Issue:** Every list view (`FigureListView`, `PlaceListView`, etc.) requires manually defining and managing its own dedicated width persistence key in `@AppStorage` (e.g., `"figureDetailWidth"`).
*   **Risk:** Violates DRY principle (Don't Repeat Yourself). Adding a new list type necessitates boilerplate code insertion in multiple places.
*   **Recommendation:** Introduce a central **`LayoutManager` EnvironmentObject**. This manager would handle width persistence for *all* views via one single, generalized `@AppStorage("detailWidth")` key mapped dynamically by the view's generic type or ID, simplifying maintenance significantly.

### B. Lineage View Complexity
*   **Issue:** `MiniLineageView` and its cousins are performing too many roles: fetching data, collapsing generations (`resolveGeneration`), managing complex localized state (popovers), and acting as a core UI component. This concentration of diverse logic is fragile.
*   **Recommendation:** Extract the "Alternative Selector" functionality into a dedicated, reusable `AltSelectorComponent` view/struct that only handles popover presentation and selection callbacks, simplifying the lineage views to act primarily as coordinators.

## 🔬 4. Development Experience & Workflow Tooling

These weaknesses slow down developer throughput and knowledge transfer.

### A. High Cognitive Load (The "API Contract")
*   **Observation:** The system relies on multiple implicit contracts: SwiftData side-annotated rules, SwiftUI layout debugging techniques (`.background()` layers), and external seeding backfill scripts.
*   **Recommendation:** Create a comprehensive internal **"Me Development Guide"** or dedicated module documentation that codifies all these patterns explicitly in one place, significantly reducing the learning curve for new team members.

### B. Lack of Global Build Validation Hook
*   **Observation:** Data validation currently relies on external `jq` commands run during testing/pre-commit hooks. There is no single, internal API call to validate *all* data dependencies and models before runtime execution starts (beyond the build system).
*   **Recommendation:** Implement a dedicated `DataValidatorService` that runs as part of the CI pipeline, checking for consistency across all `@Model` entities against expected constraints defined in a central manifest.