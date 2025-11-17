//
//  FollowersView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/18/23.
//

import SwiftUI

struct FollowingView: View {
    @State private var searchText = ""
    @State private var showingUnfollowConfirmation = false
    @State private var userToUnfollow: User?
    @ObservedObject var userViewModel: UserViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var user: User
    
    init(user: User, userViewModel: UserViewModel) {
        self.user = user
        self.userViewModel = userViewModel
    }
    
    var body: some View {
        VStack {
            // Header with cool back button
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
                
                Text("Following")
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
            
            HStack {
                SearchBar(text: $searchText)
                    .onChange(of: searchText) { newValue in
                        userViewModel.performDebouncedSearchFollowing(searchText: newValue)
                    }
                
                // Show search pending indicator
                if userViewModel.isSearchPendingFollowing && !searchText.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding()
            
            if userViewModel.isLoadingFollowing {
                // Initial loading state
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        .scaleEffect(1.5)
                    
                    Text("Loading following...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack {
                        ForEach(userViewModel.filteredFollowing) { followingUser in
                        HStack(alignment: .center) {
                            ProfileRowView(user: followingUser)
                                .foregroundColor(Color("textColor"))
                            
                            Spacer()
                            
                            // Show unfollow button only if viewing own following
                            if userViewModel.isCurrentUser {
                                Button {
                                    userToUnfollow = followingUser
                                    showingUnfollowConfirmation = true
                                } label: {
                                    Image(systemName: "person.badge.minus")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))
                                }
                                .padding(.trailing, 16)
                            }
                        }
                        .onAppear {
                            // Load more when reaching the last item
                            if followingUser.id == userViewModel.filteredFollowing.last?.id {
                                userViewModel.loadMoreFollowing()
                            }
                        }
                    }
                    
                    // Loading indicator
                    if userViewModel.isLoadingMoreFollowing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading more...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    
                    // No more results indicator
                    if !userViewModel.hasMoreFollowing && !userViewModel.filteredFollowing.isEmpty {
                        Text("No more users to load")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
            }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            userViewModel.checkIfCurrentUser(user: user)
            userViewModel.fetchUserFollowing()
        }
        .alert("Unfollow User", isPresented: $showingUnfollowConfirmation) {
            Button("Cancel", role: .cancel) {
                userToUnfollow = nil
            }
            Button("Unfollow", role: .destructive) {
                if let userToUnfollow = userToUnfollow {
                    userViewModel.unfollowSpecificUser(user: userToUnfollow) { success in
                        if success {
                            // Remove from the filtered following list
                            userViewModel.filteredFollowing.removeAll { $0.id == userToUnfollow.id }
                            userViewModel.following.removeAll { $0.id == userToUnfollow.id }
                        }
                    }
                }
                userToUnfollow = nil
            }
        } message: {
            if let userToUnfollow = userToUnfollow {
                Text("Are you sure you want to unfollow \(userToUnfollow.fullname ?? userToUnfollow.username)?")
            }
        }
    }
}

struct FollowingView_Previews: PreviewProvider {
    static var previews: some View {
        FollowingView(user: PreviewClass().previewUser, userViewModel: UserViewModel(user: PreviewClass().previewUser, authViewModel: AuthViewModel.shared))
    }
}
