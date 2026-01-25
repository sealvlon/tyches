import SwiftUI

struct AuthView: View {
    @EnvironmentObject var session: SessionStore
    @State private var isSignUp = false
    
    // Login fields
    @State private var email = ""
    @State private var password = ""
    
    // Signup fields
    @State private var signupName = ""
    @State private var signupUsername = ""
    @State private var signupEmail = ""
    @State private var signupPassword = ""
    @State private var acceptedTerms = false
    
    @State private var showPassword = false
    @State private var showSignupSuccess = false
    @State private var signupStep = 0 // 0 = email only, 1 = full form
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case email, password
        case signupName, signupUsername, signupEmail, signupPassword
    }
    
    // Check if email looks valid for progressive disclosure
    private var emailLooksValid: Bool {
        signupEmail.contains("@") && signupEmail.contains(".")
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Light gradient background
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.98, blue: 1.0),
                        Color(red: 0.96, green: 0.95, blue: 0.99),
                        Color(red: 0.94, green: 0.94, blue: 0.98)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                // Subtle accent glow (top-right)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                TychesTheme.primary.opacity(0.08),
                                TychesTheme.primary.opacity(0.02),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: 150, y: -100)
                    .blur(radius: 80)
                
                // Subtle accent glow (bottom-left)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.6, green: 0.4, blue: 0.95).opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .offset(x: -120, y: 350)
                    .blur(radius: 60)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: geo.size.height * 0.08)
                        
                        // Logo + Title (single focal point)
                        VStack(spacing: 16) {
                            TychesAnimatedLogo()
                            
                            Text("Tyches")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(TychesTheme.premiumGradient)
                            
                            Text("Predict with friends")
                                .font(.subheadline)
                                .foregroundColor(TychesTheme.textSecondary)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                        
                        // Auth toggle (simple, clear)
                        authToggle
                            .padding(.bottom, 24)
                        
                        // Form (focused, minimal)
                        if isSignUp {
                            signupForm
                        } else {
                            loginForm
                        }
                        
                        // Error message
                        if let error = session.errorMessage {
                            Text(error)
                                .foregroundColor(TychesTheme.danger)
                                .font(.caption)
                                .padding(.top, 12)
                                .transition(.opacity)
                        }
                        
                        Spacer()
                            .frame(height: 24)
                        
                        // Single clear CTA
                        submitButton
                        
                        Spacer()
                            .frame(height: 32)
                        
                        // Subtle footer (only when signing up)
                        if isSignUp {
                            HStack(spacing: 6) {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(TychesTheme.gold)
                                Text("10,000 free tokens on signup")
                                    .font(.caption)
                                    .foregroundColor(TychesTheme.gold)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(TychesTheme.gold.opacity(0.1))
                            .clipShape(Capsule())
                            .padding(.bottom, 20)
                        }
                    }
                    .padding(.horizontal, 32)
                    .frame(minHeight: geo.size.height)
                }
            }
        }
        .sheet(isPresented: $showSignupSuccess) {
            SignupSuccessView(email: signupEmail) {
                showSignupSuccess = false
                withAnimation(.spring()) {
                    isSignUp = false
                    email = signupEmail
                }
            }
        }
    }
    
    // MARK: - Auth Toggle (Simple)
    
    private var authToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isSignUp = false
                    HapticManager.selection()
                }
            } label: {
                Text("Log In")
                    .font(.subheadline.weight(isSignUp ? .medium : .semibold))
                    .foregroundColor(isSignUp ? .secondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isSignUp {
                                Color.clear
                            } else {
                                TychesTheme.primaryGradient
                            }
                        }
                    )
                    .cornerRadius(10)
            }
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isSignUp = true
                    HapticManager.selection()
                }
            } label: {
                Text("Sign Up")
                    .font(.subheadline.weight(isSignUp ? .semibold : .medium))
                    .foregroundColor(isSignUp ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isSignUp {
                                TychesTheme.primaryGradient
                            } else {
                                Color.clear
                            }
                        }
                    )
                    .cornerRadius(10)
            }
        }
        .padding(4)
        .background(TychesTheme.cardBackground)
        .cornerRadius(14)
    }
    
    // MARK: - Login Form (Minimal)
    
    private var loginForm: some View {
        VStack(spacing: 14) {
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                isFocused: focusedField == .email,
                keyboardType: .emailAddress
            )
            .focused($focusedField, equals: .email)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            
            AuthSecureField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password,
                showPassword: $showPassword,
                isFocused: focusedField == .password
            )
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit {
                if canLogin {
                    Task { await performLogin() }
                }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }
    
    // MARK: - Signup Form (Progressive disclosure)
    
    private var signupForm: some View {
        VStack(spacing: 14) {
            // Step 0: Email first
            AuthTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $signupEmail,
                isFocused: focusedField == .signupEmail,
                keyboardType: .emailAddress
            )
            .focused($focusedField, equals: .signupEmail)
            .submitLabel(signupStep == 0 ? .continue : .next)
            .onSubmit {
                if signupStep == 0 && emailLooksValid {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        signupStep = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedField = .signupName
                    }
                } else if signupStep == 1 {
                    focusedField = .signupName
                }
            }
            
            // Step 1: Reveal more fields after email
            if signupStep >= 1 {
                AuthTextField(
                    icon: "person.fill",
                    placeholder: "Full name",
                    text: $signupName,
                    isFocused: focusedField == .signupName
                )
                .focused($focusedField, equals: .signupName)
                .submitLabel(.next)
                .onSubmit { focusedField = .signupUsername }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                
                AuthTextField(
                    icon: "at",
                    placeholder: "Username",
                    text: $signupUsername,
                    isFocused: focusedField == .signupUsername
                )
                .focused($focusedField, equals: .signupUsername)
                .submitLabel(.next)
                .onSubmit { focusedField = .signupPassword }
                .onChange(of: signupUsername) { _, newValue in
                    signupUsername = newValue.lowercased().replacingOccurrences(of: " ", with: "_")
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                
                AuthSecureField(
                    icon: "lock.fill",
                    placeholder: "Password (8+ chars)",
                    text: $signupPassword,
                    showPassword: $showPassword,
                    isFocused: focusedField == .signupPassword
                )
                .focused($focusedField, equals: .signupPassword)
                .submitLabel(.go)
                .onSubmit {
                    if canSignup {
                        Task { await performSignup() }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                
                // Password strength hint
                if !signupPassword.isEmpty && signupPassword.count < 8 {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text("\(8 - signupPassword.count) more characters needed")
                            .font(.caption)
                    }
                    .foregroundColor(TychesTheme.warning)
                    .transition(.opacity)
                }
                
                // Terms - simplified inline
                HStack(spacing: 10) {
                    Button {
                        acceptedTerms.toggle()
                        HapticManager.selection()
                    } label: {
                        Image(systemName: acceptedTerms ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(acceptedTerms ? TychesTheme.primary : .secondary.opacity(0.5))
                    }
                    
                    HStack(spacing: 4) {
                        Text("I agree to the")
                            .foregroundColor(TychesTheme.textSecondary)
                        
                        Link("Terms & Conditions", destination: URL(string: "https://www.tyches.us/terms")!)
                            .foregroundColor(TychesTheme.primary)
                    }
                    .font(.subheadline)
                    
                    Spacer()
                }
                .padding(.top, 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity)
        ))
        .onChange(of: isSignUp) { _, newValue in
            if newValue {
                signupStep = 0
            }
        }
    }
    
    // MARK: - Submit Button (Single clear action)
    
    private var submitButton: some View {
        VStack(spacing: 12) {
            Button {
                focusedField = nil
                HapticManager.impact(.medium)
                
                if isSignUp && signupStep == 0 {
                    // Progressive: move to step 1
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        signupStep = 1
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        focusedField = .signupName
                    }
                } else {
                    Task {
                        if isSignUp {
                            await performSignup()
                        } else {
                            await performLogin()
                        }
                    }
                }
            } label: {
                ZStack {
                    if session.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        HStack(spacing: 8) {
                            Text(submitButtonTitle)
                                .font(.headline)
                            
                            if isSignUp && signupStep == 0 {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Group {
                        if submitButtonEnabled {
                            TychesTheme.primaryGradient
                        } else {
                            LinearGradient(colors: [Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .cornerRadius(14)
            }
            .disabled(session.isLoading || !submitButtonEnabled)
            
            // Biometric login button (only show on login, when available)
            if !isSignUp && session.canUseBiometric && session.biometricEnabled {
                Button {
                    HapticManager.impact(.light)
                    Task {
                        await session.loginWithBiometric()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: session.biometricType.iconName)
                            .font(.title3)
                        Text("Sign in with \(session.biometricType.displayName)")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(TychesTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TychesTheme.primary.opacity(0.1))
                    .cornerRadius(14)
                }
                .disabled(session.isLoading)
            }
        }
    }
    
    // MARK: - Validation
    
    private var canLogin: Bool {
        !email.isEmpty && password.count >= 8
    }
    
    private var canSignup: Bool {
        !signupName.isEmpty &&
        signupUsername.count >= 3 &&
        emailLooksValid &&
        signupPassword.count >= 8 &&
        acceptedTerms
    }
    
    private var canContinueSignup: Bool {
        emailLooksValid
    }
    
    private var submitButtonTitle: String {
        if isSignUp {
            return signupStep == 0 ? "Continue" : "Create Account"
        }
        return "Log In"
    }
    
    private var submitButtonEnabled: Bool {
        if isSignUp {
            return signupStep == 0 ? canContinueSignup : canSignup
        }
        return canLogin
    }
    
    // MARK: - Actions
    
    private func performLogin() async {
        await session.login(email: email, password: password)
        if session.isAuthenticated {
            HapticManager.notification(.success)
            password = ""
        } else {
            HapticManager.notification(.error)
        }
    }
    
    private func performSignup() async {
        await session.signup(
            name: signupName,
            username: signupUsername,
            email: signupEmail,
            password: signupPassword
        )
        
        if session.signupSuccess {
            HapticManager.notification(.success)
            showSignupSuccess = true
        } else {
            HapticManager.notification(.error)
        }
    }
}

// MARK: - Tyches Logo (Using actual asset)

struct TychesAnimatedLogo: View {
    var size: CGFloat = 100
    
    var body: some View {
        Image("iOS-iOS-Default-1024x1024")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
    }
}

// MARK: - Auth Text Field

struct AuthTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isFocused ? TychesTheme.primary : .secondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                .autocorrectionDisabled()
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? TychesTheme.primary : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Auth Secure Field

struct AuthSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var isFocused: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isFocused ? TychesTheme.primary : .secondary)
                .frame(width: 20)
            
            if showPassword {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                SecureField(placeholder, text: $text)
            }
            
            Button {
                showPassword.toggle()
                HapticManager.selection()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .padding()
        .background(TychesTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? TychesTheme.primary : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Signup Success View

struct SignupSuccessView: View {
    let email: String
    let onDismiss: () -> Void
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            TychesTheme.background.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Success icon
                ZStack {
                    Circle()
                        .fill(TychesTheme.success.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(TychesTheme.success)
                }
                
                VStack(spacing: 12) {
                    Text("Account Created!")
                        .font(.title2.bold())
                    
                    Text("Check your email to verify")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(email)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(TychesTheme.primary)
                }
                
                // Bonus
                HStack(spacing: 6) {
                    Text("🎁")
                    Text("10,000 tokens added!")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(TychesTheme.gold)
                }
                .padding()
                .background(TychesTheme.gold.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Text("Continue to Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(TychesTheme.primaryGradient)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            showConfetti = true
            HapticManager.notification(.success)
        }
    }
}
