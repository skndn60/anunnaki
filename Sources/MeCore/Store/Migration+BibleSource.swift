import Foundation
import SwiftData
import os

extension Migration {
    /// The single source row for the Hebrew Bible. A source is a *work*; a verse is a
    /// location inside it, and `Citation.location` is where a verse belongs. The store
    /// instead held one row per verse — "Bible - Genesis 6:4", "Bible - Numbers 13:33" and
    /// so on — which makes a single work look like five sources and multiplies every
    /// rename, translation note and link the user maintains on it. `Book of Enoch (1 Enoch)`
    /// was always right: twenty Watchers cited, one row, each verse in its own location.
    package static let bibleSourceName = "Bible"

    private static let perVerseBiblePrefix = "Bible - "

    package static let bibleWorkDescription = "The Hebrew Bible in an English modern translation — Genesis, Numbers, Deuteronomy, Joshua and 2 Samuel for the passages this store cites. One row for the whole work: each citation carries its own book, chapter and verse in its location, so this source is cited many times over rather than duplicated once per verse."

    private static let bibleMigrationLog = Logger(subsystem: "com.me.app", category: "store")

    /// True for a source row that is one verse of the Bible rather than the Bible itself:
    /// "Bible - Genesis 6:4". Deliberately strict — a book name, then a chapter, then a
    /// verse — so this can only ever match the shape it was written for and never a source
    /// the user named some other way. A numbered book counts as a book name: "1 Samuel 17:7"
    /// is a verse of a Bible book, and "Bible - 6:4" alone is not.
    package static func isPerVerseBibleSourceName(_ name: String) -> Bool {
        guard name.hasPrefix(perVerseBiblePrefix) else { return false }
        let verse = String(name.dropFirst(perVerseBiblePrefix.count))
        guard let colon = verse.firstIndex(of: ":") else { return false }
        let chapter = verse[verse.startIndex..<colon]
        let numbers = verse[verse.index(after: colon)...]
        return chapter.contains { $0.isLetter }
            && numbers.first?.isNumber == true
            && chapter.last?.isNumber == true
    }

    /// The verse a per-verse row was named after: "Bible - Numbers 13:33" → "Numbers 13:33".
    package static func verseInPerVerseSourceName(_ name: String) -> String {
        name.hasPrefix(perVerseBiblePrefix) ? String(name.dropFirst(perVerseBiblePrefix.count)) : name
    }

    /// Collapse the per-verse Bible rows into one work, keeping every citation and its verse.
    ///
    /// Additive in effect and idempotent: it only acts while a per-verse row exists, so a
    /// store that never had them is untouched, and a second run finds nothing to do. The
    /// re-pointing itself is `DuplicateMerger.mergeSources`, which walks all twelve
    /// relationship sides and drops a citation only when an identical one already exists
    /// on the keeper — so no citation is lost, and none is duplicated.
    ///
    /// Two things have to happen *before* the merge. A citation whose verse lived only in
    /// its source's name — the store's Mahalalel row has an empty location — would lose its
    /// reference the moment the name goes, so the verse is written into the location first,
    /// where `mergeSources` can see it when it compares for duplicates. And the store's own
    /// Genesis 6:4 quotation is copied onto the work row before the row it came from is
    /// deleted; `mergeSources` would otherwise leave it behind, because it only adopts a
    /// string into an *empty* field and the work description is not empty.
    ///
    /// `ContentAttribution.source` has no inverse on `Source`, so `mergeSources` does not
    /// walk it and a delete would strand the attribution. It is re-pointed here first.
    package static func collapseBibleVersesIntoOneSource(context: ModelContext) {
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let perVerseRows = sources.filter { isPerVerseBibleSourceName($0.name) }
        guard !perVerseRows.isEmpty else { return }

        let bible: Source
        if let existing = sources.first(where: { $0.name == bibleSourceName }) {
            bible = existing
        } else {
            let created = Source(
                name: bibleSourceName,
                sourceType: .modernTranslation,
                author: "",
                language: "English",
                period: "",
                sourceDescription: bibleWorkDescription
            )
            context.insert(created)
            bible = created
        }

        let genesisRowName = "\(perVerseBiblePrefix)Genesis 6:4"
        let genesisQuote = perVerseRows.first { $0.name == genesisRowName }?.sourceDescription ?? ""
        if !genesisQuote.isEmpty, !bible.sourceDescription.contains(genesisQuote) {
            bible.sourceDescription += "\n\nGenesis 6:4, quoted in this store: \"\(genesisQuote)\""
        }

        let attributions = (try? context.fetch(FetchDescriptor<ContentAttribution>())) ?? []

        for row in perVerseRows {
            let verse = verseInPerVerseSourceName(row.name)

            for citation in row.citations where citation.source === row {
                if citation.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    citation.location = verse
                }
            }
            for relationship in row.relationships where relationship.sourceRef === row {
                if relationship.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    relationship.source = verse
                }
            }
            for attribution in attributions where attribution.source === row {
                attribution.source = bible
            }

            do {
                try DuplicateMerger.mergeSources(bible, row, in: context)
            } catch {
                bibleMigrationLog.error("Bible collapse: merging \(row.name, privacy: .public) into Bible failed: \(error.localizedDescription, privacy: .public) — the row is left in place and retried on the next launch")
            }
        }

        Commit.save(context, "collapseBibleVersesIntoOneSource")
    }
}
