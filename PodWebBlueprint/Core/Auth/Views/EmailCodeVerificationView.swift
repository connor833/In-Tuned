import SwiftUI

struct EmailCodeVerificationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var resendTimer: Timer?
    @State private var timeRemaining = 0
    @State private var hasSentInitialCode = false
    
    let email: String
    let username: String
    let fullname: String
    let password: String
    let birthday: Date
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Email Icon
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            VStack(spacing: 15) {
                Text("Verify Your Email")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("We've sent a 6-digit code to:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(email)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 20) {
                Text("Enter the verification code below to create your account.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                
                // Verification Code Input
                VStack(spacing: 15) {
                    // Visual digit display
                    HStack(spacing: 15) {
                        ForEach(0..<6, id: \.self) { index in
                            VerificationCodeDigitView(
                                digit: getDigit(at: index),
                                isActive: verificationCode.count == index
                            )
                        }
                    }
                    .padding(.vertical, 20)
                    
                    // Actual text input field (styled to be less visible)
                    TextField("Enter 6-digit code", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .frame(height: 50)
                        .onChange(of: verificationCode) { newValue in
                            // Limit to 6 digits and only allow numbers
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count <= 6 {
                                verificationCode = filtered
                            } else {
                                // If user tries to enter more than 6 digits, truncate to 6
                                verificationCode = String(filtered.prefix(6))
                            }
                        }
                        .onAppear {
                            // Auto-focus when view appears
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                }
                
                if timeRemaining > 0 {
                    Text("Resend code in \(timeRemaining) seconds")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 15) {
                Button(action: verifyCode) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text("Verify & Create Account")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(verificationCode.count == 6 ? Color.blue : Color.gray.opacity(0.3))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(verificationCode.count != 6 || isLoading)
                
                Button(action: resendCode) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(timeRemaining > 0 ? "Resend Code (\(timeRemaining)s)" : "Resend Code")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(timeRemaining > 0 ? Color.gray.opacity(0.3) : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(timeRemaining > 0 || isLoading)
            }
            
            Spacer()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.red)
        }
        .padding()
        .background(Color(.systemBackground))
        .onAppear {
            if !hasSentInitialCode {
                sendVerificationCode()
                startResendTimer()
                hasSentInitialCode = true
            }
        }
        .onDisappear {
            resendTimer?.invalidate()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    // Only error alerts remain - no action needed on dismiss
                }
            )
        }
    }
    
    private func getDigit(at index: Int) -> String {
        guard index < verificationCode.count else { return "" }
        return String(verificationCode[verificationCode.index(verificationCode.startIndex, offsetBy: index)])
    }
    
    private func sendVerificationCode() {
        print("📧 [EmailCodeVerificationView] Sending verification code to: \(email)")
        authViewModel.sendEmailVerificationCode(email: email) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ [EmailCodeVerificationView] Verification code sent successfully")
                } else {
                    print("❌ [EmailCodeVerificationView] Failed to send verification code: \(error?.localizedDescription ?? "Unknown error")")
                    
                    // Extract user-friendly error message
                    let errorMessage = error?.localizedDescription ?? "Failed to send verification code."
                    
                    // Check if error is about email already existing
                    if errorMessage.contains("already registered") || 
                       errorMessage.contains("already exists") ||
                       (error as NSError?)?.localizedDescription.contains("already") == true {
                        alertTitle = "Email Already Registered"
                        alertMessage = "This email is already registered. Please use a different email or try logging in."
                    } else {
                        alertTitle = "Error"
                        alertMessage = errorMessage
                    }
                    
                    showAlert = true
                }
            }
        }
    }
    
    private func verifyCode() {
        isLoading = true
        
        authViewModel.verifyEmailCodeAndRegister(
            email: email,
            code: verificationCode,
            username: username,
            fullname: fullname,
            password: password,
            birthday: birthday
        ) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    print("✅ [EmailCodeVerificationView] Account created successfully")
                    print("🔄 [EmailCodeVerificationView] Dismissing sheet - onboarding should show")
                    
                    // Dismiss immediately since onboarding state is set in AuthViewModel
                    presentationMode.wrappedValue.dismiss()
                } else {
                    alertTitle = "Verification Failed"
                    alertMessage = error?.localizedDescription ?? "Invalid verification code. Please try again."
                    showAlert = true
                }
            }
        }
    }
    
    private func resendCode() {
        // Don't start timer if there's already one running
        if timeRemaining == 0 {
            sendVerificationCode()
            startResendTimer()
        }
    }
    
    private func startResendTimer() {
        timeRemaining = 60 // 60 seconds cooldown
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }
}

struct VerificationCodeDigitView: View {
    let digit: String
    let isActive: Bool
    
    var body: some View {
        Text(digit)
            .font(.title)
            .fontWeight(.bold)
            .frame(width: 40, height: 50)
            .background(isActive ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
            )
            .cornerRadius(8)
    }
}

struct EmailCodeVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailCodeVerificationView(
            email: "user@example.com",
            username: "testuser",
            fullname: "Test User",
            password: "password123",
            birthday: Date()
        )
        .environmentObject(AuthViewModel.shared)
    }
}
