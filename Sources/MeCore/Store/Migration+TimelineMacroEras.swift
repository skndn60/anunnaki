import Foundation
import SwiftData

extension Migration {
    /// Adds the major macro-periods of Mesopotamian history drawn from
    /// Wikipedia's "Timeline of Mesopotamia" template (Uruk → Sassanid) as Era
    /// entities. The SKL dynasty lanes already carry the third–second millennium
    /// kingdoms, and `ensureHistoricalPeriodEras` owns the Old Assyrian / Old
    /// Babylonian / Neo-Assyrian labels, so these seven-century-overs campaigns
    /// (plus the first-millennium empires) are appended as lanes 34–46. Every
    /// name is ALSO registered in `fixEraOrderIndices`'s name map because its
    /// catch-all otherwise bumps unlisted post-flood eras by +1 on every launch.
    /// Check-by-name creation; existing eras are never modified.
    package static func ensureTimelineMacroEras(context: ModelContext) {
        let existingKeys = Set(((try? context.fetch(FetchDescriptor<Era>())) ?? [])
            .map { NameDuplicateCheck.normalizedKey($0.name) })
        let configs: [(name: String, order: Int, description: String, start: Int, end: Int)] = [
            ("Uruk Period", 34,
             "The late Chalcolithic phase that produced the first cities of southern Mesopotamia, monumental temple districts at Uruk itself, and the invention of proto-cuneiform.",
             -3500, -3100),
            ("Jemdet Nasr Period", 35,
             "Protohistoric interval between the Uruk and Early Dynastic periods, named for the site of Jemdet Nasr where the earliest proto-cuneiform tablets were found alongside polychrome painted pottery.",
             -3100, -2900),
            ("Mitanni", 36,
             "Hurrian-led kingdom of northern Syria and Mesopotamia whose rivals stretched from Egypt to the Hittites until its collapse and partition.",
             -1600, -1400),
            ("Karduniaš (Kassite Babylonia)", 37,
             "The Kassite dynasty that ruled Babylonia as 'Karduniaš' for nearly half a millennium after the Hittite sack of Babylon, a period of stability and of diplomacy with Egypt.",
             -1600, -1150),
            ("Middle Assyrian Period", 38,
             "The reconstituted Assyrian kingdom whose kings fought the Mitanni, reached the Mediterranean, and briefly subdued Babylon.",
             -1400, -1150),
            ("Late Bronze Age Collapse", 39,
             "The systemic collapse of the eastern Mediterranean palatial order around 1200–1150 BCE, toppling the Hittites and disrupting Mesopotamian networks.",
             -1200, -1150),
            ("Neo-Babylonian Empire", 40,
             "The Chaldean empire of Nabopolassar and Nebuchadnezzar II that ended Assyrian power and rebuilt Babylon into the largest city of its age.",
             -626, -539),
            ("Achaemenid Empire", 41,
             "The first Persian empire, founded by Cyrus the Great, under which Mesopotamia became a wealthy satrapy of a state stretching from the Indus to Egypt.",
             -539, -331),
            ("Macedonian Empire", 42,
             "The realm of Alexander the Great after his conquest of Achaemenid Mesopotamia, a brief epoch that seeded Hellenistic rule across the Near East.",
             -336, -301),
            ("Seleucid Empire", 43,
             "The Hellenistic successor state founded by Seleucus I after Alexander's death, which administered Mesopotamia from Seleucia on the Tigris.",
             -311, -63),
            ("Parthian Empire", 44,
             "The Arsacid empire spanning Iran and Mesopotamia that checked Rome on the Euphrates for centuries until the Sasanian revolt.",
             -129, 224),
            ("Roman and Byzantine Mesopotamia", 45,
             "The Roman province of Mesopotamia and its Byzantine successor, the frontier stage for centuries of Roman–Persian warfare down to the Islamic conquest.",
             -63, 700),
            ("Sassanid Empire", 46,
             "The last great Persian empire before Islam, whose wars with the Romans and Byzantines repeatedly devastated Mesopotamia until its fall.",
             224, 651),
        ]
        var createdAny = false
        for config in configs where !existingKeys.contains(NameDuplicateCheck.normalizedKey(config.name)) {
            let era = Era(
                name: config.name,
                orderIndex: config.order,
                eraDescription: config.description,
                startDate: MythologicalDate(year: config.start, isApproximate: true),
                endDate: MythologicalDate(year: config.end, isApproximate: true)
            )
            context.insert(era)
            createdAny = true
        }
        if createdAny { try? context.save() }
    }
}