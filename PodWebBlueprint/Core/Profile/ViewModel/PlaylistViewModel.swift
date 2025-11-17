//
//  PlaylistViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/19/23.
//

import SwiftUI
import Firebase

class PlaylistViewModel: ObservableObject {
    @Published var pods = [Pod]()
    let service = PodService()
    let userService = UserService()
    @Published var podIds = [String]()
    @Published var AddPods = [Pod]()
    @Published var searchText = ""
    @Published var isSearchPending = false
    
    private var searchTimer: Timer?
    private let searchDelay: TimeInterval = 0.8
    
    @Published var playlist: Playlist
    var user: User
    
    init(playlist: Playlist, user: User) {
        self.playlist = playlist
        self.user = user
        self.fetchPlaylist()
    }
    
    deinit {
        searchTimer?.invalidate()
        searchTimer = nil
    }
    
    var searchableAddPods: [Pod] {
        // Since we're now doing server-side filtering, just return AddPods directly
        // The search filtering is handled by fetchPaginatedUserPodsForPlaylist
        return AddPods
    }
    
    func fetchPlaylist() {
        guard let playlistId = playlist.id, let uid = user.id else {
            print("❌ [PlaylistViewModel] Missing playlistId or uid")
            return
        }

        print("🔍 [PlaylistViewModel] Fetching playlist: \(playlistId)")

        // First fetch the complete playlist data with all new fields
        service.fetchPlaylist(withPlaylistId: playlistId, uid: uid) { fetchedPlaylist in
            if let fetchedPlaylist = fetchedPlaylist {
                DispatchQueue.main.async {
                    self.playlist = fetchedPlaylist
                    print("✅ [PlaylistViewModel] Updated playlist data")
                }
            }
        }

        // Clear existing pods array
        DispatchQueue.main.async {
            self.pods.removeAll()
        }

        // Then fetch the pod IDs and pods
        service.fetchPlaylistPodIds(withPlaylistId: playlistId, uid: uid) { podIds in
            print("📝 [PlaylistViewModel] Found \(podIds.count) pod IDs in playlist")
            
            DispatchQueue.main.async {
                self.podIds = podIds
            }
            
            // Use DispatchGroup to wait for all pods to be fetched
            let group = DispatchGroup()
            var fetchedPods: [Pod] = []
            
            for podId in podIds {
                group.enter()
                
                // Fetch pod from Firestore
                Firestore.firestore().collection("pods").document(podId).getDocument { snapshot, error in
                    if let snapshot = snapshot, snapshot.exists,
                       let pod = try? snapshot.data(as: Pod.self) {
                        // Pod exists - add it normally
                        var podWithId = pod
                        podWithId.id = podId
                        fetchedPods.append(podWithId)
                        print("✅ [PlaylistViewModel] Fetched pod: \(pod.title)")
                    } else {
                        // Pod doesn't exist - create placeholder for deleted pod
                        var placeholderPod = Pod(
                            title: "Pod not available",
                            timestamp: Timestamp(date: Date()),
                            description: "This pod has been deleted or is no longer accessible.",
                            fileUrl: "",
                            thumbnailUrl: "",
                            userId: "",
                            likes: 0
                        )
                        placeholderPod.id = podId
                        placeholderPod.isDeleted = true
                        fetchedPods.append(placeholderPod)
                        print("⚠️ [PlaylistViewModel] Pod \(podId) not found, created placeholder")
                    }
                    group.leave()
                }
            }
            
            // Update UI when all pods are fetched
            group.notify(queue: .main) {
                self.pods = fetchedPods
                print("✅ [PlaylistViewModel] All \(fetchedPods.count) pods loaded")
            }
        }
    }
    
    func deletePlaylist() {
        guard let playlistId = playlist.id, let uid = user.id else {
            print(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Playlist or user ID is missing."]))
            return
        }
        
        userService.deletePlaylist(withPlaylistId: playlistId, uid: uid) { _, _ in
      
        }
    }

    
    func deletePod(podId: String) {
        guard let playlistId = playlist.id, let uid = user.id else {
            print(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Playlist or user ID is missing."]))
            return
        }
        
        service.removePodFromPlaylist(playlistId: playlistId, uid: uid, podId: podId) { success, error in
            if success {
                // Immediately update local array and playlist podCount for UI feedback
                DispatchQueue.main.async {
                    self.pods.removeAll { $0.id == podId }
                    self.playlist.podCount = max(0, self.playlist.podCount - 1)
                }
            }
            print(success, error as Any)
        }
    }
    
    /// Removes a deleted pod from the playlist
    /// Similar to removeOrphanedSavedPod for saved pods
    func removeDeletedPod(podId: String) {
        guard let playlistId = playlist.id, let uid = user.id else {
            print("❌ [PlaylistViewModel] Missing playlistId or uid")
            return
        }
        
        print("🗑️ [PlaylistViewModel] Removing deleted pod \(podId) from playlist")
        
        service.removePodFromPlaylist(playlistId: playlistId, uid: uid, podId: podId) { success, error in
            if success {
                DispatchQueue.main.async {
                    // Remove from local array
                    self.pods.removeAll { $0.id == podId }
                    self.podIds.removeAll { $0 == podId }
                    self.playlist.podCount = max(0, self.playlist.podCount - 1)
                    print("✅ [PlaylistViewModel] Successfully removed deleted pod from playlist")
                }
            } else {
                print("❌ [PlaylistViewModel] Failed to remove deleted pod: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }

    
    func changePlaylistName(newTitle: String) {
        guard let playlistId = playlist.id, let uid = user.id else {
            return
        }
        
        service.changePlaylistName(playlistId: playlistId, newTitle: newTitle, uid: uid) { results in
            if let success = results.first, success {
                // Immediately update local playlist for UI feedback
                DispatchQueue.main.async {
                    self.playlist.title = newTitle
                }
            }
        }
    }
    
    func fetchAddPods(playlist: Playlist, user: User, searchQuery: String? = nil) {
        guard let playlistId = playlist.id, let uid = user.id else {
            print("❌ [PlaylistViewModel] Missing playlistId or uid")
            return
        }
        
        print("🔍 [PlaylistViewModel] Fetching add pods for playlist: \(playlistId), user: \(uid), search: '\(searchQuery ?? "none")'")
        print("🔍 [PlaylistViewModel] searchQuery is nil: \(searchQuery == nil)")
        print("🔍 [PlaylistViewModel] searchQuery isEmpty: \(searchQuery?.isEmpty ?? true)")
        
        // Use the new paginated search method
        service.fetchPaginatedUserPodsForPlaylist(
            uid: uid,
            searchText: searchQuery,
            limit: 10,
            lastDocument: nil
        ) { [weak self] pods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Filter out pods that are already in the playlist
                let availablePods = pods.filter { pod in
                    guard let podId = pod.id else { return false }
                    return !self.podIds.contains(podId)
                }
                
                self.AddPods = availablePods
                print("✅ [PlaylistViewModel] Loaded \(availablePods.count) pods available to add")
            }
        }
    }
    
    /// Debounced search - waits for user to stop typing (exactly like message tab view)
    func performDebouncedSearch() {
        print("🔍 [PlaylistViewModel] performDebouncedSearch called with text: '\(searchText)'")
        
        // Cancel any existing timer
        searchTimer?.invalidate()
        searchTimer = nil
        
        // Don't search if text is empty
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 [PlaylistViewModel] Search text is empty, not searching")
            isSearchPending = false
            // If search is cleared, show all available pods (no search query)
            fetchAddPods(playlist: playlist, user: user, searchQuery: nil)
            return
        }
        
        // Set search as pending
        isSearchPending = true
        print("🔍 [PlaylistViewModel] Starting debounced search for: '\(searchText)' (waiting \(searchDelay)s)")
        
        // Create new timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: searchDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("🔍 [PlaylistViewModel] Timer fired, executing search for: '\(self.searchText)'")
                print("🔍 [PlaylistViewModel] Timer fired, searchText.isEmpty: \(self.searchText.isEmpty)")
                self.isSearchPending = false
                // Call fetchAddPods directly with the current searchText value
                self.fetchAddPods(playlist: self.playlist, user: self.user, searchQuery: self.searchText)
            }
        }
    }
    
    func searchAddPods() {
        print("🔍 [PlaylistViewModel] Performing search: '\(searchText)'")
        
        // Clear current results
        AddPods.removeAll()
        
        // Use the fetchAddPods method with current search text
        fetchAddPods(playlist: playlist, user: user, searchQuery: searchText.isEmpty ? nil : searchText)
    }
    
    func addPodsToPlaylist(podIds: [String]) {
        guard let playlistId = playlist.id, let uid = user.id else {
            return
        }
        
        // Add pods to backend
        service.addPodsToPlaylist(uid: uid, playlistId: playlistId, podIds: podIds) { success, error in
            if success {
                // Update local array and playlist podCount immediately for UI feedback
                DispatchQueue.main.async {
                    // Update pod count
                    self.playlist.podCount += podIds.count
                    
                    // Fetch the added pods and append them to the local array
                    for podId in podIds {
                        self.service.fetchPod(withPodId: podId, uid: uid) { pod in
                            if !self.pods.contains(where: { $0.id == pod.id }) {
                                self.pods.append(pod)
                            }
                        }
                    }
                }
            }
        }
    }




    
}

