import Supabase
import Foundation

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var needsEmailConfirmation = false
    var errorMessage: String?

    init() {
        // authStateChanges is a synchronous property — no await on it, only on iteration.
        Task {
            for await state in SupabaseManager.client.auth.authStateChanges {
                switch state.event {
                case .initialSession, .signedIn, .tokenRefreshed:
                    isAuthenticated = state.session != nil
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
        needsEmailConfirmation = false
        do {
            try await SupabaseManager.client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        needsEmailConfirmation = false
        do {
            let response = try await SupabaseManager.client.auth.signUp(email: email, password: password)
            if response.session == nil {
                // Supabase project has email confirmation enabled.
                needsEmailConfirmation = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() async {
        try? await SupabaseManager.client.auth.signOut()
    }
}
