//
//  EditPlaylistNameView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/20/23.
//

import SwiftUI

struct EditPlaylistNameView: View {
    @State var title = ""
    
    let playlist: Playlist
    let user: User
    @ObservedObject var playlistViewModel: PlaylistViewModel
    
    @Environment(\.presentationMode) var mode
    
    // Error handling
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    init(playlist: Playlist, user: User, playlistViewModel: PlaylistViewModel) {
        self.playlist = playlist
        self.user = user
        self.playlistViewModel = playlistViewModel
    }
    var body: some View {
        VStack(spacing: 0) {
            // Modern header with cool back button
            HStack {
                Button {
                    mode.wrappedValue.dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.red, lineWidth: 2)
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
                
                Text("Edit Playlist Name")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    // Validate playlist title for profanity
                    let titleResult = InputSanitizer.sanitize(title, type: .playlistTitle)
                    if !titleResult.isValid {
                        errorMessage = titleResult.errorMessage ?? "Invalid playlist title"
                        showErrorAlert = true
                        return
                    }
                    
                    playlistViewModel.changePlaylistName(newTitle: titleResult.sanitizedText)
                    mode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Save")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
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
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            Divider()
                .background(Color(.systemGray4))
                .padding(.horizontal)
            
            // Modern form section
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playlist Name")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField(playlist.title, text: $title)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 30)
            
            Spacer()
        }
        .alert("Invalid Playlist Title", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}

struct EditPlaylistNameView_Previews: PreviewProvider {
    static var previews: some View {
        EditPlaylistNameView(playlist: PreviewClass().previewPlaylist, user: PreviewClass().previewUser, playlistViewModel: PlaylistViewModel(playlist: PreviewClass().previewPlaylist, user: PreviewClass().previewUser))
    }
}
