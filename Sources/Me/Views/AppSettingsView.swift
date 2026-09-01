import SwiftUI

struct AppSettingsView: View {
    @Environment(\.userSession) private var userSession
    @Environment(\.modelContext) private var modelContext
    @State private var users: [User] = []
    @State private var accountMessage = ""
    @State private var showAddAccountSheet = false
    @AppStorage("dynastyMapModernStartupZoom") private var modernStartupZoom = 6.0
    @AppStorage("dynastyMapHistoricalStartupZoom") private var historicalStartupZoom = 5.0
    @AppStorage("dynastyMapModernStyle") private var modernMapStyleRaw = ModernMapStyle.standard.rawValue
    @AppStorage("dynastyMapModernMuted") private var modernMapMuted = false
    @AppStorage("dynastyMapHistoricalTheme") private var historicalThemeRaw = HistoricalMapTheme.historical.rawValue
    @AppStorage("dynastyMapHistoricalLanguage") private var historicalLanguageRaw = HistoricalMapLanguage.english.rawValue
    @AppStorage("dynastyMapLabelSize") private var labelSizeRaw = MapLabelSize.medium.rawValue
    @AppStorage("dynastyMapDateFilter") private var dateFilterEnabled = false
    @AppStorage(ConsistencyCheckSettings.masterKey) private var allChecksEnabled = true
    @AppStorage("skipLogin") private var skipLogin = false
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Settings")
                .font(.title2.bold())
            Text("General preferences. Settings apply the next time the relevant view opens.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            Form {
                Section {
                    zoomRow(
                        title: "Modern map startup zoom",
                        value: $modernStartupZoom,
                        caption: "Zoom used when the Dynasty Map opens with the Modern (MapKit) style."
                    )
                    zoomRow(
                        title: "Historical map startup zoom",
                        value: $historicalStartupZoom,
                        caption: "Zoom used when the Dynasty Map opens with the Historical (OpenHistoricalMap) style."
                    )
                    Divider()
                    Picker("Modern map style", selection: $modernMapStyleRaw) {
                        ForEach(ModernMapStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    if modernMapStyleRaw == ModernMapStyle.standard.rawValue {
                        Toggle("Quiet modern basemap", isOn: $modernMapMuted)
                            .help("Uses a muted, less colorful standard basemap.")
                    }
                    Divider()
                    Picker("Historical map theme", selection: $historicalThemeRaw) {
                        ForEach(HistoricalMapTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    Picker("Historical map label language", selection: $historicalLanguageRaw) {
                        ForEach(HistoricalMapLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    Picker("Map label size", selection: $labelSizeRaw) {
                        ForEach(MapLabelSize.allCases) { size in
                            Text(size.displayName).tag(size.rawValue)
                        }
                    }
                    Toggle("Filter historical map to dynasty era", isOn: $dateFilterEnabled)
                        .help("Experimental: OpenHistoricalMap coverage of deep-past eras is sparse.")
                } header: {
                    Text("Dynasty Map")
                } footer: {
                    Text("Higher zoom numbers show a closer view. The date filter fades features that did not yet exist in the selected dynasty's era.")
                }
                Section {
                    Text("Individual checks can be disabled if they don't apply to your workflow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("All checks enabled", isOn: $allChecksEnabled)
                        .help("Master toggle: when off, no consistency checks run during the Data Integrity scan.")
                    if allChecksEnabled {
                        ForEach(ConsistencyCheckSettings.findingCategories, id: \.category) { group in
                            let isExpanded = Binding(
                                get: { expandedCategories.contains(group.category) },
                                set: { expanded in
                                    if expanded { expandedCategories.insert(group.category) }
                                    else { expandedCategories.remove(group.category) }
                                }
                            )
                            DisclosureGroup(isExpanded: isExpanded) {
                                ForEach(group.checks) { check in
                                    CheckToggleRow(check: check)
                                }
                            } label: {
                                HStack {
                                    Text(group.category)
                                    Spacer()
                                    Text("\(group.checks.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Consistency Checks")
                }
                Section {
                    if let session = userSession, let current = session.currentUser {
                        HStack {
                            Text("Signed in as \(current.name)")
                            Spacer()
                            Button("Log Out") {
                                session.currentUser = nil
                            }
                        }
                    }
                } header: {
                    Text("Account")
                }
                Section {
                    Toggle("Skip sign-in", isOn: $skipLogin)
                        .help("Development hack: when enabled, the app signs in as the first user automatically instead of showing the login screen.")
                } header: {
                    Text("Development")
                } footer: {
                    Text("When enabled, the login screen is bypassed and the first user account is used. Not meant for production.")
                }
                if isCurrentUserAdmin {
                    Section {
                        ForEach(users, id: \.persistentModelID) { user in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(user.name).fontWeight(.medium)
                                    if user.isAdministrator {
                                        Text("Admin")
                                            .font(.caption)
                                            .foregroundStyle(.purple)
                                    }
                                    if user.isAccountActive {
                                        Text("Active")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("Deactivated")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let last = user.lastLoginAt {
                                    Text("Last login \(last.formatted(.relative(presentation: .named)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if user.isAccountActive {
                                Button("Deactivate") {
                                    deactivate(user)
                                }
                                .disabled(isSelfOrLastActive(user))
                            } else {
                                Button("Reactivate") {
                                    reactivate(user)
                                }
                            }
                        }
                    }
                    HStack {
                        Button("Add Account\u{2026}") {
                            showAddAccountSheet = true
                        }
                        Spacer()
                    }
                    if !accountMessage.isEmpty {
                        Text(accountMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("User Management")
                } footer: {
                    Text("Admins can create accounts here. Deactivated accounts cannot log in but their activity history is preserved. The last active account and your own account cannot be deactivated.")
                }
                }
            }
            .formStyle(.grouped)
            .sheet(isPresented: $showAddAccountSheet) {
                AddAccountSheet(onDone: { reloadUsers() })
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { reloadUsers() }
    }

    private var isCurrentUserAdmin: Bool {
        userSession?.currentUser?.isAdministrator ?? false
    }

    private func isSelfOrLastActive(_ user: User) -> Bool {
        guard let current = userSession?.currentUser else { return true }
        if user.persistentModelID == current.persistentModelID { return true }
        return user.isAccountActive && AuthService.activeUsers(context: modelContext).count <= 1
    }

    private func reloadUsers() {
        users = AuthService.allUsers(context: modelContext)
    }

    private func deactivate(_ user: User) {
        do {
            try AuthService.deactivate(user, actor: userSession?.currentUser, context: modelContext)
            accountMessage = ""
        } catch let error as AuthServiceError {
            switch error {
            case .lastActiveAdmin: accountMessage = "Cannot deactivate the last active account."
            case .cannotDeactivateSelf: accountMessage = "You cannot deactivate your own account."
            case .notAuthorized: accountMessage = "Only administrators can manage accounts."
            default: accountMessage = error.localizedDescription
            }
        } catch {
            accountMessage = error.localizedDescription
        }
        reloadUsers()
    }

    private func reactivate(_ user: User) {
        do {
            try AuthService.reactivate(user, actor: userSession?.currentUser, context: modelContext)
            accountMessage = ""
        } catch let error as AuthServiceError where error == .notAuthorized {
            accountMessage = "Only administrators can manage accounts."
        } catch {
            accountMessage = error.localizedDescription
        }
        reloadUsers()
    }

    private struct AddAccountSheet: View {
        let onDone: () -> Void
        @Environment(\.dismiss) private var dismiss
        @Environment(\.userSession) private var userSession
        @Environment(\.modelContext) private var modelContext
        @State private var name = ""
        @State private var password = ""
        @State private var confirmPassword = ""
        @State private var isAdmin = false
        @State private var errorMessage = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add Account")
                    .font(.headline)
                Form {
                    TextField("Name", text: $name)
                    SecureField("Password", text: $password)
                    SecureField("Confirm Password", text: $confirmPassword)
                    Toggle("Administrator", isOn: $isAdmin)
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Spacer()
                        Button("Cancel") { dismiss() }
                        Button("Create Account", action: create)
                            .buttonStyle(.borderedProminent)
                            .disabled(name.isEmpty || password.isEmpty)
                    }
                }
                .formStyle(.grouped)
            }
            .padding()
            .frame(width: 380, height: 300)
        }

        private func create() {
            errorMessage = ""
            guard password == confirmPassword else {
                errorMessage = "Passwords do not match."
                return
            }
            do {
                _ = try AuthService.createUser(
                    name: name,
                    password: password,
                    isAdmin: isAdmin,
                    actor: userSession?.currentUser,
                    context: modelContext
                )
                onDone()
                dismiss()
            } catch let error as AuthServiceError {
                switch error {
                case .nameTaken: errorMessage = "That name is already taken."
                case .nameTooShort: errorMessage = "Name must be at least \(AuthService.minNameLength) characters."
                case .passwordTooShort: errorMessage = "Password must be at least \(AuthService.minPasswordLength) characters."
                case .notAuthorized: errorMessage = "Only administrators can create accounts."
                default: errorMessage = error.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func zoomRow(title: String, value: Binding<Double>, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 2...10, step: 0.5)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct CheckToggleRow: View {
    let check: ConsistencyCheckSetting
    @AppStorage private var enabled: Bool

    init(check: ConsistencyCheckSetting) {
        self.check = check
        _enabled = AppStorage(wrappedValue: true, check.key)
    }

    var body: some View {
        Toggle(check.displayLabel, isOn: $enabled)
    }
}
