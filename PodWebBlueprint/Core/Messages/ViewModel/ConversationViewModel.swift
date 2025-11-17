//
//  ConversationViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 8/10/23.
//

import Foundation
import Firebase
import FirebaseFirestore
//import FirebaseFirestoreSwift
import SwiftUI
import FirebaseAuth

class ConversationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var conversations = [Conversation]()
    @Published var convoSearchText = ""
    @Published var latestMessages: [String: Message] = [:] // conversationId -> latest message
    @Published var podCreatorUsernames: [String: String] = [:] // podId -> username
    @Published var participantUsers: [String: User] = [:] // userId -> User object
    @Published var isLoading = false
    
    // MARK: - Pagination Properties
    
    @Published var hasMoreConversations = true
    @Published var isFetchingMore = false
    private var lastConversation: Conversation?
    private let pageSize = 10
    
    // MARK: - Search Properties
    
    private var searchTimer: Timer?
    private let searchDelay: TimeInterval = 1.0 // Wait 1 second after user stops typing
    @Published var isSearchPending = false
    
    // MARK: - Computed Properties
    
    var sortedConversations: [Conversation] {
        // Sort conversations by latest message timestamp (most recent first)
        return conversations.sorted { conversation1, conversation2 in
            let message1 = latestMessages[conversation1.id ?? ""]
            let message2 = latestMessages[conversation2.id ?? ""]
            
            // If both have messages, compare timestamps
            if let timestamp1 = message1?.timestamp, let timestamp2 = message2?.timestamp {
                return timestamp1 > timestamp2
            }
            
            // If only one has a message, prioritize the one with a message
            if message1 != nil && message2 == nil {
                return true
            }
            if message1 == nil && message2 == nil {
                return false
            }
            
            // If neither has a message, maintain original order
            return false
        }
    }
    
    // MARK: - Dependencies
    
    let userService = UserService()
    let conversationService = ConversationService()
    var user: User
    
    // MARK: - Caching Properties
    private var lastConversationFetch: Date?
    private let conversationCacheTimeout: TimeInterval = 300 // 5 minutes
    private var hasInitiallyLoaded = false
    
    // MARK: - Initialization
    
    init(user: User) {
        self.user = user
        // Only fetch if not already loaded and cache is expired
        fetchConversationsIfNeeded()
    }
    
    /// Update user when user changes
    func updateUser(user: User) {
        self.user = user
        // Check if we need to refresh conversations
        checkAndRefreshIfNeeded()
    }
    
    deinit {
        searchTimer?.invalidate()
    }
    
    // MARK: - Fetch Conversations
    
    /// Fetches conversations only if needed (cache miss or expired)
    private func fetchConversationsIfNeeded() {
        // Check if we have fresh data
        if hasInitiallyLoaded,
           let lastFetch = lastConversationFetch,
           Date().timeIntervalSince(lastFetch) < conversationCacheTimeout,
           !conversations.isEmpty {
            print("🔄 [ConversationViewModel] Conversations are fresh (\(Int(Date().timeIntervalSince(lastFetch)))s ago), skipping fetch")
            return
        }
        
        // Check if we're already loading
        if isLoading {
            print("🔄 [ConversationViewModel] Already loading conversations, skipping")
            return
        }
        
        fetchConversations()
    }
    
    /// Force refresh conversations (used for manual refresh)
    func refreshConversations() {
        hasInitiallyLoaded = false
        lastConversationFetch = nil
        fetchConversations()
    }
    
    /// Check if conversations need refreshing when tab becomes active
    func checkAndRefreshIfNeeded() {
        fetchConversationsIfNeeded()
    }
    
    func fetchConversations() {
        print("🔄 Fetching conversations for user: \(user.id ?? "nil")")
        guard let userId = user.id else { return }
        
        isLoading = true
        conversations = []
        lastConversation = nil
        hasMoreConversations = true
        
        conversationService.fetchConversationsWithSearch(
            for: userId,
            searchQuery: convoSearchText,
            limit: pageSize
        ) { [weak self] conversations in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.conversations = conversations
                self.lastConversation = conversations.last
                self.hasMoreConversations = conversations.count >= self.pageSize
                self.lastConversationFetch = Date() // Update cache timestamp
                self.hasInitiallyLoaded = true
                
                if conversations.isEmpty {
                    // No conversations to load data for, so we're done loading
                    self.isLoading = false
                } else {
                    // Fetch additional data for conversations
                    // isLoading will be set to false in fetchParticipantDetails() when all data is loaded
                    self.fetchLatestMessagesForAllConversations()
                }
            }
        }
    }
    
    /// Fetch next page of conversations
    func fetchNextPage() {
        guard !isFetchingMore && hasMoreConversations,
              let userId = user.id else { return }
        
        // Don't fetch next page if we're searching
        guard convoSearchText.isEmpty else {
            print("🔍 [ConversationViewModel] Skipping regular pagination - search is active")
            return
        }
        
        isFetchingMore = true
        print("📱 [ConversationViewModel] Fetching next page of conversations")
        
        conversationService.fetchConversationsWithSearch(
            for: userId,
            searchQuery: convoSearchText,
            lastConversation: lastConversation,
            limit: pageSize
        ) { [weak self] newConversations in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.conversations.append(contentsOf: newConversations)
                self.lastConversation = newConversations.last
                self.hasMoreConversations = newConversations.count >= self.pageSize
                self.isFetchingMore = false
                
                // Fetch additional data for new conversations
                self.fetchLatestMessagesForAllConversations()
                
                print("📱 [ConversationViewModel] Next page loaded: \(newConversations.count) conversations, hasMore: \(self.hasMoreConversations)")
            }
        }
    }
    
    /// Perform new search and reset pagination
    func performSearch() {
        print("🔍 [ConversationViewModel] Performing search: '\(convoSearchText)'")
        
        // Don't search if we already have results for this query
        if !conversations.isEmpty && !isLoading {
            print("🔍 [ConversationViewModel] Already have results, not searching again")
            return
        }
        
        // Reset pagination for new search
        hasMoreConversations = true
        lastConversation = nil
        
        // Use server-side search
        searchConversations()
    }
    
    /// Server-side search for conversations
    private func searchConversations() {
        guard let currentUser = Auth.auth().currentUser else { 
            print("❌ [ConversationViewModel] No current user for search")
            return 
        }
        
        print("🔍 [ConversationViewModel] Starting server-side search for: '\(convoSearchText)'")
        print("🔍 [ConversationViewModel] Current user ID: \(currentUser.uid)")
        
        isSearchPending = false
        isLoading = true
        
        // Reset pagination for new search
        hasMoreConversations = true
        lastConversation = nil
        
        conversationService.searchConversationsByUsername(
            for: currentUser.uid,
            searchQuery: convoSearchText,
            limit: pageSize
        ) { [weak self] conversations in
            DispatchQueue.main.async {
                print("🔍 [ConversationViewModel] Search callback received \(conversations.count) conversations")
                
                self?.conversations = conversations
                
                // Set pagination state based on results
                if let self = self {
                    self.hasMoreConversations = conversations.count >= self.pageSize
                    self.lastConversation = conversations.last
                    print("🔍 [ConversationViewModel] Search pagination: hasMore=\(self.hasMoreConversations), lastConversation=\(self.lastConversation?.id ?? "nil")")
                }
                
                if conversations.isEmpty {
                    // No conversations to load data for, so we're done loading
                    self?.isLoading = false
                } else {
                    // Fetch additional data for these conversations
                    // isLoading will be set to false in fetchParticipantDetails() when all data is loaded
                    self?.fetchLatestMessagesForAllConversations()
                }
                
                print("🔍 [ConversationViewModel] Search completed with \(conversations.count) results")
            }
        }
    }
    
    /// Fetch next page of search results
    func fetchNextSearchPage() {
        guard !convoSearchText.isEmpty,
              hasMoreConversations,
              !isFetchingMore,
              let currentUser = Auth.auth().currentUser else { 
            print("🔍 [ConversationViewModel] Cannot fetch next search page: hasMore=\(hasMoreConversations), isFetching=\(isFetchingMore)")
            return 
        }
        
        isFetchingMore = true
        print("🔍 [ConversationViewModel] Fetching next search page for: '\(convoSearchText)'")
        
        conversationService.searchConversationsByUsername(
            for: currentUser.uid,
            searchQuery: convoSearchText,
            lastConversation: lastConversation,
            limit: pageSize
        ) { [weak self] conversations in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("🔍 [ConversationViewModel] Next search page received \(conversations.count) conversations")
                
                if conversations.isEmpty {
                    self.hasMoreConversations = false
                    print("🔍 [ConversationViewModel] No more search results, setting hasMoreConversations = false")
                } else {
                    self.conversations.append(contentsOf: conversations)
                    self.lastConversation = conversations.last
                    self.hasMoreConversations = conversations.count >= self.pageSize
                    
                    print("🔍 [ConversationViewModel] Added \(conversations.count) conversations, hasMore=\(self.hasMoreConversations)")
                    
                    // Fetch additional data for new conversations
                    for conversation in conversations {
                        self.fetchLatestMessagesForConversation(conversation)
                    }
                }
                
                self.isFetchingMore = false
                print("🔍 [ConversationViewModel] Next search page completed, total conversations: \(self.conversations.count)")
            }
        }
    }
    
    /// Debounced search - waits for user to stop typing
    func performDebouncedSearch() {
        // Cancel any existing timer
        searchTimer?.invalidate()
        
        // Don't search if text is empty
        guard !convoSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 [ConversationViewModel] Search text is empty, not searching")
            isSearchPending = false
            // If search is cleared, show all conversations
            if !conversations.isEmpty {
                fetchConversations()
            }
            return
        }
        
        // Set search as pending
        isSearchPending = true
        print("🔍 [ConversationViewModel] Starting debounced search for: '\(convoSearchText)' (waiting \(searchDelay)s)")
        
        // Create new timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: searchDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("🔍 [ConversationViewModel] Timer fired, executing search for: '\(self.convoSearchText)'")
                self.isSearchPending = false
                self.performSearch()
            }
        }
    }
    
    private func fetchLatestMessagesForAllConversations() {
        let group = DispatchGroup()
        
        for conversation in conversations {
            group.enter()
            guard let conversationId = conversation.id else {
                group.leave()
                continue
            }
            
            conversationService.fetchMessages(conversationId: conversationId, limit: 1) { [weak self] messages in
                DispatchQueue.main.async {
                    self?.latestMessages[conversationId] = messages.first
                    
                    // If it's a pod message, fetch the creator's username
                    if let message = messages.first, message.isPod, let podId = message.podId, !podId.isEmpty {
                        self?.fetchPodCreator(podId: podId)
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // All latest messages have been fetched, now fetch participant details
            self.fetchParticipantDetails()
        }
    }
    
    /// Fetch latest messages for a single conversation
    private func fetchLatestMessagesForConversation(_ conversation: Conversation) {
        guard let conversationId = conversation.id else { return }
        
        conversationService.fetchMessages(conversationId: conversationId, limit: 1) { [weak self] messages in
            DispatchQueue.main.async {
                self?.latestMessages[conversationId] = messages.first
                
                // If it's a pod message, fetch the creator's username
                if let message = messages.first, message.isPod, let podId = message.podId, !podId.isEmpty {
                    self?.fetchPodCreator(podId: podId)
                }
            }
        }
        
        // Fetch participant details for this conversation
        for participantId in conversation.participants {
            if participantUsers[participantId] == nil {
                conversationService.fetchUserDetails(userId: participantId) { [weak self] user in
                    DispatchQueue.main.async {
                        if let user = user {
                            self?.participantUsers[participantId] = user
                        }
                    }
                }
            }
        }
    }
    
    private func fetchParticipantDetails() {
        let group = DispatchGroup()
        
        for conversation in conversations {
            for participantId in conversation.participants {
                if participantUsers[participantId] == nil {
                    group.enter()
                    print("👤 Fetching participant user: \(participantId) for conversation: \(conversation.id ?? "nil")")
                    conversationService.fetchUserDetails(userId: participantId) { [weak self] user in
                        DispatchQueue.main.async {
                            if let user = user {
                                self?.participantUsers[participantId] = user
                                print("✅ Cached participant user: \(user.username) (ID: \(participantId))")
                            }
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ All participant details fetched and cached")
            // Now all data is loaded - conversations, messages, and participant details
            self.isLoading = false
        }
    }
    
    // MARK: - Searchable Conversations
    
    var searchableConversations: [Conversation] {
        let filteredConversations: [Conversation]
        
        if convoSearchText.isEmpty {
            filteredConversations = conversations
        } else {
            let lowercasedQuery = convoSearchText.lowercased()
            print("🔍 [ConversationViewModel] Searching for: '\(lowercasedQuery)' in \(conversations.count) conversations")
            print("🔍 [ConversationViewModel] Participant users loaded: \(participantUsers.count)")
            
            filteredConversations = conversations.filter { conversation in
                // Filter by participant usernames and fullnames
                return conversation.participants.contains { participantId in
                    if let user = participantUsers[participantId] {
                        let matches = user.username.lowercased().contains(lowercasedQuery) ||
                                     (user.fullname?.lowercased().contains(lowercasedQuery) ?? false)
                        if matches {
                            print("🔍 [ConversationViewModel] Found match: \(user.username) (\(user.fullname ?? "No name"))")
                        }
                        return matches
                    } else {
                        print("🔍 [ConversationViewModel] No user data for participant: \(participantId)")
                        return false
                    }
                }
            }
            
            print("🔍 [ConversationViewModel] Search results: \(filteredConversations.count) conversations")
        }
        
        // Sort conversations by latest message timestamp (most recent first)
        return filteredConversations.sorted { conversation1, conversation2 in
            let message1 = latestMessages[conversation1.id ?? ""]
            let message2 = latestMessages[conversation2.id ?? ""]
            
            // If both have messages, compare timestamps
            if let timestamp1 = message1?.timestamp, let timestamp2 = message2?.timestamp {
                return timestamp1 > timestamp2
            }
            
            // If only one has a message, prioritize the one with a message
            if message1 != nil && message2 == nil {
                return true
            }
            if message1 == nil && message2 == nil {
                return false
            }
            
            // If neither has a message, maintain original order
            return false
        }
    }
    
    // MARK: - Fetch Latest Message
    
    func fetchLatestMessage(for conversation: Conversation) {
        guard let conversationId = conversation.id else { return }
        
        conversationService.fetchMessages(conversationId: conversationId, limit: 1) { [weak self] messages in
            DispatchQueue.main.async {
                self?.latestMessages[conversationId] = messages.first
                
                // If it's a pod message, fetch the creator's username
                if let message = messages.first, message.isPod, let podId = message.podId, !podId.isEmpty {
                    self?.fetchPodCreator(podId: podId)
                }
            }
        }
    }
    
    // MARK: - Update Conversation Read Status
    
    func markConversationAsRead(conversationId: String) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Find the conversation in our cached list
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            // Update the lastMessageReadBy array to include the current user
            var updatedConversation = conversations[index]
            if updatedConversation.lastMessageReadBy == nil {
                updatedConversation.lastMessageReadBy = []
            }
            
            // Add current user to the read list if not already there
            if !(updatedConversation.lastMessageReadBy?.contains(currentUid) ?? false) {
                updatedConversation.lastMessageReadBy?.append(currentUid)
                conversations[index] = updatedConversation
                
                // Also update the cached latest message to show as read
                if let cachedMessage = latestMessages[conversationId] {
                    var updatedMessage = cachedMessage
                    updatedMessage.isRead = true
                    latestMessages[conversationId] = updatedMessage
                }
                
                // Trigger UI update
                objectWillChange.send()
                print("✅ Updated frontend cache: marked conversation \(conversationId) as read for user \(currentUid)")
            }
        }
    }
    
    // MARK: - Fetch Pod Creator
    
    private func fetchPodCreator(podId: String) {
        let db = Firestore.firestore()
        db.collection("pods").document(podId).getDocument { document, error in
            DispatchQueue.main.async {
                if let document = document, document.exists,
                   let pod = try? document.data(as: Pod.self) {
                    // Fetch the user who created the pod
                    db.collection("users").document(pod.userId).getDocument { userDocument, userError in
                        DispatchQueue.main.async {
                            if let userDocument = userDocument, userDocument.exists,
                               let creator = try? userDocument.data(as: User.self) {
                                self.podCreatorUsernames[podId] = creator.username
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Get Other Participant
    
    func getOtherParticipant(for conversation: Conversation) -> String? {
        guard let currentUid = Auth.auth().currentUser?.uid else { return nil }
        return conversation.participants.first { $0 != currentUid }
    }
    
    // MARK: - Get Other Participant User
    
    func getOtherParticipantUser(for conversation: Conversation) -> User? {
        guard let otherParticipantId = getOtherParticipant(for: conversation) else { 
            return nil 
        }
        
        // Simply return the cached user - no need to print every time
        return participantUsers[otherParticipantId]
    }
}
