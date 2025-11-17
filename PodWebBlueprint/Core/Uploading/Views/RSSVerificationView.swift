//
//  RSSVerificationView.swift
//  Attuned
//
//  RSS Feed Ownership Verification
//

import SwiftUI
import FirebaseFunctions

struct RSSVerificationView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var isVerifying = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var resendTimer: Timer?
    @State private var timeRemaining = 0
    @State private var hasSentInitialCode = false
    
    let feedData: RSSFeedData
    let feedUrl: String
    let onVerificationSuccess: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // RSS Icon
            Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 15) {
                Text("Verify Podcast Ownership")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("To prevent unauthorized uploads, please verify you own this podcast.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let email = feedData.channelEmail {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Podcast:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(feedData.channelTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Verification email sent to:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(email)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Text("Enter the 6-digit code from your email:")
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
                        
                        // Actual text input field
                        TextField("Enter 6-digit code", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .multilineTextAlignment(.center)
                            .font(.title2)
                            .frame(height: 50)
                            .onChange(of: verificationCode) { newValue in
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered.count <= 6 {
                                    verificationCode = filtered
                                } else {
                                    verificationCode = String(filtered.prefix(6))
                                }
                            }
                            .onAppear {
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
            } else {
                // No email found in RSS feed
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("No Email Found")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("This RSS feed doesn't contain a contact email address. Please add an email to your RSS feed using one of these tags:")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• <itunes:email>")
                        Text("• <managingEditor>")
                        Text("• <webMaster>")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            if feedData.channelEmail != nil {
                VStack(spacing: 15) {
                    Button(action: verifyCode) {
                        HStack {
                            if isVerifying {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle")
                            }
                            Text("Verify Ownership")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(verificationCode.count == 6 ? Color.orange : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(verificationCode.count != 6 || isVerifying)
                    
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
                    .disabled(timeRemaining > 0 || isVerifying)
                }
            }
            
            Spacer()
            
            Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }
            .foregroundColor(.red)
        }
        .padding()
        .padding(.top, 20)
        .padding(.bottom, 20)
        .onAppear {
            if !hasSentInitialCode && feedData.channelEmail != nil {
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
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func getDigit(at index: Int) -> String {
        guard index < verificationCode.count else { return "" }
        return String(verificationCode[verificationCode.index(verificationCode.startIndex, offsetBy: index)])
    }
    
    private func sendVerificationCode() {
        guard let email = feedData.channelEmail else { return }
        
        isLoading = true
        let functions = Functions.functions()
        let sendCode = functions.httpsCallable("sendRSSVerificationCode")
        
        let data: [String: Any] = [
            "email": email,
            "feedTitle": feedData.channelTitle,
            "feedUrl": feedUrl
        ]
        
        sendCode.call(data) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("❌ Failed to send RSS verification code: \(error.localizedDescription)")
                    alertTitle = "Error"
                    alertMessage = error.localizedDescription
                    showAlert = true
                } else {
                    print("✅ RSS verification code sent to \(email)")
                }
            }
        }
    }
    
    private func verifyCode() {
        isVerifying = true
        let functions = Functions.functions()
        let verifyOwnership = functions.httpsCallable("verifyRSSOwnership")
        
        let data: [String: Any] = [
            "feedUrl": feedUrl,
            "code": verificationCode
        ]
        
        verifyOwnership.call(data) { result, error in
            DispatchQueue.main.async {
                isVerifying = false
                
                if let error = error {
                    print("❌ RSS verification failed: \(error.localizedDescription)")
                    alertTitle = "Verification Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                } else {
                    print("✅ RSS ownership verified successfully!")
                    presentationMode.wrappedValue.dismiss()
                    onVerificationSuccess()
                }
            }
        }
    }
    
    private func resendCode() {
        if timeRemaining == 0 {
            sendVerificationCode()
            startResendTimer()
        }
    }
    
    private func startResendTimer() {
        timeRemaining = 60
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                resendTimer?.invalidate()
            }
        }
    }
}

