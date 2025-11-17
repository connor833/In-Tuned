//
//  SendPodView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/22/23.
//

import SwiftUI

struct SendPodView: View {
    @StateObject var sendPodViewModel = SendPodViewModel()
    @StateObject var repostViewModel = RepostViewModel()
    
    @State var message = ""
    @State var selectedConversations = [String]() // conversationIds
    @State var showingRepostInput = false
    
    @Environment(\.presentationMode) var mode
    @EnvironmentObject var authViewModel: AuthViewModel

    let pod: Pod
    
    init(pod: Pod) {
        self.pod = pod
    }
    
    var body: some View {
        VStack {
            // Search Bar
            HStack {
                SearchBar(text: $sendPodViewModel.conversationSearchText)
                    .onChange(of: sendPodViewModel.conversationSearchText) { newValue in
                        // Trigger debounced search when text changes
                        sendPodViewModel.performDebouncedSearch()
                    }
                
                // Show search pending indicator
                if sendPodViewModel.isSearchPending && !sendPodViewModel.conversationSearchText.isEmpty {
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
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // Modern Repost/Unrepost button
            Button {
                if repostViewModel.hasReposted {
                    // Unrepost
                    repostViewModel.deleteRepost(podId: pod.id ?? "") {
                        // Button state will update automatically
                    }
                } else {
                    // Repost
                    showingRepostInput.toggle()
                }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    // Icon
                    Image(systemName: repostViewModel.hasReposted ? "arrow.2.squarepath.fill" : "arrow.2.squarepath")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(repostViewModel.hasReposted ? .red : Color("accentColor"))
                    
                    // Text content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(repostViewModel.hasReposted ? "Unrepost" : "Repost")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(repostViewModel.hasReposted ? .red : Color("accentColor"))
                        
                        Text(repostViewModel.hasReposted ? "Remove from your profile" : "Share to your profile")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Arrow indicator
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(repostViewModel.hasReposted ? Color.red.opacity(0.1) : Color("accentColor").opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    repostViewModel.hasReposted ? Color.red.opacity(0.3) : Color("accentColor").opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: repostViewModel.hasReposted ? Color.red.opacity(0.08) : Color("accentColor").opacity(0.08),
                            radius: 8,
                            x: 0,
                            y: 3
                        )
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .buttonStyle(PlainButtonStyle())
            
            if !selectedConversations.isEmpty {
                HStack {
                    CustomTextField(placeholder: Text("New Message"), text: $message)
                    
                    Button {
                        selectedConversations.forEach { conversationId in
                            sendPodViewModel.sendPodMessage(conversationId: conversationId, podId: pod.id ?? "")
                            if message != "" {
                                sendPodViewModel.sendTextMessage(conversationId: conversationId, text: message)
                            }
                        }
                        message = ""
                        selectedConversations = []
                        mode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(Color("accentColor"))
                            .padding(10)
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: Color.black.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            ScrollView {
                LazyVStack {
                    if sendPodViewModel.isLoading {
                        VStack {
                            ProgressView()
                                .padding()
                            Text("Loading conversations...")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        .padding(.top, 50)
                    } else if sendPodViewModel.searchableConversations.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "message.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No conversations yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Start conversations with friends to share pods!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    } else {
                        // Selected conversations section
                        if !selectedConversations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Selected (\(selectedConversations.count))")
                                        .font(.headline)
                                        .foregroundColor(Color("accentColor"))
                                        .padding(.horizontal)
                                    Spacer()
                                }
                                
                                ForEach(sendPodViewModel.searchableConversations.filter { selectedConversations.contains($0.id ?? "") }) { conversation in
                                    Button {
                                        withAnimation {
                                            toggleConversationSelection(conversation)
                                        }
                                    } label: {
                                        ConversationRowView(
                                            conversation: conversation,
                                            otherUser: sendPodViewModel.getOtherParticipantUser(for: conversation),
                                            isSelected: true
                                        )
                                    }
                                }
                                
                                Divider()
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // Unselected conversations section
                        let unselectedConversations = sendPodViewModel.searchableConversations.filter { !selectedConversations.contains($0.id ?? "") }
                        
                        if !unselectedConversations.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                if !selectedConversations.isEmpty {
                                    HStack {
                                        Text("All Conversations")
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                            .padding(.horizontal)
                                        Spacer()
                                    }
                                }
                                
                                ForEach(unselectedConversations) { conversation in
                                    Button {
                                        withAnimation {
                                            toggleConversationSelection(conversation)
                                        }
                                    } label: {
                                        ConversationRowView(
                                            conversation: conversation,
                                            otherUser: sendPodViewModel.getOtherParticipantUser(for: conversation),
                                            isSelected: false
                                        )
                                        .onAppear {
                                            // Trigger pagination when reaching the last item
                                            if conversation.id == unselectedConversations.last?.id &&
                                               sendPodViewModel.hasMoreConversations &&
                                               !sendPodViewModel.isFetchingMore {
                                                
                                                if sendPodViewModel.conversationSearchText.isEmpty {
                                                    // Regular pagination
                                                    sendPodViewModel.fetchNextPage()
                                                } else {
                                                    // Search pagination
                                                    sendPodViewModel.fetchNextSearchPage()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Loading indicator for pagination
                        if sendPodViewModel.isFetchingMore {
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
                        if !sendPodViewModel.hasMoreConversations && !sendPodViewModel.searchableConversations.isEmpty {
                            Text("No more conversations to load")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
                .refreshable {
                    sendPodViewModel.fetchConversations()
                }
            }
            .padding(.vertical)
        }
        .padding(.vertical)
        .onAppear {
            if sendPodViewModel.conversations.isEmpty {
                sendPodViewModel.fetchConversations()
            }
            // Check if user has already reposted this pod
            if let podId = pod.id {
                repostViewModel.checkIfUserReposted(podId: podId)
            }
        }
        .sheet(isPresented: $showingRepostInput) {
            RepostInputView(pod: pod, repostViewModel: repostViewModel)
        }
    }
    
    private func toggleConversationSelection(_ conversation: Conversation) {
        guard let conversationId = conversation.id else { return }
        
        if selectedConversations.contains(conversationId) {
            selectedConversations.removeAll { $0 == conversationId }
        } else {
            selectedConversations.append(conversationId)
        }
    }
}

// MARK: - Conversation Row View for Send Pod

struct ConversationRowView: View {
    let conversation: Conversation
    let otherUser: User?
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Modern Profile Image
            if let otherUser = otherUser, !otherUser.profileImageUrl.isEmpty {
                AsyncImage(url: URL(string: otherUser.profileImageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
            }
            
            // Content with modern layout
            VStack(alignment: .leading, spacing: 6) {
                // User name and verification
                HStack(spacing: 6) {
                    Text(otherUser?.fullname ?? "User")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isSelected ? Color("accentColor") : .primary)
                    
                    if let otherUser = otherUser, otherUser.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(.systemBlue))
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color("accentColor"))
                    }
                }
                
                // Last message or status
                if let lastMessage = conversation.lastMessage {
                    if lastMessage.isPod {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color("accentColor"))
                            
                            Text("Pod shared")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text(lastMessage.text)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                } else {
                    Text("No messages yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color("accentColor").opacity(0.1) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color("accentColor").opacity(0.3) : Color.clear,
                            lineWidth: isSelected ? 1 : 0
                        )
                )
                .shadow(
                    color: isSelected ? Color.black.opacity(0.08) : Color.black.opacity(0.04),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 3 : 2
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct SendPodView_Previews: PreviewProvider {
    static var previews: some View {
        SendPodView(pod: PreviewClass().previewPod)
    }
}

