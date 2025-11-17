//
//  BlockedUsersView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/1/25.
//

import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var blockService = BlockService()
    @State private var blockedUsers: [BlockMetadata] = []
    @State private var isLoading = true
    @State private var showConfirmation = false
    @State private var showResultAlert = false
    @State private var alertMessage = ""
    @State private var userToUnblock: String?
    
    var body: some View {
        VStack {
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
                
                Text("Blocked Users")
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
            
            List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if blockedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("No Blocked Users")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("You haven't blocked any users yet.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowBackground(Color.clear)
            } else {
                ForEach(blockedUsers) { blockedUser in
                    BlockedUserRow(
                        blockedUser: blockedUser,
                        onUnblock: {
                            userToUnblock = blockedUser.blockedUserId
                            showConfirmation = true
                        }
                    )
                }
            }
            }
        }
        .refreshable {
            await loadBlockedUsers()
        }
        .onAppear {
            loadBlockedUsers()
        }
        .alert("Unblock User", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unblock", role: .destructive) {
                if let userId = userToUnblock {
                    unblockUser(userId)
                }
            }
        } message: {
            Text("Are you sure you want to unblock this user? They will be able to see your content and interact with you again.")
        }
        .alert("Unblock Result", isPresented: $showResultAlert) {
            Button("OK") { 
                // Clear the message after showing
                alertMessage = ""
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func loadBlockedUsers() {
        isLoading = true
        
        blockService.fetchBlockedUsers { users in
            DispatchQueue.main.async {
                self.blockedUsers = users
                self.isLoading = false
            }
        }
    }
    
    private func unblockUser(_ userId: String) {
        blockService.unblockUser(userId: userId) { success in
            DispatchQueue.main.async {
                if success {
                    alertMessage = "User unblocked successfully"
                    // Refresh the list
                    loadBlockedUsers()
                } else {
                    alertMessage = "Failed to unblock user. Please try again."
                }
                
                showResultAlert = true
            }
        }
    }
}

struct BlockedUserRow: View {
    let blockedUser: BlockMetadata
    let onUnblock: () -> Void
    
    @State private var user: User?
    @State private var isLoading = true
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Image
            if let user = user, !user.profileImageUrl.isEmpty {
                AsyncImage(url: URL(string: user.profileImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            }
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                if let user = user {
                    Text(user.fullname ?? user.username)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text("@\(user.username)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Loading...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Text(blockedUser.blockType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                    
                    Text(blockedUser.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Unblock Button
            Button("Unblock") {
                onUnblock()
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadUserInfo()
        }
    }
    
    private func loadUserInfo() {
        // Load user info from UserService
        let userService = UserService()
        userService.fetchUser(withUid: blockedUser.blockedUserId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.user = user
                case .failure(let error):
                    print("Error fetching blocked user: \(error.localizedDescription)")
                }
                self.isLoading = false
            }
        }
    }
}

#Preview {
    NavigationView {
        BlockedUsersView()
    }
}
