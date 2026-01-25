import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var pushNotificationsEnabled = true
    @State private var emailNotificationsEnabled = true
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationStack {
            List {
                // Account Section
                Section("Account") {
                    Button {
                        showEditProfile = true
                    } label: {
                        SettingsRow(icon: "person.fill", title: "Edit Profile", color: TychesTheme.primary)
                    }
                    
                    NavigationLink {
                        ChangePasswordView()
                    } label: {
                        SettingsRow(icon: "lock.fill", title: "Change Password", color: .orange)
                    }
                }
                
                // Security Section
                Section("Security") {
                    if session.biometricType != .none {
                        Toggle(isOn: Binding(
                            get: { session.biometricEnabled },
                            set: { newValue in
                                if newValue {
                                    session.enableBiometric()
                                } else {
                                    session.disableBiometric()
                                }
                            }
                        )) {
                            SettingsRow(
                                icon: session.biometricType.iconName,
                                title: session.biometricType.displayName,
                                color: .green
                            )
                        }
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    Toggle(isOn: $pushNotificationsEnabled) {
                        SettingsRow(icon: "bell.fill", title: "Push Notifications", color: .red)
                    }
                    .onChange(of: pushNotificationsEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "pushNotificationsEnabled")
                    }
                    
                    Toggle(isOn: $emailNotificationsEnabled) {
                        SettingsRow(icon: "envelope.fill", title: "Email Notifications", color: .blue)
                    }
                    .onChange(of: emailNotificationsEnabled) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "emailNotificationsEnabled")
                    }
                    
                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        SettingsRow(icon: "slider.horizontal.3", title: "Notification Preferences", color: .purple)
                    }
                }
                
                // Legal Section
                Section("Legal") {
                    Link(destination: URL(string: "https://www.tyches.us/terms.php")!) {
                        SettingsRow(icon: "doc.text.fill", title: "Terms of Service", color: .gray)
                    }
                    
                    Link(destination: URL(string: "https://www.tyches.us/privacy.php")!) {
                        SettingsRow(icon: "hand.raised.fill", title: "Privacy Policy", color: .gray)
                    }
                }
                
                // Support Section
                Section("Support") {
                    Link(destination: URL(string: "https://www.tyches.us/contact.php")!) {
                        SettingsRow(icon: "questionmark.circle.fill", title: "Help / FAQ", color: .cyan)
                    }
                    
                    Button {
                        sendSupportEmail()
                    } label: {
                        SettingsRow(icon: "envelope.circle.fill", title: "Contact Support", color: .teal)
                    }
                    
                    Button {
                        sendBugReport()
                    } label: {
                        SettingsRow(icon: "ant.fill", title: "Report a Bug", color: .orange)
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        SettingsRow(icon: "info.circle.fill", title: "Version", color: .secondary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Danger Zone
                Section {
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Log Out")
                                .foregroundColor(TychesTheme.danger)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    
                    Button {
                        showDeleteAccountAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                                .foregroundColor(TychesTheme.danger)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    Task {
                        await session.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // TODO: Implement account deletion
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "pushNotificationsEnabled")
        emailNotificationsEnabled = UserDefaults.standard.bool(forKey: "emailNotificationsEnabled")
    }
    
    private func sendSupportEmail() {
        if let url = URL(string: "mailto:admin@tyches.us?subject=Tyches%20Support") {
            UIApplication.shared.open(url)
        }
    }
    
    private func sendBugReport() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let device = UIDevice.current.model
        let ios = UIDevice.current.systemVersion
        
        let subject = "Bug Report - Tyches iOS v\(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "Device: \(device)\niOS: \(ios)\nVersion: \(version) (\(build))\n\nDescribe the bug:\n".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        if let url = URL(string: "mailto:admin@tyches.us?subject=\(subject)&body=\(body)") {
            UIApplication.shared.open(url)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.15))
                .cornerRadius(6)
            
            Text(title)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore
    @State private var name = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Name", text: $name)
                    
                    HStack {
                        Text("@")
                            .foregroundColor(.secondary)
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    TextField("Bio (optional)", text: $bio, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(TychesTheme.danger)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isSaving || name.isEmpty || username.isEmpty)
                }
            }
            .onAppear {
                if let user = session.profile?.user {
                    name = user.name ?? ""
                    username = user.username ?? ""
                }
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        // TODO: Implement profile update API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        Form {
            Section("Current Password") {
                SecureField("Enter current password", text: $currentPassword)
            }
            
            Section("New Password") {
                SecureField("Enter new password", text: $newPassword)
                SecureField("Confirm new password", text: $confirmPassword)
                
                if !newPassword.isEmpty && newPassword.count < 8 {
                    Text("Password must be at least 8 characters")
                        .font(.caption)
                        .foregroundColor(TychesTheme.danger)
                }
                
                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Text("Passwords don't match")
                        .font(.caption)
                        .foregroundColor(TychesTheme.danger)
                }
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(TychesTheme.danger)
                }
            }
            
            Section {
                Button {
                    changePassword()
                } label: {
                    HStack {
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Change Password")
                        }
                        Spacer()
                    }
                }
                .disabled(!canSubmit || isSaving)
            }
        }
        .navigationTitle("Change Password")
        .alert("Password Changed", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been updated successfully.")
        }
    }
    
    private var canSubmit: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword
    }
    
    private func changePassword() {
        isSaving = true
        errorMessage = nil
        
        // TODO: Implement password change API
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSaving = false
            showSuccess = true
        }
    }
}

// MARK: - Notification Preferences View

struct NotificationPreferencesView: View {
    @State private var betActivity = true
    @State private var gossipMentions = true
    @State private var eventResolutions = true
    @State private var closingSoon = true
    @State private var streakReminders = true
    @State private var achievements = true
    
    var body: some View {
        Form {
            Section("Trading") {
                Toggle("Bet Activity", isOn: $betActivity)
                Toggle("Event Resolutions", isOn: $eventResolutions)
                Toggle("Events Closing Soon", isOn: $closingSoon)
            }
            
            Section("Social") {
                Toggle("Gossip Mentions", isOn: $gossipMentions)
            }
            
            Section("Engagement") {
                Toggle("Streak Reminders", isOn: $streakReminders)
                Toggle("Achievement Unlocked", isOn: $achievements)
            }
        }
        .navigationTitle("Notification Preferences")
    }
}

#Preview {
    SettingsView()
        .environmentObject(SessionStore())
}

