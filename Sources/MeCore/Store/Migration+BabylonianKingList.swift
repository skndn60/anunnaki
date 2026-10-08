import Foundation
import SwiftData

extension Migration {
    /// One ruler of the Babylonian King List as given in the succession table of
    /// "List of kings of Babylon" (Wikipedia). `startYear`/`endYear` are the page's
    /// regnal bounds, negative for BCE; both are `nil` where the page prints "??",
    /// which is most of the Sealand and middle Kassite kings. Nothing here is a date
    /// the king list itself supplies — it gives succession, not absolute chronology.
    package struct BabylonianKingListRuler {
        package let dynasty: Int
        package let name: String
        package let startYear: Int?
        package let endYear: Int?
        package let note: String
    }

    /// Dynasties I–X of the Babylonian king-list tradition, in ruling order within
    /// each dynasty. Dynasties II and V (the Sealand lines) held the south
    /// concurrently with the northern dynasties and are therefore not one strict
    /// succession; each is keyed to its own dynasty number so the group order can
    /// interleave them. Seven rulers held Babylon twice with a usurper in between
    /// (Sennacherib, Ashurbanipal, Marduk-apla-iddina II and, beyond this range,
    /// Darius I, Xerxes I, Demetrius I and Phraates II); for those the span below
    /// is the outer bounding box from first accession to final deposition and the
    /// note records the interruption.
    package static let babylonianKingListRulers: [BabylonianKingListRuler] = [
        // Dynasty I (Amorite)
        .init(dynasty: 1, name: "Sumu-abum", startYear: (-1894), endYear: (-1881), note: "First king of Babylon in BKLa and BKLb"),
        .init(dynasty: 1, name: "Sumu-la-El", startYear: (-1880), endYear: (-1845), note: "Unclear succession"),
        .init(dynasty: 1, name: "Sabium", startYear: (-1844), endYear: (-1831), note: "Son of Sumu-la-El"),
        .init(dynasty: 1, name: "Apil-Sin", startYear: (-1830), endYear: (-1813), note: "Son of Sabium"),
        .init(dynasty: 1, name: "Sin-Muballit", startYear: (-1812), endYear: (-1793), note: "Son of Apil-Sin"),
        .init(dynasty: 1, name: "Hammurabi", startYear: (-1792), endYear: (-1750), note: "Son of Sin-Muballit"),
        .init(dynasty: 1, name: "Samsu-iluna", startYear: (-1749), endYear: (-1712), note: "Son of Hammurabi"),
        .init(dynasty: 1, name: "Abi-Eshuh", startYear: (-1711), endYear: (-1684), note: "Son of Samsu-iluna"),
        .init(dynasty: 1, name: "Ammi-Ditana", startYear: (-1683), endYear: (-1647), note: "Son of Abi-Eshuh"),
        .init(dynasty: 1, name: "Ammi-Saduqa", startYear: (-1646), endYear: (-1626), note: "Son of Ammi-Ditana"),
        .init(dynasty: 1, name: "Samsu-Ditana", startYear: (-1625), endYear: (-1595), note: "Son of Ammi-Saduqa"),
        // Dynasty II (Sealand)
        .init(dynasty: 2, name: "Ilum-ma-ili", startYear: (-1725), endYear: nil, note: "Unclear succession"),
        .init(dynasty: 2, name: "Itti-ili-nibi", startYear: nil, endYear: nil, note: "Unclear succession"),
        .init(dynasty: 2, name: "Damqi-ilishu", startYear: nil, endYear: nil, note: "Unclear succession"),
        .init(dynasty: 2, name: "Ishkibal", startYear: nil, endYear: nil, note: "Unclear succession"),
        .init(dynasty: 2, name: "Shushushi", startYear: nil, endYear: nil, note: "Brother of Ishkibal"),
        .init(dynasty: 2, name: "Gulkishar", startYear: nil, endYear: nil, note: "Unclear succession"),
        .init(dynasty: 2, name: "Peshgaldaramesh", startYear: (-1599), endYear: (-1549), note: "Son of Gulkishar"),
        .init(dynasty: 2, name: "Ayadaragalama", startYear: (-1548), endYear: (-1520), note: "Son of Peshgaldaramesh"),
        .init(dynasty: 2, name: "Akurduana", startYear: (-1519), endYear: (-1493), note: "Unclear succession"),
        .init(dynasty: 2, name: "Melamkurkurra", startYear: (-1492), endYear: (-1485), note: "Unclear succession"),
        .init(dynasty: 2, name: "Ea-gamil", startYear: (-1484), endYear: (-1475), note: "Unclear succession"),
        // Dynasty III (Kassite)
        .init(dynasty: 3, name: "Gandash", startYear: (-1729), endYear: (-1704), note: "Unclear succession"),
        .init(dynasty: 3, name: "Agum I", startYear: (-1703), endYear: (-1682), note: "Son of Gandash"),
        .init(dynasty: 3, name: "Kashtiliash I", startYear: (-1681), endYear: (-1660), note: "Son of Agum I"),
        .init(dynasty: 3, name: "Abi-Rattash", startYear: nil, endYear: nil, note: "Son of Kashtiliash I"),
        .init(dynasty: 3, name: "Kashtiliash II", startYear: nil, endYear: nil, note: "Unclear succession"),
        .init(dynasty: 3, name: "Urzigurumash", startYear: nil, endYear: nil, note: "Descendant of Abi-Rattash (?)"),
        .init(dynasty: 3, name: "Agum II", startYear: nil, endYear: nil, note: "Son of Urzigurumash"),
        .init(dynasty: 3, name: "Harba-Shipak", startYear: nil, endYear: nil, note: "Unclear succession"),
        .init(dynasty: 3, name: "Shipta'ulzi", startYear: nil, endYear: nil, note: "Unclear succession"),
        .init(dynasty: 3, name: "Burnaburiash I", startYear: (-1530), endYear: (-1500), note: "Unclear succession, earliest Kassite ruler confidently attested as ruling Babylon itself"),
        .init(dynasty: 3, name: "Ulamburiash", startYear: (-1475), endYear: nil, note: "Son of Burnaburiash I (?), reunified Babylonia through defeating Ea-gamil, the last king of the first Sealand dynasty"),
        .init(dynasty: 3, name: "Kashtiliash III", startYear: nil, endYear: nil, note: "Son of Burnaburiash I (?)"),
        .init(dynasty: 3, name: "Agum III", startYear: nil, endYear: nil, note: "Son of Kashtiliash III"),
        .init(dynasty: 3, name: "Karaindash", startYear: (-1415), endYear: nil, note: "Unclear succession"),
        .init(dynasty: 3, name: "Kadashman-Harbe I", startYear: (-1400), endYear: nil, note: "Son of Karaindash (?)"),
        .init(dynasty: 3, name: "Kurigalzu I", startYear: nil, endYear: nil, note: "Son of Kadashman-harbe I"),
        .init(dynasty: 3, name: "Kadashman-Enlil I", startYear: (-1374), endYear: (-1360), note: "Son of Kurigalzu I (?)"),
        .init(dynasty: 3, name: "Burnaburiash II", startYear: (-1359), endYear: (-1333), note: "Son of Kadashman-Enlil I (?)"),
        .init(dynasty: 3, name: "Kara-hardash", startYear: (-1333), endYear: (-1333), note: "Son of Burnaburiash II (?)"),
        .init(dynasty: 3, name: "Nazi-Bugash", startYear: (-1333), endYear: (-1333), note: "Usurper, unrelated to other kings"),
        .init(dynasty: 3, name: "Kurigalzu II", startYear: (-1332), endYear: (-1308), note: "Son of Burnaburiash II"),
        .init(dynasty: 3, name: "Nazi-Maruttash", startYear: (-1307), endYear: (-1282), note: "Son of Kurigalzu II"),
        .init(dynasty: 3, name: "Kadashman-Turgu", startYear: (-1281), endYear: (-1264), note: "Son of Nazi-Maruttash"),
        .init(dynasty: 3, name: "Kadashman-Enlil II", startYear: (-1263), endYear: (-1255), note: "Son of Kadashman-Turgu"),
        .init(dynasty: 3, name: "Kudur-Enlil", startYear: (-1254), endYear: (-1246), note: "Son of Kadashman-Enlil II"),
        .init(dynasty: 3, name: "Shagarakti-Shuriash", startYear: (-1245), endYear: (-1233), note: "Son of Kudur-Enlil"),
        .init(dynasty: 3, name: "Kashtiliash IV", startYear: (-1232), endYear: (-1225), note: "Son of Shagarakti-Shuriash"),
        .init(dynasty: 3, name: "Enlil-nadin-shumi", startYear: (-1224), endYear: (-1224), note: "Unclear succession"),
        .init(dynasty: 3, name: "Kadashman-Harbe II", startYear: (-1223), endYear: (-1223), note: "Unclear succession"),
        .init(dynasty: 3, name: "Adad-shuma-iddina", startYear: (-1222), endYear: (-1217), note: "Unclear succession"),
        .init(dynasty: 3, name: "Adad-shuma-usur", startYear: (-1216), endYear: (-1187), note: "Son of Kashtiliash IV (?)"),
        .init(dynasty: 3, name: "Meli-Shipak", startYear: (-1186), endYear: (-1172), note: "Son of Adad-shuma-usur"),
        .init(dynasty: 3, name: "Marduk-apla-iddina I", startYear: (-1171), endYear: (-1159), note: "Son of Meli-Shipak"),
        .init(dynasty: 3, name: "Zababa-shuma-iddin", startYear: (-1158), endYear: (-1158), note: "Unclear succession"),
        .init(dynasty: 3, name: "Enlil-nadin-ahi", startYear: (-1157), endYear: (-1155), note: "Unclear succession"),
        // Dynasty IV (Second Isin)
        .init(dynasty: 4, name: "Marduk-kabit-ahheshu", startYear: (-1153), endYear: (-1136), note: "Unclear succession"),
        .init(dynasty: 4, name: "Itti-Marduk-balatu", startYear: (-1135), endYear: (-1128), note: "Son of Marduk-kabit-ahheshu"),
        .init(dynasty: 4, name: "Ninurta-nadin-shumi", startYear: (-1127), endYear: (-1122), note: "Relative of Itti-Marduk-balatu (?)"),
        .init(dynasty: 4, name: "Nebuchadnezzar I", startYear: (-1121), endYear: (-1100), note: "Son of Ninurta-nadin-shumi"),
        .init(dynasty: 4, name: "Enlil-nadin-apli", startYear: (-1099), endYear: (-1096), note: "Son of Nebuchadnezzar I"),
        .init(dynasty: 4, name: "Marduk-nadin-ahhe", startYear: (-1095), endYear: (-1078), note: "Son of Ninurta-nadin-shumi, usurped the throne from Enlil-nadin-apli"),
        .init(dynasty: 4, name: "Marduk-shapik-zeri", startYear: (-1077), endYear: (-1065), note: "Son of Marduk-nadin-ahhe (?)"),
        .init(dynasty: 4, name: "Adad-apla-iddina", startYear: (-1064), endYear: (-1043), note: "Usurper, unrelated to previous kings"),
        .init(dynasty: 4, name: "Marduk-ahhe-eriba", startYear: (-1042), endYear: (-1042), note: "Unclear succession"),
        .init(dynasty: 4, name: "Marduk-zer-X", startYear: (-1041), endYear: (-1030), note: "Unclear succession"),
        .init(dynasty: 4, name: "Nabu-shum-libur", startYear: (-1029), endYear: (-1022), note: "Unclear succession"),
        // Dynasty V (Sealand)
        .init(dynasty: 5, name: "Simbar-shipak", startYear: (-1021), endYear: (-1004), note: "Probably of Kassite descent, unclear succession"),
        .init(dynasty: 5, name: "Ea-mukin-zeri", startYear: (-1004), endYear: (-1004), note: "Probably of Kassite descent (Bit-Hashmar clan), usurped the throne from Simbar-Shipak"),
        .init(dynasty: 5, name: "Kashshu-nadin-ahi", startYear: (-1003), endYear: (-1001), note: "Probably of Kassite descent, son of Simbar-shipak (?)"),
        // Dynasty VI (Bazi)
        .init(dynasty: 6, name: "Eulmash-shakin-shumi", startYear: (-1000), endYear: (-984), note: "Possibly of Kassite descent (Bit-Bazi clan), unclear succession"),
        .init(dynasty: 6, name: "Ninurta-kudurri-usur I", startYear: (-983), endYear: (-981), note: "Possibly of Kassite descent (Bit-Bazi clan), unclear succession"),
        .init(dynasty: 6, name: "Shirikti-shuqamuna", startYear: (-981), endYear: (-981), note: "Possibly of Kassite descent (Bit-Bazi clan), brother of Ninurta-kudurri-usur I"),
        // Dynasty VII (Elamite)
        .init(dynasty: 7, name: "Mar-biti-apla-usur", startYear: (-980), endYear: (-975), note: "Elamite, or more likely of Elamite ancestry, unclear succession"),
        // Dynasty VIII (Babylonian)
        .init(dynasty: 8, name: "Nabu-mukin-apli", startYear: (-974), endYear: (-939), note: "Babylonian, unclear succession"),
        .init(dynasty: 8, name: "Ninurta-kudurri-usur II", startYear: (-939), endYear: (-939), note: "Babylonian, son of Nabu-mukin-apli"),
        .init(dynasty: 8, name: "Mar-biti-ahhe-iddina", startYear: (-938), endYear: nil, note: "Babylonian, son of Nabu-mukin-apli"),
        .init(dynasty: 8, name: "Shamash-mudammiq", startYear: (-901), endYear: nil, note: "Babylonian, unclear succession"),
        .init(dynasty: 8, name: "Nabu-shuma-ukin I", startYear: (-900), endYear: (-887), note: "Babylonian, unclear succession"),
        .init(dynasty: 8, name: "Nabu-apla-iddina", startYear: (-886), endYear: (-853), note: "Babylonian, son of Nabu-shuma-ukin I"),
        .init(dynasty: 8, name: "Marduk-zakir-shumi I", startYear: (-852), endYear: (-825), note: "Babylonian, son of Nabu-apla-iddina"),
        .init(dynasty: 8, name: "Marduk-balassu-iqbi", startYear: (-824), endYear: (-813), note: "Babylonian, son of Marduk-zakir-shumi I"),
        .init(dynasty: 8, name: "Baba-aha-iddina", startYear: (-813), endYear: (-812), note: "Babylonian, unclear succession"),
        .init(dynasty: 8, name: "Ninurta-apla-X", startYear: nil, endYear: nil, note: "Babylonian, unclear succession"),
        .init(dynasty: 8, name: "Marduk-bel-zeri", startYear: nil, endYear: nil, note: "Babylonian, unclear succession"),
        .init(dynasty: 8, name: "Marduk-apla-usur", startYear: (-769), endYear: nil, note: "Chaldean chief of an uncertain tribe, unclear succession"),
        .init(dynasty: 8, name: "Eriba-Marduk", startYear: (-769), endYear: (-760), note: "Chaldean chief of the Bit-Yakin tribe, unclear succession"),
        .init(dynasty: 8, name: "Nabu-shuma-ishkun", startYear: (-760), endYear: (-748), note: "Chaldean chief of the Bit-Dakkuri tribe, unclear succession"),
        .init(dynasty: 8, name: "Nabonassar", startYear: (-748), endYear: (-734), note: "Babylonian, unclear succession"),
        .init(dynasty: 8, name: "Nabu-nadin-zeri", startYear: (-734), endYear: (-732), note: "Babylonian, son of Nabonassar"),
        .init(dynasty: 8, name: "Nabu-shuma-ukin II", startYear: (-732), endYear: (-732), note: "Babylonian, unclear succession"),
        // Dynasty IX (Assyrian)
        .init(dynasty: 9, name: "Nabu-mukin-zeri", startYear: (-732), endYear: (-729), note: "Chaldean chief of the Bit-Amukkani tribe, usurped the throne"),
        .init(dynasty: 9, name: "Tiglath-Pileser III", startYear: (-729), endYear: (-727), note: "King of the Neo-Assyrian Empire — conquered Babylon"),
        .init(dynasty: 9, name: "Shalmaneser V", startYear: (-727), endYear: (-722), note: "King of the Neo-Assyrian Empire — son of Tiglath-Pileser III"),
        .init(dynasty: 9, name: "Marduk-apla-iddina II", startYear: (-722), endYear: (-703), note: "Chaldean chief of the Bit-Yakin tribe, retook the throne. Held the throne in two reigns with a usurper between."),
        .init(dynasty: 9, name: "Sargon II", startYear: (-710), endYear: (-705), note: "King of the Neo-Assyrian Empire — son of Tiglath-Pileser III (?)"),
        .init(dynasty: 9, name: "Sennacherib", startYear: (-705), endYear: (-681), note: "King of the Neo-Assyrian Empire — son of Sargon II. Held the throne in two reigns with a usurper between."),
        .init(dynasty: 9, name: "Marduk-zakir-shumi II", startYear: (-703), endYear: (-703), note: "Babylonian rebel of the Arad-Ea family, rebel king"),
        .init(dynasty: 9, name: "Bel-ibni", startYear: (-703), endYear: (-700), note: "Babylonian vassal king of the Rab-bānî family, appointed by Sennacherib"),
        .init(dynasty: 9, name: "Aššur-nādin-šumi", startYear: (-700), endYear: (-694), note: "Son of Sennacherib, appointed as vassal king by his father"),
        .init(dynasty: 9, name: "Nergal-ushezib", startYear: (-694), endYear: (-693), note: "Babylonian rebel of the Gaḫal kin family, rebel king"),
        .init(dynasty: 9, name: "Mushezib-Marduk", startYear: (-693), endYear: (-689), note: "Chaldean chief of the Bit-Dakkuri tribe, rebel king"),
        .init(dynasty: 9, name: "Esarhaddon", startYear: (-681), endYear: (-669), note: "King of the Neo-Assyrian Empire — son of Sennacherib"),
        .init(dynasty: 9, name: "Ashurbanipal", startYear: (-669), endYear: (-646), note: "King of the Neo-Assyrian Empire — son of Esarhaddon. Held the throne in two reigns with a usurper between."),
        .init(dynasty: 9, name: "Šamaš-šuma-ukin", startYear: (-668), endYear: (-648), note: "Son of Esarhaddon, designated by his father as heir to Babylon, invested as vassal king by Ashurbanipal"),
        .init(dynasty: 9, name: "Kandalanu", startYear: (-647), endYear: (-627), note: "Appointed as vassal king by Ashurbanipal"),
        .init(dynasty: 9, name: "Sin-shumu-lishir", startYear: (-626), endYear: (-626), note: "Usurper in the Neo-Assyrian Empire — recognised in Babylonia"),
        .init(dynasty: 9, name: "Sinsharishkun", startYear: (-626), endYear: (-626), note: "King of the Neo-Assyrian Empire — son of Ashurbanipal"),
        // Dynasty X (Chaldean)
        .init(dynasty: 10, name: "Nabopolassar", startYear: (-626), endYear: (-605), note: "Babylonian rebel, defeated Sinsharishkun"),
        .init(dynasty: 10, name: "Nebuchadnezzar II", startYear: (-605), endYear: (-562), note: "Son of Nabopolassar"),
        .init(dynasty: 10, name: "Amel-Marduk", startYear: (-562), endYear: (-560), note: "Son of Nebuchadnezzar II"),
        .init(dynasty: 10, name: "Neriglissar", startYear: (-560), endYear: (-556), note: "Son-in-law of Nebuchadnezzar II, usurped the throne"),
        .init(dynasty: 10, name: "Labashi-Marduk", startYear: (-556), endYear: (-556), note: "Son of Neriglissar"),
        .init(dynasty: 10, name: "Nabonidus", startYear: (-556), endYear: (-539), note: "Son-in-law of Nebuchadnezzar II (?), usurped the throne, co-rulers: Nitocris and Belshazzar"),
    ]

    /// Dynasty metadata for the ten numbered dynasties. `orderIndex` continues the
    /// post-SKL ruling lane that `ensureFirstBabylonianDynasty` occupies at 31;
    /// `concurrentWith` marks a line that was not the sole ruler of Babylon and so
    /// cannot be placed in one unbroken sequence with its neighbours.
    package struct BabylonianDynasty {
        package let number: Int
        package let roman: String
        package let name: String
        package let ethnonym: String
        package let startYear: Int?
        package let endYear: Int?
        package let concurrentWith: String?
        package let summary: String
    }

    package static let babylonianDynasties: [BabylonianDynasty] = [
        .init(number: 1, roman: "I", name: "First Dynasty of Babylon", ethnonym: "Amorite", startYear: -1894, endYear: -1595, concurrentWith: nil, summary: "Amorite dynasty of Babylon, the first dynasty of the Old Babylonian period; eleven kings from Sumu-abum to Samsu-ditana, ending when Mursili I sacked the city."),
        .init(number: 2, roman: "II", name: "First Dynasty of the Sealand", ethnonym: "Sealand", startYear: -1725, endYear: -1475, concurrentWith: "Dynasties I and III", summary: "The Sealand line, ruled from the marsh country at the mouth of the Euphrates rather than Babylon itself; it overlaps Dynasties I and III in time."),
        .init(number: 3, roman: "III", name: "Kassite Dynasty of Babylon", ethnonym: "Kassite", startYear: -1729, endYear: -1155, concurrentWith: nil, summary: "Kassite dynasty of Babylon, the longest of any, overlaying Hurrian and Hittite rulers at the top of the sequence and interrupted by Elamite and Aramean claimants."),
        .init(number: 4, roman: "IV", name: "Second Dynasty of Isin", ethnonym: "Second Isin", startYear: -1153, endYear: -1022, concurrentWith: nil, summary: "Second dynasty of Isin, an Aramean line descending from Nebuchadnezzar I that ended when the Kassite king Meli-Shipak took the throne."),
        .init(number: 5, roman: "V", name: "Second Dynasty of the Sealand", ethnonym: "Sealand", startYear: -1021, endYear: -1001, concurrentWith: "Dynasty VI", summary: "Second Sealand line, holding southern Babylonia while the Bazi dynasty ruled in the north."),
        .init(number: 6, roman: "VI", name: "Bazi Dynasty", ethnonym: "Bazi", startYear: -1000, endYear: -981, concurrentWith: nil, summary: "The Bazi dynasty, possibly of Kassite descent, named for the Bit-Bazi clan; contemporaneous with the Second Sealand line."),
        .init(number: 7, roman: "VII", name: "Elamite Dynasty", ethnonym: "Elamite", startYear: -980, endYear: -975, concurrentWith: "Dynasty VIII", summary: "Elamite occupation of Babylon, ruled from Susa in Elam; Mar-biti-apla-usur was probably an Elamite of local Babylonian ancestry."),
        .init(number: 8, roman: "VIII", name: "Second Dynasty of Babylon", ethnonym: "Babylonian", startYear: -974, endYear: -732, concurrentWith: nil, summary: "Second dynasty of Babylon, native name palû e ('dynasty of E'); its kings are not a family line but a sequence of successive rulers, including several Chaldean tribal chiefs who took the throne by force."),
        .init(number: 9, roman: "IX", name: "Assyrian Dynasty of Babylon", ethnonym: "Assyrian", startYear: -732, endYear: -626, concurrentWith: nil, summary: "Assyrian dynasty of Babylon: the Neo-Assyrian kings who ruled the city as viceroys, interleaved with the local rebel and vassal kings who held it between their occupations."),
        .init(number: 10, roman: "X", name: "Chaldean Dynasty", ethnonym: "Chaldean", startYear: -626, endYear: -539, concurrentWith: nil, summary: "Chaldean dynasty of Babylon, ending in the Neo-Babylonian Empire with Nabonidus."),
    ]

    /// `Era.orderIndex` for each dynasty, appended after the existing post-SKL lane so
    /// no era the user already has is renumbered.
    package static let babylonianDynastyOrderIndex: [String: Int] = [
        "First Dynasty of Babylon": 31,
        "First Dynasty of the Sealand": 48,
        "Kassite Dynasty of Babylon": 49,
        "Second Dynasty of Isin": 50,
        "Second Dynasty of the Sealand": 51,
        "Bazi Dynasty": 52,
        "Elamite Dynasty": 53,
        "Second Dynasty of Babylon": 54,
        "Assyrian Dynasty of Babylon": 55,
        "Chaldean Dynasty": 56,
    ]

    /// Creates Dynasties II–X of the Babylonian king list as first-class data: one
    /// `Era` per dynasty carrying the era's span and a summary of what the dynasty
    /// was, the rulers as `Figure`s filed under that era in accession order, and a
    /// citation each to the king list (for the succession) and to the modern
    /// compilation the regnal dates were taken from.
    ///
    /// Dynasty I is not seeded here — `ensureFirstBabylonianDynasty` already owns
    /// "First Dynasty of Babylon" and its eleven rulers, and running two seeders
    /// over the same dynasty is how a duplicate era appears. This migration adopts
    /// that era instead of creating a tenth.
    ///
    /// No father-to-son edges are written. A king list records *succession*, not
    /// filiation, and for the Sealand lines the two dynasties are contemporaneous
    /// rather than sequential, so consecutive rows in this table are not
    /// father-and-son. Dynasty VIII's own heading says as much: its kings "did not
    /// constitute a series of coherent familial relationships". Deriving lineage
    /// from row order would put a father on the ruler who merely followed him.
    ///
    /// Additive + idempotent. Existing figures are matched on normalized name (so
    /// user spellings win) and only blank fields are filled; a ruler the user has
    /// filed under some other era keeps that era, which is what keeps the Assyrian
    /// viceroys of Dynasty IX under their Assyrian period instead of being moved
    /// onto a Babylonian one. Missing figures, eras and citations are created;
    /// nothing is deleted.
    package static func ensureBabylonianKingListDynasties(context: ModelContext) {
        let manager = RelationshipManager(context: context)
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        var eraByKey: [String: Era] = [:]
        for era in eras {
            let key = NameDuplicateCheck.normalizedKey(era.name)
            if eraByKey[key] == nil { eraByKey[key] = era }
        }

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var figureByKey: [String: Figure] = [:]
        for figure in figures {
            let key = NameDuplicateCheck.normalizedKey(figure.name)
            if figureByKey[key] == nil { figureByKey[key] = figure }
        }

        let humanType = (try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate<FigureType> { $0.name == "Human" })))?.first
        let kingListSource = babylonianKingListSource(context: context)
        let chronologySource = babylonianKingListChronologySource(context: context)

        // Dynasty I is owned by ensureFirstBabylonianDynasty; its era is reused so
        // the seed below lands in the dynasty the user already has.
        var dynastyEra: [Int: Era] = [:]
        for dynasty in babylonianDynasties where dynasty.number != 1 {
            let key = NameDuplicateCheck.normalizedKey(dynasty.name)
            let era: Era
            if let existing = eraByKey[key] {
                era = existing
                if existing.eraDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    existing.eraDescription = dynasty.summary
                }
                if existing.startDate.startYear == nil, let start = dynasty.startYear {
                    existing.startDate = MythologicalDate(startYear: start, endYear: dynasty.endYear, era: dynasty.name, isApproximate: true)
                }
                if existing.endDate.endYear == nil, let end = dynasty.endYear {
                    existing.endDate = MythologicalDate(year: end, era: dynasty.name, isApproximate: true)
                }
            } else {
                let created = Era(
                    name: dynasty.name,
                    orderIndex: babylonianDynastyOrderIndex[dynasty.name] ?? 48,
                    eraDescription: dynasty.summary,
                    startDate: MythologicalDate(startYear: dynasty.startYear ?? 0, endYear: dynasty.endYear, era: dynasty.name, isApproximate: true),
                    endDate: MythologicalDate(year: dynasty.endYear ?? 0, era: dynasty.name, isApproximate: true)
                )
                context.insert(created)
                eraByKey[key] = created
                era = created
            }
            dynastyEra[dynasty.number] = era
        }
        dynastyEra[1] = eraByKey[NameDuplicateCheck.normalizedKey(firstBabylonianEraName)]

        for (index, ruler) in babylonianKingListRulers.enumerated() {
            guard let era = dynastyEra[ruler.dynasty] else { continue }
            let key = NameDuplicateCheck.normalizedKey(ruler.name)
            let figure: Figure
            if let match = figureByKey[key] {
                figure = match
            } else {
                let created = Figure(
                    name: ruler.name,
                    title: "King of Babylon",
                    figureType: humanType,
                    gender: .male,
                    domain: "Babylonia",
                    figureDescription: babylonianKingDescription(ruler, eraName: era.name),
                    source: kingListSource.name,
                    orderIndex: index
                )
                context.insert(created)
                figureByKey[key] = created
                figure = created
            }

            if figure.title.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.title = "King of Babylon"
            }
            if figure.domain.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.domain = "Babylonia"
            }
            if figure.figureDescription.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.figureDescription = babylonianKingDescription(ruler, eraName: era.name)
            }
            if figure.source.trimmingCharacters(in: .whitespaces).isEmpty {
                figure.source = kingListSource.name
            }
            if figure.reignStartYear == nil && ruler.startYear != nil {
                figure.updateKingship(
                    reignStartYear: ruler.startYear,
                    reignEndYear: figure.reignEndYear ?? ruler.endYear,
                    reignYears: figure.reignYears
                )
            }

            figure.era = babylonianEraFor(figure, target: era)

            manager.addCitation(
                to: kingListSource,
                location: "Dynasty \(babylonianDynastyFor(ruler.dynasty))",
                note: ruler.note,
                entityType: .figure,
                linkedEntityName: figure.name
            )
            manager.addCitation(
                to: chronologySource,
                location: "Dynasty \(babylonianDynastyFor(ruler.dynasty))",
                note: babylonianRegnalNote(ruler),
                entityType: .figure,
                linkedEntityName: figure.name
            )
        }

        for dynasty in babylonianDynasties {
            guard let era = dynastyEra[dynasty.number] else { continue }
            manager.addCitation(
                to: chronologySource,
                location: "Dynasty \(dynasty.roman)",
                note: dynasty.summary,
                entityType: .era,
                linkedEntityName: era.name
            )
        }

        Commit.save(context, "ensureBabylonianKingListDynasties")
    }

    private static func babylonianDynastyFor(_ number: Int) -> String {
        babylonianDynasties.first { $0.number == number }?.roman ?? "I"
    }

    private static func babylonianKingDescription(_ ruler: BabylonianKingListRuler, eraName: String) -> String {
        var text = "Ruler of Babylon in the \(eraName), listed in the Babylonian King List. \(ruler.note)"
        let span = babylonianRegnalNote(ruler)
        if !span.isEmpty {
            text += " \(span)"
        }
        return text
    }

    private static func babylonianRegnalNote(_ ruler: BabylonianKingListRuler) -> String {
        switch (ruler.startYear, ruler.endYear) {
        case let (start?, end?):
            return "Regnal span c. \(abs(start))–\(abs(end)) BCE, as compiled in the modern table; the king list itself gives succession, not absolute dates."
        case let (start?, nil):
            return "Acceded c. \(abs(start)) BCE; the end of the reign is not given in the modern table."
        case (nil, _):
            return "No regnal dates are given in the modern table for this ruler."
        }
    }

    /// Files a seeded ruler under `target` unless the user has already put the
    /// figure somewhere else. `birthDate.era` is the source of truth
    /// `ensureFigureEraLinks` reconciles from, so the two are moved together.
    private static func babylonianEraFor(_ figure: Figure, target: Era) -> Era? {
        let targetKey = NameDuplicateCheck.normalizedKey(target.name)
        let birthKey = NameDuplicateCheck.normalizedKey(figure.birthDate.era)
        let currentKey = NameDuplicateCheck.normalizedKey(figure.era?.name ?? "")
        let sourceOfTruth = birthKey.isEmpty ? currentKey : birthKey
        guard sourceOfTruth.isEmpty || sourceOfTruth == targetKey else { return figure.era }
        figure.birthDate.era = target.name
        let deathKey = NameDuplicateCheck.normalizedKey(figure.deathDate.era)
        if deathKey.isEmpty || deathKey == targetKey {
            figure.deathDate.era = target.name
        }
        return target
    }

    /// The king list itself: the succession, with no absolute dates attached.
    private static func babylonianKingListSource(context: ModelContext) -> Source {
        let name = "Babylonian King List A"
        if let existing = (try? context.fetch(FetchDescriptor<Source>()))?
            .first(where: { NameDuplicateCheck.normalizedKey($0.name) == NameDuplicateCheck.normalizedKey(name) }) {
            return existing
        }
        let created = Source(
            name: name,
            sourceType: .kingList,
            author: "Anonymous Babylonian scribes",
            language: "Akkadian",
            period: "Second and first millennia BCE",
            sourceDescription: "Babylonian King List A and the later Babylonian king lists, which give the succession of Babylon's dynasties. The list records who followed whom; it supplies no absolute dates, so every regnal span attached to these figures is a modern reconstruction.",
            publicationInfo: "Attested in Old Babylonian school tablets; published in transliteration and translation in standard editions of Mesopotamian historical texts.",
            url: "https://en.wikipedia.org/wiki/Babylonian_King_List"
        )
        context.insert(created)
        return created
    }

    /// The modern compilation the regnal *dates* were taken from. Kept separate
    /// from the king list so the two claims stay apart: the succession is ancient,
    /// the absolute years are the table's own synthesis of Chen (2020), Beaulieu
    /// (2018), Fales (2012) and others. Citing the king list for a regnal span
    /// would attribute a date to a text that does not contain one.
    private static func babylonianKingListChronologySource(context: ModelContext) -> Source {
        let name = "List of kings of Babylon"
        if let existing = (try? context.fetch(FetchDescriptor<Source>()))?
            .first(where: { NameDuplicateCheck.normalizedKey($0.name) == NameDuplicateCheck.normalizedKey(name) }) {
            return existing
        }
        let created = Source(
            name: name,
            sourceType: .scholarlyWork,
            author: "Wikipedia contributors",
            language: "English",
            period: "Modern",
            sourceDescription: "Modern compilation of the Babylonian king lists. Its table gives, for each of Dynasties I–X, the ruler, the regnal bounds and a note on succession; the regnal dates are its editors' synthesis of Chen (2020), Beaulieu (2018), Fales (2012) and other modern chronology, not dates stated by any ancient text. Several rulers, including most of the Sealand kings and the middle Kassite kings, have no regnal bounds at all in the table and are recorded here without dates.",
            publicationInfo: "Wikipedia, article 'List of kings of Babylon', retrieved 2026.",
            url: "https://en.wikipedia.org/wiki/List_of_kings_of_Babylon"
        )
        context.insert(created)
        return created
    }
}
