//
//  CreatePlaylistView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/18/23.
//

import SwiftUI
import Kingfisher

struct AddToPlaylistView: View {
    
    @State var title = ""
    @ObservedObject var viewModel: PlaylistViewModel
    @StateObject private var podSearchViewModel = PlaylistPodSearchViewModel()
    @Environment(\.presentationMode) var mode
    
    let user: User
    var playlist: Playlist
    @State var selectedPods = [String]()
    @State private var podViewModels: [String: PodViewModel] = [:]
    
    init(user: User, playlist: Playlist, viewModel: PlaylistViewModel) {
        self.user = user
        self.playlist = playlist
        self.viewModel = viewModel
        self.title = playlist.title
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
                
                Text("Add to Playlist")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    viewModel.addPodsToPlaylist(podIds: selectedPods)
                    mode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add")
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
                    Text("Adding to:")
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
            
            HStack {
                SearchBar(text: $podSearchViewModel.searchText)
                    .onChange(of: podSearchViewModel.searchText) { _ in
                        podSearchViewModel.performSearch()
                    }
                
                // Show loading indicator while search is pending
                if podSearchViewModel.isLoading && podSearchViewModel.filteredPods.isEmpty {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
            }
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(podSearchViewModel.displayPods) { pod in
                        Button {
                            togglePodSelection(pod)
                        } label: {
                            PodRowViewThinForSelection(pod: pod, isSelected: selectedPods.contains(pod.id ?? ""))
                        }
                        .onAppear {
                            // Load more when reaching the last few items
                            if pod.id == podSearchViewModel.displayPods.last?.id && 
                               podSearchViewModel.hasMorePods && 
                               !podSearchViewModel.isFetchingMore {
                                podSearchViewModel.fetchNextPage()
                            }
                        }
                    }
                    
                    // Loading indicator at bottom
                    if podSearchViewModel.isFetchingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .onAppear {
                // Set the playlist pod IDs to filter out already added pods
                podSearchViewModel.playlistPodIds = viewModel.podIds
                podSearchViewModel.fetchFirstPage()
            }
        }
        .padding()
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
}

struct AddToPlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        AddToPlaylistView(user: PreviewClass().previewUser, playlist: PreviewClass().previewPlaylist, viewModel: PlaylistViewModel(playlist: PreviewClass().previewPlaylist, user: PreviewClass().previewUser))
    }
}
