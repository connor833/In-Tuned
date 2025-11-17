//
//  FollowersView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/18/23.
//

import SwiftUI

struct FollowersView: View {
    @State private var searchText = ""
    @State private var showingRemoveConfirmation = false
    @State private var userToRemove: User?
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
                
                Text("Followers")
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
                        userViewModel.performDebouncedSearchFollowers(searchText: newValue)
                    }
                
                // Show search pending indicator
                if userViewModel.isSearchPendingFollowers && !searchText.isEmpty {
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
            
            if userViewModel.isLoadingFollowers {
                // Initial loading state
                VStack(spacing: 20) {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        .scaleEffect(1.5)
                    
                    Text("Loading followers...")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack {
                        ForEach(userViewModel.filteredFollowers) { follower in
                        HStack(alignment: .center) {
                            ProfileRowView(user: follower)
                                .foregroundColor(Color("textColor"))
                            
                            Spacer()
                            
                            // Show remove button only if viewing own followers
                            if userViewModel.isCurrentUser {
                                Button {
                                    userToRemove = follower
                                    showingRemoveConfirmation = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 20))
                                }
                                .padding(.trailing, 16)
                            }
                        }
                        .onAppear {
                            // Load more when reaching the last item
                            if follower.id == userViewModel.filteredFollowers.last?.id {
                                userViewModel.loadMoreFollowers()
                            }
                        }
                    }
                    
                    // Loading indicator
                    if userViewModel.isLoadingMoreFollowers {
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
                    if !userViewModel.hasMoreFollowers && !userViewModel.filteredFollowers.isEmpty {
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
            userViewModel.fetchUserFollowers()
        }
        .alert("Remove Follower", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) {
                userToRemove = nil
            }
            Button("Remove", role: .destructive) {
                if let userToRemove = userToRemove {
                    userViewModel.removeFollower(user: userToRemove) { success in
                        if success {
                            // Remove from the filtered followers list
                            userViewModel.filteredFollowers.removeAll { $0.id == userToRemove.id }
                            userViewModel.followers.removeAll { $0.id == userToRemove.id }
                        }
                    }
                }
                userToRemove = nil
            }
        } message: {
            if let userToRemove = userToRemove {
                Text("Are you sure you want to remove \(userToRemove.fullname ?? userToRemove.username) as a follower?")
            }
        }
    }
}

struct FollowersView_Previews: PreviewProvider {
    static var previews: some View {
        FollowersView(user: PreviewClass().previewUser, userViewModel: UserViewModel(user: PreviewClass().previewUser, authViewModel: AuthViewModel.shared))
    }
}
