//
//  NewMessageView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/23.
//

import SwiftUI
import Kingfisher
import FirebaseFirestore

struct NewMessageView: View {
    // MARK: - Properties
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: NewMessageViewModel
    // Remove local searchText since we'll use the ViewModel's
    @State private var navigateToConversation: (User, String)? = nil
    
    
    var user: User
    
    // MARK: - Initialization
    
    init(user: User) {
        self.user = user
        self._viewModel = StateObject(wrappedValue: NewMessageViewModel(user: user))
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            // MARK: - Header with cool back button
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("accentColor"), lineWidth: 2)
                            )
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("New Message")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            
            // MARK: - Search Bar
            SearchBar(text: $viewModel.searchText)
                .padding(.horizontal)
                .onChange(of: viewModel.searchText) { newValue in
                    // Use debounced search for conversations
                    viewModel.performDebouncedSearch()
                }
            
            // MARK: - Search Pending Indicator
            if viewModel.isSearchPending && !viewModel.searchText.isEmpty {
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
            
            // MARK: - Content List
            // Conversations List
            if viewModel.filteredConversations.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "message")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text(viewModel.searchText.isEmpty ? "No conversations found" : "No conversations match your search")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color("textColor"))
                    
                    if viewModel.searchText.isEmpty {
                        Text("Start a conversation with someone new")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Try searching for a different name")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.filteredConversations) { conversation in
                            let otherUser = viewModel.getOtherParticipantUser(for: conversation)
                            
                            if let otherUser = otherUser {
                                NavigationLink {
                                    ConversationView(
                                        user: otherUser,
                                        conversationId: conversation.id,
                                        onConversationDeleted: {
                                            // Refresh the conversation list when a conversation is deleted
                                            viewModel.refreshConversations()
                                        },
                                        onMarkedAsRead: { conversationId in
                                            // Handle marking as read if needed
                                            print("Marked conversation as read: \(conversationId)")
                                        }
                                    )
                                    .id("\(otherUser.id ?? "")-\(Date().timeIntervalSince1970)")
                                } label: {
                                    ConversationsRowView(
                                        conversation: conversation,
                                        latestMessage: viewModel.latestMessages[conversation.id ?? ""],
                                        podCreatorUsername: getPodCreatorUsername(for: conversation),
                                        otherUser: otherUser,
                                        showLastMessage: false,
                                        showUnreadIndicator: false
                                    )
                                    .onAppear {
                                        print("🔍 NewMessageView: Row for conversation ID: \(conversation.id ?? "nil")")
                                        
                                        // Trigger pagination when reaching the last item
                                        if conversation.id == viewModel.filteredConversations.last?.id &&
                                            viewModel.hasMoreConversations &&
                                            !viewModel.isFetchingMore {
                                            
                                            if viewModel.searchText.isEmpty {
                                                // Regular pagination
                                                viewModel.fetchNextPage()
                                            } else {
                                                // Search pagination
                                                viewModel.fetchNextSearchPage()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Loading indicator for pagination
                            if viewModel.isFetchingMore {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more conversations...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .refreshable {
                        if viewModel.searchText.isEmpty {
                            viewModel.refreshConversations()
                        } else {
                            viewModel.performSearch()
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .background(Color(.systemBackground))
        .onAppear {
            viewModel.fetchAllConversations()
        }
        .background(
            NavigationLink(
                destination: Group {
                    if let (user, conversationId) = navigateToConversation {
                        ConversationView(
                            user: user,
                            conversationId: conversationId,
                            onConversationDeleted: {
                                // Refresh the conversation list when a conversation is deleted
                                viewModel.refreshConversations()
                            },
                            onMarkedAsRead: { conversationId in
                                // Handle marking as read if needed
                                print("Marked conversation as read: \(conversationId)")
                            }
                        )
                    }
                },
                isActive: Binding(
                    get: { navigateToConversation != nil },
                    set: { if !$0 { navigateToConversation = nil } }
                )
            ) {
                EmptyView()
            }
        )
    }
        
        
        // MARK: - Helper Methods
        
        private func getPodCreatorUsername(for conversation: Conversation) -> String? {
            guard let message = viewModel.latestMessages[conversation.id ?? ""],
                  message.isPod,
                  let podId = message.podId else {
                return nil
            }
            return viewModel.podCreatorUsernames[podId]
        }
}
    


struct NewMessageView_Previews: PreviewProvider {
    static var previews: some View {
        NewMessageView(user: PreviewClass().previewUser)
    }
}
