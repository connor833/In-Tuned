//
//  RemoveFromPlaylistView.swift
//  PodWebBlueprint
//
//  Created by AI Assistant
//

import SwiftUI
import Kingfisher

struct RemoveFromPlaylistView: View {
    
    @State var title = ""
    @ObservedObject var viewModel: PlaylistViewModel
    @Environment(\.presentationMode) var mode
    
    let user: User
    var playlist: Playlist
    @State var selectedPods = [String]()
    @State private var podViewModels: [String: PodViewModel] = [:]
    @State private var searchText = ""
    
    init(user: User, playlist: Playlist, viewModel: PlaylistViewModel) {
        self.user = user
        self.playlist = playlist
        self.viewModel = viewModel
        self.title = playlist.title
    }
    
    // Computed property for filtered pods in the playlist
    private var filteredPlaylistPods: [Pod] {
        if searchText.isEmpty {
            return viewModel.pods
        } else {
            return viewModel.pods.filter { pod in
                pod.title.localizedCaseInsensitiveContains(searchText) ||
                pod.description.localizedCaseInsensitiveContains(searchText)
            }
        }
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
                
                Text("Remove from Playlist")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    removeSelectedPods()
                    mode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Remove")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.red, .red.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: .red.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedPods.isEmpty)
                .opacity(selectedPods.isEmpty ? 0.5 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            Divider()
                .background(Color(.systemGray4))
                .padding(.horizontal)
            
            // Playlist info section
            VStack(spacing: 12) {
                HStack {
                    Text("Removing from:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    KFImage(URL(string: playlist.thumbnailUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 36)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Text("\(playlist.podCount) \(playlist.podCount == 1 ? "pod" : "pods")")
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
            
            SearchBar(text: $searchText)
                .padding(.horizontal)
            
            if filteredPlaylistPods.isEmpty && !searchText.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No pods found")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Try searching for a different title")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if viewModel.pods.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "music.note.list")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No pods in playlist")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Add some pods to this playlist first")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredPlaylistPods) { pod in
                            Button {
                                togglePodSelection(pod)
                            } label: {
                                PodRowViewThinForSelection(pod: pod, isSelected: selectedPods.contains(pod.id ?? ""))
                            }
                        }
                    }
                }
            }
        }
        .padding(.top)
    }

    private func getPodViewModel(for pod: Pod) -> PodViewModel {
        let podId = pod.id ?? ""
        if let cached = podViewModels[podId] {
            return cached
        } else {
            let newVM = PodViewModel(pod: pod)
            DispatchQueue.main.async {
                podViewModels[podId] = newVM
            }
            return newVM
        }
    }

    private func togglePodSelection(_ pod: Pod) {
        if selectedPods.contains(pod.id ?? "") {
            selectedPods.removeAll { $0 == pod.id }
        } else {
            selectedPods.append(pod.id ?? "")
        }
    }
    
    private func removeSelectedPods() {
        // Remove pods from backend (this will also update the local array)
        for podId in selectedPods {
            viewModel.deletePod(podId: podId)
        }
        
        // Clear the selection
        selectedPods.removeAll()
    }
}

struct RemoveFromPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        RemoveFromPlaylistView(user: PreviewClass().previewUser, playlist: PreviewClass().previewPlaylist, viewModel: PlaylistViewModel(playlist: PreviewClass().previewPlaylist, user: PreviewClass().previewUser))
    }
}
