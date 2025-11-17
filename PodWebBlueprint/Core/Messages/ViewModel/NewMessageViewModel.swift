//
//  NewMessageViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/23.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

class NewMessageViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var allConversations = [Conversation]()
    @Published var filteredConversations = [Conversation]()
    @Published var latestMessages: [String: Message] = [:] // conversationId -> latest message
    @Published var participantUsers: [String: User] = [:] // userId -> User object
    @Published var podCreatorUsernames: [String: String] = [:] // podId -> username
    @Published var deletedConversations: Set<String> = [] // Set of conversation IDs that are deleted for current user
    @Published var isLoading = false
    private var hasInitiallyLoaded = false
    
    // MARK: - Pagination Properties
    
    @Published var hasMoreConversations = true
    @Published var isFetchingMore = false
    private var lastConversation: Conversation?
    private let pageSize = 10
    
    // MARK: - Search Properties
    
    private var searchTimer: Timer?
    private let searchDelay: TimeInterval = 1.0 // Wait 1 second after user stops typing
    @Published var isSearchPending = false
    
    // MARK: - Search Text
    
    @Published var searchText = ""
    
    // New properties for user selection (kept for compatibility but disabled)
    @Published var availableUsers = [User]()
    @Published var filteredUsers = [User]()
    @Published var isShowingUserSelection = false
    
    // MARK: - Dependencies
    
    let conversationService = ConversationService()
    let user: User
    
    // MARK: - Initialization
    
    init(user: User) {
        self.user = user
    }
    
    deinit {
        searchTimer?.invalidate()
    }
    
    // MARK: - Fetch All Conversations
    
    func fetchAllConversations() {
        // Only fetch if we haven't loaded initially or if we're explicitly refreshing
        guard !hasInitiallyLoaded else {
            print("🔄 Skipping fetch - already loaded initially")
            return
        }
        
        isLoading = true
        print("🔄 Fetching ALL conversations for user: \(user.id ?? "nil")")
        
        guard let userId = user.id else { 
            isLoading = false
            return 
        }
        
        // Reset pagination for new fetch
        hasMoreConversations = true
        lastConversation = nil
        
        // Use the method that includes deleted conversations but still applies blocking filters
        conversationService.fetchAllConversationsIncludingDeleted(for: userId) { [weak self] conversations, deletedIds in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Sort by last activity
                let sortedConversations = conversations.sorted { $0.lastActivity > $1.lastActivity }
                self.allConversations = sortedConversations
                self.filteredConversations = sortedConversations
                
                // Update pagination state - only set hasMore if we got more than pageSize conversations
                // This prevents infinite pagination when we have exactly pageSize conversations
                self.hasMoreConversations = conversations.count > self.pageSize
                self.lastConversation = conversations.last
                
                // Update the deleted conversations set
                self.deletedConversations = deletedIds
                
                // Fetch latest messages and participant details for new conversations only
                self.fetchLatestMessagesForConversations(conversations)
                self.fetchParticipantDetailsForConversations(conversations)
                self.fetchPodCreatorsForConversations(conversations)
                
                self.hasInitiallyLoaded = true
                self.isLoading = false
                print("✅ Fetched \(conversations.count) total conversations (including deleted, filtered for blocked users)")
                print("📝 Found \(deletedIds.count) deleted conversations")
                print("📱 Pagination: hasMore=\(self.hasMoreConversations), lastConversation=\(self.lastConversation?.id ?? "nil")")
            }
        }
    }
    
    /// Force refresh conversations (used when returning from a conversation)
    func refreshConversations() {
        hasInitiallyLoaded = false
        fetchAllConversations()
    }
    
    /// Fetch next page of conversations
    func fetchNextPage() {
        guard !isFetchingMore && hasMoreConversations,
              let userId = user.id else { return }
        
        // Don't fetch next page if we're searching
        guard searchText.isEmpty else {
            print("🔍 [NewMessageViewModel] Skipping regular pagination - search is active")
            return
        }
        
        isFetchingMore = true
        print("📱 [NewMessageViewModel] Fetching next page of conversations")
        
        conversationService.fetchAllConversationsIncludingDeleted(for: userId) { [weak self] conversations, deletedIds in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Sort by last activity
                let sortedConversations = conversations.sorted { $0.lastActivity > $1.lastActivity }
                
                // Append new conversations
                self.allConversations.append(contentsOf: sortedConversations)
                self.filteredConversations = self.allConversations
                
                // Update pagination state
                self.lastConversation = sortedConversations.last
                self.hasMoreConversations = conversations.count >= self.pageSize
                self.isFetchingMore = false
                
                // Update the deleted conversations set
                self.deletedConversations = deletedIds
                
                // Fetch additional data for new conversations only
                self.fetchLatestMessagesForConversations(sortedConversations)
                self.fetchParticipantDetailsForConversations(sortedConversations)
                self.fetchPodCreatorsForConversations(sortedConversations)
                
                print("📱 [NewMessageViewModel] Next page loaded: \(sortedConversations.count) conversations, hasMore: \(self.hasMoreConversations)")
            }
        }
    }
    
    // MARK: - Server-Side Search
    
    /// Perform server-side search for conversations
    func performSearch() {
        print("🔍 [NewMessageViewModel] performSearch called with text: '\(searchText)'")
        
        print("🔍 [NewMessageViewModel] Proceeding with search...")
        
        // Reset pagination for new search
        hasMoreConversations = true
        lastConversation = nil
        
        // Use server-side search
        searchConversations()
    }
    
    /// Server-side search for conversations
    private func searchConversations() {
        guard let currentUser = Auth.auth().currentUser else { 
            print("❌ [NewMessageViewModel] No current user for search")
            return 
        }
        
        print("🔍 [NewMessageViewModel] Starting server-side search for: '\(searchText)'")
        print("🔍 [NewMessageViewModel] Current user ID: \(currentUser.uid)")
        
        isSearchPending = false
        isLoading = true
        
        conversationService.searchConversationsByUsername(
            for: currentUser.uid,
            searchQuery: searchText,
            limit: pageSize
        ) { [weak self] conversations in
            DispatchQueue.main.async {
                print("🔍 [NewMessageViewModel] Search callback received \(conversations.count) conversations")
                
                self?.filteredConversations = conversations
                self?.isLoading = false
                
                // Set pagination state based on results
                if let self = self {
                    self.hasMoreConversations = conversations.count >= self.pageSize
                    self.lastConversation = conversations.last
                    print("🔍 [NewMessageViewModel] Search pagination: hasMore=\(self.hasMoreConversations), lastConversation=\(self.lastConversation?.id ?? "nil")")
                }
                
                // Fetch additional data for these conversations ONLY
                self?.fetchLatestMessagesForSearchResults(conversations)
                self?.fetchParticipantDetailsForSearchResults(conversations)
                
                print("🔍 [NewMessageViewModel] Search completed with \(conversations.count) results")
            }
        }
    }
    
    /// Fetch next page of search results
    func fetchNextSearchPage() {
        guard !searchText.isEmpty,
              hasMoreConversations,
              !isFetchingMore,
              let currentUser = Auth.auth().currentUser else { 
            print("🔍 [NewMessageViewModel] Cannot fetch next search page: hasMore=\(hasMoreConversations), isFetching=\(isFetchingMore)")
            return 
        }
        
        isFetchingMore = true
        print("🔍 [NewMessageViewModel] Fetching next search page for: '\(searchText)'")
        
        conversationService.searchConversationsByUsername(
            for: currentUser.uid,
            searchQuery: searchText,
            lastConversation: lastConversation,
            limit: pageSize
        ) { [weak self] conversations in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("🔍 [NewMessageViewModel] Next search page received \(conversations.count) conversations")
                
                if conversations.isEmpty {
                    self.hasMoreConversations = false
                    print("🔍 [NewMessageViewModel] No more search results, setting hasMoreConversations = false")
                } else {
                    self.filteredConversations.append(contentsOf: conversations)
                    self.lastConversation = conversations.last
                    self.hasMoreConversations = conversations.count >= self.pageSize
                    
                    print("🔍 [NewMessageViewModel] Added \(conversations.count) conversations, hasMore=\(self.hasMoreConversations)")
                    
                    // Fetch additional data for new conversations
                    for conversation in conversations {
                        self.fetchLatestMessagesForConversation(conversation)
                        self.fetchParticipantDetailsForConversation(conversation)
                    }
                }
                
                self.isFetchingMore = false
                print("🔍 [NewMessageViewModel] Next search page completed, total conversations: \(self.filteredConversations.count)")
            }
        }
    }
    
    /// Debounced search - waits for user to stop typing
    func performDebouncedSearch() {
        print("🔍 [NewMessageViewModel] performDebouncedSearch called with text: '\(searchText)'")
        
        // Cancel any existing timer
        searchTimer?.invalidate()
        
        // Don't search if text is empty
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 [NewMessageViewModel] Search text is empty, not searching")
            isSearchPending = false
            // If search is cleared, show all conversations and reset pagination state
            if !allConversations.isEmpty {
                filteredConversations = allConversations
                // Reset pagination state to prevent infinite pagination after search
                hasMoreConversations = false
                lastConversation = nil
                print("🔍 [NewMessageViewModel] Showing all conversations: \(allConversations.count), reset pagination state")
            }
            return
        }
        
        // Set search as pending
        isSearchPending = true
        print("🔍 [NewMessageViewModel] Starting debounced search for: '\(searchText)' (waiting \(searchDelay)s)")
        
        // Create new timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: searchDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("🔍 [NewMessageViewModel] Timer fired, executing search for: '\(self.searchText)'")
                self.isSearchPending = false
                self.performSearch()
            }
        }
    }
    
    // MARK: - Filter Conversations
    
    func filterConversations(searchText: String) {
        if searchText.isEmpty {
            filteredConversations = allConversations
        } else {
            let lowercasedQuery = searchText.lowercased()
            
            filteredConversations = allConversations.filter { conversation in
                // Filter by participant usernames and fullnames
                return conversation.participants.contains { participantId in
                    if let user = participantUsers[participantId] {
                        return user.username.lowercased().contains(lowercasedQuery) ||
                               (user.fullname?.lowercased().contains(lowercasedQuery) ?? false)
                    }
                    return false
                }
            }
        }
    }
    
    // MARK: - Fetch Latest Messages
    
    private func fetchLatestMessagesForAllConversations() {
        let group = DispatchGroup()
        
        for conversation in allConversations {
            group.enter()
            guard let conversationId = conversation.id else {
                group.leave()
                continue
            }
            
            conversationService.fetchMessages(conversationId: conversationId, limit: 1) { [weak self] messages in
                DispatchQueue.main.async {
                    self?.latestMessages[conversationId] = messages.first
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("✅ All latest messages fetched for \(self.allConversations.count) conversations")
        }
    }
    
    /// Fetch latest messages for specific conversations only
    private func fetchLatestMessagesForConversations(_ conversations: [Conversation]) {
        let group = DispatchGroup()
        
        for conversation in conversations {
            group.enter()
            guard let conversationId = conversation.id else {
                group.leave()
                continue
            }
            
            // Only fetch if we don't already have the latest message
            if latestMessages[conversationId] == nil {
                conversationService.fetchMessages(conversationId: conversationId, limit: 1) { [weak self] messages in
                    DispatchQueue.main.async {
                        self?.latestMessages[conversationId] = messages.first
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Latest messages fetched for \(conversations.count) conversations")
        }
    }
    
    /// Fetch participant details for specific conversations only
    private func fetchParticipantDetailsForConversations(_ conversations: [Conversation]) {
        let group = DispatchGroup()
        
        for conversation in conversations {
            for participantId in conversation.participants {
                if participantUsers[participantId] == nil {
                    group.enter()
                    conversationService.fetchUserDetails(userId: participantId) { [weak self] user in
                        DispatchQueue.main.async {
                            if let user = user {
                                self?.participantUsers[participantId] = user
                            }
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Participant details fetched for \(conversations.count) conversations")
        }
    }
    
    /// Fetch pod creators for specific conversations only
    private func fetchPodCreatorsForConversations(_ conversations: [Conversation]) {
        let group = DispatchGroup()
        
        for conversation in conversations {
            if let latestMessage = latestMessages[conversation.id ?? ""],
               latestMessage.isPod,
               let podId = latestMessage.podId {
                
                if podCreatorUsernames[podId] == nil {
                    group.enter()
                    self.fetchPodCreator(podId: podId)
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Pod creators fetched for \(conversations.count) conversations")
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
    }
    
    // MARK: - Fetch Participant Details
    
    private func fetchParticipantDetails() {
        let group = DispatchGroup()
        
        for conversation in allConversations {
            for participantId in conversation.participants {
                if participantUsers[participantId] == nil {
                    group.enter()
                    conversationService.fetchUserDetails(userId: participantId) { [weak self] user in
                        DispatchQueue.main.async {
                            if let user = user {
                                self?.participantUsers[participantId] = user
                            }
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ All participant details fetched and cached")
        }
    }
    
    /// Fetch participant details for a single conversation
    private func fetchParticipantDetailsForConversation(_ conversation: Conversation) {
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
    
    // MARK: - Fetch Pod Creators
    
    private func fetchPodCreators() {
        for conversation in allConversations {
            if let message = latestMessages[conversation.id ?? ""], message.isPod, let podId = message.podId, !podId.isEmpty {
                fetchPodCreator(podId: podId)
            }
        }
    }
    
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
    
    // MARK: - Get Other Participant User
    
    func getOtherParticipantUser(for conversation: Conversation) -> User? {
        guard let otherParticipantId = getOtherParticipant(for: conversation) else { 
            return nil 
        }
        return participantUsers[otherParticipantId]
    }
    
    private func getOtherParticipant(for conversation: Conversation) -> String? {
        guard let currentUid = Auth.auth().currentUser?.uid else { return nil }
        return conversation.participants.first { $0 != currentUid }
    }
    
    // MARK: - Check Deletion Status
    
    func isConversationDeleted(for conversation: Conversation) -> Bool {
        guard let conversationId = conversation.id else { return false }
        return deletedConversations.contains(conversationId)
    }
    
    // MARK: - User Selection Methods (disabled)
    
    func fetchAvailableUsers() {
        // Disabled - no longer fetch users
    }
    
    func filterUsers(searchText: String) {
        // Disabled - no longer filter users
    }
    
    func toggleUserSelection() {
        // Disabled - always stay in conversations mode
        isShowingUserSelection = false
    }
    
    // MARK: - Search Result Data Fetching
    
    /// Fetch latest messages for search result conversations only
    private func fetchLatestMessagesForSearchResults(_ conversations: [Conversation]) {
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
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Latest messages fetched for \(conversations.count) search result conversations")
        }
    }
    
    /// Fetch participant details for search result conversations only
    private func fetchParticipantDetailsForSearchResults(_ conversations: [Conversation]) {
        let group = DispatchGroup()
        
        for conversation in conversations {
            for participantId in conversation.participants {
                if participantUsers[participantId] == nil {
                    group.enter()
                    conversationService.fetchUserDetails(userId: participantId) { [weak self] user in
                        DispatchQueue.main.async {
                            if let user = user {
                                self?.participantUsers[participantId] = user
                            }
                        }
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            print("✅ Participant details fetched for search result conversations")
        }
    }
}


