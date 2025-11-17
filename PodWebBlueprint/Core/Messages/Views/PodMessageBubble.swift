//
//  PodMessageBubble.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/8/23.
//

import SwiftUI
import Firebase
import Kingfisher
import FirebaseAuth

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct PodMessageBubble: View {
    
    // MARK: - Properties
    
    @State private var showTime = false
    @State private var isLoading = true
    @State private var loadAttempted = false

    var currentUid = Auth.auth().currentUser?.uid
    @ObservedObject var messageBubbleViewModel: MessageBubbleViewModel
    @ObservedObject var messageViewModel: MessageViewModel
    @StateObject var podViewModel: PodViewModel // Changed to @StateObject for stability
    
    // MARK: - Initialization
    
    init(message: Message, user: User, messageViewModel: MessageViewModel, podViewModel: PodViewModel) {
        self.messageBubbleViewModel = MessageBubbleViewModel(message: message, user: user)
        self.messageViewModel = messageViewModel
        self._podViewModel = StateObject(wrappedValue: podViewModel) // Initialize as StateObject
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Display the pod content
                if let pod = messageViewModel.pod(for: messageBubbleViewModel.message) {
                    // Unified card with overlay content
                    ZStack {
                        // Thumbnail background with NavigationLink
                        NavigationLink {
                            PlayerView(url: URL(string: pod.fileUrl)!, pod: pod)
                                .id(pod.id)
                        } label: {
                            KFImage(URL(string: pod.thumbnailUrl))
                                .resizable()
                                .aspectRatio(contentMode: .fit) // Changed from scaledToFill to fit to preserve aspect ratio
                                .frame(maxHeight: 180) // Use maxHeight to allow adaptive width
                                .clipped()
                                .cornerRadius(20)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Gradient overlay for better text readability
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(20)
                        .allowsHitTesting(false)
                        
                        // Content overlay
                        VStack {
                            Spacer()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    // Title
                                    Text(pod.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    // Description
                                    Text(pod.description)
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    
                                    // Creator info
                                    HStack(spacing: 8) {
                                        // Profile image
                                        if let user = pod.user, !user.profileImageUrl.isEmpty {
                                            KFImage(URL(string: user.profileImageUrl))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 20, height: 20)
                                                .clipShape(Circle())
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                                )
                                        } else {
                                            Circle()
                                                .fill(Color.white.opacity(0.3))
                                                .frame(width: 20, height: 20)
                                                .overlay(
                                                    Text(getUserInitial(pod))
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                        
                                        Text(getUsername(pod))
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Spacer()
                                        
                                        // Type indicator
                                        HStack(spacing: 4) {
                                            Image(systemName: isVideoPod(pod) ? "play.rectangle" : "waveform")
                                                .font(.system(size: 10, weight: .medium))
                                            Text(isVideoPod(pod) ? "Video" : "Audio")
                                                .font(.system(size: 10, weight: .medium))
                                        }
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.white.opacity(0.2))
                                        )
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                        }
                        .allowsHitTesting(false)
                    }
                    .shadow(
                        color: messageBubbleViewModel.message.senderId != currentUid ? 
                        Color.black.opacity(0.15) : 
                        Color("accentColor").opacity(0.2),
                        radius: messageBubbleViewModel.message.senderId != currentUid ? 8 : 12,
                        x: 0,
                        y: messageBubbleViewModel.message.senderId != currentUid ? 4 : 6
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                messageBubbleViewModel.message.senderId != currentUid ? 
                                Color.gray.opacity(0.2) : 
                                Color("accentColor").opacity(0.3),
                                lineWidth: 1
                            )
                    )
                } else if loadAttempted {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.gray)
                        
                        Text("Pod no longer available")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 240, height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        
                        Text("Loading pod...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(width: 240, height: 180)
                    .onAppear {
                        // Set loadAttempted to true after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            loadAttempted = true
                        }
                    }
                }
            }
            .frame(maxWidth: 280, alignment: messageBubbleViewModel.message.senderId != currentUid ? .leading : .trailing)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTime.toggle()
                }
            }
            
            if showTime {
                HStack {
                    if messageBubbleViewModel.message.senderId != currentUid {
                        Spacer()
                    }
                    
                    Text("\(messageBubbleViewModel.message.timestamp.formatted(.dateTime.hour().minute()))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(.systemGray6).opacity(0.9))
                        )
                    
                    if messageBubbleViewModel.message.senderId == currentUid {
                        Spacer()
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: messageBubbleViewModel.message.senderId != currentUid ? .leading : .trailing)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    
    private func isVideoPod(_ pod: Pod) -> Bool {
        let fileUrl = pod.fileUrl
        let fileExtension = URL(string: fileUrl)?.pathExtension.lowercased() ?? ""
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "m4v"]
        
        if videoExtensions.contains(fileExtension) {
            return true
        }
        
        // Check URL path patterns
        let isVideoPath = fileUrl.contains("/videos/") || fileUrl.contains("videos%2F")
        return isVideoPath
    }
    
    private func getUsername(_ pod: Pod) -> String {
        if let user = pod.user, !user.username.isEmpty {
            return user.username
        }
        return "Loading..."
    }
    
    private func getUserInitial(_ pod: Pod) -> String {
        if let user = pod.user, !user.username.isEmpty {
            return user.username.prefix(1).uppercased()
        }
        return "?"
    }
    
    
}

// MARK: - Previews

struct PodMessageBubble_Previews: PreviewProvider {
    static var previews: some View {
        let previewUser = PreviewClass().previewUser
        PodMessageBubble(
            message: Message(text: "", senderId: "", timestamp: Date(), isPod: true, pod: PreviewClass().previewPod),
            user: previewUser,
            messageViewModel: MessageViewModel(user: previewUser),
            podViewModel: PodViewModel(pod: PreviewClass().previewPod)
        )
    }
}
