import Observation

/// Startup outcomes that the main window needs to report. The seed/import chain
/// runs on a background queue while the main `ContentView` is already built (it
/// exists hidden behind the splash), so the result cannot be handed over through
/// view initialisation — `ContentView` has to read it from its body to be
/// re-rendered when the value lands.
@Observable
final class StartupReport {
    static let shared = StartupReport()

    /// Names of seed/import operations whose save failed during the launch
    /// migration chain. Empty in the normal case. Set once, before the splash is
    /// dismissed.
    var migrationFailures: [String] = []
}
