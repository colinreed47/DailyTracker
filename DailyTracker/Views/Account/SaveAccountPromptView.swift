import SwiftUI

/// A one-time (then periodically repeated) nudge for anonymous users who
/// haven't linked an email yet. Without this, "protect your account" only
/// existed as a button buried in Friends → Account that nobody had a reason
/// to go find — exactly why the original reboot bug went unrecoverable.
struct SaveAccountPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateAccount = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)
                    .padding(.top, 12)

                Text("Save Your Account")
                    .font(.title2.bold())

                Text("Right now your tasks and history only exist on this device. If it's ever reset, reinstalled, or replaced, there's no way back in.\n\nAdding an email takes a few seconds and means you can always sign back in and get everything back.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                Button {
                    showingCreateAccount = true
                } label: {
                    Text("Create Account").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Not Now") {
                    SharedDataStore.sharedDefaults.set(Date(), forKey: "saveAccountPromptDismissedAt")
                    dismiss()
                }
                .padding(.bottom, 8)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        SharedDataStore.sharedDefaults.set(Date(), forKey: "saveAccountPromptDismissedAt")
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .sheet(isPresented: $showingCreateAccount, onDismiss: {
            // Whether they finished or backed out, don't show the full-page
            // nudge again until the cooldown — LinkEmailView stays reachable
            // from Settings either way.
            if SupabaseManager.shared.linkedEmail == nil {
                SharedDataStore.sharedDefaults.set(Date(), forKey: "saveAccountPromptDismissedAt")
            }
            dismiss()
        }) {
            LinkEmailView()
        }
    }
}
