//
//  MessageViewModel.swift
//  CryptChat
//
//  Created by Connor Adams on 8/9/22.
//

import Foundation
import Firebase
import FirebaseFirestore
//import FirebaseFirestoreSwift
import SwiftUI
import Combine

class MessageViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var messages = [Message]()
    @Published var lastMessageId = ""
    @Published var latestMessage: Message?
    @Published var hasMoreMessages = true
    @Published var podCache: [String: Pod] = [:]
    @Published var isLoading = false
    @Published var isPaginating = false
    @Published var conversationId: String?
    
    private var listener: ListenerRegistration?
    private var lastDocument: DocumentSnapshot?
    private var isFirstLoad = true
    private var isListenerSetUp = false
    private var cachedPods: [String: Pod] = [:]
    private var cachedUsers: [String: User] = [:]
    
    // Computed property for debugging
    var isPaginatingState: Bool {
        return isPaginating
    }
    
    var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Dependencies
    
    let conversationService = ConversationService()
    let userService = UserService()
    
    // MARK: - User Property
    let user: User
    
    // MARK: - Initialization
    init(user: User, conversationId: String? = nil) {
        print("🔍 MessageViewModel init: user: \(user.username), conversationId: \(conversationId ?? "nil")")
        self.user = user
        self.conversationId = conversationId
        // Don't automatically set up listener - only set it up when actually viewing the conversation
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Cache Management
    
    func cachePod(_ pod: Pod, for podId: String) {
        podCache[podId] = pod
        if let user = pod.user {
            cachedUsers[pod.userId] = user
        }
    }
    
    func getCachedPod(for podId: String) -> Pod? {
        return cachedPods[podId]
    }
    
    func getCachedUser(for userId: String) -> User? {
        return cachedUsers[userId]
    }
    
    func pod(for message: Message) -> Pod? {
        guard let podId = message.podId else { return nil }
        return podCache[podId]
    }
    
    // MARK: - Setup Listener
    
    private func setupListener() {
        guard let conversationId = conversationId else { return }
        
        print("🔍 Setting up listener for conversation: \(conversationId)")
        
        listener = conversationService.setupMessageListener(conversationId: conversationId) { [weak self] (messages: [Message]) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if self.isFirstLoad {
                    self.messages = messages
                    self.isFirstLoad = false
                    self.isLoading = false
                    
                    // Mark the last message as read when conversation is first opened
                    self.markLastMessageAsRead(conversationId: conversationId)
                    print("📖 Marked last message as read when conversation opened")
                } else {
                    // For subsequent updates, just update the messages
                    self.messages = messages
                }
                
                // Pre-fetch pods for new messages
                self.preloadPodsForMessages(messages)
                
                self.objectWillChange.send()
            }
        }
        
        isListenerSetUp = true
    }
    
    // MARK: - Reset Pagination State
    
    func resetPaginationState() {
        isPaginating = false
        hasMoreMessages = true
        lastDocument = nil
    }
    
    // MARK: - Message Read Status
    
    func markLastMessageAsRead(conversationId: String) {
        conversationService.markLastMessageAsRead(conversationId: conversationId) { [weak self] success in
            if success {
                print("MessageViewModel: Successfully marked last message as read")
                
                // Also update the frontend cache immediately
                DispatchQueue.main.async {
                    // Post notification to update conversation list cache
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UpdateConversationReadStatus"),
                        object: conversationId
                    )
                }
            } else {
                print("MessageViewModel: Failed to mark last message as read")
            }
        }
    }
    
    // MARK: - Reset All State
    
    func resetAllState() {
        // Remove existing listener
        listener?.remove()
        listener = nil
        isListenerSetUp = false
        
        // Reset conversation state
        conversationId = nil
        isFirstLoad = true
        
        // Clear messages and loading state
        messages = []
        isLoading = false
        isPaginating = false
        
        // Reset pagination state
        hasMoreMessages = true
        lastDocument = nil
        
        // Clear caches
        podCache = [:]
        cachedPods = [:]
        cachedUsers = [:]
        
        // Clear latest message
        latestMessage = nil
        lastMessageId = ""
    }
    
    func resetStatePreservingConversation() {
        // Remove existing listener
        listener?.remove()
        listener = nil
        isListenerSetUp = false
        
        // Preserve conversationId
        // conversationId stays the same
        
        // Reset other state
        isFirstLoad = true
        messages = []
        isLoading = false
        isPaginating = false
        hasMoreMessages = true
        lastDocument = nil
        
        // Clear caches
        podCache = [:]
        cachedPods = [:]
        cachedUsers = [:]
        
        // Clear latest message
        latestMessage = nil
        lastMessageId = ""
    }
    
    // MARK: - Set Paginating State
    
    func setPaginatingState(_ paginating: Bool) {
        isPaginating = paginating
    }
    
    // MARK: - Preload Pods
    
    private func preloadPodsForMessages(_ messages: [Message]) {
        for message in messages {
            if message.isPod, let podId = message.podId {
                if podId.isEmpty {
                    continue // Skip empty pod IDs
                } else if podCache[podId] != nil {
                    continue // Skip already cached pods
                } else {
                    // Only fetch if not already in progress
                    conversationService.fetchPod(withPodId: podId) { [weak self] pod in
                        if let pod = pod {
                            // Load user data for the pod
                            self?.loadUserDataForPod(pod) { podWithUser in
                                self?.cachePod(podWithUser, for: podId)
                                DispatchQueue.main.async {
                                    self?.objectWillChange.send()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadUserDataForPod(_ pod: Pod, completion: @escaping (Pod) -> Void) {
        // Check if user is already cached
        if let cachedUser = cachedUsers[pod.userId] {
            var podWithUser = pod
            podWithUser.user = cachedUser
            completion(podWithUser)
            return
        }
        
        // Fetch user data
        userService.fetchUser(withUid: pod.userId) { [weak self] result in
            var podWithUser = pod
            
            switch result {
            case .success(let user):
                podWithUser.user = user
                self?.cachedUsers[pod.userId] = user
            case .failure(let error):
                print("Error fetching user for pod: \(error.localizedDescription)")
                // podWithUser.user remains nil, will show fallback in UI
            }
            
            completion(podWithUser)
        }
    }
    
    // MARK: - Fetch Latest Message
    
    func fetchLastestMessage(user: User) {
        // This will be handled by the conversation service when we have conversationId
        guard let conversationId = conversationId else { return }
        
        conversationService.fetchMessages(conversationId: conversationId, limit: 1) { [weak self] messages in
            DispatchQueue.main.async {
                self?.latestMessage = messages.first ?? Message(text: "...", senderId: "123", timestamp: Date(), isPod: false)
                self?.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Fetch Messages
    
    func fetchMostRecentMessages(user: User) {
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        guard let conversationId = conversationId else {
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        conversationService.fetchMessages(conversationId: conversationId, limit: 15) { [weak self] messages in
            guard let self = self else { return }
            
            // Pre-fetch pods for new messages
            self.preloadPodsForMessages(messages)
            
            DispatchQueue.main.async {
                self.messages = messages
                self.hasMoreMessages = messages.count == 15
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Fetch and Update Pods
    
    func fetchAndUpdatePods() {
        let group = DispatchGroup()
        var updatedPods: [String: Pod] = [:]
        
        for index in messages.indices {
            if messages[index].isPod, let podId = messages[index].podId {
                if podId.isEmpty {
                    continue // Skip empty pod IDs
                } else if podCache[podId] != nil {
                    continue // Skip already cached pods
                } else {
                    group.enter()
                    conversationService.fetchPod(withPodId: podId) { [weak self] pod in
                        defer { group.leave() }
                        if let pod = pod {
                            updatedPods[podId] = pod
                            self?.cachePod(pod, for: podId)
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.objectWillChange.send()
        }
    }
    
    // MARK: - Send Message
    
    func sendMessage(user: User, text: String) {
        guard let conversationId = conversationId else { return }
        
        // First restore the conversation if it was deleted
        conversationService.restoreConversationForNewMessage(conversationId: conversationId) { [weak self] restored in
            if restored {
                print("✅ Conversation restored for new message")
            }
            
            // Send the message regardless of restoration status
            self?.conversationService.sendMessage(text: text, conversationId: conversationId) { success in
                if success {
                    print("Message sent successfully")
                } else {
                    print("Failed to send message")
                }
            }
        }
    }
    
    // MARK: - Send Pod Message
    
    func sendPodMessage(user: User, podId: String) {
        guard let conversationId = conversationId else { return }
        
        // First restore the conversation if it was deleted
        conversationService.restoreConversationForNewMessage(conversationId: conversationId) { [weak self] restored in
            if restored {
                print("✅ Conversation restored for pod message")
            }
            
            // Send the pod message regardless of restoration status
            self?.conversationService.sendPodMessage(podId: podId, conversationId: conversationId) { success in
                if success {
                    print("Pod message sent successfully")
                } else {
                    print("Failed to send pod message")
                }
            }
        }
    }
    
    // MARK: - Paginate to Earlier Messages
    
    func paginateToEarlierMessages(user: User) {
        guard let conversationId = conversationId,
              !isPaginating,
              let lastMessage = messages.first else {
            if messages.isEmpty {
                DispatchQueue.main.async {
                    self.hasMoreMessages = false
                }
            }
            return
        }
        
        isPaginating = true
        
        conversationService.fetchMessagesPaginated(conversationId: conversationId, lastMessage: lastMessage, limit: 15) { [weak self] earlierMessages in
            guard let self = self else { return }
            
            defer {
                self.isPaginating = false
            }
            
            if earlierMessages.isEmpty {
                DispatchQueue.main.async {
                    self.hasMoreMessages = false
                }
                return
            }
            
            // Pre-fetch pods for new messages
            self.preloadPodsForMessages(earlierMessages)
            
            DispatchQueue.main.async {
                self.messages.insert(contentsOf: earlierMessages, at: 0)
                self.hasMoreMessages = earlierMessages.count == 15
            }
        }
    }
    
    // MARK: - Initialize Conversation
    
    func initializeConversation() {
        print("🔍 === INITIALIZE CONVERSATION START ===")
        print("🔍 User ID: \(user.id ?? "nil")")
        print("🔍 Current conversationId: \(conversationId ?? "nil")")
        
        // If conversationId is already set, just set up the listener
        if let existingConversationId = conversationId {
            print("🔍 Conversation ID already set: \(existingConversationId)")
            isLoading = true
            setupListener()
            return
        }
        
        guard let userId = user.id else { 
            print("❌ No user ID available")
            print("🔍 === INITIALIZE CONVERSATION END ===")
            return 
        }
        
        // Set loading state
        isLoading = true
        print("🔍 Set isLoading to true")
        
        // Only find existing conversation, don't create new one
        print("🔍 Calling findExistingConversation...")
        conversationService.findExistingConversation(with: userId) { [weak self] conversationId in
            print("🔍 findExistingConversation callback received: \(conversationId ?? "nil")")
            
            DispatchQueue.main.async {
                self?.conversationId = conversationId
                print("🔍 Set conversationId to: \(conversationId ?? "nil")")
                
                if let conversationId = conversationId {
                    print("🔍 Setting up listener for conversation: \(conversationId)")
                    self?.setupListener()
                } else {
                    print("🔍 No conversation found, setting isLoading to false")
                    self?.isLoading = false
                }
                
                print("🔍 === INITIALIZE CONVERSATION END ===")
            }
        }
    }
}
