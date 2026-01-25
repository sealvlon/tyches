import SwiftUI
import Contacts
import MessageUI

struct CreateMarketView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @State private var currentStep = 0
    @State private var name = ""
    @State private var description = ""
    @State private var selectedEmoji = "🎯"
    @State private var selectedColor = "#6366F1"
    // All markets are private by design - no toggle needed
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var createdMarketId: Int?
    @State private var showEmojiPicker = false
    
    // Friends selection
    @State private var friends: [TychesAPI.FriendData] = []
    @State private var selectedFriendIds: Set<Int> = []
    @State private var isLoadingFriends = false
    
    // Username search
    @State private var usernameSearch: String = ""
    @State private var usernameSearchResults: [TychesAPI.FriendSearchResult] = []
    @State private var selectedUsernames: Set<String> = []
    @State private var isSearchingUsername = false
    
    // Invite methods
    @State private var inviteTab: InviteTab = .friends
    @State private var emailInputs: [String] = [""]
    @State private var contacts: [ContactInfo] = []
    @State private var selectedContacts: Set<String> = [] // email addresses
    @State private var isLoadingContacts = false
    @State private var showShareSheet = false
    @State private var shareLink: String = ""
    
    enum InviteTab: String, CaseIterable {
        case friends = "Friends"
        case contacts = "Contacts"
        case email = "Email"
        case share = "Share Link"
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .contacts: return "person.crop.circle.badge.plus"
            case .email: return "envelope.fill"
            case .share: return "square.and.arrow.up"
            }
        }
    }
    
    let emojis = ["🎯", "🏠", "💼", "🏃", "🎮", "📚", "🎬", "🎵", "⚽️", "🍕", "✈️", "💰", "🎨", "🐶", "🌴", "🚀"]
    let colors = ["#6366F1", "#8B5CF6", "#EC4899", "#EF4444", "#F59E0B", "#10B981", "#3B82F6", "#6B7280"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                ProgressBar(currentStep: currentStep, totalSteps: 4)
                    .padding()
                
                // Content
                TabView(selection: $currentStep) {
                    nameAndEmojiStep.tag(0)
                    descriptionAndPrivacyStep.tag(1)
                    inviteFriendsStep.tag(2)
                    confirmationStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Create Market")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Market Created!", isPresented: $showSuccess) {
                Button("View Market") {
                    dismiss()
                }
                Button("Create Another") {
                    resetForm()
                }
            } message: {
                Text("Your market is ready! Start adding events and invite friends.")
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerSheet(selectedEmoji: $selectedEmoji)
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [shareLink])
            }
            .task {
                await loadFriends()
            }
        }
    }
    
    // MARK: - Step 1: Name & Emoji
    
    private var nameAndEmojiStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Name your market")
                .font(.title2.bold())
            
            Text("This is your friend group's prediction space")
                .foregroundColor(.secondary)
            
            // Avatar preview
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: selectedColor) ?? TychesTheme.primary)
                        .frame(width: 100, height: 100)
                        .shadow(color: (Color(hex: selectedColor) ?? TychesTheme.primary).opacity(0.4), radius: 15)
                    
                    Text(selectedEmoji)
                        .font(.system(size: 50))
                }
                .onTapGesture {
                    showEmojiPicker = true
                    HapticManager.selection()
                }
                
                Text("Tap to change emoji")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Market name")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                TextField("e.g., Roommates, Work Team, Run Club", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .padding()
                    .background(TychesTheme.cardBackground)
                    .cornerRadius(12)
                
                Text("\(name.count)/50")
                    .font(.caption)
                    .foregroundColor(name.count > 50 ? TychesTheme.danger : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // Color picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color) ?? .gray)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .shadow(color: selectedColor == color ? (Color(hex: color) ?? .gray).opacity(0.5) : .clear, radius: 5)
                            .onTapGesture {
                                selectedColor = color
                                HapticManager.selection()
                            }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 2: Description & Privacy
    
    private var descriptionAndPrivacyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Details")
                .font(.title2.bold())
            
            Text("Add context for your market")
                .foregroundColor(.secondary)
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Description (optional)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                
                TextField("What kind of predictions will this market have?", text: $description, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(TychesTheme.cardBackground)
                    .cornerRadius(12)
                    .lineLimit(3...6)
            }
            
            // Privacy info (all markets are private by design)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(TychesTheme.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Private Market")
                            .font(.headline)
                        Text("Only people you invite can see and bet on events in this market.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TychesTheme.primary.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Step 3: Invite Friends
    
    private var inviteFriendsStep: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(InviteTab.allCases, id: \.self) { tab in
                    Button {
                        inviteTab = tab
                        HapticManager.selection()
                        
                        // Load contacts when switching to contacts tab
                        if tab == .contacts && contacts.isEmpty {
                            Task {
                                await loadContacts()
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.rawValue)
                                .font(.caption2)
                        }
                        .foregroundColor(inviteTab == tab ? TychesTheme.primary : TychesTheme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(inviteTab == tab ? TychesTheme.primary.opacity(0.1) : Color.clear)
                    }
                }
            }
            .background(TychesTheme.cardBackground)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top)
            
            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Invite People")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top)
                    
                    Text("Add people to your market (you can add more later)")
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Group {
                        switch inviteTab {
                        case .friends:
                            friendsTabContent
                        case .contacts:
                            contactsTabContent
                        case .email:
                            emailTabContent
                        case .share:
                            shareTabContent
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Friends Tab
    
    private var friendsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Username search field
            VStack(alignment: .leading, spacing: 8) {
                Text("Search by username")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    TextField("@username", text: $usernameSearch)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: usernameSearch) { _, newValue in
                            if !newValue.isEmpty && newValue.count >= 2 {
                                Task {
                                    await searchUsername(newValue)
                                }
                            } else {
                                usernameSearchResults = []
                            }
                        }
                    
                    if !usernameSearch.isEmpty {
                        Button {
                            usernameSearch = ""
                            usernameSearchResults = []
                            HapticManager.selection()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(TychesTheme.textTertiary)
                        }
                    }
                }
                .padding(12)
                .background(TychesTheme.cardBackground)
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Username search results
                if !usernameSearchResults.isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(usernameSearchResults) { result in
                            UsernameSearchResultRow(
                                result: result,
                                isSelected: selectedUsernames.contains(result.username ?? ""),
                                onToggle: {
                                    let username = result.username ?? ""
                                    if selectedUsernames.contains(username) {
                                        selectedUsernames.remove(username)
                                    } else {
                                        selectedUsernames.insert(username)
                                    }
                                    HapticManager.selection()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Friends list
            if isLoadingFriends {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if friends.filter({ $0.status == "accepted" }).isEmpty && usernameSearchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 50))
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    Text("No friends yet")
                        .font(.headline)
                        .foregroundColor(TychesTheme.textSecondary)
                    
                    Text("Search by username above, or invite via email/contacts")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Selected count
                let totalSelected = selectedFriendIds.count + selectedUsernames.count
                if totalSelected > 0 {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(TychesTheme.success)
                        Text("\(totalSelected) selected")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(TychesTheme.success)
                        Spacer()
                        Button("Clear") {
                            selectedFriendIds.removeAll()
                            selectedUsernames.removeAll()
                            HapticManager.selection()
                        }
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TychesTheme.success.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Friends list
                if !friends.filter({ $0.status == "accepted" }).isEmpty {
                    LazyVStack(spacing: 8) {
                        ForEach(friends.filter { $0.status == "accepted" }) { friend in
                            FriendSelectionRow(
                                friend: friend,
                                isSelected: selectedFriendIds.contains(friend.friend_id ?? friend.id),
                                onToggle: {
                                    let friendId = friend.friend_id ?? friend.id
                                    if selectedFriendIds.contains(friendId) {
                                        selectedFriendIds.remove(friendId)
                                    } else {
                                        selectedFriendIds.insert(friendId)
                                    }
                                    HapticManager.selection()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Username Search
    
    private func searchUsername(_ query: String) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespaces).lowercased()
        if cleanQuery.isEmpty || cleanQuery.count < 2 {
            usernameSearchResults = []
            return
        }
        
        isSearchingUsername = true
        do {
            let results = try await TychesAPI.shared.searchUsers(query: cleanQuery)
            usernameSearchResults = results
        } catch {
            usernameSearchResults = []
        }
        isSearchingUsername = false
    }
    
    // MARK: - Contacts Tab
    
    private var contactsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoadingContacts {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if contacts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(TychesTheme.textTertiary)
                    
                    Text("No contacts found")
                        .font(.headline)
                        .foregroundColor(TychesTheme.textSecondary)
                    
                    Text("We couldn't find any contacts with email addresses")
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Selected count
                if !selectedContacts.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(TychesTheme.success)
                        Text("\(selectedContacts.count) contact\(selectedContacts.count == 1 ? "" : "s") selected")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(TychesTheme.success)
                        Spacer()
                        Button("Clear") {
                            selectedContacts.removeAll()
                            HapticManager.selection()
                        }
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TychesTheme.success.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Contacts list
                LazyVStack(spacing: 8) {
                    ForEach(contacts, id: \.email) { contact in
                        ContactSelectionRow(
                            contact: contact,
                            isSelected: selectedContacts.contains(contact.email),
                            onToggle: {
                                if selectedContacts.contains(contact.email) {
                                    selectedContacts.remove(contact.email)
                                } else {
                                    selectedContacts.insert(contact.email)
                                }
                                HapticManager.selection()
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Email Tab
    
    private var emailTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter email addresses")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(Array(emailInputs.enumerated()), id: \.offset) { index, email in
                    HStack(spacing: 8) {
                        TextField("friend@example.com", text: Binding(
                            get: { emailInputs[index] },
                            set: { emailInputs[index] = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(12)
                        .background(TychesTheme.cardBackground)
                        .cornerRadius(10)
                        
                        if emailInputs.count > 1 {
                            Button {
                                emailInputs.remove(at: index)
                                HapticManager.selection()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(TychesTheme.danger)
                                    .font(.title3)
                            }
                        }
                    }
                }
                
                Button {
                    emailInputs.append("")
                    HapticManager.selection()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add another email")
                    }
                    .font(.subheadline)
                    .foregroundColor(TychesTheme.primary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Share Tab
    
    private var shareTabContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(TychesTheme.primary)
            
            Text("Share Invite Link")
                .font(.title2.bold())
            
            Text("Share a link via WhatsApp, Messages, or any app")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                generateShareLink()
                showShareSheet = true
                HapticManager.impact(.medium)
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Link")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(TychesTheme.primaryGradient)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - Step 4: Confirmation
    
    private var confirmationStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Review & Create")
                    .font(.title2.bold())
                
                Text("Make sure everything looks good")
                    .foregroundColor(.secondary)
                
                // Preview card
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: selectedColor) ?? TychesTheme.primary)
                            .frame(width: 80, height: 80)
                        
                        Text(selectedEmoji)
                            .font(.system(size: 40))
                    }
                    
                    Text(name)
                        .font(.title2.bold())
                    
                    if !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                            Text("Private")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(TychesTheme.cardBackground)
                        .cornerRadius(12)
                        
                        let totalInvites = selectedFriendIds.count + selectedUsernames.count + selectedContacts.count + emailInputs.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0.contains("@") }.count
                        if totalInvites > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                Text("\(totalInvites) invited")
                            }
                            .font(.caption)
                            .foregroundColor(TychesTheme.success)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TychesTheme.success.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(TychesTheme.cardBackground)
                .cornerRadius(16)
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(TychesTheme.danger)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(TychesTheme.danger.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // Tokens bonus
                VStack(spacing: 8) {
                    HStack {
                        Text("🎁")
                        Text("You'll receive 1,000 tokens for creating this market!")
                            .font(.subheadline)
                            .foregroundColor(TychesTheme.gold)
                    }
                    
                    let totalInvites = selectedFriendIds.count + selectedUsernames.count + selectedContacts.count + emailInputs.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0.contains("@") }.count
                    if totalInvites > 0 {
                        HStack {
                            Text("👥")
                            Text("+\(totalInvites * 2000) tokens for inviting \(totalInvites) person\(totalInvites == 1 ? "" : "s")!")
                                .font(.subheadline)
                                .foregroundColor(TychesTheme.gold)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(TychesTheme.gold.opacity(0.1))
                .cornerRadius(10)
            }
            .padding()
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                    HapticManager.selection()
                } label: {
                    Text("Back")
                        .font(.headline)
                        .foregroundColor(TychesTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TychesTheme.primary.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            
            Button {
                if currentStep < 3 {
                    withAnimation {
                        currentStep += 1
                    }
                    HapticManager.selection()
                } else {
                    createMarket()
                }
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(buttonTitle)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canContinue ? TychesTheme.primaryGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(12)
            }
            .disabled(!canContinue || isCreating)
        }
        .padding()
    }
    
    private var buttonTitle: String {
        switch currentStep {
        case 2: return "Continue" // Inviting is optional, so always "Continue"
        case 3: return "Create Market"
        default: return "Continue"
        }
    }
    
    private var canContinue: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && name.count <= 50
        case 1: return true
        case 2: return true // Can skip inviting friends
        case 3: return true
        default: return false
        }
    }
    
    // MARK: - Load Friends
    
    private func loadFriends() async {
        isLoadingFriends = true
        do {
            let response = try await TychesAPI.shared.fetchFriends()
            friends = response.friends
        } catch {
            // Silently fail - user can add friends later
            friends = []
        }
        isLoadingFriends = false
    }
    
    // MARK: - Load Contacts
    
    private func loadContacts() async {
        isLoadingContacts = true
        
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
        
        do {
            try await store.requestAccess(for: .contacts)
            
            let request = CNContactFetchRequest(keysToFetch: keys)
            var loadedContacts: [ContactInfo] = []
            
            try store.enumerateContacts(with: request) { contact, _ in
                for email in contact.emailAddresses {
                    let emailString = email.value as String
                    if !emailString.isEmpty && emailString.contains("@") {
                        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                        loadedContacts.append(ContactInfo(
                            name: name.isEmpty ? emailString : name,
                            email: emailString.lowercased()
                        ))
                        break // Only take first email per contact
                    }
                }
            }
            
            // Sort by name
            contacts = loadedContacts.sorted { $0.name < $1.name }
        } catch {
            contacts = []
        }
        
        isLoadingContacts = false
    }
    
    // MARK: - Generate Share Link
    
    private func generateShareLink() {
        // Generate a shareable link - in production this would be a deep link
        // For now, we'll create a link that opens the app
        let marketName = name.isEmpty ? "my market" : name
        shareLink = "https://www.tyches.us/?invite=\(marketName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    }
    
    private func createMarket() {
        isCreating = true
        errorMessage = nil
        
        // Collect all emails: from email inputs + selected contacts
        var allEmails: [String] = []
        
        // Add emails from email input fields (filter valid emails)
        for email in emailInputs {
            let trimmed = email.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.contains("@") {
                allEmails.append(trimmed.lowercased())
            }
        }
        
        // Add selected contacts' emails
        allEmails.append(contentsOf: Array(selectedContacts))
        
        // Remove duplicates
        allEmails = Array(Set(allEmails))
        
        // Collect usernames (remove @ if present)
        let usernames = Array(selectedUsernames).map { $0.trimmingCharacters(in: .whitespaces).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "@")) }
        
        Task {
            do {
                let market = try await TychesAPI.shared.createMarket(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    visibility: "private",
                    avatarEmoji: selectedEmoji,
                    avatarColor: selectedColor,
                    friendIds: Array(selectedFriendIds),
                    usernames: usernames.isEmpty ? nil : usernames,
                    invites: allEmails.isEmpty ? nil : allEmails
                )
                
                createdMarketId = market.id
                
                // Refresh profile
                await session.refreshProfile()
                
                MissionTracker.track(action: .marketCreated)
                HapticManager.notification(.success)
                showSuccess = true
            } catch let TychesError.server(msg) {
                errorMessage = msg
                HapticManager.notification(.error)
            } catch {
                errorMessage = "Failed to create market. Please try again."
                HapticManager.notification(.error)
            }
            
            isCreating = false
        }
    }
    
    private func resetForm() {
        currentStep = 0
        name = ""
        description = ""
        selectedEmoji = "🎯"
        selectedColor = "#6366F1"
        selectedFriendIds.removeAll()
        selectedUsernames.removeAll()
        usernameSearch = ""
        usernameSearchResults = []
        emailInputs = [""]
        selectedContacts.removeAll()
        inviteTab = .friends
        errorMessage = nil
    }
}

// MARK: - Friend Selection Row

struct FriendSelectionRow: View {
    let friend: TychesAPI.FriendData
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Avatar
                Circle()
                    .fill(TychesTheme.avatarGradient(for: friend.id))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String((friend.name ?? friend.username).prefix(1)).uppercased())
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    )
                
                // Name and username
                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.name ?? friend.username)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    Text("@\(friend.username)")
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? TychesTheme.primary : TychesTheme.textTertiary)
            }
            .padding(12)
            .background(isSelected ? TychesTheme.primary.opacity(0.08) : TychesTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? TychesTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contact Info

struct ContactInfo {
    let name: String
    let email: String
}

// MARK: - Username Search Result Row

struct UsernameSearchResultRow: View {
    let result: TychesAPI.FriendSearchResult
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Avatar
                Circle()
                    .fill(TychesTheme.avatarGradient(for: result.id))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String((result.name ?? result.username ?? "U").prefix(1)).uppercased())
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    )
                
                // Name and username
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name ?? result.username ?? "User")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    if let username = result.username {
                        Text("@\(username)")
                            .font(.caption)
                            .foregroundColor(TychesTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? TychesTheme.primary : TychesTheme.textTertiary)
            }
            .padding(12)
            .background(isSelected ? TychesTheme.primary.opacity(0.08) : TychesTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? TychesTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contact Selection Row

struct ContactSelectionRow: View {
    let contact: ContactInfo
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Avatar
                Circle()
                    .fill(TychesTheme.avatarGradient(for: contact.email.hash))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(contact.name.prefix(1)).uppercased())
                            .font(.headline.bold())
                            .foregroundColor(.white)
                    )
                
                // Name and email
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(TychesTheme.textPrimary)
                    
                    Text(contact.email)
                        .font(.caption)
                        .foregroundColor(TychesTheme.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? TychesTheme.primary : TychesTheme.textTertiary)
            }
            .padding(12)
            .background(isSelected ? TychesTheme.primary.opacity(0.08) : TychesTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? TychesTheme.primary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Supporting Views

struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) var dismiss
    
    let emojis = [
        "🎯", "🏠", "💼", "🏃", "🎮", "📚", "🎬", "🎵",
        "⚽️", "🏀", "🎾", "🏈", "⚾️", "🏐", "🎱", "🏓",
        "🍕", "🍔", "🍟", "🌮", "🍣", "🍜", "🍝", "🥗",
        "✈️", "🚗", "🚀", "🛸", "🚢", "🚁", "🏍️", "🚲",
        "💰", "💎", "🏆", "🎖️", "🎪", "🎨", "🎭", "🎤",
        "🐶", "🐱", "🐼", "🦁", "🐯", "🦊", "🐻", "🐨",
        "🌴", "🌺", "🌸", "🌻", "🌹", "🍀", "🌵", "🌲",
        "❤️", "💜", "💙", "💚", "💛", "🧡", "🖤", "🤍"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 16) {
                    ForEach(emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 32))
                            .frame(width: 44, height: 44)
                            .background(selectedEmoji == emoji ? TychesTheme.primary.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                            .onTapGesture {
                                selectedEmoji = emoji
                                HapticManager.selection()
                                dismiss()
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    CreateMarketView()
        .environmentObject(SessionStore())
}

