import Foundation
import Security
import LocalAuthentication

@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUser: User?
    @Published var profile: ProfileResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var signupSuccess = false
    @Published var biometricEnabled: Bool = false
    @Published var biometricType: BiometricType = .none

    var isAuthenticated: Bool { currentUser != nil }
    
    enum BiometricType {
        case none
        case faceID
        case touchID
        
        var displayName: String {
            switch self {
            case .none: return "Biometric"
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            }
        }
        
        var iconName: String {
            switch self {
            case .none: return "faceid"
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            }
        }
    }
    
    // MARK: - Keychain Keys
    private let keychainEmailKey = "com.tyches.email"
    private let keychainPasswordKey = "com.tyches.password"
    private let biometricEnabledKey = "com.tyches.biometricEnabled"
    
    init() {
        checkBiometricAvailability()
        biometricEnabled = UserDefaults.standard.bool(forKey: biometricEnabledKey)
    }
    
    // MARK: - Biometric Authentication
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }
    
    var canUseBiometric: Bool {
        biometricType != .none && loadCredentials() != nil
    }
    
    func enableBiometric() {
        UserDefaults.standard.set(true, forKey: biometricEnabledKey)
        biometricEnabled = true
    }
    
    func disableBiometric() {
        UserDefaults.standard.set(false, forKey: biometricEnabledKey)
        biometricEnabled = false
    }
    
    func loginWithBiometric() async {
        guard canUseBiometric else {
            errorMessage = "Biometric login not available"
            return
        }
        
        let context = LAContext()
        context.localizedCancelTitle = "Use Password"
        
        do {
            let reason = "Log in to Tyches"
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                // Biometric succeeded - login with saved credentials
                if let (email, password) = loadCredentials() {
                    await login(email: email, password: password)
                }
            }
        } catch let error as LAError {
            switch error.code {
            case .userCancel:
                // User cancelled - don't show error
                break
            case .userFallback:
                // User chose to use password - don't show error
                break
            case .biometryNotAvailable:
                errorMessage = "\(biometricType.displayName) is not available"
            case .biometryNotEnrolled:
                errorMessage = "\(biometricType.displayName) is not set up on this device"
            case .biometryLockout:
                errorMessage = "\(biometricType.displayName) is locked. Please use your passcode."
            default:
                errorMessage = "Authentication failed"
            }
        } catch {
            errorMessage = "Authentication failed"
        }
    }
    
    // MARK: - Signup
    
    func signup(name: String, username: String, email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        signupSuccess = false
        
        do {
            // First fetch CSRF token for signup
            try await TychesAPI.shared.fetchCSRFToken()
            
            let response = try await TychesAPI.shared.signup(
                name: name,
                username: username,
                email: email,
                password: password
            )
            
            // Signup succeeded - user needs to verify email
            signupSuccess = true
            errorMessage = nil
            
            // Track signup
            Analytics.shared.trackSignUp()
            
        } catch let TychesError.server(msg) {
            errorMessage = msg
            signupSuccess = false
        } catch let TychesError.httpStatus(code) {
            if code == 409 {
                errorMessage = "Email or username already registered"
            } else if code == 400 {
                errorMessage = "Please check your information and try again"
            } else {
                errorMessage = "Server error (code \(code))"
            }
            signupSuccess = false
        } catch let error as DecodingError {
            errorMessage = "Invalid response from server"
            signupSuccess = false
            print("Signup decoding error: \(error)")
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                errorMessage = "No internet connection"
            } else if error.code == .timedOut {
                errorMessage = "Request timed out"
            } else {
                errorMessage = "Network error: \(error.localizedDescription)"
            }
            signupSuccess = false
        } catch {
            errorMessage = "Signup failed. Please try again."
            signupSuccess = false
            print("Signup error: \(error)")
        }
        
        isLoading = false
    }

    func login(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            let user = try await TychesAPI.shared.login(email: email, password: password)
            currentUser = user
            
            // Save credentials for session persistence
            saveCredentials(email: email, password: password)
            
            // Enable biometric if available and not already set
            if biometricType != .none && !UserDefaults.standard.bool(forKey: "hasPromptedBiometric") {
                enableBiometric()
                UserDefaults.standard.set(true, forKey: "hasPromptedBiometric")
            }
            
            // Fetch CSRF token after login for future requests
            try? await TychesAPI.shared.fetchCSRFToken()
            profile = try await TychesAPI.shared.fetchProfile()
            errorMessage = nil // Clear any previous errors
            
            // Track login
            Analytics.shared.setUserId(user.id)
            Analytics.shared.setUserProperties(name: user.name, username: user.username)
            Analytics.shared.trackLogin()
        } catch let TychesError.server(msg) {
            errorMessage = msg
        } catch let TychesError.unauthorized(msg) {
            errorMessage = msg.isEmpty ? "Invalid email or password" : msg
        } catch let TychesError.httpStatus(code) {
            if code == 401 {
                errorMessage = "Invalid email or password"
            } else if code == 403 {
                errorMessage = "Account not verified or inactive"
            } else {
                errorMessage = "Server error (code \(code))"
            }
        } catch let error as DecodingError {
            errorMessage = "Invalid response from server"
            print("Decoding error: \(error)")
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                errorMessage = "No internet connection"
            } else if error.code == .timedOut {
                errorMessage = "Request timed out"
            } else {
                errorMessage = "Network error: \(error.localizedDescription)"
            }
        } catch {
            errorMessage = "Network error. Please try again."
            print("Login error: \(error)")
        }
        isLoading = false
    }

    func bootstrapFromSession() async {
        isLoading = true
        defer { isLoading = false }
        
        // First try to restore session from server (cookies might still be valid)
        do {
            try? await TychesAPI.shared.fetchCSRFToken()
            let profile = try await TychesAPI.shared.fetchProfile()
            self.profile = profile
            self.currentUser = profile.user
            return // Session is still valid
        } catch {
            // Session expired or not logged in - try to re-login with saved credentials
        }
        
        // Try to re-login with saved credentials
        if let (email, password) = loadCredentials() {
            do {
                let user = try await TychesAPI.shared.login(email: email, password: password)
                currentUser = user
                try? await TychesAPI.shared.fetchCSRFToken()
                profile = try await TychesAPI.shared.fetchProfile()
                
                // Track auto-login
                Analytics.shared.setUserId(user.id)
                Analytics.shared.setUserProperties(name: user.name, username: user.username)
                return
            } catch {
                // Credentials no longer valid - clear them
                clearCredentials()
            }
        }
        
        // Not logged in
        self.currentUser = nil
        self.profile = nil
    }
    
    func logout() async {
        isLoading = true
        errorMessage = nil
        
        // Track logout before clearing state
        Analytics.shared.trackLogout()
        
        // Clear saved credentials
        clearCredentials()
        
        do {
            try await TychesAPI.shared.logout()
            // Clear local state
            currentUser = nil
            profile = nil
        } catch {
            // Even if logout fails on server, clear local state
            currentUser = nil
            profile = nil
        }
        isLoading = false
    }
    
    func refreshProfile() async {
        do {
            let profile = try await TychesAPI.shared.fetchProfile()
            await MainActor.run {
                self.profile = profile
                self.currentUser = profile.user
            }
        } catch let TychesError.unauthorized(_) {
            // Session expired - try to re-login
            await attemptReLogin()
        } catch let TychesError.httpStatus(401) {
            // Also handle 401 from httpStatus
            await attemptReLogin()
        } catch {
            // Other errors - don't clear session, just fail silently
            print("Profile refresh error: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    private func attemptReLogin() async {
        if let (email, password) = loadCredentials() {
            do {
                let user = try await TychesAPI.shared.login(email: email, password: password)
                self.currentUser = user
                try? await TychesAPI.shared.fetchCSRFToken()
                self.profile = try await TychesAPI.shared.fetchProfile()
                return
            } catch {
                // Re-login failed - clear everything
                clearCredentials()
            }
        }
        
        // Clear session
        self.currentUser = nil
        self.profile = nil
    }
    
    // MARK: - Keychain Helpers
    
    private func saveCredentials(email: String, password: String) {
        saveToKeychain(key: keychainEmailKey, value: email)
        saveToKeychain(key: keychainPasswordKey, value: password)
    }
    
    private func loadCredentials() -> (email: String, password: String)? {
        guard let email = loadFromKeychain(key: keychainEmailKey),
              let password = loadFromKeychain(key: keychainPasswordKey) else {
            return nil
        }
        return (email, password)
    }
    
    private func clearCredentials() {
        deleteFromKeychain(key: keychainEmailKey)
        deleteFromKeychain(key: keychainPasswordKey)
    }
    
    private func saveToKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
