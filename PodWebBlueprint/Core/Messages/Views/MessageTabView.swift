//  MessageTabView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/4/23.
//

import SwiftUI

struct MessageTabView: View {
    // MARK: - Properties
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSearching = false
    @State private var showNotificationsFromDeepLink = false
    
    var user: User
    
    // MARK: - ViewModels with Caching
    @StateObject private var conversationViewModel: ConversationViewModel
    @EnvironmentObject var userViewModel: UserViewModel
    
    // MARK: - Initialization
    init(user: User) {
        self.user = user
        // Initialize ConversationViewModel with real user data
        self._conversationViewModel = StateObject(wrappedValue: ConversationViewModel(user: user))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                NavigationLink(isActive: $showNotificationsFromDeepLink) {
                    NotificationView()
                        .navigationBarBackButtonHidden(true)
                } label: {
                    NotificationBadgeView()
                }
                .padding(.horizontal)
            }

            HStack {
                SearchBar(text: $conversationViewModel.convoSearchText)
                    .onChange(of: conversationViewModel.convoSearchText) { newValue in
                        isSearching = !newValue.isEmpty
                        // Trigger debounced search when text changes
                        conversationViewModel.performDebouncedSearch()
                    }
                
                // Show search pending indicator
                if conversationViewModel.isSearchPending && !conversationViewModel.convoSearchText.isEmpty {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                NavigationLink {
                    NewMessageView(user: user)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            
            if isSearching {
                ScrollView {
                    VStack {
                        if conversationViewModel.searchableConversations.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("No conversations found")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Try searching for a different name")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else {
                            ForEach(conversationViewModel.searchableConversations) { conversation in
                                // Compute other user once per conversation to avoid redundant calls
                                let otherUser = conversationViewModel.getOtherParticipantUser(for: conversation)
                                
                                NavigationLink {
                                    if let otherUser = otherUser {
                                        ConversationView(
                                            user: otherUser,
                                            onConversationDeleted: {
                                                // Refresh the conversation list when a conversation is deleted
                                                conversationViewModel.fetchConversations()
                                            },
                                            onMarkedAsRead: { conversationId in
                                                conversationViewModel.markConversationAsRead(conversationId: conversationId)
                                            }
                                        )
                                        .id("\(otherUser.id ?? "")-\(Date().timeIntervalSince1970)")
                                    }
                                } label: {
                                    ConversationsRowView(
                                        conversation: conversation,
                                        latestMessage: conversationViewModel.latestMessages[conversation.id ?? ""],
                                        podCreatorUsername: getPodCreatorUsername(for: conversation),
                                        otherUser: otherUser,
                                        onConversationDeleted: {
                                            // Refresh the conversation list when a conversation is deleted
                                            conversationViewModel.fetchConversations()
                                        }
                                    )
                                    .onAppear {
                                        // Trigger pagination when reaching the last item
                                        if conversation.id == conversationViewModel.searchableConversations.last?.id &&
                                           conversationViewModel.hasMoreConversations &&
                                           !conversationViewModel.isFetchingMore {
                                            
                                            if conversationViewModel.convoSearchText.isEmpty {
                                                // Regular pagination
                                                conversationViewModel.fetchNextPage()
                                            } else {
                                                // Search pagination
                                                conversationViewModel.fetchNextSearchPage()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Loading indicator for pagination
                            if conversationViewModel.isFetchingMore {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more conversations...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                            
                            // No more conversations message
                            if !conversationViewModel.hasMoreConversations && !conversationViewModel.searchableConversations.isEmpty {
                                Text("No more conversations to load")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                }
                .refreshable {
                    conversationViewModel.refreshConversations()
                }
                .onAppear {
                    conversationViewModel.checkAndRefreshIfNeeded()
                }
            } else {
                ScrollView {
                    VStack {
                        if conversationViewModel.isLoading {
                            VStack(spacing: 20) {
                                Spacer()
                                
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                
                                Text("Loading conversations...")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else if conversationViewModel.conversations.isEmpty {
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "message")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("No conversations yet")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Once you have friends, your conversations will appear here")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                NavigationLink {
                                    SearchView(user: user)
                                } label: {
                                    Text("Discover People")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color("accentColor"))
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else {
                            ForEach(conversationViewModel.conversations) { conversation in
                                // Compute other user once per conversation to avoid redundant calls
                                let otherUser = conversationViewModel.getOtherParticipantUser(for: conversation)
                                
                                NavigationLink {
                                    if let otherUser = otherUser {
                                        ConversationView(
                                            user: otherUser,
                                            onConversationDeleted: {
                                                // Refresh the conversation list when a conversation is deleted
                                                conversationViewModel.fetchConversations()
                                            },
                                            onMarkedAsRead: { conversationId in
                                                conversationViewModel.markConversationAsRead(conversationId: conversationId)
                                            }
                                        )
                                        .id("\(otherUser.id ?? "")-\(Date().timeIntervalSince1970)")
                                    }
                                } label: {
                                    ConversationsRowView(
                                        conversation: conversation,
                                        latestMessage: conversationViewModel.latestMessages[conversation.id ?? ""],
                                        podCreatorUsername: getPodCreatorUsername(for: conversation),
                                        otherUser: otherUser,
                                        onConversationDeleted: {
                                            // Refresh the conversation list when a conversation is deleted
                                            conversationViewModel.fetchConversations()
                                        }
                                    )
                                    .onAppear {
                                        // Trigger pagination when reaching the last item
                                        if conversation.id == conversationViewModel.conversations.last?.id &&
                                           conversationViewModel.hasMoreConversations &&
                                           !conversationViewModel.isFetchingMore {
                                            conversationViewModel.fetchNextPage()
                                        }
                                    }
                                }
                            }
                            
                            // Loading indicator for pagination
                            if conversationViewModel.isFetchingMore {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more conversations...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                            
                            // No more conversations message
                            if !conversationViewModel.hasMoreConversations && !conversationViewModel.conversations.isEmpty {
                                Text("No more conversations to load")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                }
                .refreshable {
                    conversationViewModel.fetchConversations()
                }
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Check if conversations need refreshing when tab becomes active
            conversationViewModel.checkAndRefreshIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenNotificationsFromDeepLink"))) { _ in
            // Handle deep link to notifications
            showNotificationsFromDeepLink = true
        }

    }
    
    // MARK: - Helper Methods
    
    private func getPodCreatorUsername(for conversation: Conversation) -> String? {
        guard let message = conversationViewModel.latestMessages[conversation.id ?? ""],
              message.isPod,
              let podId = message.podId else {
            return nil
        }
        return conversationViewModel.podCreatorUsernames[podId]
    }
}
