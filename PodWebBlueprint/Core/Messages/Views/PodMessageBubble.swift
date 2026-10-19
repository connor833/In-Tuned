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
                    // Clean card layout (similar to PodRowView)
                    VStack(spacing: 12) {
                        // Thumbnail
                        NavigationLink {
                            PlayerView(url: URL(string: pod.fileUrl)!, pod: pod)
                                .id(pod.id)
                        } label: {
                            KFImage(URL(string: pod.thumbnailUrl))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 160)
                                .clipped()
                                .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Content below thumbnail
                        VStack(alignment: .leading, spacing: 8) {
                            // Title
                            Text(pod.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            // Description
                            Text(pod.description)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            // Creator info and type
                            HStack(spacing: 8) {
                                // Profile image
                                if let user = pod.user, !user.profileImageUrl.isEmpty {
                                    KFImage(URL(string: user.profileImageUrl))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Text(getUserInitial(pod))
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                
                                Text(getUsername(pod))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // Type indicator
                                HStack(spacing: 4) {
                                    Image(systemName: isVideoPod(pod) ? "play.rectangle.fill" : "waveform")
                                        .font(.system(size: 10, weight: .medium))
                                    Text(isVideoPod(pod) ? "Video" : "Audio")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                )
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                messageBubbleViewModel.message.senderId != currentUid ? 
                                Color.gray.opacity(0.15) : 
                                Color("accentColor").opacity(0.2),
                                lineWidth: 1
                            )
                    )
                } else if loadAttempted {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.orange)
                        
                        Text("Pod not available")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("This pod has been deleted")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 240, height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        
                        Text("Loading pod...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 240, height: 200)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
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
