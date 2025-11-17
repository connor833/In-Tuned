import SwiftUI
import Kingfisher
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct ConversationView: View {
    // MARK: - Properties
    
    @ObservedObject var viewModel: MessageViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var shouldScrollToBottom = true
    @State private var podViewModels: [String: PodViewModel] = [:]
    @State private var hasInitiallyScrolled = false
    @State private var canPaginate = false
    @State private var firstVisibleMessageId: String?
    @State private var lastPaginationTime: Date = Date()
    @State private var paginationBuffer: TimeInterval = 5.0 // 5 second buffer
    @State private var showingDeleteAlert = false
    @State private var showingBlockedAlert = false
    @State private var isDeleting = false
    @State private var hasMarkedAsRead = false
    
    // For previews
    var messages = [Message]()
    @State var message = ""
    @AppStorage("uid") var userID = ""
    @Namespace var bottomID
    
    var user: User
    var onConversationDeleted: (() -> Void)? // Callback to refresh conversation list
    var onMarkedAsRead: ((String) -> Void)? // NEW: notify parent to update frontend cache
    
    // MARK: - Initialization
    
    init(user: User, conversationId: String? = nil, onConversationDeleted: (() -> Void)? = nil, onMarkedAsRead: ((String) -> Void)? = nil) {
        print("🔍 ConversationView init: user: \(user.username), conversationId: \(conversationId ?? "nil")")
        self.viewModel = MessageViewModel(user: user, conversationId: conversationId)
        self.user = user
        self.onConversationDeleted = onConversationDeleted
        self.onMarkedAsRead = onMarkedAsRead
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            VStack {
                // MARK: - Header
                 
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Color("textColor"))
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    NavigationLink {
                        ProfileView(user: user)
                    } label: {
                        HStack(spacing: 8) {
                            KFImage(URL(string: user.profileImageUrl))
                                .resizable()
                                .clipShape(Circle())
                                .scaledToFill()
                                .frame(width: 42, height: 42)
                                .cornerRadius(8)
                                .foregroundColor(Color("accentColor"))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.username)
                                    .foregroundColor(Color("textColor"))
                                    .font(.headline)
                                
                                if user.isVerified {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(Color(.systemBlue))
                                            .font(.system(size: 14))
                                        
                                        Text("Verified")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Options button
                    Menu {
                        Button(role: .destructive) {
                            deleteConversation()
                        } label: {
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Label("Delete Conversation", systemImage: "trash")
                            }
                        }
                        .disabled(isDeleting || viewModel.isLoading)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .foregroundColor(Color("textColor"))
                    .padding(.trailing)
                }
                
                // MARK: - Messages
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            if viewModel.isLoading {
                                VStack(spacing: 20) {
                                    Spacer()
                                    
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .foregroundColor(Color("accentColor"))
                                    
                                    Text("Loading messages...")
                                        .font(.title2)
                                        .fontWeight(.medium)
                                        .foregroundColor(Color("textColor"))
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                            } else if !viewModel.isLoading && viewModel.messages.isEmpty {
                                VStack(spacing: 20) {
                                    Spacer()
                                    
                                    Image(systemName: "message")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    
                                    Text("No messages yet")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color("textColor"))
                                    
                                    Text("Start a conversation with \(user.username)!")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding()
                            } else {
                                // MARK: - Scroll Detection for Pagination
                                
                                if hasInitiallyScrolled {
                                    GeometryReader { geometry in
                                        Color.clear
                                            .frame(height: 1)
                                            .onChange(of: geometry.frame(in: .named("scroll")).minY) { newValue in
                                                let currentScrollOffset = newValue
                                                
                                                // Trigger pagination when user scrolls near the top
                                                if currentScrollOffset > -50 && hasInitiallyScrolled && viewModel.hasMoreMessages && !viewModel.isPaginatingState && canPaginate {
                                                    let timeSinceLastPagination = Date().timeIntervalSince(lastPaginationTime)
                                                    if timeSinceLastPagination >= paginationBuffer {
                                                        // Store the first visible message ID before pagination
                                                        firstVisibleMessageId = viewModel.messages.first?.id
                                                        lastPaginationTime = Date()
                                                        viewModel.paginateToEarlierMessages(user: user)
                                                    }
                                                }
                                            }
                                    }
                                    .frame(height: 1)
                                }
                                
                                // MARK: - Pagination Loading Indicator
                                
                                if viewModel.hasMoreMessages && viewModel.isPaginatingState {
                                    ProgressView()
                                        .padding()
                                }
                                
                                // MARK: - For each for messages
                                
                                ForEach(viewModel.messages, id: \.id) { message in
                                    Group {
                                        if message.isPod {
                                            let podId = message.podId ?? ""
                                            let pod = viewModel.pod(for: message)
                                            
                                            if podId.isEmpty || pod == nil {
                                                PodMessageBubble(
                                                    message: message,
                                                    user: user,
                                                    messageViewModel: viewModel,
                                                    podViewModel: PodViewModel(
                                                        pod: Pod(
                                                            title: "Pod not available",
                                                            timestamp: Timestamp(date: Date()),
                                                            description: "This pod is no longer available.",
                                                            fileUrl: "",
                                                            thumbnailUrl: "",
                                                            userId: "",
                                                            likes: 0
                                                        )
                                                    )
                                                )
                                            } else {
                                                PodMessageBubble(
                                                    message: message,
                                                    user: user,
                                                    messageViewModel: viewModel,
                                                    podViewModel: PodViewModel(pod: pod!)
                                                )
                                            }
                                        } else {
                                            MessageBubble(
                                                message: message,
                                                user: user,
                                                messageViewModel: viewModel
                                            )
                                        }
                                    }
                                    .id(message.id) // Use Firebase document ID for consistent tracking
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: viewModel.messages.count)
                                    .onAppear {
                                        // Mark message as read when it comes into view (if conversation is already opened)
                                        markMessageAsReadIfNeeded(message: message)
                                    }
                                }
                                
                                // Bottom anchor
                                HStack {
                                    Spacer()
                                }
                                .id(bottomID) // Add an ID to the bottom to scroll to
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .padding(.top, 10)
                    }
                    .coordinateSpace(name: "scroll")
                    .onAppear {
                        // On first load, wait for messages to load before scrolling
                        if viewModel.messages.isEmpty {
                            // Wait for messages to load, then scroll
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(bottomID, anchor: .bottom)
                                }
                                
                                // Set flags after the scroll animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    hasInitiallyScrolled = true
                                    canPaginate = true
                                }
                            }
                        } else {
                            // Messages already loaded, scroll immediately
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(bottomID, anchor: .bottom)
                                }
                                
                                // Set flags after the scroll animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    hasInitiallyScrolled = true
                                    canPaginate = true
                                }
                            }
                        }
                    }
                }
            }
            // MARK: - Message Input
            
            MessageField(user: user, viewModel: viewModel)
                .padding(.horizontal)
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            print("🔍 === CONVERSATION VIEW APPEARED ===")
            print("🔍 Current user: \(Auth.auth().currentUser?.uid ?? "nil")")
            print("🔍 ViewModel conversationId: \(viewModel.conversationId ?? "nil")")
            print("🔍 ViewModel isLoading: \(viewModel.isLoading)")
            
            // Check if current user is blocked by the conversation user
            guard !user.uid.isEmpty else {
                print("❌ CONVERSATION_VIEW: User UID is empty, cannot check blocking status")
                return
            }
            
            viewModel.conversationService.isCurrentUserBlockedBy(userId: user.uid) { isBlocked in
                if isBlocked {
                    print("🚫 CONVERSATION_VIEW: Current user is blocked by \(user.username), dismissing view")
                    DispatchQueue.main.async {
                        // Show blocked alert briefly before dismissing
                        showingBlockedAlert = true
                        
                        // Dismiss after a short delay to show the alert
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    return
                }
                
                print("✅ CONVERSATION_VIEW: No blocking detected, proceeding with conversation")
                
                // If we already have a conversationId, preserve it and just reset other state
                if viewModel.conversationId != nil {
                    print("🔍 Preserving existing conversationId: \(viewModel.conversationId!)")
                    viewModel.resetStatePreservingConversation()
                } else {
                    print("🔍 No existing conversationId, resetting everything")
                    viewModel.resetAllState()
                }
                
                // Reset local state
                canPaginate = false
                firstVisibleMessageId = nil
                hasMarkedAsRead = false
                
                // Initialize the conversation
                print("🔍 Calling initializeConversation...")
                viewModel.initializeConversation()
                
                // Set flag to true since MessageViewModel will mark as read during initialization
                hasMarkedAsRead = true
                
                // Mark conversation as read when opened (for message badge)
                if let conversationId = viewModel.conversationId {
                    MessageBadgeManager.shared.markConversationAsRead(conversationId: conversationId)
                }
                
                print("🔍 === CONVERSATION VIEW APPEARED END ===")
            }
        }
        .onDisappear {
            // Clean up when view disappears
            // Post notification to refresh conversations when leaving conversation view
            NotificationCenter.default.post(name: NSNotification.Name("ConversationViewDismissed"), object: nil)
        }
        .onChange(of: viewModel.isPaginatingState) { isPaginating in
            if !isPaginating && firstVisibleMessageId != nil {
                firstVisibleMessageId = nil // Reset for next pagination
            }
        }
        .onChange(of: viewModel.messages.count) { newCount in
            if !viewModel.isPaginatingState && firstVisibleMessageId != nil {
                // Check if the target message still exists
                let messageExists = viewModel.messages.contains { $0.id == firstVisibleMessageId }
                print("📌 Target message exists: \(messageExists)")
                
                if messageExists {
                    print("📌 Would restore scroll to message: \(firstVisibleMessageId!)")
                }
                firstVisibleMessageId = nil
            }
            

        }
        .onChange(of: viewModel.conversationId) { newId in
            // Conversation id established - update frontend cache immediately
            if let id = newId {
                onMarkedAsRead?(id)
                hasMarkedAsRead = true
            }
        }


        .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performDeleteConversation()
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone.")
        }
        .alert("User Blocked", isPresented: $showingBlockedAlert) {
            Button("OK") { }
        } message: {
            Text("You cannot access this conversation. The user has blocked you.")
        }
    }
    
    
    // MARK: - Helper Methods
    
    func scrollToBottom(using proxy: ScrollViewProxy?) {
        withAnimation {
            // Use ScrollViewProxy to scroll to the bottom
            if let proxy = proxy {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }
    
    private func getPodViewModel(for message: Message) -> PodViewModel {
        let podId = message.podId ?? ""
        if let cached = podViewModels[podId] {
            return cached
        } else {
            let pod = viewModel.pod(for: message) ?? Pod(title: "", timestamp: Timestamp(date: Date()), description: "", fileUrl: "", thumbnailUrl: "", userId: "", likes: 0)
            let newVM = PodViewModel(pod: pod)
            DispatchQueue.main.async {
                podViewModels[podId] = newVM
            }
            return newVM
        }
    }
    
    private func markMessageAsReadIfNeeded(message: Message) {
        // Only mark as read if:
        // 1. Message is from the other user (not current user)
        // 2. Message is not already marked as read
        // 3. We have a conversation ID
        // 4. The conversation is already initialized (not during initial load)
        // 5. This is a new message that arrived while conversation was open
        guard let currentUid = Auth.auth().currentUser?.uid,
              message.senderId != currentUid,
              message.isRead != true,
              let conversationId = viewModel.conversationId,
              viewModel.isLoading == false else { return }
        
        // Check if this is a new message (not from initial load)
        let isNewMessage = !hasMarkedAsRead || message.timestamp > Date().addingTimeInterval(-60) // Within last minute
        
        if isNewMessage {
            print("📖 Marking new message as read when it came into view: \(message.id ?? "nil")")
            
            // Mark the last message as read in the conversation
            viewModel.markLastMessageAsRead(conversationId: conversationId)
            // Frontend cache mark
            onMarkedAsRead?(conversationId)
        }
    }
    
    private func deleteConversation() {
        guard let conversationId = viewModel.conversationId else {
            print("No conversation ID available")
            return
        }
        
        showingDeleteAlert = true
    }
    
    private func performDeleteConversation() {
        print("🔍 === DELETE CONVERSATION DIRECT FIRESTORE ===")
        
        guard let conversationId = viewModel.conversationId else {
            print("❌ No conversation ID available")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No current user ID")
            return
        }
        
        print("✅ Conversation ID: \(conversationId)")
        print("✅ Current user ID: \(currentUserId)")
        
        isDeleting = true
        
        // Direct Firestore updates to mark conversation as deleted
        let db = Firestore.firestore()
        
        // 1. Update the main conversation document
        let conversationRef = db.collection("conversations").document(conversationId)
        let updateData: [String: Any] = [
            "deletedFor.\(currentUserId)": [
                "deletedAt": FieldValue.serverTimestamp(),
                "isDeleted": true
            ]
        ]
        
        // 2. Update the user's conversation reference
        let userConversationRef = db.collection("users").document(currentUserId)
            .collection("conversations").document(conversationId)
        let userUpdateData: [String: Any] = [
            "isDeleted": true,
            "deletedAt": FieldValue.serverTimestamp()
        ]
        
        // Perform both updates
        conversationRef.updateData(updateData) { error in
            if let error = error {
                print("❌ Error updating main conversation: \(error)")
                DispatchQueue.main.async {
                    self.isDeleting = false
                    // TODO: Show error alert to user
                }
                return
            }
            
            print("✅ Main conversation updated successfully")
            
            // Update user's conversation reference
            userConversationRef.updateData(userUpdateData) { error in
                DispatchQueue.main.async {
                    self.isDeleting = false
                    
                    if let error = error {
                        print("❌ Error updating user conversation reference: \(error)")
                        // TODO: Show error alert to user
                    } else {
                        print("✅ User conversation reference updated successfully")
                        print("✅ Conversation marked as deleted for user \(currentUserId)")
                        
                        // Dismiss the conversation view
                        self.presentationMode.wrappedValue.dismiss()
                        self.onConversationDeleted?() // Call the callback
                    }
                }
            }
        }
    }
}

struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ConversationView(user: PreviewClass().previewUser, onConversationDeleted: nil)
                .environment(\.colorScheme, .light)
            
            ConversationView(user: PreviewClass().previewUser, onConversationDeleted: nil)
                .environment(\.colorScheme, .dark)
        }
    }
}
