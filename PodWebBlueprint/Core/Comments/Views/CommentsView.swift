//
//  CommentsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/22/23.
//

import SwiftUI

struct CommentsView: View {
    
    @StateObject var commentViewModel: CommentViewModel
    @StateObject var commentRowViewModel: CommentRowViewModel
    
    @State var selectedComment: Comment?
    @State var showingReplyView = false // Track reply view state
    
    let pod: Pod
    let onPodSelected: ((Pod) -> Void)?
    
    init(pod: Pod, comment: Comment, onPodSelected: ((Pod) -> Void)? = nil) {
        self.pod = pod
        self.onPodSelected = onPodSelected
        _commentViewModel = StateObject(wrappedValue: CommentViewModel(pod: pod))
        _commentRowViewModel = StateObject(wrappedValue: CommentRowViewModel(comment: comment, pod: pod))
    }
    
    private func replyCountText(_ count: Int) -> String {
        return count == 1 ? "1 reply" : "\(count) replies"
    }
    
    var body: some View {
        VStack {
            if showingReplyView && selectedComment != nil {
                // Reply View with back navigation
                VStack(spacing: 0) {
                    // Modern Reply Header
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingReplyView = false
                                selectedComment = nil
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.left")
                                    .font(.title3)
                                    .foregroundColor(Color("accentColor"))
                                
                                Text("Back")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(Color("accentColor"))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color("accentColor").opacity(0.1))
                            )
                        }
                        
                        Spacer()
                        
                        Text("Reply to comment")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("textColor"))
                        
                        Spacer()
                        
                        // Invisible spacer to center the title
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.title3)
                                .foregroundColor(.clear)
                            
                            Text("Back")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.clear)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    CommentReplyView(pod: pod, comment: selectedComment!, commentViewModel: commentViewModel)
                        .onDisappear {
                            // Reset state when reply view disappears
                            showingReplyView = false
                            selectedComment = nil
                        }
                }
            } else {
                // Main Comments View
                VStack(spacing: 0) {
                    // Modern Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Comments")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(Color("textColor"))
                            
                            if commentViewModel.isLoading {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                    Text("Loading comments...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Text("\(commentViewModel.comments.count) \(commentViewModel.comments.count == 1 ? "comment" : "comments")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundColor(Color("accentColor"))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    ZStack {
                        ScrollView {
                            LazyVStack {
                                if commentViewModel.isLoading {
                                    // Show loading indicator while fetching comments
                                    VStack(spacing: 20) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                        
                                        Text("Loading comments...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 60)
                                } else if commentViewModel.comments.isEmpty {
                                    VStack(spacing: 20) {
                                        Image(systemName: "text.bubble")
                                            .font(.system(size: 48))
                                            .foregroundColor(.gray.opacity(0.6))
                                        
                                        VStack(spacing: 8) {
                                            Text("No comments yet")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.gray)
                                            
                                            Text("Be the first to comment!")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 60)
                                } else {
                                    ForEach(commentViewModel.comments) { comment in
                                        CommentRowView(comment: comment, pod: pod, onDelete: { deletedComment in
                                            // Remove the deleted comment from the main comments list
                                            commentViewModel.deleteComment(deletedComment) { _ in }
                                        }, onPodSelected: onPodSelected, onReply: { replyComment in
                                            // Navigate to reply view
                                            withAnimation {
                                                selectedComment = replyComment
                                                showingReplyView = true
                                            }
                                        })
                                        
                                        if comment.id != commentViewModel.comments.last?.id {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                    
                                    if commentViewModel.hasMoreComments {
                                        ProgressView()
                                            .padding()
                                            .onAppear {
                                                commentViewModel.loadMoreComments()
                                            }
                                    }
                                }
                            }
                        }
                        .refreshable {
                            commentViewModel.fetchComments()
                        }
                    }
                    
                    CommentField(pod: pod, comment: PreviewClass().previewComment, commentViewModel: commentViewModel)
                }
            }
        }
        .onAppear {
            if commentViewModel.comments.isEmpty {
                commentViewModel.fetchComments()
            }
        }
        .fullScreenCover(isPresented: $commentViewModel.isReplying) {
            if let selectedComment = selectedComment {
                CommentReplyView(pod: pod, comment: selectedComment, commentViewModel: commentViewModel)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
    }
}

struct CommentsView_Previews: PreviewProvider {
    static var previews: some View {
        CommentsView(pod: PreviewClass().previewPod, comment: PreviewClass().previewComment)
    }
}
