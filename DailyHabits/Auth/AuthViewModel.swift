import Supabase
import Foundation

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var errorMessage: String?

    init() {
        Task {
            // Restore session from shared storage if one exists.
            if (try? await SupabaseManager.client.auth.session) != nil {
                isAuthenticated = true
            }
            // Listen for future auth state changes.
            for await state in await SupabaseManager.client.auth.authStateChanges {
                switch state.event {
                case .signedIn, .tokenRefreshed:
                    isAuthenticated = true
                case .signedOut:
                    isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        do {
            try await SupabaseManager.client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        do {
            try await SupabaseManager.client.auth.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await SupabaseManager.client.auth.signOut()
    }
}
