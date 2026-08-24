import SwiftUI
import SwiftData
import MeCore

private struct UserSessionKey: EnvironmentKey {
    static let defaultValue: UserSession? = nil
}

extension EnvironmentValues {
    var userSession: UserSession? {
        get { self[UserSessionKey.self] }
        set { self[UserSessionKey.self] = newValue }
    }
}

struct LoginView: View {
    let session: UserSession
    @Environment(\.modelContext) private var modelContext
    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var hasExistingUsers = true
    @FocusState private var nameFocused: Bool

    enum Mode {
        case login
        case register

        var title: String {
            switch self {
            case .login: return "Log In"
            case .register: return "Create Account"
            }
        }

        var buttonLabel: String {
            switch self {
            case .login: return "Log In"
            case .register: return "Create Account"
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Me")
                .font(.largeTitle.bold())

            Text(mode == .register && !hasExistingUsers
                 ? "Welcome — create the first account to get started."
                 : "Sign in to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            form

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            hasExistingUsers = AuthService.hasAnyUser(context: modelContext)
            if !hasExistingUsers {
                mode = .register
            } else {
                nameFocused = true
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption).foregroundStyle(.secondary)
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(submit)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Password").font(.caption).foregroundStyle(.secondary)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(submit)
            }

            if mode == .register {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirm Password").font(.caption).foregroundStyle(.secondary)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(submit)
                }
            }

            Button(mode.buttonLabel, action: submit)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)

            if mode == .login {
                Button("Forgot password?", action: showRecoveryHint)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }

    private func submit() {
        errorMessage = ""
        do {
            switch mode {
            case .register:
                guard password == confirmPassword else {
                    errorMessage = "Passwords do not match."
                    return
                }
                let user = try AuthService.register(name: name, password: password, context: modelContext)
                session.currentUser = user
                hasExistingUsers = true
            case .login:
                do {
                    let user = try AuthService.login(name: name, password: password, context: modelContext)
                    session.currentUser = user
                } catch let error as AuthServiceError {
                    switch error {
                    case .invalidCredentials:
                        errorMessage = "Incorrect name or password."
                    case .accountDeactivated:
                        errorMessage = "This account has been deactivated."
                    default:
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } catch let error as AuthServiceError {
            switch error {
            case .nameTaken:
                errorMessage = "That name is already taken."
            case .nameTooShort:
                errorMessage = "Name must be at least \(AuthService.minNameLength) characters."
            case .passwordTooShort:
                errorMessage = "Password must be at least \(AuthService.minPasswordLength) characters."
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func showRecoveryHint() {
        errorMessage = "Password recovery is not available yet."
    }
}
