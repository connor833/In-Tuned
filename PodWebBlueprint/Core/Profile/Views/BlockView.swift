//
//  BlockView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/1/25.
//

import SwiftUI

struct BlockView: View {
    let user: User
    @Environment(\.presentationMode) private var presentationMode
    @StateObject private var blockService = BlockService()
    @State private var reason: String = ""
    @State private var isBlocking = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isUserBlocked = false
    
    var body: some View {
        VStack {
            // Header with back arrow
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(Color("accentColor"))
                }
                .padding()
                
                Spacer()
                
                Text(isUserBlocked ? "Unblock User" : "Block User")
                    .font(.headline)
                    .foregroundColor(Color("textColor"))
                
                Spacer()
                
                // Invisible button for symmetry
                Button { } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(.clear)
                }
                .padding()
                .disabled(true)
            }
            
            VStack(spacing: 20) {
                // User Info Header
                VStack(spacing: 16) {
                    if !user.profileImageUrl.isEmpty {
                        AsyncImage(url: URL(string: user.profileImageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                    }
                    
                    VStack(spacing: 4) {
                        Text(user.fullname ?? user.username)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("@\(user.username)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // Block/Unblock Description
                VStack(alignment: .leading, spacing: 12) {
                    Text(isUserBlocked ? "Unblock User" : "Block User")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(isUserBlocked ? 
                        "This will restore all interactions with this user. You'll be able to see their content and interact with them again." :
                        "This will block all interactions with this user. You won't see their content, and they won't see yours.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal)
                
                // Reason Input (Optional)
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("Reason (Optional)", comment: ""))
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Why are you blocking this user?", text: $reason, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Block/Unblock Button
                Button(action: isUserBlocked ? unblockUser : blockUser) {
                    HStack {
                        if isBlocking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: isUserBlocked ? "person.badge.plus" : "slash.circle.fill")
                            Text(isUserBlocked ? "Unblock \(user.username)" : "Block \(user.username)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isUserBlocked ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .fontWeight(.semibold)
                }
                .disabled(isBlocking)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            checkBlockStatus()
        }
        .alert(NSLocalizedString("Block User", comment: ""), isPresented: $showAlert) {
            Button("OK") {
                if alertMessage.contains("successfully") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func checkBlockStatus() {
        blockService.checkIfUserIsBlocked(userId: user.uid) { isBlocked in
            DispatchQueue.main.async {
                self.isUserBlocked = isBlocked
            }
        }
    }
    
    private func blockUser() {
        guard !isBlocking else { 
            print("⚠️ BLOCK_VIEW: blockUser called but already blocking")
            return 
        }
        
        print("🚫 BLOCK_VIEW: blockUser initiated for user: \(user.username) (UID: \(user.uid))")
        print("🚫 BLOCK_VIEW: Reason: \(reason.isEmpty ? "none" : reason)")
        
        isBlocking = true
        print("🚫 BLOCK_VIEW: Set isBlocking to true")
        
        blockService.blockUser(
            userId: user.uid,
            reason: reason.isEmpty ? nil : reason
        ) { success in
            print("🚫 BLOCK_VIEW: blockService.blockUser completion called with success: \(success)")
            
            DispatchQueue.main.async {
                self.isBlocking = false
                print("🚫 BLOCK_VIEW: Set isBlocking to false")
                
                if success {
                    self.alertMessage = "Successfully blocked \(self.user.username)"
                    self.isUserBlocked = true
                    print("✅ BLOCK_VIEW: Block operation successful")
                } else {
                    self.alertMessage = "Failed to block user. Please try again."
                    print("❌ BLOCK_VIEW: Block operation failed")
                }
                
                print("🚫 BLOCK_VIEW: Showing alert with message: \(self.alertMessage)")
                self.showAlert = true
            }
        }
    }
    
    private func unblockUser() {
        guard !isBlocking else { 
            print("⚠️ BLOCK_VIEW: unblockUser called but already processing")
            return 
        }
        
        print("🔓 BLOCK_VIEW: unblockUser initiated for user: \(user.username) (UID: \(user.uid))")
        
        isBlocking = true
        print("🔓 BLOCK_VIEW: Set isBlocking to true")
        
        blockService.unblockUser(userId: user.uid) { success in
            print("🔓 BLOCK_VIEW: blockService.unblockUser completion called with success: \(success)")
            
            DispatchQueue.main.async {
                self.isBlocking = false
                print("🔓 BLOCK_VIEW: Set isBlocking to false")
                
                if success {
                    self.alertMessage = "Successfully unblocked \(self.user.username)"
                    self.isUserBlocked = false
                    print("✅ BLOCK_VIEW: Unblock operation successful")
                } else {
                    self.alertMessage = "Failed to unblock user. Please try again."
                    print("❌ BLOCK_VIEW: Unblock operation failed")
                }
                
                print("🔓 BLOCK_VIEW: Showing alert with message: \(self.alertMessage)")
                self.showAlert = true
            }
        }
    }
}

#Preview {
    BlockView(user: User(
        uid: "preview",
        username: "previewuser",
        fullname: "Preview User",
        profileImageUrl: "",
        email: "preview@example.com",
        isVerified: false,
        followers: 0,
        following: 0,
        podCount: 0
    ))
}
