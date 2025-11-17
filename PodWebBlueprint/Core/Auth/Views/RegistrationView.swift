import SwiftUI

enum UsernameAvailabilityResult {
    case available
    case taken
    case checking
    case error(String)
    
    var message: String {
        switch self {
        case .available:
            return "✓ Username is available"
        case .taken:
            return "✗ Username is already taken"
        case .checking:
            return "Checking availability..."
        case .error(let message):
            return "✗ \(message)"
        }
    }
    
    var isAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }
    
    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }
}

struct RegistrationView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var fullname = ""
    @State private var password = ""
    @State private var birthday = Date()
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLoading = false
    
    @State private var showErrorBanner = false
    @State private var errorBanner = ""
    @State private var showSuccessBanner = false
    @State private var showAgeError = false
    @State private var showBirthdayVerification = false
    @State private var showEmailCodeVerification = false
    
    // Username validation state
    @State private var usernameValidationResult: UsernameValidationResult?
    @State private var showUsernameSuggestions = false
    @State private var isCheckingUsername = false
    @State private var usernameAvailabilityResult: UsernameAvailabilityResult?
    
    // Password validation state
    @State private var passwordValidationResult: PasswordValidator.ValidationResult?
    @State private var showPasswordSuggestions = false

    var body: some View {
        ZStack {
            // Background gradient for entire view
            LinearGradient(
                gradient: Gradient(colors: [Color("mainColor").opacity(0.1), Color("accentColor").opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Modern Header
                    VStack(spacing: 16) {
                        HStack {
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Get Started.")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color("textColor"))
                            
                            Text("Create your account")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color("accentColor"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                VStack(spacing: 32) {
                    // Error Banners
                    if showErrorBanner {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorBanner)
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showErrorBanner = false
                                }
                            }
                        }
                    }
                    
                    if showAgeError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("You must be 13 or older to use this app")
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showAgeError = false
                                }
                            }
                        }
                    }
                    
                    // Input Fields
                    VStack(spacing: 24) {
                        CustomInputField(imageName: "envelope", placeholderText: "Email", text: $email)
                            .disabled(isLoading)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            CustomInputField(imageName: "person", placeholderText: "Username", text: $username)
                                .disabled(isLoading)
                                .onChange(of: username) { newValue in
                                    validateUsername(newValue)
                                }
                            
                            // Username validation feedback
                            if let validationResult = usernameValidationResult {
                                if !validationResult.isValid {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(validationResult.errorMessage ?? "Invalid username")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        
                                        // Show suggestions for invalid usernames
                                        if !UsernameValidator.getSuggestions(for: username).isEmpty {
                                            Button("Show suggestions") {
                                                showUsernameSuggestions.toggle()
                                            }
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            
                                            if showUsernameSuggestions {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Suggestions:")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                    
                                                    ForEach(UsernameValidator.getSuggestions(for: username), id: \.self) { suggestion in
                                                        Button(suggestion) {
                                                            username = suggestion
                                                            showUsernameSuggestions = false
                                                        }
                                                        .font(.caption2)
                                                        .foregroundColor(.blue)
                                                    }
                                                }
                                                .padding(.leading, 8)
                                            }
                                        }
                                    }
                                } else if let availabilityResult = usernameAvailabilityResult {
                                    // Show availability result
                                    HStack {
                                        if availabilityResult.isChecking {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                        
                                        Text(availabilityResult.message)
                                            .foregroundColor(availabilityResult.isAvailable ? .green : .red)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                        
                        CustomInputField(imageName: "person", placeholderText: "Name (Optional)", text: $fullname)
                            .disabled(isLoading)
                            .onChange(of: fullname) { newValue in
                                // Sanitize full name input
                                let sanitized = InputSanitizer.clean(newValue, type: .fullName)
                                if sanitized != newValue {
                                    fullname = sanitized
                                }
                            }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            CustomInputField(imageName: "lock", placeholderText: "Password", isSecureField: true, text: $password)
                                .disabled(isLoading)
                                .onChange(of: password) { newValue in
                                    validatePassword(newValue)
                                }
                            
                            // Password validation feedback
                            if let validationResult = passwordValidationResult {
                                if !validationResult.isValid {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(validationResult.errorMessage ?? "Invalid password")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        
                                        // Show suggestions for invalid passwords
                                        if !validationResult.suggestions.isEmpty {
                                            Button("Show suggestions") {
                                                showPasswordSuggestions.toggle()
                                            }
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                            
                                            if showPasswordSuggestions {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Suggestions:")
                                                        .font(.caption2)
                                                        .foregroundColor(.gray)
                                                    
                                                    ForEach(validationResult.suggestions, id: \.self) { suggestion in
                                                        Text("• \(suggestion)")
                                                            .font(.caption2)
                                                            .foregroundColor(.gray)
                                                    }
                                                }
                                                .padding(.leading, 8)
                                            }
                                        }
                                    }
                                } else {
                                    HStack {
                                        Text("✓ Password strength: \(validationResult.strength.rawValue)")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        
                                        Spacer()
                                        
                                        // Password strength indicator
                                        HStack(spacing: 2) {
                                            ForEach(0..<5, id: \.self) { index in
                                                Circle()
                                                    .fill(getStrengthColor(for: index, strength: validationResult.strength))
                                                    .frame(width: 8, height: 8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign Up Button
                    Button {
                        if (email == "" || username == "" || password == "") {
                            errorBanner = "Please fill out all required fields."
                            showErrorBanner = true
                        } else if let validationResult = usernameValidationResult, !validationResult.isValid {
                            errorBanner = validationResult.errorMessage ?? "Invalid username"
                            showErrorBanner = true
                        } else if let availabilityResult = usernameAvailabilityResult, !availabilityResult.isAvailable {
                            errorBanner = "Username is not available"
                            showErrorBanner = true
                        } else if usernameAvailabilityResult == nil {
                            errorBanner = "Please wait for username validation to complete"
                            showErrorBanner = true
                        } else if !PasswordValidator.isValid(password) {
                            let passwordValidation = PasswordValidator.validate(password)
                            errorBanner = passwordValidation.errorMessage ?? "Invalid password"
                            showErrorBanner = true
                        } else {
                            // Validate fullname for profanity only if provided
                            if !fullname.isEmpty {
                                let fullnameResult = InputSanitizer.sanitize(fullname, type: .fullName)
                                if !fullnameResult.isValid {
                                    errorBanner = fullnameResult.errorMessage ?? "Invalid full name"
                                    showErrorBanner = true
                                    return
                                }
                            }
                            
                            // Show birthday verification instead of proceeding directly
                            showBirthdayVerification = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Creating Account...")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            } else {
                                Text("Sign Up")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color("accentColor").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isLoading || (usernameValidationResult?.isValid != true))
                    .opacity((usernameValidationResult?.isValid != true) ? 0.6 : 1.0)
                    .padding(.horizontal, 24)
                    
                    // Log In Link
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Text("Log In")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("accentColor"))
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.bottom, 40)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showBirthdayVerification) {
            BirthdayVerificationView(
                birthday: $birthday,
                onVerified: {
                    proceedWithRegistration()
                },
                onRejected: {
                    showAgeError = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showEmailCodeVerification) {
            EmailCodeVerificationView(
                email: email,
                username: username,
                fullname: fullname,
                password: password,
                birthday: birthday
            )
            .environmentObject(authViewModel)
        }
        .onChange(of: authViewModel.userSession) { userSession in
            if userSession != nil {
                print("🔄 RegistrationView: User authenticated, dismissing view")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    // MARK: - Username Validation
    
    private func validateUsername(_ username: String) {
        // First check format validation
        usernameValidationResult = UsernameValidator.validate(username)
        
        // If format is valid and username is not empty, check availability
        if let validationResult = usernameValidationResult, 
           validationResult.isValid && !username.isEmpty {
            checkUsernameAvailability(username)
        } else {
            // Clear availability result if format is invalid
            usernameAvailabilityResult = nil
        }
    }
    
    private func checkUsernameAvailability(_ username: String) {
        // Set checking state
        usernameAvailabilityResult = .checking
        
        // Debounce the API call to avoid too many requests
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only proceed if this is still the current username
            guard self.username == username else { return }
            
            authViewModel.checkUsername(username: username.lowercased()) { isTaken in
                DispatchQueue.main.async {
                    // Only update if this is still the current username
                    guard self.username == username else { return }
                    
                    if isTaken {
                        self.usernameAvailabilityResult = .taken
                    } else {
                        self.usernameAvailabilityResult = .available
                    }
                }
            }
        }
    }
    
    private func validatePassword(_ password: String) {
        passwordValidationResult = PasswordValidator.validate(password)
    }
    
    // MARK: - Age Validation
    
    private func validateAge() {
        // This function is called when birthday changes
        // The actual validation happens in isAgeValid()
    }
    
    private func isAgeValid() -> Bool {
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return age >= 13
    }
    
    private func proceedWithRegistration() {
        isLoading = true
        
        // Final availability check right before registration to handle race conditions
        authViewModel.checkUsername(username: username.lowercased()) { isTaken in
            if isTaken {
                // Username was taken between validation and registration
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.usernameAvailabilityResult = .taken
                    self.errorBanner = "Username is no longer available. Please choose another."
                    self.showErrorBanner = true
                }
            } else {
                // Username is still available, show email code verification
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showEmailCodeVerification = true
                }
            }
        }
    }
    
    private func getStrengthColor(for index: Int, strength: PasswordValidator.PasswordStrength) -> Color {
        let strengthLevel = PasswordValidator.PasswordStrength.allCases.firstIndex(of: strength) ?? 0
        let maxIndex = PasswordValidator.PasswordStrength.allCases.count - 1
        
        if index <= strengthLevel {
            switch strength {
            case .weak: return .red
            case .fair: return .orange
            case .good: return .yellow
            case .strong: return .green
            case .veryStrong: return .blue
            }
        } else {
            return .gray.opacity(0.3)
        }
    }
}

struct BirthdayVerificationView: View {
    @Binding var birthday: Date
    let onVerified: () -> Void
    let onRejected: () -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 50))
                    .foregroundColor(Color("accentColor"))
                
                Text("Age Verification")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Please confirm your birthday to continue")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Birthday picker
            VStack(spacing: 15) {
                Text("Your Birthday")
                    .font(.headline)
                
                DatePicker("", selection: $birthday, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .frame(maxHeight: 200)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(15)
            
            // Age requirement info
            VStack(spacing: 10) {
                Text("Age Requirement")
                    .font(.headline)
                
                Text("You must be 13 or older to use this app")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(15)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 15) {
                Button(action: {
                    if isAgeValid() {
                        onVerified()
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        onRejected()
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("accentColor"))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(Color("accentColor"))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("accentColor"), lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .padding()
    }
    
    private func isAgeValid() -> Bool {
        let calendar = Calendar.current
        let age = calendar.dateComponents([.year], from: birthday, to: Date()).year ?? 0
        return age >= 13
    }
}

struct RegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        RegistrationView()
    }
}
