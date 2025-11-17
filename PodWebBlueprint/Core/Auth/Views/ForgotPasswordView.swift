//
//  ForgotPasswordView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/12/23.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct ForgotPasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var email = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
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
                            Text("Hello.")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color("textColor"))
                            
                            Text("Reset Password")
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
                        // Description
                        VStack(spacing: 12) {
                            Text("Enter your email address and we'll send you a link to reset your password.")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        
                        // Email Input
                        CustomInputField(imageName: "envelope", placeholderText: "Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: email) { newValue in
                                email = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                            .padding(.horizontal, 24)
                        
                        // Reset Password Button
                        Button {
                            Task {
                                await resetPassword()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Sending...")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                } else {
                                    Text("Reset Password")
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
                        .disabled(isLoading || !isValidEmail(email))
                        .opacity(isValidEmail(email) ? 1.0 : 0.6)
                        .padding(.horizontal, 24)
                        
                        // Log In Link
                        HStack(spacing: 4) {
                            Text("Remember your password?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            NavigationLink {
                                LoginView()
                                    .navigationBarHidden(true)
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
        .alert(alertTitle, isPresented: $showAlert) {
            Button(isSuccess ? "OK" : "Try Again") {
                if isSuccess {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Password Reset Methods
    
    /// Sends password reset email using Firebase Auth
    private func resetPassword() async {
        guard isValidEmail(email) else {
            showAlert(title: "Invalid Email", message: "Please enter a valid email address.", isSuccess: false)
            return
        }
        
        isLoading = true
        
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            
            await MainActor.run {
                isLoading = false
                showAlert(
                    title: "Reset Email Sent", 
                    message: "We've sent a password reset link to \(email). Please check your email and follow the instructions to reset your password.",
                    isSuccess: true
                )
            }
        } catch {
            await MainActor.run {
                isLoading = false
                let errorMessage = getErrorMessage(for: error)
                showAlert(title: "Reset Failed", message: errorMessage, isSuccess: false)
            }
        }
    }
    
    /// Shows alert with the given title and message
    private func showAlert(title: String, message: String, isSuccess: Bool) {
        alertTitle = title
        alertMessage = message
        self.isSuccess = isSuccess
        showAlert = true
    }
    
    /// Validates email format
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email) && !email.isEmpty
    }
    
    /// Converts Firebase Auth errors to user-friendly messages
    private func getErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        
        switch nsError.code {
        case AuthErrorCode.userNotFound.rawValue:
            return "No account found with this email address. Please check your email or create a new account."
        case AuthErrorCode.invalidEmail.rawValue:
            return "The email address format is invalid. Please enter a valid email address."
        case AuthErrorCode.tooManyRequests.rawValue:
            return "Too many reset attempts. Please wait a few minutes before trying again."
        case AuthErrorCode.networkError.rawValue:
            return "Network error. Please check your internet connection and try again."
        default:
            return "An error occurred while sending the reset email. Please try again."
        }
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ForgotPasswordView()
    }
}
