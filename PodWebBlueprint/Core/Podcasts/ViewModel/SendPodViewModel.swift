//
//  ConversationViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 8/10/23.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import SwiftUI


class SendPodViewModel: ObservableObject {
    @Published var conversations = [Conversation]()
    @Published var conversationSearchText = ""
    @Published var isLoading = false
    @Published var participantUsers: [String: User] = [:] // userId -> User object
    
    // MARK: - Pagination Properties
    
    @Published var hasMoreConversations = true
    @Published var isFetchingMore = false
    private var lastConversation: Conversation?
    private let pageSize = 10
    
    // MARK: - Search Properties
    
    private var searchTimer: Timer?
    private let searchDelay: TimeInterval = 1.0 // Wait 1 second after user stops typing
    @Published var isSearchPending = false
    
    let conversationService = ConversationService()
    let userService = UserService()
    let currentUid = Auth.auth().currentUser?.uid
    
    init() {
        // Don't fetch conversations in init
    }
    
    deinit {
        searchTimer?.invalidate()
    }
    
    func fetchConversations() {
        guard !isLoading, let currentUid = currentUid else { return }
        isLoading = true
        
        // Reset pagination for new fetch
        conversations = []
        lastConversation = nil
        hasMoreConversations = true
        
        conversationService.fetchConversationsWithSearch(
            for: currentUid,
            searchQuery: conversationSearchText,
            limit: pageSize
        ) { [weak self] conversations in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.conversations = conversations
                self.lastConversation = conversations.last
                self.hasMoreConversations = conversations.count >= self.pageSize
                self.fetchParticipantDetails()
                self.isLoading = false
            }
        }
    }
    
    private func fetchParticipantDetails() {
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
    }
    
    var searchableConversations: [Conversation] {
        let filteredConversations: [Conversation]
        
        if conversationSearchText.isEmpty {
            filteredConversations = conversations
        } else {
            let lowercasedQuery = conversationSearchText.lowercased()
            filteredConversations = conversations.filter { conversation in
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
        
        // Return conversations with selected ones at the top
        return filteredConversations
    }
    
    func getOtherParticipant(for conversation: Conversation) -> String? {
        guard let currentUid = currentUid else { return nil }
        return conversation.participants.first { $0 != currentUid }
    }
    
    func getOtherParticipantUser(for conversation: Conversation) -> User? {
        guard let otherParticipantId = getOtherParticipant(for: conversation) else { return nil }
        return participantUsers[otherParticipantId]
    }
    
    func sendPodMessage(conversationId: String, podId: String) {
        conversationService.sendPodMessage(podId: podId, conversationId: conversationId) { success in
            if success {
                print("Pod message sent successfully to conversation: \(conversationId)")
            } else {
                print("Failed to send pod message to conversation: \(conversationId)")
            }
        }
    }
    
    func sendTextMessage(conversationId: String, text: String) {
        conversationService.sendMessage(text: text, conversationId: conversationId) { success in
            if success {
                print("Text message sent successfully to conversation: \(conversationId)")
            } else {
                print("Failed to send text message to conversation: \(conversationId)")
            }
        }
    }
    
    // MARK: - Pagination Methods
    
    /// Fetch next page of conversations
    func fetchNextPage() {
        guard !isFetchingMore && hasMoreConversations,
              let currentUid = currentUid else { return }
        
        // Don't fetch next page if we're searching
        guard conversationSearchText.isEmpty else {
            print("🔍 [SendPodViewModel] Skipping regular pagination - search is active")
            return
        }
        
        isFetchingMore = true
        print("📱 [SendPodViewModel] Fetching next page of conversations")
        
        conversationService.fetchConversationsWithSearch(
            for: currentUid,
            searchQuery: conversationSearchText,
            lastConversation: lastConversation,
            limit: pageSize
        ) { [weak self] newConversations in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.conversations.append(contentsOf: newConversations)
                self.lastConversation = newConversations.last
                self.hasMoreConversations = newConversations.count >= self.pageSize
                self.isFetchingMore = false
                
                // Fetch participant details for new conversations
                self.fetchParticipantDetails()
                
                print("📱 [SendPodViewModel] Next page loaded: \(newConversations.count) conversations, hasMore: \(self.hasMoreConversations)")
            }
        }
    }
    
    // MARK: - Search Methods
    
    /// Perform new search and reset pagination
    func performSearch() {
        print("🔍 [SendPodViewModel] Performing search: '\(conversationSearchText)'")
        
        // Don't search if we already have results for this query
        if !conversations.isEmpty && !isLoading {
            print("🔍 [SendPodViewModel] Already have results, not searching again")
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
        guard let currentUid = currentUid else { 
            print("❌ [SendPodViewModel] No current user for search")
            return 
        }
        
        print("🔍 [SendPodViewModel] Starting server-side search for: '\(conversationSearchText)'")
        
        isSearchPending = false
        isLoading = true
        
        // Reset pagination for new search
        hasMoreConversations = true
        lastConversation = nil
        
        conversationService.searchConversationsByUsername(
            for: currentUid,
            searchQuery: conversationSearchText,
            limit: pageSize
        ) { [weak self] conversations in
            DispatchQueue.main.async {
                print("🔍 [SendPodViewModel] Search callback received \(conversations.count) conversations")
                
                self?.conversations = conversations
                
                // Set pagination state based on results
                if let self = self {
                    self.hasMoreConversations = conversations.count >= self.pageSize
                    self.lastConversation = conversations.last
                    print("🔍 [SendPodViewModel] Search pagination: hasMore=\(self.hasMoreConversations), lastConversation=\(self.lastConversation?.id ?? "nil")")
                }
                
                self?.fetchParticipantDetails()
                self?.isLoading = false
                
                print("🔍 [SendPodViewModel] Search completed with \(conversations.count) results")
            }
        }
    }
    
    /// Fetch next page of search results
    func fetchNextSearchPage() {
        guard !conversationSearchText.isEmpty,
              hasMoreConversations,
              !isFetchingMore,
              let currentUid = currentUid else { 
            print("🔍 [SendPodViewModel] Cannot fetch next search page: hasMore=\(hasMoreConversations), isFetching=\(isFetchingMore)")
            return 
        }
        
        isFetchingMore = true
        print("🔍 [SendPodViewModel] Fetching next search page for: '\(conversationSearchText)'")
        
        conversationService.searchConversationsByUsername(
            for: currentUid,
            searchQuery: conversationSearchText,
            lastConversation: lastConversation,
            limit: pageSize
        ) { [weak self] conversations in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                print("🔍 [SendPodViewModel] Next search page received \(conversations.count) conversations")
                
                if conversations.isEmpty {
                    self.hasMoreConversations = false
                    print("🔍 [SendPodViewModel] No more search results, setting hasMoreConversations = false")
                } else {
                    self.conversations.append(contentsOf: conversations)
                    self.lastConversation = conversations.last
                    self.hasMoreConversations = conversations.count >= self.pageSize
                    
                    print("🔍 [SendPodViewModel] Added \(conversations.count) conversations, hasMore=\(self.hasMoreConversations)")
                    
                    // Fetch participant details for new conversations
                    self.fetchParticipantDetails()
                }
                
                self.isFetchingMore = false
                print("🔍 [SendPodViewModel] Next search page completed, total conversations: \(self.conversations.count)")
            }
        }
    }
    
    /// Debounced search - waits for user to stop typing
    func performDebouncedSearch() {
        // Cancel any existing timer
        searchTimer?.invalidate()
        
        // Don't search if text is empty
        guard !conversationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔍 [SendPodViewModel] Search text is empty, not searching")
            isSearchPending = false
            // If search is cleared, show all conversations
            if !conversations.isEmpty {
                fetchConversations()
            }
            return
        }
        
        // Set search as pending
        isSearchPending = true
        print("🔍 [SendPodViewModel] Starting debounced search for: '\(conversationSearchText)' (waiting \(searchDelay)s)")
        
        // Create new timer
        searchTimer = Timer.scheduledTimer(withTimeInterval: searchDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                print("🔍 [SendPodViewModel] Timer fired, executing search for: '\(self.conversationSearchText)'")
                self.isSearchPending = false
                self.performSearch()
            }
        }
    }
}

