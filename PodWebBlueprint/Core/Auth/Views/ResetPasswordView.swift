//
//  ResetPasswordView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/6/23.
//

import SwiftUI
import Firebase
import FirebaseAuth


struct ResetPasswordView: View {
    @State private var email = ""
    @Environment(\.presentationMode) var mode
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
                    // Modern Header with Back Button
                    VStack(spacing: 16) {
                        HStack {
                            Button {
                                mode.wrappedValue.dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.left")
                                        .font(.title3)
                                        .foregroundColor(Color("accentColor"))
                                    Text("Back")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color("accentColor"))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color("accentColor").opacity(0.1))
                                )
                            }
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reset your")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color("textColor"))
                            
                            Text("password")
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
                    
                    // Success Banner
                    if showSuccessBanner {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Password reset email sent successfully")
                                .font(.subheadline)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSuccessBanner = false
                                    mode.wrappedValue.dismiss()
                                }
                            }
                        }
                    }
                    
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
                        .padding(.horizontal, 24)
                    
                    // Send Reset Email Button
                    Button {
                        Auth.auth().sendPasswordReset(withEmail: email) { error in
                            if let error = error {
                                withAnimation {
                                    showErrorBanner = true
                                }
                                errorBanner = error.localizedDescription
                                print("Error sending password reset email: \(error.localizedDescription)")
                            } else {
                                withAnimation {
                                    showSuccessBanner = true
                                }
                                print("Password reset email sent successfully")
                            }
                        }
                    } label: {
                        Text("Send Password Reset Email")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
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
                    .disabled(email.isEmpty)
                    .opacity(email.isEmpty ? 0.6 : 1.0)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40)
                }
            }
        }
        .navigationBarBackButtonHidden()
    }
}

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
    }
}
