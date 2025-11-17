import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    @State private var verificationTimer: Timer?
    @State private var timeRemaining = 0
    
    let email: String
    
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
                
                Text("We've sent a verification link to:")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Text(email)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 20) {
                Text("Please check your email and click the verification link to activate your account.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                
                if timeRemaining > 0 {
                    Text("Resend email in \(timeRemaining) seconds")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 15) {
                Button(action: resendVerification) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(timeRemaining > 0 ? "Resend Email (\(timeRemaining)s)" : "Resend Email")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(timeRemaining > 0 ? Color.gray.opacity(0.3) : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(timeRemaining > 0 || isLoading)
                
                Button(action: checkVerification) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("I've Verified My Email")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isLoading)
            }
            
            Spacer()
            
            Button {
                authViewModel.signOut {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                HStack {
                    if authViewModel.isLoggingOut {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.red)
                    }
                    Text(authViewModel.isLoggingOut ? "Signing Out..." : "Sign Out")
                        .foregroundColor(.red)
                }
            }
            .disabled(authViewModel.isLoggingOut)
        }
        .padding()
        .onAppear {
            startVerificationTimer()
        }
        .onDisappear {
            verificationTimer?.invalidate()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK")) {
                    if isSuccess {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            )
        }
    }
    
    private func resendVerification() {
        isLoading = true
        
        authViewModel.sendEmailVerification { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    alertTitle = "Email Sent"
                    alertMessage = "A new verification email has been sent to \(email)."
                    isSuccess = false
                    showAlert = true
                    startVerificationTimer()
                } else {
                    alertTitle = "Error"
                    alertMessage = error?.localizedDescription ?? "Failed to send verification email."
                    isSuccess = false
                    showAlert = true
                }
            }
        }
    }
    
    private func checkVerification() {
        isLoading = true
        
        authViewModel.reloadUser { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success && authViewModel.isEmailVerified() {
                    // Complete the registration process
                    authViewModel.completeRegistration()
                    
                    alertTitle = "Email Verified!"
                    alertMessage = "Your email has been successfully verified. Welcome to PodWeb!"
                    isSuccess = true
                    showAlert = true
                } else {
                    alertTitle = "Not Verified Yet"
                    alertMessage = "Your email hasn't been verified yet. Please check your email and click the verification link."
                    isSuccess = false
                    showAlert = true
                }
            }
        }
    }
    
    private func startVerificationTimer() {
        timeRemaining = 60 // 60 seconds cooldown
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                verificationTimer?.invalidate()
            }
        }
    }
}

struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailVerificationView(email: "user@example.com")
            .environmentObject(AuthViewModel.shared)
    }
}
