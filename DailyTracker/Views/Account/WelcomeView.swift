import SwiftUI

/// Shown once, on a device with no known identity at all (true first launch,
/// or a fresh install/reinstall). Replaces silently creating a new anonymous
/// account: that silent creation is exactly how accounts used to get
/// orphaned, since "reinstall = fresh account" meant there was never a
/// moment to say "wait, I already have one of these."
struct WelcomeView: View {
    @State private var showingSignIn = false
    @State private var isStarting = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("DailyTracker")
                    .font(.largeTitle.bold())
                Text("Keep a daily checklist and track your streaks over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    isStarting = true
                    Task {
                        await SupabaseManager.shared.continueAsNewAccount()
                        isStarting = false
                    }
                } label: {
                    if isStarting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Get Started").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isStarting)

                Button("I already have an account") {
                    showingSignIn = true
                }
                .disabled(isStarting)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingSignIn) {
            RecoverAccountView(context: .onboarding)
        }
    }
}
