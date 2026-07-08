import SwiftUI

/// Links an email address to the current anonymous account so the account
/// (and everything in it) can be recovered if the local session is ever lost.
struct LinkEmailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var isSending = false
    @State private var confirmationSent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if confirmationSent {
                    Section {
                        Label("Confirmation email sent", systemImage: "envelope.badge")
                        Text("Open the link in the email to finish linking \(email) to your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red)
                            }
                            Text("Your account and data stay on this device either way — linking an email just makes them recoverable if you ever get signed out.")
                        }
                    }
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(confirmationSent ? "Done" : "Cancel") { dismiss() }
                }
                if !confirmationSent {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { sendConfirmation() }
                            .disabled(isSending || !email.contains("@"))
                    }
                }
            }
        }
    }

    private func sendConfirmation() {
        isSending = true
        errorMessage = nil
        Task {
            do {
                try await SupabaseManager.shared.linkEmail(
                    email.trimmingCharacters(in: .whitespaces)
                )
                confirmationSent = true
            } catch {
                errorMessage = "Couldn't send the confirmation email. Check the address and try again."
                print("[Account] link email error: \(error)")
            }
            isSending = false
        }
    }
}

/// Signs this device into an existing account using a one-time code sent to
/// the account's linked email. On success the app rebinds local data and
/// pulls the account's data down from the server. Used both as the "I
/// already have an account" path during onboarding and as the "Recover
/// Account" rescue path from Settings — same flow, different framing.
struct RecoverAccountView: View {
    enum Context {
        case onboarding
        case settings

        var title: String {
            switch self {
            case .onboarding: return "Sign In"
            case .settings: return "Recover Account"
            }
        }

        var doneMessage: String {
            switch self {
            case .onboarding: return "Signed in. Your tasks and calendar history are being restored — they'll appear in a moment."
            case .settings: return "Your tasks and calendar history are being restored. They'll appear in a moment."
            }
        }
    }

    var context: Context = .settings

    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case enterEmail
        case enterCode
        case done
    }

    @State private var step: Step = .enterEmail
    @State private var email = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                switch step {
                case .enterEmail:
                    Section {
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red)
                            }
                            Text("Enter the email linked to your account. We'll send a one-time code.")
                        }
                    }

                case .enterCode:
                    Section {
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(.title3, design: .monospaced))
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red)
                            }
                            Text("Enter the code sent to \(email).")
                        }
                    }
                    Button("Send a new code") { sendCode() }
                        .disabled(isWorking)

                case .done:
                    Section {
                        Label("Signed in", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(context.doneMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(step == .done ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    switch step {
                    case .enterEmail:
                        Button("Send Code") { sendCode() }
                            .disabled(isWorking || !email.contains("@"))
                    case .enterCode:
                        Button("Verify") { verifyCode() }
                            .disabled(isWorking || code.trimmingCharacters(in: .whitespaces).count < 6)
                    case .done:
                        EmptyView()
                    }
                }
            }
        }
    }

    private func sendCode() {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await SupabaseManager.shared.sendRecoveryCode(
                    to: email.trimmingCharacters(in: .whitespaces)
                )
                step = .enterCode
            } catch {
                errorMessage = "Couldn't send a code to that address. Make sure it's the email linked to your account."
                print("[Account] send recovery code error: \(error)")
            }
            isWorking = false
        }
    }

    private func verifyCode() {
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await SupabaseManager.shared.verifyRecoveryCode(
                    email: email.trimmingCharacters(in: .whitespaces),
                    code: code.trimmingCharacters(in: .whitespaces)
                )
                step = .done
            } catch {
                errorMessage = "That code didn't work. Check it and try again, or request a new one."
                print("[Account] verify recovery code error: \(error)")
            }
            isWorking = false
        }
    }
}
