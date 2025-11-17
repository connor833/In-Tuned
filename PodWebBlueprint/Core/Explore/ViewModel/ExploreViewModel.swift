//
//  ExploreViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import Foundation
import SwiftUI

/// ViewModel for the main Explore home view
/// Manages state for preview sections
class ExploreViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var trendingPods: [Pod] = []
    @Published var newPods: [Pod] = []
    @Published var topChartsPods: [Pod] = []
    @Published var featuredPods: [Pod] = []
    
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String = ""
    
    // MARK: - Private Properties
    
    private let service: ExploreService
    private let previewLimit = 5 // Show 5 items in home preview sections
    
    // MARK: - Initialization
    
    init(currentUser: User? = nil) {
        self.service = ExploreService(currentUser: currentUser)
    }
    
    // MARK: - Public Methods
    
    /// Load all explore home data (trending, new, top charts preview)
    func loadExploreHome() {
        guard !isLoading else { return }
        
        print("🏠 [ExploreViewModel] Loading explore home data...")
        isLoading = true
        hasError = false
        
        let group = DispatchGroup()
        
        // Fetch Trending (preview)
        group.enter()
        service.fetchTrending(limit: previewLimit) { [weak self] pods in
            DispatchQueue.main.async {
                self?.trendingPods = pods
                print("✅ [ExploreViewModel] Loaded \(pods.count) trending pods")
                group.leave()
            }
        }
        
        // Fetch New & Noteworthy (preview)
        group.enter()
        service.fetchNewAndNoteworthy(limit: previewLimit) { [weak self] pods in
            DispatchQueue.main.async {
                self?.newPods = pods
                print("✅ [ExploreViewModel] Loaded \(pods.count) new pods")
                group.leave()
            }
        }
        
        // Fetch Top Charts (preview - just top 3)
        group.enter()
        service.fetchTopCharts(limit: 3) { [weak self] pods in
            DispatchQueue.main.async {
                self?.topChartsPods = pods
                print("✅ [ExploreViewModel] Loaded \(pods.count) top chart pods")
                group.leave()
            }
        }
        
        // Fetch Featured (preview)
        group.enter()
        service.fetchFeatured(limit: previewLimit) { [weak self] pods in
            DispatchQueue.main.async {
                self?.featuredPods = pods
                print("✅ [ExploreViewModel] Loaded \(pods.count) featured pods")
                group.leave()
            }
        }
        
        // All fetches complete
        group.notify(queue: .main) { [weak self] in
            self?.isLoading = false
            print("✅ [ExploreViewModel] Explore home data loaded successfully")
        }
    }
    
    /// Refresh all content
    func refresh() {
        print("🔄 [ExploreViewModel] Refreshing explore home...")
        loadExploreHome()
    }
}