//
//  PlaylistPodSearchViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/19/23.
//

import SwiftUI
import Firebase
import FirebaseAuth

class PlaylistPodSearchViewModel: ObservableObject {
    @Published var allPods = [Pod]() // All loaded pods
    @Published var filteredPods = [Pod]() // Displayed pods (either all or search results)
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var hasMorePods = true
    @Published var isFetchingMore = false
    
    private let service = PodService()
    private let userService = UserService()
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 10
    private var currentUserId: String?
    
    // Playlist context
    var playlistPodIds: [String] = []
    
    // Debounced search
    private var searchTimer: Timer?
    private let searchDelay: TimeInterval = 0.8 // Wait 0.8 seconds after user stops typing
    
    init() {
        // Get current user ID
        if let uid = Auth.auth().currentUser?.uid {
            self.currentUserId = uid
        }
    }
    
    deinit {
        searchTimer?.invalidate()
    }
    
    // MARK: - Search and Fetch Methods
    
    /// Performs debounced search for user pods - waits for user to stop typing
    func performSearch() {
        // Cancel any existing timer
        searchTimer?.invalidate()
        
        // If search text is empty, show all pods immediately
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Smoothly switch back to all pods without clearing data
            filteredPods = allPods
            return
        }
        
        // Set a new timer - only search after user stops typing
        searchTimer = Timer.scheduledTimer(withTimeInterval: searchDelay, repeats: false) { [weak self] _ in
            self?.searchPods()
        }
    }
    
    /// Searches for user pods with current search text
    private func searchPods() {
        guard let uid = currentUserId else {
            print("❌ [PlaylistPodSearchViewModel] No current user ID")
            return
        }
        
        // For search, we need to fetch more aggressively since we're doing client-side filtering
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fetchSearchResults()
        } else {
            // If search is cleared, show all pods
            filteredPods = allPods
        }
    }
    
    /// Fetches search results with more aggressive fetching for client-side filtering
    private func fetchSearchResults() {
        guard let uid = currentUserId, !isLoading else { return }
        
        isLoading = true
        print("🔍 [PlaylistPodSearchViewModel] Fetching search results (search: '\(searchText)')")
        
        // For search, fetch a larger batch to get better results
        service.fetchPaginatedUserPodsForPlaylist(
            uid: uid,
            searchText: searchText,
            limit: 50, // Fetch more for better search coverage
            lastDocument: nil
        ) { [weak self] pods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Update filteredPods with search results (don't touch allPods)
                self.filteredPods = pods
                self.lastDocument = lastDocument
                // For search, we typically don't need pagination since we fetch a large batch
                self.hasMorePods = false
                self.isLoading = false
                
                print("✅ [PlaylistPodSearchViewModel] Search results loaded: \(pods.count) pods")
            }
        }
    }
    
    /// Fetches the first page of user pods
    func fetchFirstPage() {
        guard let uid = currentUserId, !isLoading else { return }
        
        isLoading = true
        print("🔍 [PlaylistPodSearchViewModel] Fetching first page")
        
        service.fetchPaginatedUserPodsForPlaylist(
            uid: uid,
            searchText: nil, // No search for first page
            limit: pageSize,
            lastDocument: nil
        ) { [weak self] pods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.allPods = pods
                self.filteredPods = pods // Show all pods initially
                self.lastDocument = lastDocument
                self.hasMorePods = pods.count == self.pageSize // Only show more if we got exactly the page size
                self.isLoading = false
                
                print("✅ [PlaylistPodSearchViewModel] First page loaded: \(pods.count) pods, hasMore: \(self.hasMorePods)")
            }
        }
    }
    
    /// Fetches the next page of user pods
    func fetchNextPage() {
        guard let uid = currentUserId, 
              hasMorePods, 
              !isFetchingMore,
              let lastDoc = lastDocument else { return }
        
        isFetchingMore = true
        print("🔍 [PlaylistPodSearchViewModel] Fetching next page")
        
        service.fetchPaginatedUserPodsForPlaylist(
            uid: uid,
            searchText: nil, // No search for pagination
            limit: pageSize,
            lastDocument: lastDoc
        ) { [weak self] newPods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.allPods.append(contentsOf: newPods)
                self.filteredPods = self.allPods // Update filtered pods to show all
                self.lastDocument = lastDocument
                self.hasMorePods = newPods.count == self.pageSize // Only show more if we got exactly the page size
                self.isFetchingMore = false
                
                print("✅ [PlaylistPodSearchViewModel] Next page loaded: \(newPods.count) pods, hasMore: \(self.hasMorePods)")
            }
        }
    }
    
    /// Clears search and resets to show all user pods
    func clearSearch() {
        searchText = ""
        // Smoothly switch back to all pods without clearing data
        filteredPods = allPods
    }
    
    /// Refreshes the current search
    func refresh() {
        // Cancel any pending search
        searchTimer?.invalidate()
        
        lastDocument = nil
        hasMorePods = true
        allPods.removeAll()
        filteredPods.removeAll()
        fetchFirstPage()
    }
    
    /// Cancels any pending search
    func cancelSearch() {
        searchTimer?.invalidate()
    }
    
    // MARK: - Computed Properties
    
    /// Returns filtered pods based on search text and excludes pods already in playlist
    var displayPods: [Pod] {
        // First filter out pods that are already in the playlist
        let availablePods = filteredPods.filter { pod in
            guard let podId = pod.id else { return false }
            return !playlistPodIds.contains(podId)
        }
        
        return availablePods
    }
    
    /// Returns whether to show loading indicator
    var shouldShowLoading: Bool {
        return isLoading && filteredPods.isEmpty
    }
    
    /// Returns whether to show "no pods" message
    var shouldShowNoPodsMessage: Bool {
        return filteredPods.isEmpty && !isLoading && !hasMorePods
    }
    
    /// Returns whether to show "no more pods" message
    var shouldShowNoMorePodsMessage: Bool {
        return !filteredPods.isEmpty && !hasMorePods && !isFetchingMore
    }
}
