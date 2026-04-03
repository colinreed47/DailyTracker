import SwiftUI

struct FriendsView: View {
    @State private var vm = FriendsViewModel()
    @State private var showingAddFriend = false
    @State private var selectedFriend: FriendEntry? = nil
    @State private var friendCodeInput = ""
    @State private var addError: String? = nil
    @State private var editingName = false
    @State private var nameInput = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                profileSection

                let incoming = vm.friends.filter { $0.isIncomingRequest }
                if !incoming.isEmpty {
                    requestsSection(incoming)
                }

                friendsSection
            }
            .navigationTitle("Friends")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddFriend = true } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                addFriendSheet
            }
            .sheet(item: $selectedFriend) { friend in
                FriendCalendarView(friend: friend, vm: vm)
            }
            .task { await vm.load() }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section("My Profile") {
            HStack {
                Text("Name")
                Spacer()
                if editingName {
                    TextField("Display name", text: $nameInput)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { submitName() }
                } else {
                    Text(vm.profile?.displayName ?? "–")
                        .foregroundStyle(.secondary)
                }
                Button {
                    if editingName { submitName() }
                    else {
                        nameInput = vm.profile?.displayName ?? ""
                        editingName = true
                    }
                } label: {
                    Image(systemName: editingName ? "checkmark" : "pencil")
                        .font(.caption)
                }
            }

            HStack {
                Text("Friend Code")
                Spacer()
                Text(vm.profile?.friendCode ?? "–")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button {
                    UIPasteboard.general.string = vm.profile?.friendCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
            }

            Toggle("Share My Calendar", isOn: Binding(
                get: { vm.profile?.isSharingEnabled ?? true },
                set: { val in Task { await vm.toggleSharing(val) } }
            ))
        }
    }

    private func submitName() {
        let trimmed = nameInput.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { Task { await vm.updateDisplayName(trimmed) } }
        editingName = false
    }

    // MARK: - Requests Section

    private func requestsSection(_ requests: [FriendEntry]) -> some View {
        Section("Requests") {
            ForEach(requests) { request in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(request.displayName)
                        Text("Wants to be friends")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Accept") {
                        Task { await vm.acceptFriend(friendshipId: request.friendshipId) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        let accepted = vm.friends.filter { $0.isAccepted }
        let outgoing = vm.friends.filter { $0.isPending && $0.isRequester }

        return Section("Friends") {
            if accepted.isEmpty && outgoing.isEmpty {
                Text("No friends yet. Tap + to add someone.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            ForEach(accepted) { friend in
                Button {
                    guard friend.isSharingEnabled else { return }
                    selectedFriend = friend
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.displayName)
                                .foregroundStyle(.primary)
                            if !friend.isSharingEnabled {
                                Text("Calendar not shared")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if friend.isSharingEnabled {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            ForEach(outgoing) { pending in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pending.displayName)
                        Text("Request sent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Cancel", role: .destructive) {
                        Task { await vm.cancelFriendRequest(friendshipId: pending.friendshipId) }
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - Add Friend Sheet

    private var addFriendSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter friend code", text: $friendCodeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let error = addError {
                            Text(error).foregroundStyle(.red)
                        }
                        Text("Ask your friend for their 6-character code shown in My Profile.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        addError = nil
                        friendCodeInput = ""
                        showingAddFriend = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        Task {
                            addError = await vm.addFriend(code: friendCodeInput)
                            if addError == nil {
                                friendCodeInput = ""
                                showingAddFriend = false
                            }
                        }
                    }
                    .disabled(friendCodeInput.trimmingCharacters(in: .whitespaces).count != 6)
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
