//
//  TermsAcceptanceView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import SwiftUI

struct TermsAcceptanceView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var hasAcceptedTerms = false
    @State private var hasAcceptedPrivacy = false
    @State private var hasAcceptedMarketing = false
    @State private var isUpdating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showTerms = false
    @State private var showPrivacy = false
    
    var allAccepted: Bool {
        hasAcceptedTerms && hasAcceptedPrivacy
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Terms & Privacy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Please review and accept our terms to continue")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Terms and Privacy Options
            VStack(spacing: 20) {
                // Terms of Service
                HStack {
                    Button(action: {
                        hasAcceptedTerms.toggle()
                    }) {
                        Image(systemName: hasAcceptedTerms ? "checkmark.square.fill" : "square")
                            .foregroundColor(hasAcceptedTerms ? .blue : .gray)
                            .font(.title2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Terms of Service")
                            .font(.headline)
                        Text("I agree to the Terms of Service")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button("View") {
                        showTerms = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Privacy Policy
                HStack {
                    Button(action: {
                        hasAcceptedPrivacy.toggle()
                    }) {
                        Image(systemName: hasAcceptedPrivacy ? "checkmark.square.fill" : "square")
                            .foregroundColor(hasAcceptedPrivacy ? .blue : .gray)
                            .font(.title2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Privacy Policy")
                            .font(.headline)
                        Text("I agree to the Privacy Policy")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Button("View") {
                        showPrivacy = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                
                // Marketing (Optional)
                HStack {
                    Button(action: {
                        hasAcceptedMarketing.toggle()
                    }) {
                        Image(systemName: hasAcceptedMarketing ? "checkmark.square.fill" : "square")
                            .foregroundColor(hasAcceptedMarketing ? .blue : .gray)
                            .font(.title2)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Marketing Communications")
                            .font(.headline)
                        Text("Receive updates and promotional content (optional)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
            
            // Continue Button
            Button(action: {
                acceptTerms()
            }) {
                HStack {
                    if isUpdating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isUpdating ? "Updating..." : "Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(allAccepted ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!allAccepted || isUpdating)
            
            // Error Message
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            checkCurrentAcceptanceStatus()
        }
        .sheet(isPresented: $showTerms) {
            TermsAndPoliciesView()
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView()
        }
    }
    
    private func checkCurrentAcceptanceStatus() {
        // Check if user has already accepted terms
        if let currentUser = authViewModel.currentUser {
            hasAcceptedTerms = currentUser.termsAcceptedAt != nil
            hasAcceptedPrivacy = currentUser.termsAcceptedAt != nil // Assuming same timestamp
        }
    }
    
    private func acceptTerms() {
        isUpdating = true
        showError = false
        
        // Update user's terms acceptance
        authViewModel.updateTermsAcceptance(
            termsAccepted: hasAcceptedTerms,
            privacyAccepted: hasAcceptedPrivacy,
            marketingAccepted: hasAcceptedMarketing
        ) { success, error in
            DispatchQueue.main.async {
                isUpdating = false
                
                if success {
                    // Terms accepted successfully
                    print("✅ Terms accepted successfully")
                    // You might want to dismiss this view or navigate away
                } else {
                    showError = true
                    errorMessage = error?.localizedDescription ?? "Failed to update terms acceptance"
                }
            }
        }
    }
    
}

#Preview {
    TermsAcceptanceView()
        .environmentObject(AuthViewModel.shared)
}
