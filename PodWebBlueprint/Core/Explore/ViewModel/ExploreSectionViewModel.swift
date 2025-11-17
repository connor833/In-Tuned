//
//  ExploreSectionViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseFirestore

/// ViewModel for drill-down section views (Trending, New, Top Charts, etc.)
/// Handles loading full list of pods for a specific section with pagination
class ExploreSectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var pods: [Pod] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var hasError = false
    @Published var errorMessage: String = ""
    
    // MARK: - Private Properties
    
    private let service: ExploreService
    private let pageSize = 20 // Load 20 items per page
    private var lastDocument: DocumentSnapshot?
    
    // Track current query for loadMore
    private var currentCategory: PodCategory?
    private var currentMood: PodMood?
    
    // MARK: - Initialization
    
    init(currentUser: User? = nil) {
        self.service = ExploreService(currentUser: currentUser)
    }
    
    // MARK: - Public Methods
    
    /// Load pods for a specific section
    /// - Parameter section: The explore section to load
    func loadPods(for section: ExploreSection) {
        guard !isLoading else { return }
        
        print("📱 [ExploreSectionViewModel] Loading pods for section: \(section.rawValue)")
        isLoading = true
        hasError = false
        pods = [] // Clear existing
        
        switch section {
        case .trending:
            service.fetchTrending(limit: 50) { [weak self] fetchedPods in
                self?.handleFetchComplete(fetchedPods, section: section)
            }
            
        case .newAndNoteworthy:
            service.fetchNewAndNoteworthy(limit: 50) { [weak self] fetchedPods in
                self?.handleFetchComplete(fetchedPods, section: section)
            }
            
        case .topCharts:
            service.fetchTopCharts(limit: 25) { [weak self] fetchedPods in
                self?.handleFetchComplete(fetchedPods, section: section)
            }
            
        case .featured:
            service.fetchFeatured(limit: 50) { [weak self] fetchedPods in
                self?.handleFetchComplete(fetchedPods, section: section)
            }
            
        case .categories, .moods:
            // These sections navigate to category/mood picker, not here
            print("⚠️ [ExploreSectionViewModel] Section \(section.rawValue) should use specific category/mood loading")
            isLoading = false
        }
    }
    
    /// Load pods for a specific category
    /// - Parameter category: The category to load
    func loadPods(for category: PodCategory) {
        guard !isLoading else { return }
        
        print("📂 [ExploreSectionViewModel] Loading pods for category: \(category.rawValue)")
        isLoading = true
        hasError = false
        pods = []
        lastDocument = nil
        hasMore = true
        currentCategory = category
        currentMood = nil
        
        service.fetchByCategory(category, limit: pageSize, lastDocument: nil) { [weak self] fetchedPods, lastDoc in
            DispatchQueue.main.async {
                self?.pods = fetchedPods
                self?.lastDocument = lastDoc
                self?.hasMore = fetchedPods.count == self?.pageSize
                self?.isLoading = false
                print("✅ [ExploreSectionViewModel] Loaded \(fetchedPods.count) pods for category: \(category.rawValue)")
            }
        }
    }
    
    /// Load pods for a specific mood
    /// - Parameter mood: The mood to load
    func loadPods(for mood: PodMood) {
        guard !isLoading else { return }
        
        print("🎭 [ExploreSectionViewModel] Loading pods for mood: \(mood.rawValue)")
        isLoading = true
        hasError = false
        pods = []
        lastDocument = nil
        hasMore = true
        currentMood = mood
        currentCategory = nil
        
        service.fetchByMood(mood, limit: pageSize, lastDocument: nil) { [weak self] fetchedPods, lastDoc in
            DispatchQueue.main.async {
                self?.pods = fetchedPods
                self?.lastDocument = lastDoc
                self?.hasMore = fetchedPods.count == self?.pageSize
                self?.isLoading = false
                print("✅ [ExploreSectionViewModel] Loaded \(fetchedPods.count) pods for mood: \(mood.rawValue)")
            }
        }
    }
    
    // MARK: - Load More (Pagination)
    
    /// Load more pods (next page)
    func loadMore() {
        guard !isLoadingMore, hasMore, let lastDoc = lastDocument else {
            print("⚠️ [ExploreSectionViewModel] Cannot load more - isLoadingMore: \(isLoadingMore), hasMore: \(hasMore), hasLastDoc: \(lastDocument != nil)")
            return
        }
        
        print("📄 [ExploreSectionViewModel] Loading more pods...")
        isLoadingMore = true
        
        if let category = currentCategory {
            // Loading more for category
            service.fetchByCategory(category, limit: pageSize, lastDocument: lastDoc) { [weak self] fetchedPods, newLastDoc in
                self?.handleLoadMoreComplete(fetchedPods: fetchedPods, newLastDoc: newLastDoc)
            }
        } else if let mood = currentMood {
            // Loading more for mood
            service.fetchByMood(mood, limit: pageSize, lastDocument: lastDoc) { [weak self] fetchedPods, newLastDoc in
                self?.handleLoadMoreComplete(fetchedPods: fetchedPods, newLastDoc: newLastDoc)
            }
        }
    }
    
    private func handleLoadMoreComplete(fetchedPods: [Pod], newLastDoc: DocumentSnapshot?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.pods.append(contentsOf: fetchedPods)
            self.lastDocument = newLastDoc
            self.hasMore = fetchedPods.count == self.pageSize
            self.isLoadingMore = false
            
            print("✅ [ExploreSectionViewModel] Loaded \(fetchedPods.count) more pods. Total: \(self.pods.count)")
        }
    }
    
    /// Refresh current pods
    func refresh() {
        print("🔄 [ExploreSectionViewModel] Refreshing pods...")
        // Note: Would need to track current section/category/mood to refresh properly
        // For now, just clear loading state
        isLoading = false
    }
    
    // MARK: - Private Helpers
    
    private func handleFetchComplete(_ fetchedPods: [Pod], section: ExploreSection) {
        DispatchQueue.main.async { [weak self] in
            self?.pods = fetchedPods
            self?.isLoading = false
            print("✅ [ExploreSectionViewModel] Loaded \(fetchedPods.count) pods for \(section.rawValue)")
        }
    }
}
