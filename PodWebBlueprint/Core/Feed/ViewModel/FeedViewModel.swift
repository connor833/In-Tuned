import SwiftUI
import FirebaseFirestore
import Firebase
import FirebaseAuth

class FeedViewModel: ObservableObject {
    static let shared = FeedViewModel()
    
    @Published var pods = [Pod]()
    @Published var followedItems = [FeedItem]()
    @Published var searchText = ""

    @Published var hasMorePods = true
    @Published var hasMoreFollowItems = true

    private var lastSnapshot: DocumentSnapshot? = nil
    private var lastFollowItemsSnapshot: DocumentSnapshot? = nil
    private let pageSize = 8
    private let followItemsPageSize = 20
    @Published var isFetching = false // Now accessible and observable from the view
    @Published var isFetchingFollowItems = false

    private let service = UserService()
    private let podService = PodService()
    private let blockService = BlockService() // Add blocking service
    private let db = Firestore.firestore()
    
    var currentUser: User?
    var userPreferences: UserPreferences?
    
    // MARK: - Caching for Performance Optimization
    
    // Cache user data to avoid repeated fetches
    @Published var cachedUsers: [String: User] = [:]
    
    // Cache following items to avoid repeated fetches
    private var cachedFollowItems: [FeedItem] = []
    private var followItemsCacheTimestamp: Date?
    private let followItemsCacheExpiry: TimeInterval = 7200 // 2 hours cache expiry - behave like for you pods
    
    // Cache feed data to avoid repeated fetches
    private var lastFeedFetch: Date?
    private let feedCacheTimeout: TimeInterval = 300 // 5 minutes
    
    // MARK: - Real-time Listeners
    private var followItemsListenerId: String?
    private var isFollowItemsListenerActive = false

    private init() {
        // Private init for singleton
    }
    
    func setup(user: User, userPreferences: UserPreferences) {
        self.currentUser = user
        self.userPreferences = userPreferences
        // Use caching method instead of direct fetch
        fetchFirstPageOfPods()
    }
    
    /// Update user and preferences when user changes
    func updateUser(user: User, userPreferences: UserPreferences) {
        self.currentUser = user
        self.userPreferences = userPreferences
        // Check if we need to refresh data
        checkAndRefreshIfNeeded()
    }

    // MARK: - Load First Page of Pods
    
    /// Check if feed data needs refreshing when tab becomes active
    func checkAndRefreshIfNeeded() {
        // Check if data is fresh
        if let lastFetch = lastFeedFetch,
           Date().timeIntervalSince(lastFetch) < feedCacheTimeout,
           !pods.isEmpty {
            print("🔄 [FeedViewModel] Feed data is fresh (\(Int(Date().timeIntervalSince(lastFetch)))s ago), skipping fetch")
            return
        }
        
        // Data is stale or empty, fetch fresh data
        fetchFirstPageOfPods()
    }
    
    /// Check if follow items data needs refreshing when tab becomes active
    func checkAndRefreshFollowItemsIfNeeded() {
        // Check if data is fresh
        if let lastFetch = followItemsCacheTimestamp,
           Date().timeIntervalSince(lastFetch) < followItemsCacheExpiry,
           !followedItems.isEmpty {
            print("🔄 [FeedViewModel] Follow items data is fresh (\(Int(Date().timeIntervalSince(lastFetch)))s ago), skipping fetch")
            // Ensure loading state is cleared when data is fresh
            isFetchingFollowItems = false
            return
        }
        
        // Data is stale or empty, fetch fresh data
        fetchFirstPageOfFollowItems()
    }

    func fetchFirstPageOfPods() {
        guard !isFetching else { return }
        guard let userPreferences = userPreferences else { return }
        
        // Reset pagination state for fresh fetch
        lastSnapshot = nil
        hasMorePods = true
        pods.removeAll() // Clear old pods to prevent stale data from showing
        
        isFetching = true
        print("📱 [FeedViewModel] Fetching FIRST page of For You pods...")
        print("📱 [FeedViewModel] User has \(userPreferences.selectedCategories.count) categories")
        
        podService.fetchForYouFeed(
            preferences: userPreferences,
            limit: 10
        ) { [weak self] newPods, lastSnapshot in
            guard let self = self else { return }
            
            print("📱 [FeedViewModel] Received \(newPods.count) pods from service")
            print("📱 [FeedViewModel] lastSnapshot exists: \(lastSnapshot != nil)")
            
            // Filter out blocked content using current user's blocking arrays
            let filteredPods = self.filterBlockedContentFromUserDoc(pods: newPods)
            print("📱 [FeedViewModel] After blocking filter: \(filteredPods.count) pods")
            
            // Load user data for all pods at once
            self.loadUserDataForPods(filteredPods) { [weak self] podsWithUsers in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    print("📱 [FeedViewModel] FIRST page loaded: \(podsWithUsers.count) pods (filtered from \(newPods.count))")
                    
                    // Clear user data so PlayerView shows loading state (consistent with Following pods)
                    let podsWithoutUsers = podsWithUsers.map { pod in
                        var podWithoutUser = pod
                        podWithoutUser.user = nil
                        return podWithoutUser
                    }
                    
                    self.pods = podsWithoutUsers
                    self.lastSnapshot = lastSnapshot
                    // Set hasMorePods based on whether lastSnapshot exists (not pod count)
                    self.hasMorePods = lastSnapshot != nil
                    print("📱 [FeedViewModel] hasMorePods set to: \(self.hasMorePods)")
                    self.isFetching = false
                    self.lastFeedFetch = Date() // Update cache timestamp
                }
            }
        }
    }

    // MARK: - Fetch Next Page of Pods

    func fetchNextPageOfPods() {
        guard !isFetching, hasMorePods else { 
            print("[FeedViewModel] Skipping next page: isFetching=\(isFetching), hasMorePods=\(hasMorePods)")
            return 
        }
        guard let userPreferences = userPreferences else { 
            print("[FeedViewModel] No user preferences available for pagination")
            return 
        }
        
        isFetching = true
        print("📱 [FeedViewModel] Fetching NEXT page of For You pods...")
        print("📱 [FeedViewModel] Current pod count: \(pods.count)")
        
        podService.fetchForYouFeed(
            preferences: userPreferences,
            limit: 10,
            lastSnapshot: lastSnapshot
        ) { [weak self] newPods, lastSnapshot in
            guard let self = self else { return }
            
            print("📱 [FeedViewModel] Received \(newPods.count) pods from service")
            print("📱 [FeedViewModel] lastSnapshot exists: \(lastSnapshot != nil)")
            
            // Filter out blocked content using current user's blocking arrays
            let filteredPods = self.filterBlockedContentFromUserDoc(pods: newPods)
            print("📱 [FeedViewModel] After blocking filter: \(filteredPods.count) pods")
            
            // Load user data for all pods at once
            self.loadUserDataForPods(filteredPods) { [weak self] podsWithUsers in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    print("📱 [FeedViewModel] NEXT page loaded: \(podsWithUsers.count) pods (filtered from \(newPods.count))")
                    
                    // Clear user data so PlayerView shows loading state (consistent with Following pods)
                    let podsWithoutUsers = podsWithUsers.map { pod in
                        var podWithoutUser = pod
                        podWithoutUser.user = nil
                        return podWithoutUser
                    }
                    
                    if !podsWithoutUsers.isEmpty {
                        // Check for duplicates before adding
                        let uniqueNewPods = podsWithoutUsers.filter { newPod in
                            !self.pods.contains { existingPod in
                                existingPod.id == newPod.id
                            }
                        }
                        
                        self.pods.append(contentsOf: uniqueNewPods)
                        self.lastSnapshot = lastSnapshot
                        print("📱 [FeedViewModel] Added \(uniqueNewPods.count) unique pods to feed (total: \(self.pods.count))")
                    }
                    // Set hasMorePods based on whether lastSnapshot exists
                    self.hasMorePods = lastSnapshot != nil
                    print("📱 [FeedViewModel] hasMorePods set to: \(self.hasMorePods)")
                    self.isFetching = false
                }
            }
        }
    }

    // MARK: - Simplified Follow Feed Fetching

    func fetchFirstPageOfFollowItems() {
        guard !isFetchingFollowItems else { 
            print("🔍 [FeedViewModel] Already fetching follow items, skipping")
            return 
        }
        
        print("🔍 [FeedViewModel] Starting first page fetch of follow items")
        isFetchingFollowItems = true
        
        guard let currentUser = currentUser else { return }
        service.fetchUserFollowing(forUid: currentUser.uid, limit: 100) { [weak self] users in
            guard let self = self else { return }
            
            print("🔍 [FeedViewModel] Fetched \(users.count) followed users")
            
            self.podService.fetchFollowFeed(
                withUsers: users,
                limit: 10,
                lastSnapshot: nil // Start from beginning
            ) { [weak self] (items: [FeedItem], lastSnapshot: DocumentSnapshot?) in
                guard let self = self else { return }
                
                print("🔍 [FeedViewModel] Received \(items.count) items from first page")
                
                // Load user data for all items at once
                self.loadUserDataForFeedItems(items) { [weak self] itemsWithUsers in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        // REPLACE the array for first page (like For You tab)
                        self.followedItems = itemsWithUsers
                        self.lastFollowItemsSnapshot = lastSnapshot
                        self.hasMoreFollowItems = !itemsWithUsers.isEmpty && itemsWithUsers.count >= 5
                        self.isFetchingFollowItems = false
                        
                        print("🎯 [FeedViewModel] First page loaded: \(self.followedItems.count) items, hasMore: \(self.hasMoreFollowItems)")
                    }
                }
            }
        }
    }
    
    func fetchNextPageOfFollowItems() {
        guard let lastSnapshot = lastFollowItemsSnapshot,
              !isFetchingFollowItems, 
              hasMoreFollowItems else { 
            print("🔍 [FeedViewModel] Cannot fetch next page: fetching=\(isFetchingFollowItems), hasMore=\(hasMoreFollowItems)")
            return 
        }
        
        print("🔍 [FeedViewModel] Starting next page fetch of follow items")
        isFetchingFollowItems = true
        
        guard let currentUser = currentUser else { return }
        service.fetchUserFollowing(forUid: currentUser.uid, limit: 100) { [weak self] users in
            guard let self = self else { return }
            
            // Use cursor-based pagination like For You tab
            self.podService.fetchFollowFeed(
                withUsers: users,
                limit: 10,
                lastSnapshot: lastSnapshot // Use cursor for pagination
            ) { [weak self] (items: [FeedItem], lastSnapshot: DocumentSnapshot?) in
                guard let self = self else { return }
                
                print("🔍 [FeedViewModel] Received \(items.count) items for pagination")
                
                // Load user data for all items at once
                self.loadUserDataForFeedItems(items) { [weak self] (itemsWithUsers: [FeedItem]) in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        // APPEND to existing array (like For You tab)
                        if !itemsWithUsers.isEmpty {
                            self.followedItems.append(contentsOf: itemsWithUsers)
                            self.lastFollowItemsSnapshot = lastSnapshot
                        }
                        
                        // Set hasMore based on items received (like For You tab)
                        self.hasMoreFollowItems = !itemsWithUsers.isEmpty && itemsWithUsers.count >= 5
                        self.isFetchingFollowItems = false
                        
                        print("🎯 [FeedViewModel] Pagination completed: \(self.followedItems.count) total items, hasMore: \(self.hasMoreFollowItems)")
                    }
                }
            }
        }
    }
    
    // MARK: - Real-time Follow Items Updates
    
    func startFollowItemsListener() {
        guard !isFollowItemsListenerActive else { return }
        
        guard let currentUser = currentUser else { return }
        service.fetchUserFollowing(forUid: currentUser.uid) { [weak self] users in
            guard let self = self else { return }
            
            let userIds = users.map { $0.uid }
            self.followItemsListenerId = self.podService.startFollowPodsListener(
                for: userIds
            ) { [weak self] (updatedItems: [FeedItem]) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // Only update if we have new data, don't clear existing data
                    if !updatedItems.isEmpty {
                        // Update cache with real-time data
                        self.cachedFollowItems = updatedItems
                        self.followItemsCacheTimestamp = Date()
                        
                        self.followedItems = updatedItems
                        self.isFetchingFollowItems = false // Clear loading state
                        print("🔄 [FeedViewModel] Updated follow items from real-time listener: \(updatedItems.count) items")
                    } else {
                        // Don't clear existing data if real-time listener returns empty
                        // This preserves the cache and prevents "no content" messages
                        self.isFetchingFollowItems = false // Clear loading state even for empty results
                        print("🔄 [FeedViewModel] Real-time listener returned empty items, keeping existing \(self.followedItems.count) items")
                    }
                }
            }
            
            self.isFollowItemsListenerActive = true
        }
    }
    
    func stopFollowItemsListener() {
        guard isFollowItemsListenerActive else { return }
        
        if let listenerId = followItemsListenerId {
            // The service will handle stopping the listener
            isFollowItemsListenerActive = false
            print("🛑 [FeedViewModel] Stopped follow items listener, preserving cache")
        }
    }
    
    // MARK: - Legacy Follow Pods (for backward compatibility)
    
    func fetchFollowItems() {
        // Use the caching method instead of direct fetch
        checkAndRefreshFollowItemsIfNeeded()
    }
    
    // MARK: - Cache Management
    
    private func isFollowItemsCacheValid() -> Bool {
        guard let timestamp = followItemsCacheTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < followItemsCacheExpiry
    }
    
    func clearFollowItemsCache() {
        podService.clearFollowPodsCache()
        followedItems.removeAll()
        cachedFollowItems.removeAll()
        followItemsCacheTimestamp = nil
        lastFollowItemsSnapshot = nil
        hasMoreFollowItems = true
        print("🗑️ [FeedViewModel] Cleared follow items cache")
    }
    
    func refreshFollowItems() {
        // Don't clear the displayed data during refresh - keep showing old data until new data loads
        // Only clear the cache timestamp to force fresh fetch
        followItemsCacheTimestamp = nil
        podService.clearFollowPodsCache()
        print("🔄 [FeedViewModel] Refreshing follow items (keeping displayed data)")
        fetchFirstPageOfFollowItems()
    }
    
    func invalidateFollowItemsCache() {
        followItemsCacheTimestamp = nil
        print("🔄 [FeedViewModel] Invalidated follow items cache")
    }
    
    /// Force refresh the For You feed (called when user manually pulls to refresh)
    func refreshForYouFeed() {
        print("🔄 [FeedViewModel] Force refreshing For You feed")
        lastFeedFetch = nil // Invalidate cache to force fresh fetch
        fetchFirstPageOfPods()
    }
    
    // MARK: - Bulk User Data Loading for Feed Items
    
    private func loadUserDataForFeedItems(_ items: [FeedItem], completion: @escaping ([FeedItem]) -> Void) {
        // Get unique user IDs that we haven't cached yet
        let uncachedUserIds = Set(items.map { $0.userId }).subtracting(Set(cachedUsers.keys))
        
        if uncachedUserIds.isEmpty {
            // All users are already cached, just return items with cached user data
            let itemsWithUsers = items.map { item in
                var itemWithUser = item
                // Note: FeedItems already contain the pod data, so we just need to ensure user data is loaded
                return itemWithUser
            }
            completion(itemsWithUsers)
            return
        }
        
        print("[FeedViewModel] Loading user data for \(uncachedUserIds.count) uncached users")
        
        let group = DispatchGroup()
        var newCachedUsers: [String: User] = [:]
        
        for userId in uncachedUserIds {
            group.enter()
            
            db.collection("users").document(userId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("[FeedViewModel] Error loading user \(userId): \(error)")
                    return
                }
                
                if let user = try? snapshot?.data(as: User.self) {
                    newCachedUsers[userId] = user
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Update cache with new users
            self.cachedUsers.merge(newCachedUsers) { _, new in new }
            
            // Return items (FeedItems already contain all necessary data)
            completion(items)
        }
    }
    
    // MARK: - Simple Blocking Filter (For "For You" tab only)
    
    private func filterBlockedContentFromUserDoc(pods: [Pod]) -> [Pod] {
        // Get blocking arrays from current user document (simple, one-time check)
        guard let currentUid = Auth.auth().currentUser?.uid else { return pods }
        guard let currentUser = currentUser else { return pods }
        
        // Quick check - if we don't have blocking data yet, fetch it once
        if (currentUser.blockedUsers?.isEmpty ?? true) && (currentUser.blockedBy?.isEmpty ?? true) {
            // This is a simple approach - just use the arrays from the currentUser object
            // which should already be loaded when the FeedViewModel is initialized
            print("[FeedViewModel] No blocking data available, returning all pods")
            return pods
        }
        
        let blockedUserIds = Set(currentUser.blockedUsers ?? [])
        let blockedByUserIds = Set(currentUser.blockedBy ?? [])
        
        let filteredPods = pods.filter { pod in
            let isBlocked = blockedUserIds.contains(pod.userId) || blockedByUserIds.contains(pod.userId)
            if isBlocked {
                print("[FeedViewModel] Filtering out pod from blocked user: \(pod.userId)")
            }
            return !isBlocked
        }
        
        print("[FeedViewModel] Filtered \(pods.count) pods down to \(filteredPods.count) pods using user doc blocking arrays")
        return filteredPods
    }
    
    // MARK: - Bulk User Data Loading (Eliminates Repeated Queries)
    
    private func loadUserDataForPods(_ pods: [Pod], completion: @escaping ([Pod]) -> Void) {
        // Get unique user IDs that we need to load
        let userIds = Set(pods.map { $0.userId })
        
        print("[FeedViewModel] Loading user data for \(userIds.count) users using shared cache")
        
        let group = DispatchGroup()
        var podsWithUsers: [Pod] = []
        
        for pod in pods {
            group.enter()
            
            UserCacheService.shared.getUser(userId: pod.userId) { user in
                var podWithUser = pod
                podWithUser.user = user
                podsWithUsers.append(podWithUser)
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // Sort pods back to original order
            let sortedPods = pods.map { originalPod in
                podsWithUsers.first { $0.id == originalPod.id } ?? originalPod
            }
            
            completion(sortedPods)
        }
    }
    
    // MARK: - Public Methods for Views
    
    /// Get user data for a specific user ID (from cache)
    func getUser(for userId: String) -> User? {
        return cachedUsers[userId]
    }
    


    // MARK: - Generate Query Categories



}
