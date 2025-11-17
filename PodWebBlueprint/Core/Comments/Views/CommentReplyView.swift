//
//  CommentsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/22/23.
//

import SwiftUI
import Kingfisher

struct CommentReplyView: View {
    
    let pod: Pod
    let comment: Comment
    @Environment(\.presentationMode) var mode
    @ObservedObject var commentViewModel: CommentViewModel
    @ObservedObject var commentRowViewModel: CommentRowViewModel
    @State private var isLoading = true
    @State var isReplying = false
    
    init(pod: Pod, comment: Comment, commentViewModel: CommentViewModel) {
        self.commentViewModel = commentViewModel
        self.commentRowViewModel = CommentRowViewModel(comment: comment, pod: pod)
        self.pod = pod
        self.comment = comment
        commentRowViewModel.fetchReplies()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation header removed - now handled by parent CommentsView
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Modern comment display for reply view
                    VStack(spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            // Profile image
                            if let profileImageUrl = comment.user?.profileImageUrl, !profileImageUrl.isEmpty {
                                KFImage(URL(string: profileImageUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                // Username and verification
                                HStack(spacing: 6) {
                                    if let user = comment.user {
                                        Text("@\(user.username)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.blue)
                                        
                                        if user.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(comment.timestamp.dateValue().timeAgoDisplay())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                }
                                
                                // Comment text
                                Text(comment.caption)
                                    .font(.body)
                                    .foregroundColor(Color("textColor"))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(nil) // Always show full text
                                
                                // Likes count
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                    
                                    Text("\(comment.likes) \(comment.likes == 1 ? "like" : "likes")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("accentColor"), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Replies content
                    if commentRowViewModel.replyComments.isEmpty {
                        // Show "No replies yet" message when there are no replies
                        VStack(spacing: 20) {
                            Spacer()
                            
                            Image(systemName: "text.bubble")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("No replies yet")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                
                                Text("Be the first to reply!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 20)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(commentRowViewModel.replyComments) { reply in
                                    ReplyRowView(
                                        reply: reply,
                                        parentComment: comment,
                                        pod: pod,
                                        commentViewModel: commentViewModel,
                                        onDelete: { deletedReply in
                                            // Remove the deleted reply from the list
                                            commentRowViewModel.replyComments.removeAll { $0.id == deletedReply.id }
                                        }
                                    )
                                    
                                    if reply.id != commentRowViewModel.replyComments.last?.id {
                                        Divider()
                                            .padding(.horizontal, 24)
                                    }
                                }
                                
                                if commentRowViewModel.hasMoreReplies {
                                    ProgressView()
                                        .padding()
                                        .onAppear {
                                            commentRowViewModel.loadMoreReplies()
                                        }
                                }
                            }
                        }
                        .refreshable {
                            commentRowViewModel.fetchReplies()
                        }
                    }
                }
            }
            
            // Reply field at bottom
            VStack(spacing: 0) {
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                ReplyField(pod: pod, comment: comment, commentRowViewModel: commentRowViewModel)
                    .background(Color(.systemBackground))
            }
        }
        .onReceive(commentRowViewModel.$replyComments) { comments in
            isLoading = false
        }
        .onAppear {
            commentRowViewModel.fetchReplies()
        }
    }
}
