//
//  PlayerViewModel.swift
//  Attuned
//
//  Created by Connor Adams on 8/12/25.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth

@MainActor
class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()
    
    // MARK: - Published Properties
    @Published var recommendedPods: [Pod] = []
    @Published var isFetching = false
    @Published var hasLoadedPods = false
    @Published var hasLoadedPreferences = false
    @Published var isUserDataLoading = false
    
    // MARK: - Private Properties
    private var podViewModels: [String: PodViewModel] = [:]
    @Published var lastSnapshot: DocumentSnapshot?
    private var cachedQueryCategories: [String] = []
    private let pageSize = 8
    
    // MARK: - Caching Properties
    private var recommendedPodsCache: [String: [Pod]] = [:] // podId -> recommended pods cache
    private var recommendedPodsLastFetch: [String: Date] = [:] // podId -> last fetch time
    private let cacheExpirationInterval: TimeInterval = 120 // 2 minutes (reduced for more variety)
    
    // MARK: - Recommended Pods
    private let recommendedPodsPageSize = 10
    
    // MARK: - Dependencies
    private var userPreferencesViewModel: UserPreferencesViewModel?
    
    // MARK: - Initialization
    private init() {
        // Private init for singleton
    }
    
    func setup(userPreferencesViewModel: UserPreferencesViewModel) {
        self.userPreferencesViewModel = userPreferencesViewModel
    }
    
    // MARK: - Cache Management
    
    /// Check if cache is valid for a specific pod
    private func isCacheValid(for podId: String) -> Bool {
        guard let lastFetch = recommendedPodsLastFetch[podId] else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheExpirationInterval
    }
    
    /// Clear cache for a specific pod
    func clearCache(for podId: String) {
        recommendedPodsCache.removeValue(forKey: podId)
        recommendedPodsLastFetch.removeValue(forKey: podId)
        print("🎯 [PlayerViewModel] Cleared cache for pod: \(podId)")
    }
    
    /// Clear all caches
    func clearAllCaches() {
        recommendedPodsCache.removeAll()
        recommendedPodsLastFetch.removeAll()
        print("🎯 [PlayerViewModel] Cleared all caches")
    }
    
    /// Force refresh recommended pods (bypass cache)
    func forceRefreshRecommendedPods(for currentPod: Pod) {
        guard let podId = currentPod.id else { return }
        
        // Clear cache for this pod
        clearCache(for: podId)
        
        // Reset all state
        hasLoadedPods = false
        isFetching = false
        
        // Clear cached query categories to ensure fresh generation
        cachedQueryCategories = []
        
        // Clear current recommendations
        recommendedPods = []
        
        // Fetch fresh data
        fetchFirstPageOfRecommendedPods(for: currentPod)
    }
    
    /// Get cache statistics for debugging
    func getCacheStats() -> String {
        let cacheCount = recommendedPodsCache.count
        let cacheKeys = Array(recommendedPodsCache.keys)
        let oldestCache = recommendedPodsLastFetch.values.min()
        let newestCache = recommendedPodsLastFetch.values.max()
        
        return """
        🎯 [PlayerViewModel] Cache Stats:
        - Cached pods: \(cacheCount)
        - Cache keys: \(cacheKeys.joined(separator: ", "))
        - Oldest cache: \(oldestCache?.description ?? "none")
        - Newest cache: \(newestCache?.description ?? "none")
        """
    }
    
    /// Check if we have cached data for a specific pod
    func hasCachedData(for podId: String) -> Bool {
        return recommendedPodsCache[podId] != nil && isCacheValid(for: podId)
    }
    
    // MARK: - Public Methods
    
    func loadPreferences(for pod: Pod) async {
        guard !hasLoadedPreferences else { return }
        
        if let category = pod.category, !category.isEmpty, let keywords = pod.keywords, !keywords.isEmpty {
            // Update preferences when user interacts with pod
            if let userId = Auth.auth().currentUser?.uid {
                await userPreferencesViewModel?.handlePodInteraction(pod: pod, userId: userId)
            }
            self.cachedQueryCategories = self.generateQueryCategories(for: pod)
            self.hasLoadedPreferences = true
        } else {
            print("Pod category or keywords are missing, skipping preference adjustments.")
            self.cachedQueryCategories = self.generateQueryCategories(for: pod)
            self.hasLoadedPreferences = true
        }
    }
    
    func fetchFirstPageOfRecommendedPods(for currentPod: Pod) {
        guard let podId = currentPod.id else { return }
        
        print("🎯 [PlayerViewModel] fetchFirstPageOfRecommendedPods called for pod: \(podId)")
        print("🎯 [PlayerViewModel] Cache status - hasLoadedPods: \(hasLoadedPods), isFetching: \(isFetching)")
        
        // Reset state for new pod
        
        // Check cache first
        if let cachedPods = recommendedPodsCache[podId],
           let lastFetch = recommendedPodsLastFetch[podId],
           Date().timeIntervalSince(lastFetch) < cacheExpirationInterval {
            print("🎯 [PlayerViewModel] Using cached recommended pods for pod: \(podId)")
            self.recommendedPods = cachedPods
            self.hasLoadedPods = true
            return
        }
        
        print("🎯 [PlayerViewModel] Cache miss or expired, proceeding with fetch")
        guard !isFetching && !hasLoadedPods else { 
            print("🎯 [PlayerViewModel] Skipping fetch - isFetching: \(isFetching), hasLoadedPods: \(hasLoadedPods)")
            return 
        }
        isFetching = true
        
        let queryCategories = cachedQueryCategories.isEmpty ? generateQueryCategories(for: currentPod) : cachedQueryCategories
        let db = Firestore.firestore()
        let podsCollection = db.collection("pods")

        print("🎯 [PlayerViewModel] Fetching recommended pods with categories: \(queryCategories)")
        print("🎯 [PlayerViewModel] Current pod ID to exclude: \(podId)")

        // Check if we need to chunk the categories (Firestore 'in' filter has 10 element limit)
        if queryCategories.count <= 10 {
            // Single query for 10 or fewer categories
            executeSingleCategoryQuery(podsCollection: podsCollection, categories: queryCategories, currentPod: currentPod)
        } else {
            // Chunked query for more than 10 categories
            executeChunkedCategoryQuery(podsCollection: podsCollection, categories: queryCategories, currentPod: currentPod)
        }
    }
    
    private func executeSingleCategoryQuery(podsCollection: CollectionReference, categories: [String], currentPod: Pod) {
        let query = podsCollection
            .whereField("category", in: categories as [Any])
            .limit(to: recommendedPodsPageSize)
        
        executeQuery(query: query, currentPod: currentPod)
    }
    
    private func executeChunkedCategoryQuery(podsCollection: CollectionReference, categories: [String], currentPod: Pod) {
        let chunks = chunkArray(categories, into: 10)
        print("🎯 [PlayerViewModel] Executing chunked query with \(chunks.count) chunks")
        
        let group = DispatchGroup()
        var allPods: [Pod] = []
        var allDocuments: [QueryDocumentSnapshot] = []
        
        for (index, chunk) in chunks.enumerated() {
            group.enter()
            
            let query = podsCollection
                .whereField("category", in: chunk as [Any])
                .limit(to: recommendedPodsPageSize)
            
            query.getDocuments { [weak self] snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("❌ [PlayerViewModel] Error in chunk \(index): \(error.localizedDescription)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    print("🎯 [PlayerViewModel] Chunk \(index) returned \(documents.count) documents")
                    
                    for document in documents {
                        if var pod = try? document.data(as: Pod.self) {
                            pod.id = document.documentID
                            allPods.append(pod)
                            allDocuments.append(document)
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Remove duplicates and current pod
            let uniquePods = Array(Set(allPods.map { $0.id ?? "" })).compactMap { podId in
                allPods.first { $0.id == podId }
            }.filter { $0.id != currentPod.id }
            
            // Sort by timestamp (newest first) and take the first pageSize
            let sortedPods = uniquePods.sorted { $0.timestamp.dateValue() > $1.timestamp.dateValue() }
            let finalPods = Array(sortedPods.prefix(self.recommendedPodsPageSize))
            
            print("🎯 [PlayerViewModel] Chunked query completed: \(finalPods.count) unique pods")
            
            Task { @MainActor in
                for pod in finalPods {
                    _ = self.getOrCreateViewModel(for: pod)
                }
                self.recommendedPods = finalPods
                self.lastSnapshot = allDocuments.last
                
                // Update cache
                self.recommendedPodsCache[currentPod.id ?? ""] = finalPods
                self.recommendedPodsLastFetch[currentPod.id ?? ""] = Date()
                print("🎯 [PlayerViewModel] Cached recommended pods for pod: \(currentPod.id ?? "")")
            }
            
            self.isFetching = false
            self.hasLoadedPods = true
        }
    }
    
    private func executeQuery(query: Query, currentPod: Pod) {
        guard let podId = currentPod.id else { return }
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [PlayerViewModel] Error fetching recommended pods: \(error.localizedDescription)")
                self.isFetching = false
                return
            }

            if let documents = snapshot?.documents {
                print("🎯 [PlayerViewModel] Found \(documents.count) documents")
                var newPods: [Pod] = []
                
                // Process each document individually
                for document in documents {
                    if var pod = try? document.data(as: Pod.self) {
                        pod.id = document.documentID
                        newPods.append(pod)
                    }
                }
                
                // Filter out the current pod
                newPods = newPods.filter { $0.id != currentPod.id }
                
                if RecommendationConfig.enableRecommendationDebugging {
                    print("🎯 [PlayerViewModel] After filtering current pod, have \(newPods.count) pods")
                }
                
                // Apply popularity-based sorting
                newPods = self.sortPodsByPopularity(newPods)
                
                // Apply player recommendations diversification
                newPods = self.diversifyPlayerRecommendations(newPods)
                
                // Take only the requested page size after sorting and diversification
                let finalPods = Array(newPods.prefix(self.recommendedPodsPageSize))
                
                if RecommendationConfig.enableRecommendationDebugging {
                    print("🎯 [PlayerViewModel] Final recommendations: \(finalPods.count) pods after popularity sorting & diversification")
                }
                
                Task { @MainActor in
                    for pod in finalPods {
                        _ = self.getOrCreateViewModel(for: pod)
                    }
                    self.recommendedPods = finalPods
                    self.lastSnapshot = documents.last
                    
                    // Update cache
                    self.recommendedPodsCache[podId] = finalPods
                    self.recommendedPodsLastFetch[podId] = Date()
                    
                    if RecommendationConfig.enableRecommendationDebugging {
                        print("🎯 [PlayerViewModel] Cached recommended pods for pod: \(podId)")
                    }
                }
            } else {
                print("🎯 [PlayerViewModel] No documents found, trying fallback")
                self.fetchFallbackPods(for: currentPod)
            }

            self.isFetching = false
            self.hasLoadedPods = true
        }
    }
    

    
    func fetchUserForPod(_ pod: Pod) async -> User? {
        let db = Firestore.firestore()
        let userId = pod.userId
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if document.exists {
                let user = try document.data(as: User.self)
                return user
            }
        } catch {
            print("Error fetching user for pod: \(error)")
        }
        
        return nil
    }
    
    func getTimeAgo(for pod: Pod) -> String {
        let currentTime = Date()
        let postedTime = pod.timestamp.dateValue()
        
        // Check if it's today
        let calendar = Calendar.current
        if calendar.isDate(postedTime, inSameDayAs: currentTime) {
            return "today"
        }
        
        // Otherwise show just the date
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: postedTime)
    }
    
    // MARK: - Helper Methods
    
    private func getOrCreateViewModel(for pod: Pod) -> PodViewModel {
        if let existingViewModel = podViewModels[pod.id ?? ""] {
            return existingViewModel
        }
        let viewModel = PodViewModel(pod: pod)
        podViewModels[pod.id ?? ""] = viewModel
        return viewModel
    }

    private func generateQueryCategories(for pod: Pod) -> [String] {
        // Clear cache to ensure fresh categories each time
        cachedQueryCategories = []

        // Get user's top categories
        let userCategories = userPreferencesViewModel?.getTopCategories(limit: 10) ?? []
        
        // Get pod's context: category + keywords for similarity
        let podCategory = pod.category ?? "Miscellaneous"
        let podKeywords = pod.keywords ?? []
        let podContext = [podCategory] + podKeywords
        
        // NEW WEIGHTS: 50% similarity, 35% user prefs, 15% random
        let totalQuerySize = 15
        let similarityCount = Int(Double(totalQuerySize) * RecommendationConfig.PlayerRecommendations.currentPodSimilarityWeight) // 50% = 7-8 items
        let userPrefCount = Int(Double(totalQuerySize) * RecommendationConfig.PlayerRecommendations.userPreferenceWeight) // 35% = 5-6 items  
        let randomCount = totalQuerySize - similarityCount - userPrefCount // 15% = remaining items
        
        if RecommendationConfig.enableRecommendationDebugging {
            print("🎯 [PlayerViewModel] New recommendation weights - Similarity: \(similarityCount), User Prefs: \(userPrefCount), Random: \(randomCount)")
        }
        
        // 1. SIMILARITY CATEGORIES (50%) - Current pod category + keywords
        let selectedSimilarityCategories = Array(podContext.prefix(similarityCount))
        
        // 2. USER PREFERENCE CATEGORIES (35%) - Top weighted categories, shuffled for variety
        let shuffledUserCategories = userCategories.shuffled()
        let selectedUserCategories = Array(shuffledUserCategories.prefix(userPrefCount))
        
        // 3. RANDOM CATEGORIES (15%) - For discovery and variety
        let allAvailableCategories = AIConfig.validCategories
        let usedCategories = Set(selectedSimilarityCategories + selectedUserCategories)
        let availableRandomCategories = allAvailableCategories.filter { category in
            !usedCategories.contains(category)
        }
        let randomCategories = Array(availableRandomCategories.shuffled().prefix(randomCount))
        
        // Combine all categories with proper weighting
        let combinedCategories = selectedSimilarityCategories + selectedUserCategories + randomCategories
        
        if RecommendationConfig.enableRecommendationDebugging {
            print("🔍 [PlayerViewModel] Query breakdown:")
            print("   🎯 Similarity (\(similarityCount)): \(selectedSimilarityCategories)")
            print("   👤 User Prefs (\(userPrefCount)): \(selectedUserCategories)")
            print("   🎲 Random (\(randomCount)): \(randomCategories)")
            print("   📊 Total: \(combinedCategories.count) categories")
        }
        
        return combinedCategories
    }
    
    // Helper function to chunk array into smaller arrays
    private func chunkArray<T>(_ array: [T], into size: Int) -> [[T]] {
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }

    private func fetchFallbackPods(for currentPod: Pod) {
        guard let podId = currentPod.id else { return }
        
        let db = Firestore.firestore()
        let podsCollection = db.collection("pods")

        print("🎯 [PlayerViewModel] Fetching fallback pods for pod: \(podId)")
        let fallbackQuery = podsCollection
            .limit(to: pageSize)

        fallbackQuery.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [PlayerViewModel] Error fetching fallback pods: \(error.localizedDescription)")
                return
            }

            if let documents = snapshot?.documents {
                print("🎯 [PlayerViewModel] Found \(documents.count) fallback documents")
                var newPods: [Pod] = []
                
                // Process each document individually
                for document in documents {
                    if var pod = try? document.data(as: Pod.self) {
                        pod.id = document.documentID
                        newPods.append(pod)
                    }
                }
                
                // Filter out the current pod
                newPods = newPods.filter { $0.id != currentPod.id }
                print("🎯 [PlayerViewModel] After filtering current pod, have \(newPods.count) fallback pods")
                
                Task { @MainActor in
                    self.recommendedPods.append(contentsOf: newPods)
                    self.lastSnapshot = snapshot?.documents.last
                    
                    // Update cache with fallback pods
                    self.recommendedPodsCache[podId] = newPods
                    self.recommendedPodsLastFetch[podId] = Date()
                    print("🎯 [PlayerViewModel] Cached fallback pods for pod: \(podId)")
                }
            }
        }
    }
    
    // MARK: - Setup Methods
    
    func startAllLoadingInParallel(for pod: Pod, currentUrl: URL, manager: PlayerManager, viewModel: PodViewModel) {
        print("PlayerViewModel: startAllLoadingInParallel - UI is immediately responsive")
        
        // 1. Start media player immediately (completely non-blocking)
        DispatchQueue.global(qos: .userInitiated).async {
            manager.play(url: currentUrl, pod: pod)
            Task { @MainActor in
                manager.setupBasicNowPlayingInfo()
            }
        }
        
        // 2. Start user data fetch in parallel (only if needed)
        if pod.user == nil {
            print("🔄 PlayerViewModel: User data is nil, starting fetch for pod: \(pod.title)")
            Task {
                let user = await self.fetchUserForPod(pod)
                await MainActor.run {
                    print("🔄 PlayerViewModel: User fetch completed, updating all state")
                    var updatedPod = pod
                    updatedPod.user = user
                    viewModel.pod = updatedPod
                    viewModel.refreshSaveState()
                    
                    // Update PlayerManager's currentPod with user data
                    manager.currentPod = updatedPod
                    
                    if let user = user {
                        print("🔄 PlayerViewModel: Updating now playing info with user: \(user.username)")
                        manager.setNowPlayingInfoWithPod(updatedPod, user: user)
                    }
                    
                    // Small delay to ensure proper state synchronization without animation queue
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("🔄 PlayerViewModel: Setting isUserDataLoading = false (with delay)")
                        self.isUserDataLoading = false
                    }
                }
            }
        } else {
            print("🔄 PlayerViewModel: User already available, refreshing state")
            // User already available - just refresh state
            viewModel.refreshSaveState()
            self.isUserDataLoading = false
        }
        
        // 3. Start preferences loading in parallel
        if !hasLoadedPreferences {
            Task {
                await self.loadPreferences(for: pod)
            }
        }
        
        // 4. Start recommendations loading in parallel
        if !hasLoadedPods && !isFetching {
            self.fetchFirstPageOfRecommendedPods(for: pod)
        }
        
        // UI is fully responsive immediately - everything loads as it goes!
    }
    
    // MARK: - Popularity & Diversification for Player Recommendations
    
    /// Sort pods by popularity score with randomness for player recommendations
    private func sortPodsByPopularity(_ pods: [Pod]) -> [Pod] {
        if RecommendationConfig.Diversification.enablePopularityTierShuffling {
            return sortPodsByPopularityTiers(pods)
        } else {
            return sortPodsByPopularityWithRandomness(pods)
        }
    }
    
    /// Sort pods by popularity but add randomness to prevent same content every time
    private func sortPodsByPopularityWithRandomness(_ pods: [Pod]) -> [Pod] {
        let randomnessFactor = RecommendationConfig.Diversification.popularityRandomnessFactor
        
        return pods.sorted { pod1, pod2 in
            let score1 = RecommendationConfig.calculatePopularityScore(
                likes: pod1.likes,
                views: pod1.views,
                shares: pod1.shares,
                saves: pod1.saves,
                comments: pod1.comments,
                createdAt: pod1.createdAt?.dateValue()
            )
            
            let score2 = RecommendationConfig.calculatePopularityScore(
                likes: pod2.likes,
                views: pod2.views,
                shares: pod2.shares,
                saves: pod2.saves,
                comments: pod2.comments,
                createdAt: pod2.createdAt?.dateValue()
            )
            
            // Add randomness to popularity scores to create variety
            let randomBonus1 = Double.random(in: 0...score1) * randomnessFactor
            let randomBonus2 = Double.random(in: 0...score2) * randomnessFactor
            
            let finalScore1 = score1 + randomBonus1
            let finalScore2 = score2 + randomBonus2
            
            // Higher final score (popularity + randomness) first
            if finalScore1 != finalScore2 {
                return finalScore1 > finalScore2
            }
            
            // If same final score, fall back to timestamp (newer first)
            return pod1.timestamp.dateValue() > pod2.timestamp.dateValue()
        }
    }
    
    /// Sort pods by popularity tiers with randomization within each tier
    private func sortPodsByPopularityTiers(_ pods: [Pod]) -> [Pod] {
        // Calculate popularity scores for all pods
        let podsWithScores = pods.map { pod in
            let score = RecommendationConfig.calculatePopularityScore(
                likes: pod.likes,
                views: pod.views,
                shares: pod.shares,
                saves: pod.saves,
                comments: pod.comments,
                createdAt: pod.createdAt?.dateValue()
            )
            return (pod: pod, score: score)
        }
        
        // Group into popularity tiers (high, medium, low)
        let allScores = podsWithScores.map { $0.score }.sorted(by: >)
        guard !allScores.isEmpty else { return pods }
        
        let maxScore = allScores.first ?? 0
        let minScore = allScores.last ?? 0
        let scoreRange = maxScore - minScore
        
        // Define tier boundaries
        let highTierThreshold = maxScore - (scoreRange * 0.33)
        let mediumTierThreshold = maxScore - (scoreRange * 0.67)
        
        var highTierPods: [Pod] = []
        var mediumTierPods: [Pod] = []
        var lowTierPods: [Pod] = []
        
        for (pod, score) in podsWithScores {
            if score >= highTierThreshold {
                highTierPods.append(pod)
            } else if score >= mediumTierThreshold {
                mediumTierPods.append(pod)
            } else {
                lowTierPods.append(pod)
            }
        }
        
        if RecommendationConfig.enableRecommendationDebugging {
            print("🎯 [PlayerViewModel] Popularity tiers - High: \(highTierPods.count), Medium: \(mediumTierPods.count), Low: \(lowTierPods.count)")
        }
        
        // Randomize within each tier to create variety
        let shuffledHighTier = highTierPods.shuffled()
        let shuffledMediumTier = mediumTierPods.shuffled()
        let shuffledLowTier = lowTierPods.shuffled()
        
        // Combine tiers (high first, then medium, then low)
        return shuffledHighTier + shuffledMediumTier + shuffledLowTier
    }
    
    /// Apply diversification to player recommendations
    private func diversifyPlayerRecommendations(_ pods: [Pod]) -> [Pod] {
        guard RecommendationConfig.Diversification.enableSmartShuffling else {
            return pods
        }
        
        var optimizedPods = pods
        let maxSameCategory = RecommendationConfig.Diversification.maxConsecutiveSameCategory
        let maxSameUser = RecommendationConfig.Diversification.maxConsecutiveSameUser
        
        // Track consecutive counts
        var lastCategory: String? = nil
        var lastUserId: String? = nil
        var consecutiveCategoryCount = 0
        var consecutiveUserCount = 0
        
        var i = 0
        while i < optimizedPods.count - 1 {
            let currentPod = optimizedPods[i]
            let currentCategory = currentPod.category
            let currentUserId = currentPod.userId
            
            // Update consecutive counts
            if currentCategory == lastCategory {
                consecutiveCategoryCount += 1
            } else {
                consecutiveCategoryCount = 1
                lastCategory = currentCategory
            }
            
            if currentUserId == lastUserId {
                consecutiveUserCount += 1
            } else {
                consecutiveUserCount = 1
                lastUserId = currentUserId
            }
            
            // Check if we need to swap to break monotony
            if consecutiveCategoryCount > maxSameCategory || consecutiveUserCount > maxSameUser {
                // Find a suitable pod to swap with later in the array
                if let swapIndex = findDiversePodInRecommendations(
                    in: optimizedPods,
                    startingFrom: i + 1,
                    avoidingCategory: currentCategory,
                    avoidingUser: currentUserId
                ) {
                    optimizedPods.swapAt(i + 1, swapIndex)
                    
                    if RecommendationConfig.enableRecommendationDebugging {
                        print("🔄 [PlayerViewModel] Swapped recommendations at \(i+1) and \(swapIndex) for diversification")
                    }
                    
                    // Reset counts after swap
                    consecutiveCategoryCount = 1
                    consecutiveUserCount = 1
                }
            }
            
            i += 1
        }
        
        return optimizedPods
    }
    
    /// Find a pod that's different from the specified category and user for recommendations
    private func findDiversePodInRecommendations(
        in pods: [Pod],
        startingFrom index: Int,
        avoidingCategory: String?,
        avoidingUser: String
    ) -> Int? {
        for i in index..<pods.count {
            let pod = pods[i]
            if pod.category != avoidingCategory && pod.userId != avoidingUser {
                return i
            }
        }
        return nil
    }
}
