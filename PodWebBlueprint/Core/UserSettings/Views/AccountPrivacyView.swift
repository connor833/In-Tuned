//
//  AccountPrivacyView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 5/27/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct AccountPrivacyView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isPrivate: Bool = false
    @State private var isLoading: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var initialPrivacyState: Bool = false
    @State private var isProcessingFollowRequests: Bool = false
    @State private var followRequestCount: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
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
                
                Text("Account Privacy")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
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
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    // Privacy Setting Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Header with icon
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Color("accentColor"))
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Private Account")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Control who can see your profile and activity")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("When your account is private:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• Only approved friends can see your profile")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                Text("• Your posts and activity are hidden from non-friends")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                Text("• You can approve or deny follow requests")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.leading, 36)
                        
                        // Toggle with modern styling
                        HStack {
                            Text("Enable Private Account")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $isPrivate)
                                .labelsHidden()
                                .disabled(isProcessingFollowRequests)
                                .onChange(of: isPrivate) { newValue in
                                    if newValue != initialPrivacyState {
                                        updatePrivacySetting(isPrivate: newValue)
                                    }
                                }
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(
                                color: Color.black.opacity(0.08),
                                radius: 12,
                                x: 0,
                                y: 4
                            )
                    )
                    
                    // Processing State Card
                    if isProcessingFollowRequests {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                    .scaleEffect(1.2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Processing Follow Requests")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("Converting your account to public...")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            if followRequestCount > 0 {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color("accentColor"))
                                    
                                    Text("Accepting \(followRequestCount) pending requests")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                .padding(.top, 8)
                                .padding(.leading, 36)
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color("accentColor").opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadCurrentPrivacySetting()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Privacy Update"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func loadCurrentPrivacySetting() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Firestore.firestore().collection("users").document(uid)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Error loading privacy setting: \(error)")
                    return
                }
                
                if let data = snapshot?.data(),
                   let isPrivate = data["isPrivate"] as? Bool {
                    self.isPrivate = isPrivate
                    self.initialPrivacyState = isPrivate
                }
            }
    }
    
    private func updatePrivacySetting(isPrivate: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        
        // If going from private to public, we need to process follow requests
        if !isPrivate && initialPrivacyState == true {
            isProcessingFollowRequests = true
            followRequestCount = 0 // Will be updated by the cloud function
            
            // First update the privacy setting
            Firestore.firestore().collection("users").document(uid)
                .updateData(["isPrivate": isPrivate]) { [self] error in
                    if let error = error {
                        isLoading = false
                        isProcessingFollowRequests = false
                        alertMessage = "Failed to update privacy setting: \(error.localizedDescription)"
                        showAlert = true
                        self.isPrivate.toggle() // Revert the toggle if update failed
                        return
                    }
                    
                    // Privacy setting updated successfully, now process follow requests
                    let userService = UserService()
                    userService.handlePrivateToPublicTransition { success, message, acceptedCount in
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.isProcessingFollowRequests = false
                            
                            if success {
                                if acceptedCount > 0 {
                                    self.alertMessage = "Account is now public! \(acceptedCount) follow requests were automatically accepted."
                                } else {
                                    self.alertMessage = "Account is now public! No pending follow requests to process."
                                }
                            } else {
                                self.alertMessage = "Account is now public, but there was an issue processing follow requests: \(message)"
                            }
                            
                            self.showAlert = true
                            self.initialPrivacyState = isPrivate // Update the initial state after successful change
                        }
                    }
                }
        } else {
            // Normal privacy update (public to private, or initial load)
            Firestore.firestore().collection("users").document(uid)
                .updateData(["isPrivate": isPrivate]) { error in
                    isLoading = false
                    
                    if let error = error {
                        alertMessage = "Failed to update privacy setting: \(error.localizedDescription)"
                        showAlert = true
                        self.isPrivate.toggle() // Revert the toggle if update failed
                    } else {
                        alertMessage = "Privacy setting updated successfully"
                        showAlert = true
                        self.initialPrivacyState = isPrivate // Update the initial state after successful change
                    }
                }
        }
    }
}

#Preview {
    AccountPrivacyView()
}
