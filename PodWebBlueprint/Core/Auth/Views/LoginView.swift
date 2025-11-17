import SwiftUI
import Firebase

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false  // Add this state variable
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showErrorBanner = false
    @State private var errorBanner = ""
    @State private var showSuccessBanner = false

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
                            
                            Text("Welcome Back")
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
                    // Error Banner
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
                    
                    // Input Fields
                    VStack(spacing: 24) {
                        CustomInputField(imageName: "envelope", placeholderText: "Email", text: $email)
                            .disabled(isLoading)
                        
                        CustomInputField(imageName: "lock", placeholderText: "Password", isSecureField: true, text: $password)
                            .disabled(isLoading)
                    }
                    .padding(.horizontal, 24)
                    
                    // Forgot Password Link
                    HStack {
                        Spacer()
                        NavigationLink {
                            ResetPasswordView()
                        } label: {
                            Text("Forgot Password?")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Color("accentColor"))
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Sign In Button
                    Button {
                        isLoading = true
                        
                        authViewModel.login(withEmail: email, password: password) { success, error in
                            DispatchQueue.main.async {
                                isLoading = false
                                
                                if success {
                                    print("✅ LoginView: Login successful")
                                } else {
                                    withAnimation {
                                        showErrorBanner = true
                                    }
                                    
                                    // Handle rate limiting errors specially
                                    if let nsError = error as NSError?, nsError.domain == "AuthRateLimitError" {
                                        errorBanner = nsError.localizedDescription
                                        
                                        // Show lockout time if available
                                        if let lockoutTime = nsError.userInfo["lockoutTime"] as? TimeInterval, lockoutTime > 0 {
                                            let minutes = Int(lockoutTime / 60)
                                            errorBanner += " Account locked for \(minutes) minutes."
                                        }
                                    } else {
                                        errorBanner = error?.localizedDescription ?? "Incorrect Password"
                                    }
                                    
                                    print("❌ LoginView: Login failed - \(error?.localizedDescription ?? "Unknown error")")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Signing In...")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            } else {
                                Text("Sign In")
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
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .opacity((email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                    .padding(.horizontal, 24)
                    
                    // Sign Up Link
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        NavigationLink {
                            RegistrationView()
                                .navigationBarHidden(true)
                        } label: {
                            Text("Sign Up")
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
        .onChange(of: authViewModel.userSession) { userSession in
            if userSession != nil {
                print("🔄 LoginView: User authenticated, dismissing view")
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
