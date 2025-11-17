//
//  UserPlaylistsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import FirebaseAuth

struct UserPlaylistsView: View {
    @Environment(\.presentationMode) var mode
    @StateObject private var userViewModel: UserViewModel
    @State private var createPlaylist = false
    
    let user: User
    
    // Check if this is the current user's playlist view
    private var isCurrentUser: Bool {
        return user.uid == Auth.auth().currentUser?.uid
    }
    
    init(user: User) {
        self.user = user
        self._userViewModel = StateObject(wrappedValue: UserViewModel(user: user, authViewModel: AuthViewModel.shared))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header with cool back button
            HStack {
                Button {
                    mode.wrappedValue.dismiss()
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
                
                Text("Playlists")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Only show create playlist button for current user
                if isCurrentUser {
                    Button {
                        createPlaylist.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Create")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color("accentColor").opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $createPlaylist) {
                        CreatePlaylistView(user: user)
                    }
                } else {
                    // Empty space to balance the layout
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Create")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.clear)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            Divider()
                .background(Color(.systemGray4))
                .padding(.horizontal)
            
            // Playlists list
            ScrollView {
                LazyVStack {
                    if userViewModel.isLoadingPlaylists {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                            
                            Text("Loading playlists...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else if userViewModel.playlists.isEmpty {
                        VStack(spacing: 24) {
                            Spacer()
                            
                            // Modern empty state icon
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(spacing: 8) {
                                Text("No playlists yet")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                if isCurrentUser {
                                    Text("Create your first playlist to organize your favorite pods")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                } else {
                                    Text("This user hasn't created any playlists yet")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                            }
                            
                            if isCurrentUser {
                                Button {
                                    createPlaylist.toggle()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("Create Playlist")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(
                                                color: Color("accentColor").opacity(0.3),
                                                radius: 8,
                                                x: 0,
                                                y: 4
                                            )
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        ForEach(userViewModel.playlists) { playlist in
                            NavigationLink {
                                PlaylistView(playlist: playlist, user: user)
                            } label: {
                                PlaylistRowView(playlist: playlist)
                            }
                        }
                    }
                }
            }
            .refreshable {
                userViewModel.fetchUserPlaylists(user: user)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            userViewModel.fetchUserPlaylists(user: user)
        }
    }
}

struct UserPlaylistsView_Previews: PreviewProvider {
    static var previews: some View {
        UserPlaylistsView(user: PreviewClass().previewUser)
    }
} 