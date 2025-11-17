//
//  ReplyRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 6/11/25.
//

import SwiftUI
import Kingfisher
import FirebaseAuth

struct ReplyRowView: View {
    @State var isLoading = false
    @State private var expanded: Bool = false
    @ObservedObject var replyRowViewModel: ReplyRowViewModel
    let lineLimit = 2
    @State private var isCooldownActive = false
    @State private var showingActionSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingReportSheet = false
    @State private var deleteSuccess = false
    @State var isPresented = false
    @State var showingProfile = false
    
    let reply: Comment
    let parentComment: Comment
    let pod: Pod
    let commentViewModel: CommentViewModel
    let onDelete: ((Comment) -> Void)?
    
    init(reply: Comment, parentComment: Comment, pod: Pod, commentViewModel: CommentViewModel, onDelete: ((Comment) -> Void)? = nil) {
        self.replyRowViewModel = ReplyRowViewModel(reply: reply, parentComment: parentComment, pod: pod)
        self.reply = reply
        self.parentComment = parentComment
        self.pod = pod
        self.commentViewModel = commentViewModel
        self.onDelete = onDelete
    }
    
    private var shouldShowReadMore: Bool {
        // Simple check: if text has more than 2 lines worth of characters, show read more
        let maxChars = 120 // Approximate characters for 2 lines
        return reply.caption.count > maxChars
    }
    
    var body: some View {
        if let user = replyRowViewModel.reply.user {
            VStack(spacing: 0) {
                // Modern Reply Card
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        // Profile Image
                        Button {
                            showingProfile = true
                        } label: {
                            if let profileImageUrl = replyRowViewModel.reply.user?.profileImageUrl, !profileImageUrl.isEmpty {
                                KFImage(URL(string: profileImageUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .sheet(isPresented: $showingProfile) {
                            if #available(iOS 16.0, *) {
                                ProfileView(user: replyRowViewModel.reply.user ?? PreviewClass().previewUser) { selectedPod in
                                    // Dismiss the profile sheet
                                    showingProfile = false
                                    
                                    // Handle pod selection - this will be handled by the parent view
                                    // For now, we just dismiss the sheet
                                }
                                .presentationDetents([.large])
                                .presentationDragIndicator(.visible)
                            } else {
                                ProfileView(user: replyRowViewModel.reply.user ?? PreviewClass().previewUser) { selectedPod in
                                    // Dismiss the profile sheet
                                    showingProfile = false
                                    
                                    // Handle pod selection - this will be handled by the parent view
                                    // For now, we just dismiss the sheet
                                }
                            }
                        }
                        
                        // Reply Content
                        VStack(alignment: .leading, spacing: 8) {
                            // Username and timestamp
                            HStack(spacing: 6) {
                                Button {
                                    showingProfile = true
                                } label: {
                                    Text("@\(user.username)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if user.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(reply.timestamp.dateValue().timeAgoDisplay())
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            
                            // Reply text
                            VStack(alignment: .leading, spacing: 6) {
                                Text(reply.caption)
                                    .font(.subheadline)
                                    .foregroundColor(Color("textColor"))
                                    .lineLimit(expanded ? nil : lineLimit)
                                
                                if shouldShowReadMore {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            expanded.toggle()
                                        }
                                    }, label: {
                                        Text(expanded ? "read less" : "read more")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color("accentColor"))
                                    })
                                }
                            }
                            
                            // Like button
                            HStack {
                                Button {
                                    if !isCooldownActive {
                                        replyRowViewModel.toggleLike()
                                        
                                        isCooldownActive = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isCooldownActive = false
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: replyRowViewModel.isLiked ? "heart.fill" : "heart")
                                            .font(.caption2)
                                            .foregroundColor(replyRowViewModel.isLiked ? .red : Color("textColor"))
                                        
                                        Text("\(replyRowViewModel.reply.likes) \(replyRowViewModel.reply.likes == 1 ? "like" : "likes")")
                                            .font(.caption2)
                                            .foregroundColor(replyRowViewModel.isLiked ? .red : Color("textColor"))
                                    }
                                }
                                .disabled(isCooldownActive)
                                
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .redacted(reason: isLoading ? .placeholder : [])
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
                )
                .padding(.leading, 24) // Indent replies to show hierarchy
                .padding(.trailing, 16)
                .padding(.vertical, 2)
            }
            .contextMenu {
                Button {
                    if !isCooldownActive {
                        replyRowViewModel.toggleLike()
                        
                        isCooldownActive = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isCooldownActive = false
                        }
                    }
                } label: {
                    Label(replyRowViewModel.isLiked ? "Unlike" : "Like", systemImage: replyRowViewModel.isLiked ? "heart.fill" : "heart")
                }
                
                Button {
                    UIPasteboard.general.string = reply.caption
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Button(role: .destructive) {
                    showingReportSheet = true
                } label: {
                    Label("Report", systemImage: "exclamationmark.triangle")
                }
                
                if reply.uid == Auth.auth().currentUser?.uid {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .onChange(of: reply.caption) { _ in
                // Reset expanded state when text changes
                expanded = false
            }
            .sheet(isPresented: $showingReportSheet) {
                ReportCommentView(comment: reply, pod: pod)
            }
            .alert("Delete Reply", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    replyRowViewModel.deleteReply { success in
                        deleteSuccess = success
                        if success {
                            // Notify parent view about the deletion
                            onDelete?(reply)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this reply? This action cannot be undone.")
            }
            .opacity(deleteSuccess ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: deleteSuccess)
        }
    }
    

}

#Preview {
    ReplyRowView(
        reply: PreviewClass().previewComment,
        parentComment: PreviewClass().previewComment,
        pod: PreviewClass().previewPod,
        commentViewModel: CommentViewModel(pod: PreviewClass().previewPod)
    )
}
