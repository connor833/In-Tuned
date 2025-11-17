//
//  DeleteAccountView.swift
//  PodWebBlueprint
//
//  Created by Assistant on Account Deletion Implementation
//

import SwiftUI

struct DeleteAccountView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showFirstConfirmation = false
    @State private var showSecondConfirmation = false
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    private let userService = UserService()
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern header with glassmorphism effect
                VStack(spacing: 20) {
                    HStack {
                        Button {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.prepare()
                            impactFeedback.impactOccurred()
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
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.6)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .shadow(
                                        color: Color("accentColor").opacity(0.2),
                                        radius: 8,
                                        x: 0,
                                        y: 4
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        VStack(spacing: 4) {
                            Text("Delete Account")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Permanent Action")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Invisible spacer for symmetry
                        Button { } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Back")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.clear)
                        }
                        .disabled(true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .padding(.bottom, 20)
                .background(.ultraThinMaterial)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Warning Section with modern design
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.red, Color.red.opacity(0.7)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Warning")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.red)
                                    
                                    Text("Permanent Action")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Text("Deleting your account is a permanent action that cannot be undone. This will remove all your data, pods, and personal information from our platform.")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color("textColor"))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: Color.red.opacity(0.1), radius: 12, x: 0, y: 6)
                        )
                        
                        // What Will Happen Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What will happen:")
                                .font(.headline)
                                .foregroundColor(Color("textColor"))
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 20)
                                    
                                    Text("All your pods will be permanently deleted")
                                        .foregroundColor(Color("textColor"))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "person.crop.circle.badge.minus")
                                        .foregroundColor(.orange)
                                        .frame(width: 20)
                                    
                                    Text("Your personal information will be anonymized")
                                        .foregroundColor(Color("textColor"))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "envelope.open.fill")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    
                                    Text("Your email will be freed for future use")
                                        .foregroundColor(Color("textColor"))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                                
                                HStack(alignment: .top) {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .foregroundColor(.gray)
                                        .frame(width: 20)
                                    
                                    Text("Your comments will remain but show as 'Anonymous User'")
                                        .foregroundColor(Color("textColor"))
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                        .background(Color("tabColor"))
                        .cornerRadius(12)
                        
                    Spacer(minLength: 40)
                        
                        // Delete Account Button
                        Button {
                            showFirstConfirmation = true
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                
                                Text(isLoading ? "Processing..." : "Delete My Account")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isLoading ? Color.gray : Color.red)
                            .cornerRadius(12)
                        }
                        .disabled(isLoading)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .alert("Are You Sure?", isPresented: $showFirstConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    showSecondConfirmation = true
                }
            } message: {
                Text("This action will permanently delete your account and all associated data.")
            }
            .alert("Final Confirmation", isPresented: $showSecondConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, Delete Forever", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This action is IRREVERSIBLE and CANNOT be undone. Your account, pods, and personal data will be permanently deleted. Are you absolutely certain you want to proceed?")
            }
        .alert("Account Deleted", isPresented: $showSuccess) {
            Button("OK") {
                // Post notification to dismiss all views first
                NotificationCenter.default.post(name: NSNotification.Name("ResetNavigationStack"), object: nil)
                
                // Then sign out after a brief delay to allow views to dismiss
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    authViewModel.signOut {
                        // Additional cleanup if needed
                    }
                }
            }
        } message: {
            Text(successMessage)
        }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
                Button("Try Again") {
                    deleteAccount()
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
        
        private func deleteAccount() {
            isLoading = true
            
            userService.anonymizeUserAccount { success, error, summary in
                DispatchQueue.main.async {
                    isLoading = false
                    
                    if success {
                        successMessage = summary ?? "Your account has been successfully deleted."
                        showSuccess = true
                    } else {
                        errorMessage = error?.localizedDescription ?? "An unexpected error occurred. Please try again."
                        showError = true
                    }
                }
            }
        }
    }

struct DeleteAccountView_Previews: PreviewProvider {
    static var previews: some View {
        DeleteAccountView()
            .environmentObject(AuthViewModel())
    }
}
