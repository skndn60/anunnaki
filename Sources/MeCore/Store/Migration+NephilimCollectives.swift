import Foundation
import OSLog
import SwiftData

extension Migration {
    /// Deletions here are logged, so a store that refuses one says so instead of quietly
    /// keeping a withdrawn edge.
    private static let nephilimMigrationLog = Logger(subsystem: "com.me.app", category: "store")
    /// The collective type the Nephilim *peoples* live on. It is the sibling of the existing
    /// "Mythical figure" type — same `sparkles` lineage, and the same `FF2600` the store
    /// already uses for this theme, so the peoples keep the visual identity the user gave
    /// them. `category == "collective"` is set by `ensureFigureTypeCategories`, the single
    /// owner of that flag, which this name was added to: a figure on it has members, never
    /// parents.
    package static let nephilimCollectiveTypeName = "Mythical Collective"

    /// The era the store uses for the age before the flood. It is the only pre-flood era this
    /// migration writes, and it is also the value an earlier build of it assigned to Rephaim —
    /// which `ensureNephilimCollectives` is now allowed to correct, since it is our own
    /// mistake rather than the user's choice.
    package static let watchEraName = "Age of the Watchers"

    /// The store's post-flood era, ordered immediately after "The Great Flood". Every other
    /// figure in it is a Sumerian dynasty, so it is an awkward home for the Transjordan and
    /// Gath material — see the note on the Rephaim seed.
    package static let postFloodEraName = "Post-Flood Kingdoms"

    /// The figure type that holds the *named giants* — Hahyah, Ohyah, Og of Bashan: beings
    /// with a father, so this type is deliberately **not** categorised `collective`. It cannot
    /// be. Before this migration the store's "Nephilim" type carried the peoples and these
    /// individuals at once, and no single `category` value is true of both: a collective is
    /// defined by having members instead of parents, and three of its seven figures are
    /// persons. Categorising it would have given Hahyah, Ohyah and Og a membership strip and
    /// taken away their parent slots, which is the category error in the reverse direction
    /// from the one it fixed. So the type is left alone and the peoples move to
    /// `nephilimCollectiveTypeName` instead.
    package static let nephilimFigureTypeName = "Nephilim"

    /// Review-flag prefix for the sticky notes this migration attaches, registered in
    /// `autoStickyPrefixes` so deleting one records a dismissal and it never returns.
    package static let nephilimStickyPrefix = "MODELLED 30-09-2026 — Nephilim"

    /// Find-or-create the collective type for the Nephilim peoples, so each step below can run
    /// on its own. The *category* is deliberately not set here — `ensureFigureTypeCategories`
    /// owns it.
    private static func nephilimCollectiveFigureType(context: ModelContext) -> FigureType {
        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        if let existing = types.first(where: { $0.name == nephilimCollectiveTypeName }) {
            return existing
        }
        let created = FigureType(
            name: nephilimCollectiveTypeName,
            icon: "person.3.fill",
            colorHex: "FF2600"
        )
        context.insert(created)
        return created
    }

    /// Find-or-create the type for the named giants, so each step below can run on its own.
    /// The colour is the one the store already uses for this type and is left alone; only the
    /// icon typo is repaired, because "peron.3" is not an SF Symbol and renders as a missing
    /// glyph on every card and legend that shows this type.
    private static func nephilimIndividualFigureType(context: ModelContext) -> FigureType {
        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        if let existing = types.first(where: { $0.name == nephilimFigureTypeName }) {
            if existing.icon == "peron.3" { existing.icon = "person.3.fill" }
            return existing
        }
        let created = FigureType(
            name: nephilimFigureTypeName,
            icon: "person.3.fill",
            colorHex: "FF2600"
        )
        context.insert(created)
        return created
    }

    /// Seed the Nephilim and the peoples and individuals around them.
    ///
    /// The model follows the Hebrew Bible and attributes the rest, because the Hebrew Bible
    /// does *not* equate the Nephilim with the Repha'îm and this migration previously did.
    ///
    /// - **Nephilim** is the primeval generation of Genesis 6:4 and stays a collective of its
    ///   own. It has exactly one recorded member, the Anakim, and that edge rests on Numbers
    ///   13:33 — a clause that is circular as the Hebrew stands ("the Nephilim, the sons of
    ///   Anak, *from the Nephilim*") and that the Septuagint omits entirely. The genealogy is
    ///   supplied by Jubilees 15:8-12 and 1 Enoch, which are cited for it, so the edge is kept
    ///   and marked as a later reading rather than presented as Torah.
    /// - **Repha'îm** is what the Torah actually uses as a heading for the great-statured
    ///   Transjordan peoples, so it is a collective in its own right with a real membership
    ///   roll: Deuteronomy 2:11 counts the Emim with them, 2:20 does the same for Ammon's
    ///   Zamzummim, 3:13 calls Bashan "the land of the Repha'îm" and 3:11 makes Og of Bashan
    ///   the last of the remnant. The earlier build recorded no edge for Emim or Zuzim,
    ///   reading those same verses as merely setting the peoples *beside* the Rephaim; that
    ///   was the misreading, and the membership is what the verses say.
    /// - **Gibborim** is neither. It is the common noun "the mighty ones", not a people, so
    ///   it is no longer a collective and has no membership roll; it survives as a figure only
    ///   so the word stays findable, with the epithet also recorded as an alternate name on
    ///   the Nephilim.
    ///
    /// Two kinds of figure are seeded and they get different types, because the model
    /// distinguishes them: the assemblies (Nephilim, Rephaim, Anakim, Emim, Zuzim) go on
    /// `nephilimCollectiveTypeName`; everything else (Hahyah, Ohyah, Og of Bashan, Gibborim)
    /// is a person or a word and stays on the user's own `Nephilim` type.
    ///
    /// Moves are narrow. An assembly is moved onto the collective type only if it is currently
    /// on some *collective* type — the Nephilim were typed "Divine Collective" by hand, which
    /// is wrong, the Nephilim being the offspring of the Watchers rather than gods — or on
    /// the `Nephilim` type, which is the state this migration is correcting. A non-assembly is
    /// moved only off a collective type. A type the user chose deliberately is never
    /// overwritten, and only empty fields are filled, so a description they wrote is kept.
    ///
    /// The one exception to "never overwrite" is a description that still reads *verbatim*
    /// what an earlier build of this migration wrote: `Seed.previousDescription` carries that
    /// exact text, and a field matching it is corrected. A user who edited the description no
    /// longer matches it, so their prose is untouched. Additive + idempotent.
    ///
    /// That guard is not theoretical. Four of these figures — Anakim, Rephaim, Emim, Zuzim —
    /// already carry descriptions of your own, so the seed has never been applied to them and
    /// they are still worded for the old model: Rephaim's calls the word "a term often used
    /// interchangeably with the Nephilim", and Anakim's states the Num 13:33 descent as plain
    /// fact. They carry no `previousDescription` for that reason — a value describing text
    /// those rows never held would be a fiction — and each of them has a sticky naming the
    /// sentence you may want to revisit. Nothing is rewritten without you.
    package static func ensureNephilimCollectives(context: ModelContext) {
        let collectiveType = nephilimCollectiveFigureType(context: context)
        let individualType = nephilimIndividualFigureType(context: context)
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var byName = Dictionary(allFigures.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let antediluvian = MythologicalDate(year: nil, era: "Antediluvian", isApproximate: true)

        struct Seed {
            let name: String
            let title: String
            let domain: String
            let description: String
            let isPeople: Bool
            let gender: Figure.Gender
            /// Name of the era to link, or "" for none. Per figure rather than per set,
            /// because the flood is the dividing line in this material and a single era for
            /// the whole set would date the survivors into the world that ended them.
            let era: String
            let source: String
            /// The exact text an earlier build of this migration wrote into
            /// `description`. A field still holding it verbatim is corrected to the new text;
            /// anything else — including an empty field — is left to the is-empty fill below,
            /// so user prose is never overwritten.
            var previousDescription: String? = nil
            /// Same verbatim rule for `domain`, for the same reason: a domain this migration
            /// wrote can still be corrected, one the user wrote is left alone.
            var previousDomain: String? = nil
        }

        let seeds: [Seed] = [
            Seed(
                name: "Nephilim",
                title: "The Giants of the Antediluvian Age",
                domain: "The antediluvian earth, Mount Hermon, Canaan, Bashan",
                description: "The primeval generation the Hebrew Bible knows from Genesis 6:4 alone, where they take human wives 'in those days' and then vanish from the earth. The Torah keeps them strictly separate from the Repha'îm, the ethnic category it uses for the great-statured peoples of the Transjordan: no Torah text says the Repha'îm descend from the Nephilim, and the one verse that appears to say so is not trustworthy evidence for it. The genealogy belongs to the Second Temple books — Jubilees 15:8-12 and 1 Enoch, which make the Nephilim the offspring of the angelic unions — and the Septuagint's rendering of the name with the same Greek gigantes it uses for the 'mighty ones' is why European tradition says 'giant'. They are not gods: 1 Enoch has Gabriel sent to destroy the Watchers' children by setting them against one another.",
                isPeople: true,
                gender: .unknown,
                era: watchEraName,
                source: "Book of Enoch (1 Enoch)",
                previousDescription: "The general name for the giants of the antediluvian age rather than the name of one tribe. Genesis 6:4 has them taking human wives 'in those days' and then vanish from the earth, and the Septuagint renders the Hebrew name with the same Greek gigantes it uses for the 'mighty ones', which is where European 'giant' comes from. 1 Enoch 6:7 calls them the offspring of the holy angels and names them Nephilim, and the Book of Jubilees likewise makes them the children of the angelic unions. They are not gods: 1 Enoch has Gabriel sent to destroy the Watchers' children by setting them against one another, and the spies sent into Canaan report surviving descendants of theirs in Numbers 13:33. The name covers several peoples, and the Anakim, the Gibborim and the Rephaim of the Hebrew Bible are all used of this class — not always as distinct from one another.",
            ),
            Seed(
                name: "Anakim",
                title: "The Anakim of the Canaanite Hill Country",
                domain: "The Canaanite hill country, Amorite territory, Transjordan",
                description: "A people of great stature in the hill country of the Amorites, reported by the spies Moses sent out from Paran and by Deuteronomy, which calls them 'mighty men, sons of the Anakim' and describes them as like the Nephilim, 'and there was a dwarf among them, and like the small of a locust'. Deuteronomy 2:11 counts them with the Repha'îm, and that is the membership recorded here. Numbers 13:33 appears to make them a branch of the Nephilim — 'the Nephilim, the sons of Anak, from the Nephilim' — but the clause is circular as the Hebrew stands and the Septuagint omits it entirely, so the ancestry is supplied by Jubilees and 1 Enoch instead. The name is also not a genealogy: 'sons of Anak' is the spies' taunt, a term of contempt for a tall people rather than the children of a named ancestor, though Joshua 14:15 and 15:13 do give an Anak a son and a father in the tribe of Judah. Two Transjordan kingdoms are said to have survived from them: Sihon's realm and the kingdom of Og of Bashan, whose iron bed and nine-cubit height Deuteronomy 3:11 attributes to 'the remnant of the Repha'îm'.",
                isPeople: true,
                gender: .unknown,
                era: "",
                source: bibleSourceName,
                
            ),
            Seed(
                name: "Rephaim",
                title: "The Rephaim of the Hebrew Bible",
                domain: "Bashan, the Transjordan, Gath",
                description: "An ethnic and geopolitical category of the Hebrew Bible rather than the name of a single tribe: the heading under which the Deuteronomic notes file the great-statured peoples of the Transjordan. Deuteronomy 2:11 counts the Emim with them — 'for they are also counted as Repha'îm, but the Moabites call them Emim' — and 2:20 does the same for Ammon and its Zamzummim; 3:13 calls Bashan 'the land of the Repha'îm' and 3:11 makes Og of Bashan the last of the remnant; Joshua 12:4 and 13:12 give the name to the two Transjordan kingdoms of Sihon and Og. Genesis 14:5 already lists a Rephaim of Bashan in Abraham's day, so the category is older than the conquest. It is not the Nephilim: no Torah text says so, and that identification comes from 1 Enoch and Jubilees rather than from the Hebrew Bible. Two other senses of the same word are not this one and should not be merged into it — the shades of the dead in Sheol (Psalms 88:11, Proverbs 9:18, Isaiah 26:14), and the Gathite warriors of 2 Samuel 21, who are 'the Rephaim' in verse 19 but 'descendants of Rapha' in verses 20-21, a difference some read as a cultic warrior order rather than a bloodline. The Septuagint is inconsistent, rendering the name now as gigantes, now as titanes, and elsewhere simply transliterating it as Raphain.",
                isPeople: true,
                gender: .unknown,
                // The one figure in this set that the flood did not end. Its Hebrew Bible
                // occurrences are all post-flood — the remnant in Bashan, the two Transjordan
                // kingdoms, the Gittite Goliath, the Gittites of Gibeon — and the name
                // survives *because* it names the survivors. The Enochic usage (1 Enoch 8:12,
                // "the Rephaim of the Nephilim") is pre-flood and is kept as a citation
                // rather than as this figure's source, which is what put it in the Enoch
                // view before. The era is the store's post-flood era, whose other contents
                // are all Sumerian dynasties — the honest home for Bashan and Gath would be a
                // Late Bronze Age era the store does not have yet.
                era: postFloodEraName,
                source: bibleSourceName,
                previousDomain: "Bashan, Transjordan, Gibeon, Gath",
            ),
            Seed(
                name: "Gibborim",
                title: "The Mighty Ones — the Giants of Genesis",
                domain: "The antediluvian earth, Mount Hermon",
                description: "gibborim, 'the mighty ones, the men of renown' — a common noun, not the name of a people. Genesis 6:4 reads 'the Nephilim, the mighty ones', and Deuteronomy 1:28 reports 'mighty men, sons of the Anakim'; the Septuagint resolves the pair into the single Greek gigantes, which is where the European word 'giant' comes from. It describes the Nephilim rather than naming a tribe among them, so it is recorded here only so the word stays findable, with the epithet also carried as an alternate name on the Nephilim. It has no membership roll and no place among the named giants.",
                isPeople: false,
                gender: .unknown,
                era: watchEraName,
                source: "Book of Enoch (1 Enoch)",
                previousDescription: "The Hebrew word for the Nephilim — gibborim, 'the mighty ones, the men of renown' — and the word the Septuagint resolves into the single Greek gigantes. Genesis 6:4 reads 'the Nephilim, the mighty ones', and 1 Enoch 6-7 and 15 use gigantes for the same offspring of the angels. The term is used both for the class and for one group inside it: the spies in Numbers 13:33 and Deuteronomy 1:28 report 'mighty men, sons of the Anakim', and Deuteronomy 3:11, Joshua 12:4 and 2 Samuel 5:18-22 apply the same word family to Og of Bashan and to the Gittite of Gath. It is therefore a name for the Nephilim rather than a separate tribe of them.",
                previousDomain: "The antediluvian earth, Mount Hermon, Canaan, Bashan",
            ),
            Seed(
                name: "Emim",
                title: "The Emim of the Transjordan",
                domain: "Moab, Seir, the Transjordan",
                description: "A people of great stature in Moab, told of in Deuteronomy 2:10-11 as dwelling in Seir, 'like the Anakim', and destroyed with a remnant left to that day. The same verse is the clearest statement of what the Repha'îm are: 'for they are also counted as Repha'îm, but the Moabites call them Emim' — Emim is the Moabite name for a people the Bible files under the Repha'îm, and 2:20 gives the exact parallel for Ammon and its Zamzummim. They are members of the Repha'îm and not of the Nephilim: nothing in the Hebrew Bible connects them to the antediluvian generation.",
                isPeople: true,
                gender: .unknown,
                era: "",
                source: bibleSourceName,
                
            ),
            Seed(
                name: "Zuzim",
                title: "The Zuzim of the Ammon",
                domain: "Hamm, the Ammon",
                description: "A people of great stature in the land of the Ammon, called by the Ammonites Zamzummim. Deuteronomy 2:20 identifies them with the Repha'îm of that land — 'Repha'îm formerly lived there, but the Ammonites call them Zamzummim' — and that is the membership recorded here. Genesis 14:5 earlier lists them as a people parallel to the Rephaim of Bashan, the Emim of Shaveh-kiriathaim and the Sheshites, all four struck down by the kings of the coalition in the Transjordan, so the sources do not agree on whether the Zuzim are a tribe within the Repha'îm or a separate people. The membership follows Deuteronomy and the tension is recorded here rather than resolved.",
                isPeople: true,
                gender: .unknown,
                era: "",
                source: bibleSourceName,
                
            ),
            Seed(
                name: "Hahyah",
                title: "Hahyah, One of the Giants",
                domain: "The antediluvian earth, Mount Hermon",
                description: "A named giant of the antediluvian generation. The Book of Enoch lists him among the offspring of the holy angels — the ones it calls Nephilim — among whom they appear, and he belongs to the generation 1 Enoch 6-9 and 15 has Gabriel set destroying. He is a person rather than a people, so he is kept on the 'Nephilim' type and is not given a membership roll.",
                isPeople: false,
                gender: .male,
                era: watchEraName,
                source: "Book of Enoch (1 Enoch)"
            ),
            Seed(
                name: "Ohyah",
                title: "Ohyah, One of the Giants",
                domain: "The antediluvian earth, Mount Hermon",
                description: "A named giant of the antediluvian generation, listed with Hahyah among the offspring of the holy angels in the Book of Enoch and in the Dead Sea Scrolls Book of Giants. He is a person rather than a people, so he is kept on the 'Nephilim' type and is not given a membership roll.",
                isPeople: false,
                gender: .male,
                era: watchEraName,
                source: "Book of Enoch (1 Enoch)"
            ),
            Seed(
                name: "Og of Bashan",
                title: "Og, King of Bashan",
                domain: "Bashan, the Transjordan",
                description: "The last survivor of the remnant of the Rephaim, whom Deuteronomy 3:11 describes with an iron bed of thirteen cubits, and the last king of Bashan, whose kingdom is said to have come from the Anakim. He is a person rather than a people, so he is kept on the 'Nephilim' type; and because the passage that places him in the line of giants places him in the Rephaim, it is as a member of the Rephaim that he is linked, not as a member of the Nephilim.",
                isPeople: false,
                gender: .male,
                era: "",
                source: bibleSourceName
            ),
        ]

        for seed in seeds {
            let target = seed.isPeople ? collectiveType : individualType
            let figure: Figure
            if let existing = byName[seed.name.lowercased()] {
                figure = existing
            } else {
                let created = Figure(
                    name: seed.name,
                    title: seed.title,
                    figureType: target,
                    gender: seed.gender,
                    domain: seed.domain,
                    figureDescription: seed.description,
                    birthDate: antediluvian,
                    deathDate: MythologicalDate.unknown,
                    source: seed.source
                )
                context.insert(created)
                byName[seed.name.lowercased()] = created
                figure = created
            }

            if let current = figure.figureType,
               current.persistentModelID != target.persistentModelID {
                let mustMove = seed.isPeople
                    ? (current.category == "collective" || current.name == nephilimFigureTypeName)
                    : current.category == "collective"
                if mustMove {
                    // Set through the annotated side: `FigureType.figures` carries the
                    // @Relationship(inverse:) and `Figure.figureType` does not, so assigning
                    // the forward property is the variant that silently does nothing.
                    current.figures.removeAll { $0.persistentModelID == figure.persistentModelID }
                    target.figures.append(figure)
                }
            }
            if figure.title.isEmpty { figure.title = seed.title }
            // Correcting our own earlier text, and only that. The old value is carried verbatim
            // in the seed, so a user who reworded the field no longer matches and is left
            // alone; the is-empty fill below then does not touch it either.
            if let previous = seed.previousDescription,
               !previous.isEmpty,
               figure.figureDescription == previous {
                figure.figureDescription = seed.description
            }
            if let previous = seed.previousDomain,
               !previous.isEmpty,
               figure.domain == previous {
                figure.domain = seed.domain
            }
            if figure.domain.isEmpty { figure.domain = seed.domain }
            if figure.figureDescription.isEmpty { figure.figureDescription = seed.description }
            if figure.source.isEmpty { figure.source = seed.source }
            // "Hebrew Bible" was this migration's own label for the Bible before the collapse
            // migration settled on one `Source` row named `Bible`. The join is the authority;
            // this mirror had drifted away from it and is brought back into line, again only
            // when it holds verbatim what we wrote.
            if figure.source == "Hebrew Bible" { figure.source = seed.source }
            if figure.gender == .unknown, seed.gender != .unknown { figure.gender = seed.gender }
            if !seed.era.isEmpty, figure.era?.name != seed.era {
                // Reassignable when unset, or when it still holds "Age of the Watchers" — a
                // value only this migration has ever written, so correcting it is repairing
                // our own seed and not overriding a choice. Any other era is the user's.
                if figure.era == nil || figure.era?.name == watchEraName {
                    if let target = eras.first(where: { $0.name == seed.era }) {
                        figure.era = target
                    }
                }
            }
        }

        struct AltSeed {
            let figure: String
            let name: String
            let tradition: AlternateName.Tradition
            let nameType: AlternateName.NameType
            let note: String
        }
        let altSeeds: [AltSeed] = [
            AltSeed(figure: "Nephilim", name: "Nêfilim", tradition: .hebrew, nameType: .spelling,
                note: "Hebrew transliteration of the name; the pointing is reconstructed."),
            AltSeed(figure: "Rephaim", name: "Rephaîm", tradition: .hebrew, nameType: .spelling,
                note: "Hebrew transliteration with the pointing. The pointing is reconstructed from the Masoretic tradition rather than copied from a verse, so it marks the name rather than a single quotation."),
            AltSeed(figure: "Nephilim", name: "gibborim", tradition: .hebrew, nameType: .epithet,
                note: "'The mighty ones, the men of renown' — Genesis 6:4's second term for them in the same breath as the Nephilim. A common noun describing that generation, not the name of a people among them, which is why it belongs here as an epithet rather than as a figure of its own."),
            AltSeed(figure: "Nephilim", name: "Nephilim (gigantes)", tradition: .greek, nameType: .spelling,
                note: "The Septuagint's rendering, which uses the same Greek it uses for the 'mighty ones' — the source of the European word 'giant'."),
        ]
        for seed in altSeeds {
            guard let figure = byName[seed.figure.lowercased()] else { continue }
            if figure.alternateNames.contains(where: { $0.name.lowercased() == seed.name.lowercased() }) { continue }
            context.insert(AlternateName(figure: figure, name: seed.name, tradition: seed.tradition, nameType: seed.nameType, note: seed.note))
        }

        Commit.save(context, "ensureNephilimCollectives")
    }

    /// Relate the Nephilim peoples to each other, following the Hebrew Bible: the Repha'îm
    /// get the membership roll the Deuteronomic notes support, and the Nephilim keep the one
    /// edge that claims otherwise only because it is the tradition's whole point — and only
    /// with its weakness recorded.
    ///
    /// - Repha'îm ⊃ Anakim, Emim, Zuzim, Og of Bashan. Deuteronomy 2:11 counts the Emim with
    ///   the Repha'îm, 2:20 does the same for Ammon's Zamzummim, 3:11 makes Og "the remnant
    ///   of the Rephaim". The Anakim are counted with them at 2:11.
    /// - Nephilim ⊃ Anakim, on Numbers 13:33 alone. This is the one edge the earlier build
    ///   treated as the primary structure, and it is the weakest one in the set: the clause is
    ///   circular in MT and absent from the Septuagint. Both stickies below say so.
    /// - No `Local form of` edges to the Nephilim. An earlier build asserted Rephaim and
    ///   Gibborim as regional names for that class, which no Torah text supports and which
    ///   1 Enoch, not the Hebrew Bible, is the source of; they are withdrawn by
    ///   `withdrawSynonymyEdgesIntoTheNephilim`.
    ///
    /// Og's membership is the one edge that is a *person* inside a people's roll, and it is
    /// there on the strength of a single explicit verse rather than on any general
    /// identification — a membership of a people, not a synonymy. Additive + idempotent, and
    /// the withdrawals are reversible in the sense that matters: they touch only rows this
    /// migration created.
    package static func ensureNephilimRelations(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let byName = Dictionary(allFigures.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let nephilim = byName["nephilim"]
        guard let nephilim else { return }

        let relTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let memberOf = relTypes.first { $0.name == "Member of" }
        let localFormOf = relTypes.first { $0.name == "Local form of" }

        let allSources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let sourceByName = Dictionary(allSources.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        let manager = RelationshipManager(context: context)

        // The Repha'îm roll. `Member of` is directed member → collective, so the call is
        // written with the member first; there is no spelling of this that inverts it.
        if let memberOf, let rephaim = byName["rephaim"] {
            let rephaimMembers: [(name: String, source: String)] = [
                ("Anakim", "Deuteronomy 2:11"),
                ("Emim", "Deuteronomy 2:11"),
                ("Zuzim", "Deuteronomy 2:20"),
                ("Og of Bashan", "Deuteronomy 3:11"),
            ]
            for (name, source) in rephaimMembers {
                guard let figure = byName[name.lowercased()] else { continue }
                let alreadyLinked = figure.outgoingRelationships.contains {
                    $0.toFigure?.persistentModelID == rephaim.persistentModelID &&
                    $0.relationshipType?.persistentModelID == memberOf.persistentModelID
                }
                guard !alreadyLinked else { continue }
                manager.addMembership(
                    member: figure, collective: rephaim, relationshipType: memberOf,
                    source: source, sourceRef: sourceByName[bibleSourceName]
                )
            }
        }

        // The contested one, kept because it is the tradition's lineage and because the
        // citations for the Nephilim descend from it, but held at arm's length: the sticky on
        // each end records that Num 13:33 is circular in MT and dropped by the Septuagint.
        if let memberOf, let anakim = byName["anakim"] {
            let alreadyLinked = anakim.outgoingRelationships.contains {
                $0.toFigure?.persistentModelID == nephilim.persistentModelID &&
                $0.relationshipType?.persistentModelID == memberOf.persistentModelID
            }
            if !alreadyLinked {
                manager.addMembership(
                    member: anakim, collective: nephilim, relationshipType: memberOf,
                    source: "Numbers 13:33 (LXX omits the descent clause)", sourceRef: sourceByName[bibleSourceName]
                )
            }
        }

        withdrawSynonymyEdgesIntoTheNephilim(context: context, byName: byName, nephilim: nephilim, localFormOf: localFormOf)

        Commit.save(context, "ensureNephilimRelations")
    }

    /// Delete the two `Local form of` edges an earlier build of this migration created for
    /// Rephaim and Gibborim, which asserted that they are regional names for the Nephilim.
    ///
    /// This is a deletion, so it is narrow on every axis. It will only remove a row whose
    /// source figure is one of those two, whose type is `Local form of`, whose target is the
    /// Nephilim figure, and whose `sourceRef` is the `Bible` — the exact shape this function
    /// wrote. A user who drew their own such edge, from a different source, or to a different
    /// target, does not match any of those and survives. Nothing cascades from a
    /// `Relationship`, so there are no children to re-point first.
    private static func withdrawSynonymyEdgesIntoTheNephilim(
        context: ModelContext,
        byName: [String: Figure],
        nephilim: Figure,
        localFormOf: RelationshipType?
    ) {
        guard let localFormOf else { return }
        let allSources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let bible = allSources.first { $0.name == bibleSourceName }
        let doomed = ["rephaim", "gibborim"].compactMap { byName[$0] }.flatMap { figure in
            figure.outgoingRelationships.filter { relationship in
                relationship.relationshipType?.persistentModelID == localFormOf.persistentModelID &&
                relationship.toFigure?.persistentModelID == nephilim.persistentModelID &&
                relationship.sourceRef?.persistentModelID == bible?.persistentModelID
            }
        }
        guard !doomed.isEmpty else { return }
        // Empty the observed arrays before deleting, or SwiftData faults the deleted rows
        // mid-render if anything is still watching them.
        do {
            try context.transaction {
                for relationship in doomed {
                    relationship.fromFigure?.outgoingRelationships.removeAll { $0.persistentModelID == relationship.persistentModelID }
                    relationship.toFigure?.incomingRelationships.removeAll { $0.persistentModelID == relationship.persistentModelID }
                    context.delete(relationship)
                }
            }
        } catch {
            nephilimMigrationLog.error("Nephilim model: withdrawing the 'local form of' edges into the Nephilim failed: \(error.localizedDescription, privacy: .public) — they are left in place and withdrawn again on the next launch")
        }
    }

    /// The Bible, as one source, and a citation per figure.
    ///
    /// Runs before `ensureNephilimRelations` so the relationship rows can be attributed
    /// through the source key rather than only through a free-text verse string.
    ///
    /// **One row for the whole work.** An earlier build of this migration created a source
    /// per verse — "Bible - Genesis 6:4", "Bible - Numbers 13:33", "Bible - Deuteronomy 3:11"
    /// — by copying the shape of the store's hand-made "Bible - Genesis 6:4" row. That is
    /// the wrong level: a verse is not a work, so five references to one book became five
    /// sources, each with its own translation, language and link to maintain. The verse
    /// belongs in `Citation.location`, which is where the citation seeds below already put
    /// it, exactly as `Book of Enoch (1 Enoch)` is cited twenty times without being
    /// duplicated. `collapseBibleVersesIntoOneSource` repairs the rows that build created.
    ///
    /// The verse summaries that lived in those descriptions are not lost by the change: each
    /// is repeated in the note of the citation for the figure it concerns, which is the
    /// right home for the substance of a passage. Additive + idempotent.
    package static func ensureNephilimCitations(context: ModelContext) {
        let allSources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        var byName = Dictionary(allSources.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        if byName[bibleSourceName] == nil {
            let created = Source(
                name: bibleSourceName,
                sourceType: .modernTranslation,
                author: "",
                language: "English",
                period: "",
                sourceDescription: bibleWorkDescription
            )
            context.insert(created)
            byName[bibleSourceName] = created
        }

        struct CitationSeed {
            let figure: String
            let sourceName: String
            let location: String
            let note: String
        }
        let citationSeeds: [CitationSeed] = [
            CitationSeed(figure: "Nephilim", sourceName: "Book of Enoch (1 Enoch)", location: "1 Enoch 6:7; 15:8-12",
                note: "Calls the offspring of the holy angels the Nephilim, and has them destroyed by being set against one another."),
            CitationSeed(figure: "Nephilim", sourceName: bibleSourceName, location: "Gen 6:4",
                note: "The Nephilim on the earth in those days, taking human wives; the verse that also reads them as the 'mighty ones'."),
            CitationSeed(figure: "Nephilim", sourceName: "Book of Jubilees", location: "Jub 4:15-16; 5:1-3",
                note: "Jubilees dates the birth of the Nephilim to the angelic unions and omits Cain's line from Seth onward."),
            CitationSeed(figure: "Anakim", sourceName: bibleSourceName, location: "Num 13:22-33; 33",
                note: "The spies report the Anakim in the hill country and name them as coming from the Nephilim."),
            CitationSeed(figure: "Rephaim", sourceName: bibleSourceName, location: "Deut 3:11; Josh 12:4; 2 Sam 21:18-22",
                note: "The Rephaim as the people of Og of Bashan and of the Gittite Goliath — the same race Genesis calls the Nephilim."),
            CitationSeed(figure: "Rephaim", sourceName: "Book of Enoch (1 Enoch)", location: "1 Enoch 8:12",
                note: "'The Rephaim of the Nephilim' — the pre-flood usage, where the name is the antediluvian generation rather than the remnant that survived the flood."),
            CitationSeed(figure: "Gibborim", sourceName: bibleSourceName, location: "Gen 6:4; Num 13:33; Deut 1:28",
                note: "gibborim, 'the mighty ones', the Hebrew of Genesis 6:4 that the Septuagint renders as gigantes."),
            CitationSeed(figure: "Emim", sourceName: bibleSourceName, location: "Deut 2:10-11",
                note: "The Emim of Seir, like the Anakim in strength and height, with a remnant left to this day."),
            CitationSeed(figure: "Zuzim", sourceName: bibleSourceName, location: "Gen 14:5",
                note: "The Zuzim of Hamm, struck down by the kings of the coalition in the Transjordan."),
            CitationSeed(figure: "Hahyah", sourceName: "Book of Enoch (1 Enoch)", location: "1 Enoch 6:13-15",
                note: "Named among the offspring of the holy angels — those the book calls Nephilim — in the generation Gabriel is sent against."),
            CitationSeed(figure: "Ohyah", sourceName: "Book of Enoch (1 Enoch)", location: "1 Enoch 6:13-15",
                note: "Named among the offspring of the holy angels, and named again among the giants of the Dead Sea Scrolls Book of Giants."),
            CitationSeed(figure: "Og of Bashan", sourceName: bibleSourceName, location: "Deut 3:11; Josh 12:4; 13:12",
                note: "Og as the last survivor of the remnant of the Rephaim, with an iron bed of thirteen cubits, and the last king of Bashan."),
        ]

        let allCitations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureNames = Set(allFigures.map { $0.name.lowercased() })

        for seed in citationSeeds {
            guard figureNames.contains(seed.figure.lowercased()) else { continue }
            let alreadyCited = allCitations.contains {
                $0.safeEntityType == .figure &&
                $0.safeEntityName.caseInsensitiveCompare(seed.figure) == .orderedSame &&
                $0.location == seed.location
            }
            guard !alreadyCited else { continue }
            let citation = Citation(
                source: byName[seed.sourceName],
                location: seed.location,
                note: seed.note,
                entityType: .figure,
                linkedEntityName: allFigures.first { $0.name.caseInsensitiveCompare(seed.figure) == .orderedSame }?.name ?? seed.figure
            )
            context.insert(citation)
        }

        Commit.save(context, "ensureNephilimCitations")
    }

    /// Attach the antediluvian generation to the flood that ended it, and record who was left.
    ///
    /// The store holds two flood events and they are not the same story. "The great Flood" is
    /// the Sumerian account — Enlil decrees the destruction of mankind, Enki warns Ziusudra,
    /// the ark — and it says nothing about giants; anchoring the Nephilim to it would be a
    /// category error. "The Deluge Judgment" is 1 Enoch 10:1-3, 106-107, and *is* about them:
    /// the flood is decreed as the judgment for the corruption brought by the Watchers and the
    /// Nephilim, and its own description says the flood cleansed the earth preserving only
    /// Noah's family. So the lookup is by that name, and nothing is attached if it is absent.
    ///
    /// The role types are seeded here because `EventFigureRoleType` is empty in the store: the
    /// event graph already has 20 figure links and no vocabulary at all to describe them.
    /// "destroyed by" / "survived" are written as a pair so the edge reads correctly from both
    /// ends. In the Enochic narrative the giants actually die in mutual strife (1 Enoch 8-9,
    /// 15) while the flood is the decree for the world's corruption — "destroyed by" is the
    /// frame the event itself states, not an invention.
    ///
    /// Additive + idempotent.
    package static func ensureNephilimFlood(context: ModelContext) {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let deluge = events.first { $0.name == "The Deluge Judgment" }
        guard let deluge else { return }
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        guard !figures.isEmpty else { return }

        struct RoleSeed {
            let name: String
            let icon: String
            let colorHex: String
            let reverseName: String
        }
        // Inserted rather than routed through `ensureTypesExist`, which cannot set reverseName.
        let roleSeeds: [RoleSeed] = [
            RoleSeed(name: "destroyed by", icon: "drop.triangle", colorHex: "DC2626", reverseName: "destroys"),
            RoleSeed(name: "survived", icon: "figure.walk", colorHex: "34C759", reverseName: "spared"),
        ]
        let existingRoles = (try? context.fetch(FetchDescriptor<EventFigureRoleType>())) ?? []
        var rolesByName = Dictionary(existingRoles.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        for seed in roleSeeds where rolesByName[seed.name] == nil {
            let created = EventFigureRoleType(name: seed.name, icon: seed.icon, colorHex: seed.colorHex, reverseName: seed.reverseName)
            context.insert(created)
            rolesByName[seed.name] = created
        }

        struct LinkSeed {
            let figure: String
            let role: String
        }
        let linkSeeds: [LinkSeed] = [
            LinkSeed(figure: "Nephilim", role: "destroyed by"),
            LinkSeed(figure: "Hahyah", role: "destroyed by"),
            LinkSeed(figure: "Ohyah", role: "destroyed by"),
            LinkSeed(figure: "Rephaim", role: "survived"),
            LinkSeed(figure: "Og of Bashan", role: "survived"),
        ]
        let manager = RelationshipManager(context: context)
        for seed in linkSeeds {
            guard let figure = figures.first(where: { $0.name.caseInsensitiveCompare(seed.figure) == .orderedSame }),
                  let role = rolesByName[seed.role] else { continue }
            manager.addEventFigureAssociation(event: deluge, figure: figure, roleType: role)
        }

        // "gibborim" is an epithet for the Nephilim, not a further people, so the second
        // "destroyed by" row this migration created for it was a second row for one referent.
        // Withdrawn, narrowly: the exact figure, event and role this function writes.
        if let gibborim = figures.first(where: { $0.name.caseInsensitiveCompare("Gibborim") == .orderedSame }),
           let destroyedBy = rolesByName["destroyed by"],
           let stale = (deluge.figureAssociations ?? []).first(where: {
               $0.figure?.persistentModelID == gibborim.persistentModelID &&
               $0.roleType?.persistentModelID == destroyedBy.persistentModelID
           }) {
do {
                try context.transaction {
                    deluge.figureAssociations?.removeAll { $0.persistentModelID == stale.persistentModelID }
                    gibborim.events.removeAll { $0.persistentModelID == deluge.persistentModelID }
                    deluge.involvedFigures.removeAll { $0.persistentModelID == gibborim.persistentModelID }
                    context.delete(stale)
                }
            } catch {
                nephilimMigrationLog.error("Nephilim model: withdrawing the duplicate 'destroyed by' link for Gibborim failed: \(error.localizedDescription, privacy: .public) — it is left in place and withdrawn again on the next launch")
            }
        }

        let stickyText = "\(nephilimStickyPrefix) — this generation is attached to 'The Deluge Judgment' (1 Enoch 10) and not to the store's other flood event 'The great Flood', which is the Sumerian story of Enlil, Enki and Ziusudra's ark and does not concern the giants. Nephilim, Hahyah and Ohyah are 'destroyed by' it; Rephaim and Og of Bashan are the post-flood remnant and are 'survived' by it. 'Gibborim' is not linked separately: it is an epithet for the Nephilim, so a second row would have counted one people twice. The two event-figure roles were seeded for this — the event graph had 20 figure links and no role vocabulary at all."
        if let nephilim = figures.first(where: { $0.name.caseInsensitiveCompare("Nephilim") == .orderedSame }),
           !nephilim.stickies.contains(where: { $0.text == stickyText }),
           !isStickyDismissed(textPrefix: nephilimStickyPrefix, entityKey: DuplicateMerger.normalizationKey(nephilim.name), context: context) {
            context.insert(StickyNote(text: stickyText, figure: nephilim))
        }

        Commit.save(context, "ensureNephilimFlood")
    }

    /// Remove the review notes that an earlier build of this migration wrote for the model it
    /// has since withdrawn.
    ///
    /// A sticky is not overwritten, only appended to, so a store that ran the earlier build now
    /// carries two notes on the same figure: one stating that the Nephilim were the umbrella
    /// over the Repha'îm and one saying that claim is withdrawn. The first is worse than
    /// useless now, because the user reads both.
    ///
    /// Deletion, so it matches on the full text — every string here is reproduced verbatim from
    /// the earlier build, including the prefix. A note you wrote yourself, or one of ours that
    /// has since been reworded, does not match and stays. The set is fixed, so this can only
    /// ever remove the eight notes it lists.
    package static func withdrawSupersededNephilimNotes(context: ModelContext) {
        let superseded: [(figure: String, text: String)] = [
            ("Nephilim", "\(nephilimStickyPrefix) — 'Nephilim' is modelled as the umbrella: a collective whose parts are named peoples, not a tribe of its own. It was previously typed 'Divine Collective', which is wrong — the Nephilim are the offspring of the Watchers, not gods — so it now sits on a collective type of its own. Anakim is linked as a member; Rephaim and Gibborim are other names for this class, so they are linked as local forms instead, which is what Deuteronomy 3:11, Joshua 12:4 and 2 Samuel 5:18-22 support."),
            ("Rephaim", "\(nephilimStickyPrefix) — Rephaim is kept as a separate figure but recorded as a name for the Nephilim rather than a branch of them: the Hebrew Bible and 1 Enoch use the two words of one race. It is dated after the flood and sourced to the Hebrew Bible, because every Rephaim in the Hebrew Bible is post-flood — the remnant in Bashan, the two Transjordan kingdoms, the Gittite Goliath, the Gittites of Gibeon — and the name survives precisely because it names the survivors. The pre-flood Enochic usage (1 Enoch 8:12) is kept as a citation. Two things follow: review whether you want it merged into Nephilim as an alternate name, and note that its era is the store's post-flood era, whose other contents are Sumerian dynasties — a Late Bronze Age era would be the honest home for Bashan and Gath."),
            ("Anakim", "\(nephilimStickyPrefix) — Anakim is recorded as a member of the Nephilim, on Numbers 13:33 ('the sons of the Anakim, who come from the Nephilim'), which is the one passage that makes it a branch rather than a synonym."),
            ("Emim", "\(nephilimStickyPrefix) — No edge to Nephilim is recorded for the Emim, on purpose: Deuteronomy 2:10-11 sets them beside the Anakim and the Rephaim as their own people, 'like the Anakim', without making them a branch of the Nephilim. If you want them under the umbrella, a membership row is the honest way to add it."),
            ("Zuzim", "\(nephilimStickyPrefix) — No edge to Nephilim is recorded for the Zuzim, on purpose: Genesis 14:5 has them as a Transjordan people already displaced centuries before the spies went out, and the passage does not place them inside the Nephilim."),
            ("Og of Bashan", "\(nephilimStickyPrefix) — Og is linked as a member of the Rephaim, not of the Nephilim: Deuteronomy 3:11 is the verse that puts him in that line ('the remnant of the Rephaim'), and it is a membership of a people rather than a synonymy, so it is the honest edge. He is also the one figure in this set that is a person rather than a people, which is why he stays on the 'Nephilim' type and keeps his parent slots."),
            ("Nephilim", "\(nephilimStickyPrefix) — this generation is attached to 'The Deluge Judgment' (1 Enoch 10) and not to the store's other flood event 'The great Flood', which is the Sumerian story of Enlil, Enki and Ziusudra's ark and does not concern the giants. Nephilim, Gibborim, Hahyah and Ohyah are 'destroyed by' it; Rephaim and Og of Bashan are the post-flood remnant and are 'survived' by it. The two event-figure roles were seeded for this — the event graph had 20 figure links and no role vocabulary at all."),
        ]
        // Hahyah's note is absent on purpose: its text is unchanged, so the note is still true
        // and the append-only loop below will not have created a second one.

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        var doomed: [StickyNote] = []
        for entry in superseded {
            guard let figure = figures.first(where: { $0.name.caseInsensitiveCompare(entry.figure) == .orderedSame }) else { continue }
            doomed.append(contentsOf: notes.filter { $0.text == entry.text && $0.figure?.persistentModelID == figure.persistentModelID })
        }
        guard !doomed.isEmpty else { return }
        do {
            try context.transaction {
                for note in doomed {
                    note.figure?.stickies.removeAll { $0.persistentModelID == note.persistentModelID }
                    context.delete(note)
                }
            }
        } catch {
            nephilimMigrationLog.error("Nephilim model: withdrawing \(doomed.count, privacy: .public) superseded review notes failed: \(error.localizedDescription, privacy: .public) — they are left in place and withdrawn again on the next launch")
        }
        Commit.save(context, "withdrawSupersededNephilimNotes")
    }

    /// Put the Enochic figures of the generation where they can be reached: a "Children of the
    /// Watchers" subgroup under the Enoch group (looked up by kind, falling back to the name,
    /// since the store's row is named "The Book of Enoch" while the seeder's default is "Book
    /// of Enoch"), plus review stickies recording the modelling decisions the user may want
    /// to overrule.
    ///
    /// Only the figures the Enochic books actually name go in the group — Nephilim, Gibborim,
    /// Hahyah and Ohyah. The rest are Hebrew Bible only and putting them in a section of
    /// 1 Enoch would assert a source they do not come from: the Anakim, Emim and Zuzim of the
    /// Transjordan (all after the flood), Og of Bashan, and Rephaim, whose Enochic usage
    /// (1 Enoch 8:12) is a citation rather than its source. Those five are reachable through
    /// their own type and citations instead. Additive + idempotent.
    package static func ensureNephilimGroup(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []

        // The review flags are raised whether or not the group exists — a store whose Enoch
        // group the user renamed out of recognition must still be told what was decided.
        struct StickySeed {
            let figure: String
            let text: String
        }
        let stickySeeds: [StickySeed] = [
            StickySeed(figure: "Nephilim", text: "\(nephilimStickyPrefix) — 'Nephilim' is the primeval generation of Genesis 6:4, modelled as a collective of its own because it names a generation rather than a tribe. It was previously typed 'Divine Collective', which is wrong — they are the offspring of the Watchers, not gods. It now has exactly one recorded member, the Anakim, and that edge is the weakest thing in this part of the model: it rests on Numbers 13:33, 'the Nephilim, the sons of Anak, from the Nephilim', which is circular as the Hebrew stands and which the Septuagint omits. The genealogy itself is Jubilees 15:8-12 and 1 Enoch, both cited here. An earlier build of this migration treated the Nephilim as an umbrella over the Anakim, the Rephaim and the Gibborim; that has been withdrawn, because no Torah text says the Repha'îm descend from them."),
            StickySeed(figure: "Rephaim", text: "\(nephilimStickyPrefix) — Repha'îm is what the Hebrew Bible uses as a heading for the great-statured Transjordan peoples, so it is modelled as a collective in its own right and the Anakim, Emim, Zuzim and Og of Bashan are members of it. An earlier build recorded no edge for the Emim and the Zuzim, reading Deuteronomy 2:11 and 2:20 as merely setting those peoples beside the Rephaim; those verses in fact count them with them, and 2:20 equates Ammon's Zamzummim with the Repha'îm outright. An earlier build also recorded a 'local form of the Nephilim' edge, on the grounds that the Hebrew Bible and 1 Enoch use the two words of one race. The first was a misreading of two verses, and the second is an identification made by 1 Enoch rather than by the Hebrew Bible, so that edge has been withdrawn. Two things remain for you: the same Hebrew word also means the shades of the dead in Sheol and names the Gathite warriors of 2 Samuel 21, which are not this people; and its era is the store's post-flood era, whose other contents are Sumerian dynasties — a Late Bronze Age era would be the honest home for Bashan and Gath."),
            StickySeed(figure: "Anakim", text: "\(nephilimStickyPrefix) — The Anakim are recorded as members of the Repha'îm, on Deuteronomy 2:11, which counts them with that category. They are also recorded as members of the Nephilim, and that second edge is the weaker of the two: it rests on Numbers 13:33, 'the Nephilim, the sons of Anak, from the Nephilim', which is circular as the Hebrew stands and is omitted by the Septuagint. The ancestry is really Jubilees and 1 Enoch. Note also that 'sons of Anak' is not a genealogy — it is the spies' taunt for a tall people, so no figure named Anak is implied by it, though Joshua 14:15 and 15:13 do give an Anak a son and a father in Judah."),
            StickySeed(figure: "Emim", text: "\(nephilimStickyPrefix) — The Emim are recorded as members of the Repha'îm, on Deuteronomy 2:11: 'for they are also counted as Repha'îm, but the Moabites call them Emim'. An earlier build of this migration deliberately recorded no edge for them at all, reading that same verse as setting the Emim beside the Repha'îm rather than under them; that was the misreading, and the membership is what the verse says. Genesis 14:5 lists the Emim as a people parallel to the Rephaim of Bashan, which is a reason to treat the Repha'îm as a category rather than as one tribe."),
            StickySeed(figure: "Zuzim", text: "\(nephilimStickyPrefix) — The Zuzim, called by the Ammonites Zamzummim, are recorded as members of the Repha'îm on Deuteronomy 2:20, which identifies the Repha'îm of Ammon with the Zamzummim. Genesis 14:5 lists the Zuzim instead as a people parallel to the Rephaim of Bashan, the Emim and the Sheshites, so the sources disagree on whether they are a tribe within the Repha'îm or a separate people. The membership follows Deuteronomy; the conflict is recorded on the figure rather than resolved."),
            StickySeed(figure: "Gibborim", text: "\(nephilimStickyPrefix) — 'Gibborim' is a common noun, 'the mighty ones', and not the name of a people. Genesis 6:4 reads 'the Nephilim, the mighty ones'. An earlier build of this migration gave it a 'local form of the Nephilim' edge, on the reading that it named a tribe or a class of the giants; that edge has been withdrawn. The word is kept as a figure so it stays findable, the epithet is carried on the Nephilim as an alternate name, and it has no membership roll and no place among the named giants."),
            StickySeed(figure: "Anakim", text: "\(nephilimStickyPrefix) — This figure's description is your own prose, so it was left exactly as written, but one sentence in it now describes a model this app no longer asserts: it says the Anakim were descendants of the Nephilim. That is Numbers 13:33 read straight, and Num 13:33 is circular in the Hebrew and omits the clause in the Septuagint. The membership edges below were corrected either way, so the description and the graph now disagree — worth a sentence of your own. Deuteronomy 2:11, which counts the Anakim with the Repha'îm, is the firmer ground."),
            StickySeed(figure: "Rephaim", text: "\(nephilimStickyPrefix) — This figure's description is your own prose, so it was left exactly as written, but it is worded for the model this migration has just withdrawn. It calls the Repha'îm 'a term often used interchangeably or alongside the Nephilim to describe a race of ancient giants'. The Hebrew Bible never equates the two: it uses the Repha'îm as an ethnic heading for the Transjordan peoples, and the identification with the Nephilim comes from 1 Enoch and Jubilees. The graph now says so — Rephaim is a collective with the Anakim, Emim, Zuzim and Og in it — so the description is now the part that is out of step. Two senses of the word it does not mention are also absent from it: the shades of the dead, and the Gathite warriors of 2 Samuel 21."),
            StickySeed(figure: "Emim", text: "\(nephilimStickyPrefix) — This figure's description is your own prose and was left as written; it says the Emim are 'comparable in size and stature to the Anakim', which is right and remains right. It does not say where they belong, and the answer is now recorded on the figure: Deuteronomy 2:11 counts them with the Repha'îm, not with the Nephilim. No edit needed unless you want the verse quoted."),
            StickySeed(figure: "Zuzim", text: "\(nephilimStickyPrefix) — This figure's description is your own prose and was left as written; it calls the Zuzim 'an ancient giant clan residing in the territory of Ammon', which stands. One point it does not have: Deuteronomy 2:20 gives the Ammonite name for the Repha'îm as Zamzummim, which is the membership now recorded, while Genesis 14:5 lists the Zuzim as a people parallel to the Rephaim of Bashan. The two verses disagree and the graph follows Deuteronomy."),
            StickySeed(figure: "Og of Bashan", text: "\(nephilimStickyPrefix) — Og is a member of the Repha'îm, not of the Nephilim: Deuteronomy 3:11 is the verse that puts him in that line ('the remnant of the Repha'îm'), and that is a membership of a people rather than a synonymy. He is a person rather than a people, so he stays on the 'Nephilim' type and keeps his parent slots."),
            StickySeed(figure: "Hahyah", text: "\(nephilimStickyPrefix) — Hahyah and Ohyah are people, not peoples: the Book of Enoch lists them among the named offspring of the holy angels. They stay on the 'Nephilim' type, which is left uncategorised for exactly this reason, and no membership row was added — the Enochic lists name them but do not give them a father this app could record."),
        ]
        for seed in stickySeeds {
            guard let figure = allFigures.first(where: { $0.name.caseInsensitiveCompare(seed.figure) == .orderedSame }) else { continue }
            if figure.stickies.contains(where: { $0.text == seed.text }) { continue }
            let entityKey = DuplicateMerger.normalizationKey(figure.name)
            guard !isStickyDismissed(textPrefix: nephilimStickyPrefix, entityKey: entityKey, context: context) else { continue }
            context.insert(StickyNote(text: seed.text, figure: figure))
        }

        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        if let enochGroup = allGroups.first(where: { $0.parentGroup == nil && $0.kind == .enoch })
            ?? allGroups.first(where: { $0.parentGroup == nil && ($0.name == "The Book of Enoch" || $0.name == "Book of Enoch") }) {
            let subgroup: FigureGroup
            if let existing = enochGroup.sortedSubgroups.first(where: { $0.name == "Children of the Watchers" }) {
                subgroup = existing
            } else {
                let created = FigureGroup(
                    name: "Children of the Watchers",
                    groupDescription: "The named offspring of the angels in 1 Enoch — the Nephilim and the giants of that generation",
                    icon: "person.3",
                    colorHex: "DC2626",
                    orderIndex: 5,
                    kind: .enoch,
                    entityType: .figure,
                    sortMode: .ordered,
                    memberSingular: "person",
                    memberPlural: "people"
                )
                context.insert(created)
                enochGroup.subgroups?.append(created)
                subgroup = created
            }

            let enochicNames = ["Nephilim", "Hahyah", "Ohyah"]
            for (index, name) in enochicNames.enumerated() {
                guard let figure = allFigures.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
                if figure.groupAssociations.contains(where: { $0.group?.persistentModelID == subgroup.persistentModelID }) { continue }
                let assoc = FigureGroupAssociation(figure: figure, orderIndex: index)
                context.insert(assoc)
                figure.groupAssociations.append(assoc)
                subgroup.figureAssociations.append(assoc)
            }

            // The section is "Children of the Watchers", so it holds the Enochic generation.
            // Rephaim and Gibborim were placed here by an earlier build that read them as
            // names for the Nephilim; under the corrected model the Repha'îm are a post-flood
            // ethnic category and "gibborim" is a common noun, so neither is a child of the
            // Watchers. Narrow to the two figures this migration added to that subgroup.
            for name in ["Rephaim", "Gibborim"] {
                guard let figure = allFigures.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { continue }
                let stale = figure.groupAssociations.filter {
                    $0.group?.persistentModelID == subgroup.persistentModelID
                }
                guard !stale.isEmpty else { continue }
                do {
                    try context.transaction {
                        for assoc in stale {
                            figure.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                            subgroup.figureAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                            context.delete(assoc)
                        }
                    }
                } catch {
                    nephilimMigrationLog.error("Nephilim model: withdrawing \(name, privacy: .public) from 'Children of the Watchers' failed: \(error.localizedDescription, privacy: .public) — it is left in place and withdrawn again on the next launch")
                }
            }
        }

        Commit.save(context, "ensureNephilimGroup")
    }
}
