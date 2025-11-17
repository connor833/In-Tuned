import SwiftUI
import Firebase
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showErrorBanner = false
    @State private var errorBanner = ""
    @State private var showSuccessBanner = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color("accentColor").opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header with icon
                    VStack(spacing: 16) {
                        // Back button and title
                        HStack {
                            Button {
                                presentationMode.wrappedValue.dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.left")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(Color("accentColor"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color("accentColor"), lineWidth: 2)
                                        )
                                        .shadow(
                                            color: Color.black.opacity(0.1),
                                            radius: 8,
                                            x: 0,
                                            y: 4
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Title with icon
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .shadow(
                                        color: Color("accentColor").opacity(0.3),
                                        radius: 12,
                                        x: 0,
                                        y: 6
                                    )
                                
                                Image(systemName: "lock.rotation")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Change Password")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(Color("textColor"))
                            
                            Text("Update your account security")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Error/Success banners
                    if showErrorBanner {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(errorBanner)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                        .opacity(showErrorBanner ? 1 : 0)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showErrorBanner = false
                                }
                            }
                        }
                    }
                    
                    if showSuccessBanner {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("Password updated successfully!")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.green)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                        .opacity(showSuccessBanner ? 1 : 0)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSuccessBanner = false
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                    }
                    
                    // Input fields container
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Password")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("textColor"))
                            
                            CustomInputField(imageName: "lock", placeholderText: "Enter current password", isSecureField: true, text: $currentPassword)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Password")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("textColor"))
                            
                            CustomInputField(imageName: "lock", placeholderText: "Enter new password", isSecureField: true, text: $newPassword)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm New Password")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color("textColor"))
                            
                            CustomInputField(imageName: "lock", placeholderText: "Confirm new password", isSecureField: true, text: $confirmPassword)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                    )
                    .padding(.horizontal)
                    
                    // Update button
                    Button {
                        updatePassword()
                    } label: {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            
                            Text(isLoading ? "Updating..." : "Update Password")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color("accentColor").opacity(0.3),
                                    radius: 12,
                                    x: 0,
                                    y: 6
                                )
                        )
                        .scaleEffect(isLoading ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isLoading)
                    }
                    .disabled(isLoading)
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
    
    private func updatePassword() {
        guard let user = Auth.auth().currentUser else {
            showError("No user is currently signed in")
            return
        }
        
        // Validate inputs
        if currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty {
            showError("Please fill in all fields")
            return
        }
        
        if newPassword != confirmPassword {
            showError("New passwords do not match")
            return
        }
        
        if !PasswordValidator.isValid(newPassword) {
            let passwordValidation = PasswordValidator.validate(newPassword)
            showError(passwordValidation.errorMessage ?? "Invalid password")
            return
        }
        
        isLoading = true
        
        // First, reauthenticate the user
        let credential = EmailAuthProvider.credential(withEmail: user.email ?? "", password: currentPassword)
        
        user.reauthenticate(with: credential) { result, error in
            if let error = error {
                isLoading = false
                showError("Current password is incorrect")
                print("Reauthentication error: \(error.localizedDescription)")
                return
            }
            
            // If reauthentication successful, update the password
            user.updatePassword(to: newPassword) { error in
                isLoading = false
                
                if let error = error {
                    showError("Failed to update password: \(error.localizedDescription)")
                    print("Password update error: \(error.localizedDescription)")
                } else {
                    withAnimation {
                        showSuccessBanner = true
                    }
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        withAnimation {
            errorBanner = message
            showErrorBanner = true
        }
    }
}

#Preview {
    ChangePasswordView()
} 
