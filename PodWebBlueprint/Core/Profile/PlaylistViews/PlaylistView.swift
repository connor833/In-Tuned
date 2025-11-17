//
//  PlaylistView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/19/23.
//

import SwiftUI
import Kingfisher
import FirebaseAuth

struct PlaylistView: View {
    
    var playlist: Playlist
    var user: User
    @Environment(\.presentationMode) var mode
    @State var AddToPlaylist = false
    @State var editPlaylistName = false
    @State var removeFromPlaylist = false
    
    @ObservedObject var playlistViewModel: PlaylistViewModel
    
    // Check if this playlist belongs to the current user
    private var isCurrentUserPlaylist: Bool {
        return playlist.userId == Auth.auth().currentUser?.uid
    }
    
    init(playlist: Playlist, user: User) {
        self.playlist = playlist
        self.user = user
        self.playlistViewModel = PlaylistViewModel(playlist: playlist, user: user)
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
                
                // Playlist info with exact same image code as PlaylistRowView
                HStack(spacing: 12) {
                    KFImage(URL(string: playlistViewModel.playlist.thumbnailUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 48)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlistViewModel.playlist.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("\(playlistViewModel.pods.count) \(playlistViewModel.pods.count == 1 ? "pod" : "pods")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Only show edit button for playlist owner
                if isCurrentUserPlaylist {
                    Menu {
                        Button {
                            editPlaylistName.toggle()
                        } label: {
                            Text("Change playlist name")
                            Image(systemName: "pencil")
                        }
                        
                        Button {
                            AddToPlaylist.toggle()
                        } label: {
                            Text("Add to playlist")
                            Image(systemName: "plus")
                        }
                        
                        Button {
                            removeFromPlaylist.toggle()
                        } label: {
                            Text("Remove pods from playlist")
                            Image(systemName: "minus")
                        }
                        
                        Button {
                            print("delete playlist")
                            playlistViewModel.deletePlaylist()
                            mode.wrappedValue.dismiss()
                        } label: {
                            Text("Delete playlist")
                            Image(systemName: "x.square")
                        }
                        
                        
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Edit")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color("accentColor"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
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
                    .sheet(isPresented: $AddToPlaylist) {
                        AddToPlaylistView(user: user, playlist: playlistViewModel.playlist, viewModel: playlistViewModel)
                    }
                    .sheet(isPresented: $removeFromPlaylist) {
                        RemoveFromPlaylistView(user: user, playlist: playlistViewModel.playlist, viewModel: playlistViewModel)
                    }
                    .sheet(isPresented: $editPlaylistName) {
                        EditPlaylistNameView(playlist: playlistViewModel.playlist, user: user, playlistViewModel: playlistViewModel)
                    }
                } else {
                    // Empty space to balance the layout
                    HStack(spacing: 6) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Edit")
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
            
            
            // Modern creator info section (non-clickable)
            HStack(spacing: 12) {
                Text("Created by")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    if user.profileImageUrl != "" {
                        KFImage(URL(string: user.profileImageUrl))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(user.fullname?.isEmpty == false ? user.fullname! : user.username)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if user.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(.systemBlue))
                            }
                        }
                        
                        Text("@\(user.username)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            
            
            ScrollView {
                LazyVStack {
                    ForEach(playlistViewModel.pods, id: \.id) { pod in
                        if pod.isDeleted == true {
                            // Show deleted pod placeholder with remove button
                            DeletedPodRowView(pod: pod) {
                                if let podId = pod.id {
                                    playlistViewModel.removeDeletedPod(podId: podId)
                                }
                            }
                        } else {
                            // Show normal pod
                            NavigationLink {
                                PlayerView(url: (URL(string: pod.fileUrl))!, pod: pod)
                            } label: {
                                PodRowViewThin(pod: pod)
                                    .foregroundColor(Color("textColor"))
                            }
                        }
                    }
                }
            }

            
        }
        .navigationBarBackButtonHidden()
    }
}

struct PlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistView(playlist: PreviewClass().previewPlaylist, user: PreviewClass().previewUser)
    }
}
