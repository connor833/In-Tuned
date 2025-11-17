//
//  ExploreViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/14/23.
//

import SwiftUI
import Firebase
import FirebaseFunctions
import FirebaseAuth

class UserViewModel: ObservableObject {
    static let shared = UserViewModel()
    
    @Published var user: User?
    @Published var pods = [Pod]()
    @Published var playlists = [Playlist]()
    @Published var isLoadingPlaylists = false
    @Published var savedPods = [Pod]()
    @Published var reposts = [Repost]()
    @Published var repostsWithPods = [RepostWithPod]()
    @Published var isFollowing = false
    @Published var isCurrentUser = false
    @Published var isFriend = false
    @Published var isLoadingFriendshipStatus = false
    @Published var followRequestSent = false
    @Published var isLoadingFollowRequestStatus = false
    @Published var users = [User]()
    @Published var friends = [User]()
    @Published var actualPodCount = 0
    private let authViewModel: AuthViewModel
    let service = UserService()
    let podService = PodService()
    let repostService = RepostService()
    let blockService = BlockService()
    @Published var searchText = ""
    
    @Published var following = [User]()
    @Published var followers = [User]()
    
    // Filtered arrays for search functionality
    @Published var filteredFollowing = [User]()
    @Published var filteredFollowers = [User]()
    
    // Blocking properties
    @Published var isBlocked = false
    @Published var isBlockedByCurrentUser = false
    @Published var isLoadingBlockStatus = false
    @Published var isUserBlocked = false
    
    // Rate limiting popup properties
    @Published var showRateLimitPopup = false
    @Published var rateLimitMessage = ""
    
    // New blocking security properties
    @Published var isCurrentUserBlockedByThisUser = false
    @Published var isBlockingCheckComplete = false
    
    // Follow action loading state
    @Published var isFollowActionInProgress = false
    
    // MARK: - Pagination Properties for User Pods
    @Published var hasMorePods = true
    @Published var isFetchingPods = false
    private var lastPodDocument: DocumentSnapshot?
    let podPageSize = 10
    
    // MARK: - Pagination Properties for User Reposts
    @Published var hasMoreReposts = true
    @Published var isFetchingReposts = false
    private var lastRepostDocument: DocumentSnapshot?
    let repostPageSize = 10
    
    // MARK: - Pagination Properties for Saved Pods
    @Published var hasMoreSavedPods = true
    @Published var isFetchingSavedPods = false
    private var lastSavedPodDocument: DocumentSnapshot?
    let savedPodPageSize = 10
    
    // MARK: - Initialization Flags
    private var hasInitiallyLoadedPods = false
    private var hasInitiallyLoadedReposts = false
    private var hasInitiallyLoadedSavedPods = false
    
    private init() {
        self.authViewModel = AuthViewModel.shared
    }
    
    // Public init for backward compatibility
    init(user: User, authViewModel: AuthViewModel) {
        self.user = user
        self.authViewModel = authViewModel
    }
    
    func setup(user: User) {
        self.user = user
        
        // Only fetch data if not already loaded to prevent redundant calls
        if !hasInitiallyLoadedPods {
            self.fetchUserPods() // Re-enabled for playlist creation
            hasInitiallyLoadedPods = true
        }
        
        // self.fetchUserPlaylists(user: user)
        // self.checkIfUserIsFollowed(user: user)
        self.checkIfCurrentUser(user: user)
        // self.checkIfUsersAreFriends(user: user)
        // self.checkIfFollowRequestStatus(user: user)
        
        // Only fetch saved pods if not already loaded
        if !hasInitiallyLoadedSavedPods {
            self.fetchFirstPageOfSavedPods() // Use paginated method for saved pods
            hasInitiallyLoadedSavedPods = true
        }
        
        // self.fetchUserReposts()
        // self.fetchFriends()
        // self.fetchUserFollowing()
        // self.fetchUserFollowers()
        // self.fetchActualPodCount()
    }
    
    /// Update user when user changes
    func updateUser(user: User) {
        self.user = user
        // Check if we need to refresh data
        checkIfCurrentUser(user: user)
    }
    
    deinit {
        searchTimerFollowing?.invalidate()
        searchTimerFollowers?.invalidate()
    }
    
    // MARK: - Computed Properties
    
    var shouldShowNoPodsMessage: Bool {
        return pods.isEmpty && !isFetchingPods
    }
    
    var shouldShowNoRepostsMessage: Bool {
        return repostsWithPods.isEmpty && !isFetchingReposts
    }
    
    var shouldShowNoSavedPodsMessage: Bool {
        return savedPods.isEmpty && !isFetchingSavedPods && !hasMoreSavedPods
    }
    
    var searchablePods: [Pod] {
        if searchText.isEmpty {
            return pods
        } else {
            let lowercasedQuery = searchText.lowercased()
            
            return pods.filter({
                $0.title.lowercased().contains(lowercasedQuery)
                
            })
        }
        
    }
    
    func fetchUserPlaylists (user: User) {
        let uid = user.uid
        isLoadingPlaylists = true
        service.fetchUserPlaylists(uid: uid) { playlists in
            DispatchQueue.main.async {
                self.playlists = playlists
                self.isLoadingPlaylists = false
            }
        }
    }

    
    func fetchUsers() {
        service.fetchUsers { result in
            switch result {
            case .success(let (users, lastDocument)):
                self.users = users
            case .failure(let error):
                print("Error fetching users: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchFriends() {
        guard let user = user else { return }
        service.fetchFriends(withUid: user.uid) { users in
            self.friends = users
        }
    }
    
    func fetchPods() {
        podService.fetchPods { pods in
            self.pods = pods
        }
    }
    
    func fetchUserPods() {
        guard let user = user, let uid = user.id else { 
            print("❌ [UserViewModel] No user ID available")
            return 
        }
        
        print("🔍 [UserViewModel] Fetching user pods for uid: \(uid)")
        podService.fetchPods(withUid: uid) { pods in
            print("📝 [UserViewModel] Fetched \(pods.count) pods from service")
            
            DispatchQueue.main.async {
                self.pods = pods
                
                for i in 0 ..< pods.count {
                    self.pods[i].user = self.user
                }
                
                print("✅ [UserViewModel] Updated pods array with \(self.pods.count) pods")
            }
        }
    }
    
    // MARK: - Paginated User Pods
    
    /// Fetch initial data only if not already loaded - prevents UI freezing on tab switches
    func fetchInitialDataIfNeeded() {
        // Only fetch pods if never loaded before
        if !hasInitiallyLoadedPods && !isFetchingPods {
            print("📱 [UserViewModel] Initial pods load needed")
            fetchFirstPageOfUserPods()
        } else {
            print("📱 [UserViewModel] Pods already loaded, skipping initial fetch")
        }
        
        // Only fetch reposts if never loaded before
        if !hasInitiallyLoadedReposts && !isFetchingReposts {
            print("📱 [UserViewModel] Initial reposts load needed")
            fetchFirstPageOfUserReposts()
        } else {
            print("📱 [UserViewModel] Reposts already loaded, skipping initial fetch")
        }
        
        // Always fetch pod count (lightweight operation)
        fetchActualPodCount()
    }
    
    func fetchFirstPageOfUserPods() {
        guard let user = user, let uid = user.id, !isFetchingPods else { return }
        
        // Skip if already loaded to prevent unnecessary network calls
        if hasInitiallyLoadedPods && !pods.isEmpty {
            print("📱 [UserViewModel] Pods already loaded, skipping fetch")
            return
        }
        
        print("📱 [UserViewModel] Fetching FIRST page of user pods for user: \(uid)")
        isFetchingPods = true
        hasMorePods = true
        lastPodDocument = nil
        
        podService.fetchPaginatedUserPods(
            forUid: uid,
            limit: podPageSize,
            lastDocument: nil
        ) { [weak self] pods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Set user data for all pods
                var podsWithUser = pods
                for i in 0..<podsWithUser.count {
                    podsWithUser[i].user = self.user
                }
                
                self.pods = podsWithUser
                self.lastPodDocument = lastDocument
                self.hasMorePods = lastDocument != nil && pods.count >= self.podPageSize
                self.isFetchingPods = false
                self.hasInitiallyLoadedPods = true
                
                print("📱 [UserViewModel] FIRST page loaded: \(pods.count) pods, hasMore: \(self.hasMorePods)")
            }
        }
    }
    
    func fetchNextPageOfUserPods() {
        guard let user = user, let uid = user.id,
              let lastDocument = lastPodDocument,
              !isFetchingPods,
              hasMorePods else { return }
        
        print("📱 [UserViewModel] Fetching NEXT page of user pods for user: \(uid)")
        isFetchingPods = true
        
        podService.fetchPaginatedUserPods(
            forUid: uid,
            limit: podPageSize,
            lastDocument: lastDocument
        ) { [weak self] newPods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Set user data for new pods
                var newPodsWithUser = newPods
                for i in 0..<newPodsWithUser.count {
                    newPodsWithUser[i].user = self.user
                }
                
                self.pods.append(contentsOf: newPodsWithUser)
                self.lastPodDocument = lastDocument
                self.hasMorePods = lastDocument != nil && newPods.count >= self.podPageSize
                self.isFetchingPods = false
                
                print("📱 [UserViewModel] NEXT page loaded: \(newPods.count) pods, total: \(self.pods.count), hasMore: \(self.hasMorePods)")
            }
        }
    }
    
    func refreshUserPods() {
        print("📱 [UserViewModel] Refreshing user pods")
        pods = []
        hasMorePods = true
        lastPodDocument = nil
        hasInitiallyLoadedPods = false // Reset flag to allow fresh fetch
        fetchFirstPageOfUserPods()
    }
    
    // MARK: - Paginated User Reposts
    
    func fetchFirstPageOfUserReposts() {
        guard let user = user, let uid = user.id, !isFetchingReposts else { return }
        
        // Skip if already loaded to prevent unnecessary network calls
        if hasInitiallyLoadedReposts && !repostsWithPods.isEmpty {
            print("📱 [UserViewModel] Reposts already loaded, skipping fetch")
            return
        }
        
        print("📱 [UserViewModel] Fetching FIRST page of user reposts for user: \(uid)")
        isFetchingReposts = true
        hasMoreReposts = true
        lastRepostDocument = nil
        
        repostService.fetchPaginatedUserRepostsWithPods(
            userId: uid,
            limit: repostPageSize,
            lastDocument: nil
        ) { [weak self] repostsWithPods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.repostsWithPods = repostsWithPods
                self.lastRepostDocument = lastDocument
                self.hasMoreReposts = lastDocument != nil && repostsWithPods.count >= self.repostPageSize
                self.isFetchingReposts = false
                self.hasInitiallyLoadedReposts = true
                
                print("📱 [UserViewModel] FIRST page of reposts loaded: \(repostsWithPods.count) reposts, hasMore: \(self.hasMoreReposts)")
            }
        }
    }
    
    func fetchNextPageOfUserReposts() {
        guard let user = user, let uid = user.id,
              let lastDocument = lastRepostDocument,
              !isFetchingReposts,
              hasMoreReposts else { return }
        
        print("📱 [UserViewModel] Fetching NEXT page of user reposts for user: \(uid)")
        isFetchingReposts = true
        
        repostService.fetchPaginatedUserRepostsWithPods(
            userId: uid,
            limit: repostPageSize,
            lastDocument: lastDocument
        ) { [weak self] newRepostsWithPods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.repostsWithPods.append(contentsOf: newRepostsWithPods)
                self.lastRepostDocument = lastDocument
                self.hasMoreReposts = lastDocument != nil && newRepostsWithPods.count >= self.repostPageSize
                self.isFetchingReposts = false
                
                print("📱 [UserViewModel] NEXT page of reposts loaded: \(newRepostsWithPods.count) reposts, total: \(self.repostsWithPods.count), hasMore: \(self.hasMoreReposts)")
            }
        }
    }
    
    func refreshUserReposts() {
        print("📱 [UserViewModel] Refreshing user reposts")
        repostsWithPods = []
        hasMoreReposts = true
        lastRepostDocument = nil
        hasInitiallyLoadedReposts = false // Reset flag to allow fresh fetch
        fetchFirstPageOfUserReposts()
    }
    
    func fetchUserSavedPods() {
        guard let user = user else { return }
        let uid = user.uid
        
        print("🔍 [UserViewModel] Fetching saved pods for user: \(uid)")
        podService.fetchSavedPods(withUid: uid) { pods in
            print("🔍 [UserViewModel] Received \(pods.count) saved pods from service")
            self.savedPods = pods
            
            // Load user data for each saved pod
            for i in 0 ..< pods.count {
                let pod = self.savedPods[i]
                if pod.user == nil && !pod.userId.isEmpty {
                    // Fetch user data for this pod
                    self.service.fetchUser(withUid: pod.userId) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let user):
                                if i < self.savedPods.count {
                                    self.savedPods[i].user = user
                                }
                            case .failure(let error):
                                print("Error fetching user for saved pod: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
            
            print("🔍 [UserViewModel] Updated savedPods array with \(self.savedPods.count) pods")
        }
    }
    
    // MARK: - Paginated Saved Pods
    
    func fetchFirstPageOfSavedPods() {
        guard !isFetchingSavedPods else { return }
        guard let user = user else { return }
        
        let uid = user.uid
        
        print("📱 [UserViewModel] Fetching FIRST page of saved pods for user: \(uid)")
        isFetchingSavedPods = true
        hasMoreSavedPods = true
        lastSavedPodDocument = nil
        
        podService.fetchPaginatedSavedPods(
            forUid: uid,
            limit: savedPodPageSize,
            lastDocument: nil
        ) { [weak self] pods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Load user data for all saved pods
                var podsWithUsers = pods
                for i in 0..<podsWithUsers.count {
                    let pod = podsWithUsers[i]
                    if pod.user == nil && !pod.userId.isEmpty {
                        // Fetch user data for this pod
                        self.service.fetchUser(withUid: pod.userId) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let user):
                                    if i < podsWithUsers.count {
                                        podsWithUsers[i].user = user
                                    }
                                case .failure(let error):
                                    print("Error fetching user for pod: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
                
                self.savedPods = podsWithUsers
                self.lastSavedPodDocument = lastDocument
                self.hasMoreSavedPods = lastDocument != nil && pods.count >= self.savedPodPageSize
                self.isFetchingSavedPods = false
                
                print("📱 [UserViewModel] FIRST page of saved pods loaded: \(pods.count) pods, hasMore: \(self.hasMoreSavedPods)")
            }
        }
    }
    
    func fetchNextPageOfSavedPods() {
        guard let lastDocument = lastSavedPodDocument,
              !isFetchingSavedPods,
              hasMoreSavedPods else { return }
        guard let user = user else { return }
        
        let uid = user.uid
        
        print("📱 [UserViewModel] Fetching NEXT page of saved pods for user: \(uid)")
        isFetchingSavedPods = true
        
        podService.fetchPaginatedSavedPods(
            forUid: uid,
            limit: savedPodPageSize,
            lastDocument: lastDocument
        ) { [weak self] newPods, lastDocument in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Load user data for new saved pods
                var newPodsWithUsers = newPods
                for i in 0..<newPodsWithUsers.count {
                    let pod = newPodsWithUsers[i]
                    if pod.user == nil && !pod.userId.isEmpty {
                        // Fetch user data for this pod
                        self.service.fetchUser(withUid: pod.userId) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let user):
                                    if i < newPodsWithUsers.count {
                                        newPodsWithUsers[i].user = user
                                    }
                                case .failure(let error):
                                    print("Error fetching user for new pod: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
                
                self.savedPods.append(contentsOf: newPodsWithUsers)
                self.lastSavedPodDocument = lastDocument
                self.hasMoreSavedPods = lastDocument != nil && newPods.count >= self.savedPodPageSize
                self.isFetchingSavedPods = false
                
                print("📱 [UserViewModel] NEXT page of saved pods loaded: \(newPods.count) pods, total: \(self.savedPods.count), hasMore: \(self.hasMoreSavedPods)")
            }
        }
    }
    
    func refreshSavedPods() {
        fetchFirstPageOfSavedPods()
    }
    
    func fetchUserReposts() {
        guard let user = user, let uid = user.id else { return }
        repostService.fetchUserRepostsWithPods(userId: uid) { repostsWithPods in
            self.repostsWithPods = repostsWithPods
        }
    }
    
    // Remove orphaned saved pod reference
    func removeOrphanedSavedPod(podId: String) {
        podService.removeOrphanedSavedPod(podId: podId) {
            DispatchQueue.main.async {
                self.savedPods.removeAll { $0.id == podId }
            }
        }
    }
    
    // Remove orphaned repost reference
    func removeOrphanedRepost(podId: String) {
        repostService.removeOrphanedRepost(podId: podId) {
            DispatchQueue.main.async {
                self.repostsWithPods.removeAll { $0.repost.podId == podId }
            }
        }
    }
    
    // MARK: - Bulk Delete Functions
    
    /// Bulk delete multiple pods sequentially (delete pod → remove RSS GUID → delete next pod)
    func bulkDeletePods(podIds: [String], progressCallback: ((Int, Int) -> Void)? = nil, completion: @escaping (Bool) -> Void) {
        guard !podIds.isEmpty else {
            completion(false)
            return
        }
        
        print("🗑️ [UserViewModel] Starting sequential bulk delete of \(podIds.count) pods")
        print("🗑️ [UserViewModel] Pod IDs to delete: \(podIds)")
        
        // Process pods sequentially to ensure proper RSS GUID cleanup
        Task {
            var successfulDeletes = 0
            var failedDeletes = 0
            let totalPods = podIds.count
            
            for (index, podId) in podIds.enumerated() {
                // Find the pod
                guard let pod = pods.first(where: { $0.id == podId }) else {
                    failedDeletes += 1
                    print("❌ [UserViewModel] Could not find pod \(podId) for deletion")
                    continue
                }
                
                print("🗑️ [UserViewModel] [\(index + 1)/\(totalPods)] Deleting pod: \(pod.title) - fileUrl: \(pod.fileUrl)")
                print("🗑️ [UserViewModel] [\(index + 1)/\(totalPods)] Pod has RSS GUID: \(pod.rssGuid ?? "none")")
                
                // Delete pod individually (this includes RSS GUID removal)
                let podViewModel = PodViewModel(pod: pod)
                let deletionSuccess = await withCheckedContinuation { continuation in
                    podViewModel.deletePod {
                        continuation.resume(returning: true)
                    }
                }
                
                if deletionSuccess {
                    successfulDeletes += 1
                    print("✅ [UserViewModel] [\(index + 1)/\(totalPods)] Successfully deleted pod \(podId) - \(pod.title)")
                    
                    // Remove from local array immediately
                    await MainActor.run {
                        self.pods.removeAll { $0.id == podId }
                    }
                } else {
                    failedDeletes += 1
                    print("❌ [UserViewModel] [\(index + 1)/\(totalPods)] Failed to delete pod \(podId) - \(pod.title)")
                }
                
                // Report progress after each pod
                await MainActor.run {
                    progressCallback?(successfulDeletes + failedDeletes, totalPods)
                }
            }
            
            let overallSuccess = successfulDeletes > 0 && failedDeletes == 0
            print("🗑️ [UserViewModel] Sequential bulk delete completed: \(successfulDeletes) successful, \(failedDeletes) failed")
            
            await MainActor.run {
                completion(overallSuccess)
            }
        }
    }
    
    func followUser() {
        guard let user = user else { return }
        
        // Set loading state and disable button
        isFollowActionInProgress = true
        
        // Optimistic UI update - change immediately
        withAnimation {
            if user.isPrivate == true {
                followRequestSent = true
            } else {
                isFollowing = true
                self.user?.didFollow = true
                self.user?.followers = (self.user?.followers ?? 0) + 1
            }
        }
        
        // Check if the user has a private account
        if user.isPrivate == true {
            // Send follow request instead of following directly
            service.sendFollowRequest(to: user) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        // Success - keep optimistic changes
                        self?.isFollowActionInProgress = false
                    } else {
                        // Failure - rollback optimistic changes
                        withAnimation {
                            self?.followRequestSent = false
                        }
                        self?.isFollowActionInProgress = false
                    }
                }
            }
        } else {
            // Public account - follow directly
            service.followUser(user: user) { [weak self] success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        // Success - keep optimistic changes
                        self?.isFollowActionInProgress = false
                        // Check if this creates mutual friendship
                        if let user = self?.user {
                            self?.checkIfUsersAreFriends(user: user)
                        }
                    } else {
                        // Failure - rollback optimistic changes
                        withAnimation {
                            self?.isFollowing = false
                            self?.user?.didFollow = false
                            self?.user?.followers = max(0, (self?.user?.followers ?? 1) - 1)
                        }
                        self?.isFollowActionInProgress = false
                        
                        // Show rate limit popup if applicable
                        if errorMessage == "RATE_LIMITED" {
                            self?.showRateLimitMessage()
                        }
                    }
                }
            }
        }
    }
    
    func unfollowUser() {
        guard let currentUser = user else { return }
        
        // Set loading state and disable button
        isFollowActionInProgress = true
        
        // Store current state for potential rollback
        let wasFollowing = isFollowing
        let wasRequestSent = followRequestSent
        let previousFollowers = currentUser.followers
        
        // Optimistic UI update - change immediately
        withAnimation {
            if currentUser.isPrivate == true && followRequestSent {
                followRequestSent = false
            } else {
                isFollowing = false
                self.user?.didFollow = false
                self.user?.followers = max(0, (self.user?.followers ?? 1) - 1)
            }
        }
        
        // Check if the user has a private account and we sent a follow request
        if currentUser.isPrivate == true && wasRequestSent {
            // Cancel follow request
            service.cancelFollowRequest(to: currentUser) { [weak self] success in
                DispatchQueue.main.async {
                    if success {
                        // Success - keep optimistic changes
                        self?.isFollowActionInProgress = false
                    } else {
                        // Failure - rollback optimistic changes
                        withAnimation {
                            self?.followRequestSent = wasRequestSent
                        }
                        self?.isFollowActionInProgress = false
                    }
                }
            }
        } else {
            // Public account or already following - unfollow normally
            service.unfollowUser(user: currentUser) { [weak self] success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        // Success - keep optimistic changes
                        self?.isFollowActionInProgress = false
                        // Refresh friendship status
                        if let user = self?.user {
                            self?.checkIfUsersAreFriends(user: user)
                        }
                    } else {
                        // Failure - rollback optimistic changes
                        withAnimation {
                            self?.isFollowing = wasFollowing
                            self?.user?.didFollow = wasFollowing
                            self?.user?.followers = previousFollowers
                        }
                        self?.isFollowActionInProgress = false
                        
                        // Show rate limit popup if applicable
                        if errorMessage == "RATE_LIMITED" {
                            self?.showRateLimitMessage()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Rate Limiting
    
    func showRateLimitMessage() {
        rateLimitMessage = "You've followed/unfollowed this user too many times. Please wait 10 minutes before trying again."
        showRateLimitPopup = true
    }
    
    // MARK: - Remove Follower
    
    func removeFollower(user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUser = self.user else { return }
        
        // Set loading state
        isFollowActionInProgress = true
        
        // Store current state for potential rollback
        let previousFollowers = currentUser.followers
        
        // Optimistic UI update - decrement follower count immediately
        withAnimation {
            self.user?.followers = max(0, (self.user?.followers ?? 1) - 1)
        }
        
        // Call the service to remove the follower
        service.removeFollower(user: user) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // Success - keep optimistic changes
                    self?.isFollowActionInProgress = false
                    completion(true)
                } else {
                    // Failure - rollback optimistic changes
                    withAnimation {
                        self?.user?.followers = previousFollowers
                    }
                    self?.isFollowActionInProgress = false
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Unfollow Specific User
    
    func unfollowSpecificUser(user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUser = self.user else { return }
        
        // Set loading state
        isFollowActionInProgress = true
        
        // Store current state for potential rollback
        let previousFollowing = currentUser.following
        
        // Optimistic UI update - decrement following count immediately
        withAnimation {
            self.user?.following = max(0, (self.user?.following ?? 1) - 1)
        }
        
        // Call the service to unfollow the user
        service.unfollowUser(user: user) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    // Success - keep optimistic changes
                    self?.isFollowActionInProgress = false
                    completion(true)
                } else {
                    // Failure - rollback optimistic changes
                    withAnimation {
                        self?.user?.following = previousFollowing
                    }
                    self?.isFollowActionInProgress = false
                    
                    // Show rate limit popup if applicable
                    if errorMessage == "RATE_LIMITED" {
                        self?.showRateLimitMessage()
                    }
                    
                    completion(false)
                }
            }
        }
    }
    
    
    // MARK: - Following Pagination and Search
    
    @Published var isLoadingMoreFollowing = false
    @Published var isLoadingFollowing = false
    @Published var hasMoreFollowing = true
    @Published var isSearchPendingFollowing = false
    private var lastFollowingUser: User?
    private let followingPageSize = 10
    private var searchTimerFollowing: Timer?
    private let searchDelay: TimeInterval = 1.0 // Wait 1 second after user stops typing
    
    func fetchUserFollowing() {
        guard let user = user, let uid = user.id else { return }
        
        // Set loading state
        isLoadingFollowing = true
        
        // Reset pagination state
        lastFollowingUser = nil
        hasMoreFollowing = true
        following.removeAll()
        filteredFollowing.removeAll()
        
        service.fetchUserFollowing(forUid: uid, lastUser: nil, limit: followingPageSize) { users in
            DispatchQueue.main.async {
                self.following = users
                // Filter out deleted and anonymous accounts
                self.filteredFollowing = users.filter { user in
                    let isDeleted = user.isDeleted ?? false
                    let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                    return !isDeleted && !isAnonymous
                }
                
                // Set the last user reference for pagination
                if let lastUser = users.last {
                    self.lastFollowingUser = lastUser
                }
                
                self.hasMoreFollowing = users.count == self.followingPageSize
                self.isLoadingFollowing = false
            }
        }
    }
    
    func loadMoreFollowing() {
        guard !isLoadingMoreFollowing && hasMoreFollowing else { return }
        
        // Use the last user from the previous page, not the current array
        let lastUser = lastFollowingUser
        
        isLoadingMoreFollowing = true
        
        guard let user = user else { return }
        service.fetchUserFollowing(forUid: user.id ?? "", lastUser: lastUser, limit: followingPageSize) { newUsers in
            // Check for duplicates before adding
            let uniqueNewUsers = newUsers.filter { newUser in
                !self.following.contains { existingUser in
                    existingUser.id == newUser.id
                }
            }
            
            self.following.append(contentsOf: uniqueNewUsers)
            // Filter out deleted and anonymous accounts
            let filteredNewUsers = uniqueNewUsers.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                return !isDeleted && !isAnonymous
            }
            self.filteredFollowing.append(contentsOf: filteredNewUsers)
            
            // Update the last user reference for next pagination
            if let lastNewUser = uniqueNewUsers.last {
                self.lastFollowingUser = lastNewUser
            }
            
            self.hasMoreFollowing = uniqueNewUsers.count == self.followingPageSize
            self.isLoadingMoreFollowing = false
        }
    }
    
    func performDebouncedSearchFollowing(searchText: String) {
        searchTimerFollowing?.invalidate() // Cancel previous timer
        
        if searchText.isEmpty {
            // Reset to show all loaded following users (filtered)
            filteredFollowing = following.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                return !isDeleted && !isAnonymous
            }
            isSearchPendingFollowing = false
            return
        }
        
        isSearchPendingFollowing = true
        
        searchTimerFollowing = Timer.scheduledTimer(withTimeInterval: searchDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSearchPendingFollowing = false
                self?.performSearchFollowing(searchText: searchText)
            }
        }
    }
    
    private func performSearchFollowing(searchText: String) {
        let lowercasedQuery = searchText.lowercased()
        
        // First filter through already loaded users (excluding deleted/anonymous)
        let loadedMatches = following.filter { user in
            let isDeleted = user.isDeleted ?? false
            let isAnonymous = user.username.lowercased().hasPrefix("anon_")
            let matchesSearch = (user.fullname?.lowercased().contains(lowercasedQuery) ?? false) ||
                               user.username.lowercased().contains(lowercasedQuery)
            return !isDeleted && !isAnonymous && matchesSearch
        }
        
        // If we have enough results from loaded users, use those
        if loadedMatches.count >= 10 {
            filteredFollowing = loadedMatches
        } else {
            // Search through loaded users first, then load more if needed
            filteredFollowing = loadedMatches
            
            // Load more users to find better matches
            if hasMoreFollowing && !isLoadingMoreFollowing {
                loadMoreFollowing()
            }
        }
    }
    
    func filterFollowing(searchText: String) {
        if searchText.isEmpty {
            // Show all loaded following users (filtered)
            filteredFollowing = following.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                return !isDeleted && !isAnonymous
            }
        } else {
            let lowercasedQuery = searchText.lowercased()
            
            // First filter through already loaded users (excluding deleted/anonymous)
            let loadedMatches = following.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                let matchesSearch = (user.fullname?.lowercased().contains(lowercasedQuery) ?? false) ||
                                   user.username.lowercased().contains(lowercasedQuery)
                return !isDeleted && !isAnonymous && matchesSearch
            }
            
            // If we have enough results from loaded users, use those
            if loadedMatches.count >= 10 {
                filteredFollowing = loadedMatches
            } else {
                // Search through loaded users first, then load more if needed
                filteredFollowing = loadedMatches
                
                // Load more users to find better matches
                if hasMoreFollowing && !isLoadingMoreFollowing {
                    loadMoreFollowing()
                }
            }
        }
    }
    
    // MARK: - Followers Pagination and Search
    
    @Published var isLoadingMoreFollowers = false
    @Published var isLoadingFollowers = false
    @Published var hasMoreFollowers = true
    @Published var isSearchPendingFollowers = false
    private var lastFollowersUser: User?
    private let followersPageSize = 10
    private var searchTimerFollowers: Timer?
    
    func fetchUserFollowers() {
        guard let user = user, let uid = user.id else { return }
        
        // Set loading state
        isLoadingFollowers = true
        
        // Reset pagination state
        lastFollowersUser = nil
        hasMoreFollowers = true
        followers.removeAll()
        filteredFollowers.removeAll()
        
        service.fetchUserFollowers(forUid: uid, lastUser: nil, limit: followersPageSize) { users in
            DispatchQueue.main.async {
                self.followers = users
                // Filter out deleted and anonymous accounts
                self.filteredFollowers = users.filter { user in
                    let isDeleted = user.isDeleted ?? false
                    let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                    return !isDeleted && !isAnonymous
                }
                
                // Set the last user reference for pagination
                if let lastUser = users.last {
                    self.lastFollowersUser = lastUser
                }
                
                self.hasMoreFollowers = users.count == self.followersPageSize
                self.isLoadingFollowers = false
            }
        }
    }
    
    func loadMoreFollowers() {
        guard !isLoadingMoreFollowers && hasMoreFollowers else { return }
        
        // Use the last user from the previous page, not the current array
        let lastUser = lastFollowersUser
        
        isLoadingMoreFollowers = true
        
        guard let user = user else { return }
        service.fetchUserFollowers(forUid: user.id ?? "", lastUser: lastUser, limit: followersPageSize) { newUsers in
            // Check for duplicates before adding
            let uniqueNewUsers = newUsers.filter { newUser in
                !self.followers.contains { existingUser in
                    existingUser.id == newUser.id
                }
            }
            
            self.followers.append(contentsOf: uniqueNewUsers)
            // Filter out deleted and anonymous accounts
            let filteredNewUsers = uniqueNewUsers.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                return !isDeleted && !isAnonymous
            }
            self.filteredFollowers.append(contentsOf: filteredNewUsers)
            
            // Update the last user reference for next pagination
            if let lastNewUser = uniqueNewUsers.last {
                self.lastFollowersUser = lastNewUser
            }
            
            self.hasMoreFollowers = uniqueNewUsers.count == self.followersPageSize
            self.isLoadingMoreFollowers = false
        }
    }
    
    func performDebouncedSearchFollowers(searchText: String) {
        searchTimerFollowers?.invalidate() // Cancel previous timer
        
        if searchText.isEmpty {
            // Reset to show all loaded followers (filtered)
            filteredFollowers = followers.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                return !isDeleted && !isAnonymous
            }
            isSearchPendingFollowers = false
            return
        }
        
        isSearchPendingFollowers = true
        
        searchTimerFollowers = Timer.scheduledTimer(withTimeInterval: searchDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSearchPendingFollowers = false
                self?.performSearchFollowers(searchText: searchText)
            }
        }
    }
    
    private func performSearchFollowers(searchText: String) {
        let lowercasedQuery = searchText.lowercased()
        
        // First filter through already loaded users (excluding deleted/anonymous)
        let loadedMatches = followers.filter { user in
            let isDeleted = user.isDeleted ?? false
            let isAnonymous = user.username.lowercased().hasPrefix("anon_")
            let matchesSearch = (user.fullname?.lowercased().contains(lowercasedQuery) ?? false) ||
                               user.username.lowercased().contains(lowercasedQuery)
            return !isDeleted && !isAnonymous && matchesSearch
        }
        
        // If we have enough results from loaded users, use those
        if loadedMatches.count >= 10 {
            filteredFollowers = loadedMatches
        } else {
            // Search through loaded users first, then load more if needed
            filteredFollowers = loadedMatches
            
            // Load more users to find better matches
            if hasMoreFollowers && !isLoadingMoreFollowers {
                loadMoreFollowers()
            }
        }
    }
    
    func filterFollowers(searchText: String) {
        if searchText.isEmpty {
            // Show all loaded followers (filtered)
            filteredFollowers = followers.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                return !isDeleted && !isAnonymous
            }
        } else {
            let lowercasedQuery = searchText.lowercased()
            
            // First filter through already loaded users (excluding deleted/anonymous)
            let loadedMatches = followers.filter { user in
                let isDeleted = user.isDeleted ?? false
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                let matchesSearch = (user.fullname?.lowercased().contains(lowercasedQuery) ?? false) ||
                                   user.username.lowercased().contains(lowercasedQuery)
                return !isDeleted && !isAnonymous && matchesSearch
            }
            
            // If we have enough results from loaded users, use those
            if loadedMatches.count >= 10 {
                filteredFollowers = loadedMatches
            } else {
                // Load more users to find better matches
                filteredFollowers = loadedMatches
                
                if hasMoreFollowers && !isLoadingMoreFollowers {
                    loadMoreFollowers()
                }
            }
        }
    }
    
    func checkIfUserIsFollowed(user: User) {
        service.checkIfUserIsFollowed(user: user) { didFollow in
            DispatchQueue.main.async {
                self.isFollowing = didFollow
                if didFollow {
                    self.user?.didFollow = true
                }
            }
        }
    }
    
    func editProfile(fullname: String, username: String, bio: String, link: String) {
        guard let user = user else { return }
        service.editProfile(withUid: user.uid, fullname: fullname, username: username, bio: bio, link: link) { _ in
            
        }
    }
    
    func checkUsername(username: String, completion: @escaping(Bool) -> Void) {
        service.isUsernameInUse(username: username) { bool in
            completion(bool)
        }
    }
    
    /// Changes username atomically via cloud function (prevents race conditions)
    /// - Parameters:
    ///   - newUsername: The new username to set
    ///   - fullname: Updated full name
    ///   - bio: Updated bio
    ///   - link: Updated link
    ///   - completion: Completion handler with success status and any error
    func changeUsernameAndProfile(newUsername: String, fullname: String, bio: String, link: String, completion: @escaping (Bool, Error?) -> Void) {
        let functions = Functions.functions()
        let changeUsername = functions.httpsCallable("changeUsername")
        
        guard let user = user else { return }
        let data: [String: Any] = [
            "newUsername": newUsername,
            "currentUsername": user.username
        ]
        
        changeUsername.call(data) { [weak self] result, error in
            if let error = error {
                print("Error changing username: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            // If username change successful, update other profile fields
            self?.service.editProfile(withUid: self?.user?.uid ?? "", fullname: fullname, username: newUsername, bio: bio, link: link) { result in
                switch result {
                case .success(let updatedUser):
                    DispatchQueue.main.async {
                        // Update the @Published user object to trigger UI refresh
                        self?.user = updatedUser
                        
                        // Force UI update by triggering objectWillChange
                        self?.objectWillChange.send()
                        
                        print("✅ Profile updated successfully: \(newUsername)")
                    }
                    completion(true, nil)
                case .failure(let error):
                    print("❌ Failed to update profile fields: \(error.localizedDescription)")
                    completion(false, error)
                }
            }
        }
    }
    
    func deleteUsername(username: String) {
        service.deleteUsername(username: username)
    }

    func addUsername(username: String) {
        service.addUsername(username: username)
    }
    
    var isFollowed: Bool {
        return user?.didFollow ?? false
        }
    
    func toggleFollow() {
        guard let user = user else { return }
        if user.isPrivate == true {
            if followRequestSent {
                unfollowUser()
            } else if isFollowing {
                unfollowUser()
            } else {
                followUser()
            }
        } else {
            if isFollowing {
                unfollowUser()
            } else {
                followUser()
            }
        }
    }
    
    func createPlaylist(title: String, podIds: [String], thumbnailUrl: String, description: String? = nil) {
        service.createPlaylist(title: title, podIds: podIds, thumbnailUrl: thumbnailUrl, description: description) { success, error in
            
        }
            
    }
    
    func checkIfCurrentUser(user: User) {
        guard let currentUserId = authViewModel.currentUser?.id else {
            isCurrentUser = false
            return
        }
        
        isCurrentUser = (user.id == currentUserId)
    }
    
    func checkIfUsersAreFriends(user: User) {
        service.checkIfUsersAreFriends(withUid: user.uid) { isFriend in
            DispatchQueue.main.async {
                self.isFriend = isFriend
                self.isLoadingFriendshipStatus = false
            }
        }
    }
    
    func checkIfFollowRequestSent(user: User) {
        service.checkIfFollowRequestSent(to: user) { sent in
            DispatchQueue.main.async {
                self.followRequestSent = sent
                self.isLoadingFollowRequestStatus = false
            }
        }
    }
    
    func fetchActualPodCount() {
        guard let user = user else { return }
        service.countUserPods(withUid: user.uid) { count in
            DispatchQueue.main.async {
                self.actualPodCount = count
            }
        }
    }
    
    // MARK: - Blocking Methods
    
    func checkBlockStatus(user: User) {
        print("🔍 USER_VIEWMODEL: checkBlockStatus called for user: \(user.username) (UID: \(user.uid))")
        
        guard let currentUid = Auth.auth().currentUser?.uid else { 
            print("❌ USER_VIEWMODEL: checkBlockStatus failed - no authenticated user")
            return 
        }
        
        print("🔍 USER_VIEWMODEL: Current user UID: \(currentUid)")
        print("🔍 USER_VIEWMODEL: Starting blocking status checks...")
        
        // Use DispatchGroup to wait for both blocking checks to complete
        let group = DispatchGroup()
        
        // Check if current user has blocked this user (quick array check for ongoing app usage)
        group.enter()
        print("🔍 USER_VIEWMODEL: Checking if current user has blocked user \(user.username)")
        blockService.checkIfUserIsBlocked(userId: user.uid) { isBlocked in
            print("🔍 USER_VIEWMODEL: checkIfUserIsBlocked result for \(user.username): \(isBlocked)")
            DispatchQueue.main.async {
                self.isBlockedByCurrentUser = isBlocked
                self.isUserBlocked = isBlocked
                print("🔍 USER_VIEWMODEL: Updated isBlockedByCurrentUser: \(isBlocked), isUserBlocked: \(isBlocked)")
            }
            group.leave()
        }
        
        // Check if current user is blocked by this user (real-time subcollection check for profile views)
        group.enter()
        print("🔍 USER_VIEWMODEL: Checking if current user is blocked by user \(user.username) using subcollection")
        blockService.accurateCheckIfCurrentUserIsBlocked(by: user.uid) { isBlocked in
            print("🔍 USER_VIEWMODEL: accurateCheckIfCurrentUserIsBlocked subcollection result for \(user.username): \(isBlocked)")
            DispatchQueue.main.async {
                self.isBlocked = isBlocked
                self.isCurrentUserBlockedByThisUser = isBlocked
                print("🔍 USER_VIEWMODEL: Updated isBlocked: \(isBlocked), isCurrentUserBlockedByThisUser: \(isBlocked)")
            }
            group.leave()
        }
        
        // When both checks complete, set the final status
        group.notify(queue: .main) {
            print("🔍 USER_VIEWMODEL: Both blocking checks completed")
            self.isLoadingBlockStatus = false
            self.isBlockingCheckComplete = true
            
            // If no blocking detected, fetch profile content and check follow status
            if !self.isCurrentUserBlockedByThisUser && !self.isUserBlocked {
                print("🔍 USER_VIEWMODEL: No blocking detected, fetching profile content...")
                self.fetchActualPodCount()
                self.fetchFirstPageOfUserPods()
                self.fetchFirstPageOfUserReposts()
                
                // Also check follow status for the follow button
                print("🔍 USER_VIEWMODEL: Checking follow status...")
                self.checkIfUserIsFollowed(user: user)
                self.checkIfFollowRequestSent(user: user)
            } else {
                print("🔍 USER_VIEWMODEL: Blocking detected, skipping content fetch")
            }
        }
    }
    
    func blockUser(completion: @escaping (Bool) -> Void) {
        guard let user = user else { return }
        print("🚫 USER_VIEWMODEL: blockUser called for user: \(user.username) (UID: \(user.uid))")
        
        print("🚫 USER_VIEWMODEL: Calling blockService.blockUser...")
        blockService.blockUser(userId: user.uid) { success in
            print("🚫 USER_VIEWMODEL: blockService.blockUser result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.isBlockedByCurrentUser = true
                    self.isUserBlocked = true  // Add this line for UI
                    print("🚫 USER_VIEWMODEL: Successfully blocked user, updated isBlockedByCurrentUser: true, isUserBlocked: true")
                } else {
                    print("🚫 USER_VIEWMODEL: Failed to block user")
                }
                completion(success)
            }
        }
    }
    
    func unblockUser(completion: @escaping (Bool) -> Void) {
        guard let user = user else { return }
        print("🔓 USER_VIEWMODEL: unblockUser called for user: \(user.username) (UID: \(user.uid))")
        
        print("🔓 USER_VIEWMODEL: Calling blockService.unblockUser...")
        blockService.unblockUser(userId: user.uid) { success in
            print("🔓 USER_VIEWMODEL: blockService.unblockUser result: \(success)")
            DispatchQueue.main.async {
                if success {
                    self.isBlockedByCurrentUser = false
                    self.isUserBlocked = false  // Add this line for UI
                    print("🔓 USER_VIEWMODEL: Successfully unblocked user, updated isBlockedByCurrentUser: false, isUserBlocked: false")
                } else {
                    print("🔓 USER_VIEWMODEL: Failed to unblock user")
                }
                completion(success)
            }
        }
    }
    
}
