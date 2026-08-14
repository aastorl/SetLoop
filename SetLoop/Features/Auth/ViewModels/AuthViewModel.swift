import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    enum Mode {
        case login
        case register
    }

    enum SessionState: Equatable {
        case loading
        case signedOut
        case signedIn(UserProfile)
    }

    @Published var mode: Mode = .login
    @Published var email = ""
    @Published var password = ""
    @Published var displayName = ""
    @Published var city = ""
    @Published var selectedRole: UserRole = .musician
    @Published private(set) var sessionState: SessionState = .loading
    @Published private(set) var isSubmitting = false
    @Published private(set) var isRequestingPasswordReset = false
    @Published private(set) var isUpdatingRecoveredPassword = false
    @Published var isPasswordResetRequestPresented = false
    @Published var isPasswordUpdatePresented = false
    @Published var passwordResetEmail = ""
    @Published var recoveredPassword = ""
    @Published var recoveredPasswordConfirmation = ""
    @Published var passwordResetMessage: String?
    @Published var passwordResetErrorMessage: String?
    @Published var errorMessage: String?

    let authMode: AuthMode
    private let authService: AuthServicing
    private var passwordRecoveryAccessToken: String?

    init() {
        self.authService = AuthServiceFactory.make()
        self.authMode = AuthServiceFactory.currentMode
        Task {
            await restoreSession()
        }
    }

    init(authService: AuthServicing, authMode: AuthMode) {
        self.authService = authService
        self.authMode = authMode
        Task {
            await restoreSession()
        }
    }

    var currentProfile: UserProfile? {
        if case .signedIn(let profile) = sessionState {
            return profile
        }
        return nil
    }

    var canRequestPasswordReset: Bool {
        passwordResetEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && isRequestingPasswordReset == false
    }

    var canUpdateRecoveredPassword: Bool {
        recoveredPassword.count >= 6
            && recoveredPassword == recoveredPasswordConfirmation
            && passwordRecoveryAccessToken != nil
            && isUpdatingRecoveredPassword == false
    }

    func restoreSession() async {
        sessionState = .loading
        do {
            if let profile = try await authService.restoreSession() {
                sessionState = .signedIn(profile)
            } else {
                sessionState = .signedOut
            }
        } catch {
            sessionState = .signedOut
            errorMessage = error.setLoopUserMessage
        }
    }

    func submit() async {
        errorMessage = nil
        passwordResetErrorMessage = nil
        passwordResetMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let profile: UserProfile
            switch mode {
            case .login:
                profile = try await authService.signIn(email: email, password: password)
            case .register:
                profile = try await authService.signUp(
                    email: email,
                    password: password,
                    displayName: displayName,
                    city: city,
                    role: selectedRole
                )
            }
            sessionState = .signedIn(profile)
        } catch {
            errorMessage = error.setLoopUserMessage
        }
    }

    func beginPasswordResetRequest() {
        passwordResetEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        passwordResetErrorMessage = nil
        passwordResetMessage = nil
        isPasswordResetRequestPresented = true
    }

    func requestPasswordReset() async {
        guard canRequestPasswordReset else {
            passwordResetErrorMessage = "Escribe el email de tu cuenta."
            return
        }

        passwordResetErrorMessage = nil
        passwordResetMessage = nil
        isRequestingPasswordReset = true
        defer { isRequestingPasswordReset = false }

        do {
            let emailToRecover = passwordResetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            try await authService.requestPasswordReset(email: emailToRecover)
            email = emailToRecover
            isPasswordResetRequestPresented = false
            passwordResetMessage = "Te enviamos un email para cambiar la contrasena."
        } catch {
            passwordResetErrorMessage = error.setLoopUserMessage
        }
    }

    @discardableResult
    func handlePasswordRecoveryURL(_ url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let isSetLoopRecoveryURL = url.scheme == "setloop"
            && (url.host == "password-reset" || url.path.contains("password-reset"))

        guard isSetLoopRecoveryURL else {
            return false
        }

        let parameters = recoveryParameters(from: url, components: components)

        if let errorDescription = parameters["error_description"]?.removingPercentEncoding,
           errorDescription.isEmpty == false {
            passwordResetErrorMessage = errorDescription
            return true
        }

        guard let accessToken = parameters["access_token"],
              accessToken.isEmpty == false else {
            passwordResetErrorMessage = "El link de recuperacion no es valido. Pide otro email."
            return true
        }

        passwordRecoveryAccessToken = accessToken
        recoveredPassword = ""
        recoveredPasswordConfirmation = ""
        errorMessage = nil
        passwordResetErrorMessage = nil
        passwordResetMessage = "Elige una nueva contrasena para tu cuenta."
        mode = .login
        sessionState = .signedOut
        isPasswordUpdatePresented = true
        return true
    }

    func completeRecoveredPasswordUpdate() async {
        guard let accessToken = passwordRecoveryAccessToken else {
            passwordResetErrorMessage = "El link de recuperacion no es valido. Pide otro email."
            return
        }

        guard recoveredPassword.count >= 6 else {
            passwordResetErrorMessage = "La contrasena debe tener al menos 6 caracteres."
            return
        }

        guard recoveredPassword == recoveredPasswordConfirmation else {
            passwordResetErrorMessage = "Las contrasenas no coinciden."
            return
        }

        passwordResetErrorMessage = nil
        isUpdatingRecoveredPassword = true
        defer { isUpdatingRecoveredPassword = false }

        do {
            try await authService.updatePassword(
                accessToken: accessToken,
                newPassword: recoveredPassword
            )
            passwordRecoveryAccessToken = nil
            recoveredPassword = ""
            recoveredPasswordConfirmation = ""
            password = ""
            isPasswordUpdatePresented = false
            passwordResetMessage = "Contrasena actualizada. Ya puedes iniciar sesion."
        } catch {
            passwordResetErrorMessage = error.setLoopUserMessage
        }
    }

    func enterDemo() async {
        email = "demo@setloop.local"
        password = "demo1234"
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let profile = try await authService.signIn(email: email, password: password)
            sessionState = .signedIn(profile)
        } catch {
            errorMessage = error.setLoopUserMessage
        }
    }

    func signOut() async {
        errorMessage = nil
        do {
            try await authService.signOut()
            sessionState = .signedOut
            password = ""
        } catch {
            errorMessage = error.setLoopUserMessage
        }
    }

    @discardableResult
    func updateProfile(_ profile: UserProfile) async throws -> UserProfile {
        let savedProfile = try await authService.updateProfile(profile)
        sessionState = .signedIn(savedProfile)
        return savedProfile
    }

    @discardableResult
    func persistProfile(_ profile: UserProfile) async throws -> UserProfile {
        try await authService.updateProfile(profile)
    }

    func applySignedInProfile(_ profile: UserProfile) {
        sessionState = .signedIn(profile)
    }

    private func recoveryParameters(
        from url: URL,
        components: URLComponents?
    ) -> [String: String] {
        var parameters: [String: String] = [:]

        components?.queryItems?.forEach { item in
            parameters[item.name] = item.value
        }

        if let fragment = url.fragment,
           let fragmentComponents = URLComponents(string: "setloop://password-reset?\(fragment)") {
            fragmentComponents.queryItems?.forEach { item in
                parameters[item.name] = item.value
            }
        }

        return parameters
    }
}
