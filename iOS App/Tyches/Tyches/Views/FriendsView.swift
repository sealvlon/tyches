import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @State private var friends: [TychesAPI.FriendData] = []
    @State private var pendingRequests: [TychesAPI.FriendData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var showAddFriend = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("", selection: $selectedTab) {
                    Text("Friends").tag(0)
                    HStack {
                        Text("Requests")
                        if !pendingRequests.isEmpty {
                            Text("\(pendingRequests.count)")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TychesTheme.danger)
                                .clipShape(Capsule())
                        }
                    }.tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search friends...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(12)
                .background(TychesTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    if selectedTab == 0 {
                        friendsList
                    } else {
                        requestsList
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView(onFriendAdded: loadFriends)
            }
            .refreshable {
                await loadFriends()
            }
            .task {
                await loadFriends()
            }
        }
    }
    
    private var filteredFriends: [TychesAPI.FriendData] {
        if searchText.isEmpty {
            return friends
        }
        return friends.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(searchText) ||
            $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var friendsList: some View {
        Group {
            if filteredFriends.isEmpty {
                emptyFriendsState
            } else {
                List {
                    ForEach(filteredFriends) { friend in
                        FriendRow(friend: friend, showActions: true) {
                            await removeFriend(friend)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var requestsList: some View {
        Group {
            if pendingRequests.isEmpty {
                emptyRequestsState
            } else {
                List {
                    ForEach(pendingRequests) { request in
                        FriendRequestRow(request: request) {
                            await acceptRequest(request)
                        } onDecline: {
                            await declineRequest(request)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    private var emptyFriendsState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("👥")
                .font(.system(size: 60))
            Text("No friends yet")
                .font(.headline)
            Text("Add friends to compete on predictions!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showAddFriend = true
            } label: {
                Label("Add Friend", systemImage: "person.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(TychesTheme.primaryGradient)
                    .cornerRadius(12)
            }
            Spacer()
        }
    }
    
    private var emptyRequestsState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("📬")
                .font(.system(size: 60))
            Text("No pending requests")
                .font(.headline)
            Text("Friend requests will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func loadFriends() async {
        do {
            let response = try await TychesAPI.shared.fetchFriends()
            // Filter by status
            friends = response.friends.filter { $0.status == "accepted" }
            pendingRequests = response.friends.filter { $0.status == "pending" }
        } catch {
            errorMessage = "Failed to load friends"
        }
        isLoading = false
    }
    
    private func acceptRequest(_ request: TychesAPI.FriendData) async {
        do {
            // Use friend_id if available, otherwise use id
            let userId = request.friend_id ?? request.id
            _ = try await TychesAPI.shared.acceptFriendRequest(userId: userId)
            HapticManager.notification(.success)
            await loadFriends()
        } catch {
            HapticManager.notification(.error)
        }
    }
    
    private func declineRequest(_ request: TychesAPI.FriendData) async {
        do {
            let userId = request.friend_id ?? request.id
            _ = try await TychesAPI.shared.declineFriendRequest(userId: userId)
            await loadFriends()
        } catch {
            // Handle error
        }
    }
    
    private func removeFriend(_ friend: TychesAPI.FriendData) async {
        do {
            let userId = friend.friend_id ?? friend.id
            _ = try await TychesAPI.shared.removeFriend(userId: userId)
            await loadFriends()
        } catch {
            HapticManager.notification(.error)
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: TychesAPI.FriendData
    let showActions: Bool
    let onRemove: () async -> Void
    @State private var showRemoveConfirm = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(TychesTheme.avatarGradient(for: friend.id))
                    .frame(width: 44, height: 44)
                
                Text(String(friend.username.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name ?? friend.username)
                    .font(.headline)
                
                Text("@\(friend.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Online indicator
            if friend.is_online == true {
                Circle()
                    .fill(TychesTheme.success)
                    .frame(width: 8, height: 8)
            }
            
            if showActions {
                Menu {
                    Button(role: .destructive) {
                        showRemoveConfirm = true
                    } label: {
                        Label("Remove Friend", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Remove Friend", isPresented: $showRemoveConfirm) {
            Button("Remove", role: .destructive) {
                Task { await onRemove() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove \(friend.name ?? friend.username) from your friends?")
        }
    }
}

// MARK: - Friend Request Row

struct FriendRequestRow: View {
    let request: TychesAPI.FriendData
    let onAccept: () async -> Void
    let onDecline: () async -> Void
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(TychesTheme.avatarGradient(for: request.id))
                    .frame(width: 44, height: 44)
                
                Text(String(request.username.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(request.name ?? request.username)
                    .font(.headline)
                
                Text("@\(request.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
            } else {
                HStack(spacing: 8) {
                    Button {
                        isProcessing = true
                        Task {
                            await onAccept()
                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(TychesTheme.success)
                            .clipShape(Circle())
                    }
                    
                    Button {
                        isProcessing = true
                        Task {
                            await onDecline()
                            isProcessing = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(TychesTheme.danger)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Friend View

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @State private var searchQuery = ""
    @State private var searchResults: [TychesAPI.FriendSearchResult] = []
    @State private var isSearching = false
    @State private var sentRequests: Set<Int> = []
    @State private var errorMessage: String?
    let onFriendAdded: () async -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Username or email...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            searchUsers()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                            searchResults = []
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(TychesTheme.cardBackground)
                .cornerRadius(10)
                .padding()
                
                // Quick add by username/email
                if !searchQuery.isEmpty && searchResults.isEmpty && !isSearching {
                    Button {
                        sendRequestByQuery()
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Send request to '\(searchQuery)'")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(TychesTheme.primaryGradient)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(TychesTheme.danger)
                        .padding()
                }
                
                if isSearching {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if searchResults.isEmpty && searchQuery.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("👋")
                            .font(.system(size: 50))
                        Text("Find friends")
                            .font(.headline)
                        Text("Search by username or email")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if !searchResults.isEmpty {
                    List(searchResults) { user in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(TychesTheme.avatarGradient(for: user.id))
                                    .frame(width: 44, height: 44)
                                
                                Text(String((user.username ?? user.name ?? "U").prefix(1)).uppercased())
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name ?? user.username ?? "User")
                                    .font(.headline)
                                
                                if let username = user.username {
                                    Text("@\(username)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if sentRequests.contains(user.id) {
                                Text("Sent")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            } else {
                                Button {
                                    sendRequest(to: user)
                                } label: {
                                    Text("Add")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(TychesTheme.primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: searchQuery) { _, newValue in
                // Auto-search after typing stops
                if newValue.count >= 2 {
                    searchUsers()
                }
            }
        }
    }
    
    private func searchUsers() {
        guard searchQuery.count >= 2 else { return }
        
        isSearching = true
        errorMessage = nil
        
        Task {
            do {
                searchResults = try await TychesAPI.shared.searchUsers(query: searchQuery)
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }
    
    private func sendRequest(to user: TychesAPI.FriendSearchResult) {
        Task {
            do {
                _ = try await TychesAPI.shared.sendFriendRequest(userId: user.id)
                sentRequests.insert(user.id)
                HapticManager.notification(.success)
                await onFriendAdded()
            } catch let TychesError.server(msg) {
                errorMessage = msg
                HapticManager.notification(.error)
            } catch {
                errorMessage = "Failed to send request"
                HapticManager.notification(.error)
            }
        }
    }
    
    private func sendRequestByQuery() {
        guard !searchQuery.isEmpty else { return }
        
        Task {
            do {
                _ = try await TychesAPI.shared.sendFriendRequest(query: searchQuery)
                errorMessage = nil
                HapticManager.notification(.success)
                await onFriendAdded()
                dismiss()
            } catch let TychesError.server(msg) {
                errorMessage = msg
                HapticManager.notification(.error)
            } catch {
                errorMessage = "User not found"
                HapticManager.notification(.error)
            }
        }
    }
}

#Preview {
    FriendsView()
        .environmentObject(SessionStore())
}

