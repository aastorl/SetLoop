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
    @Published var errorMessage: String?

    let authMode: AuthMode
    private let authService: AuthServicing

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
}
