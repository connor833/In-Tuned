//
//  CommentViewModel.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/25/22.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth

class CommentViewModel: ObservableObject {
    @Published var pod: Pod
    @Published var didUploadComment = false
    private let service = CommentService()
    private let userService = UserService()
    private let notificationService = NotificationService()
    private let commentRateLimiter = CommentRateLimiter.shared
    
    @Published var comments = [Comment]()
    @Published var isLoadingMore = false
    @Published var hasMoreComments = true
    @Published var isLoading = true
    
    @Published var isReplying = false
    
    init(pod: Pod) {
        self.pod = pod
    }
    
    func uploadComment(withCaption caption: String) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let podId = pod.id else { return }
        
        print("💬 CommentViewModel: Starting comment upload for pod: \(podId)")
        
        // Check rate limits before attempting to comment
        commentRateLimiter.canAttemptComment(podId: podId) { [weak self] allowed, reason in
            guard let self = self else { return }
            
            if !allowed {
                print("🚫 CommentViewModel: Comment blocked by rate limiter - \(reason ?? "Unknown reason")")
                
                // Show rate limiting error to user
                DispatchQueue.main.async {
                    // You might want to show an alert or error message here
                    print("🚫 Comment rate limited: \(reason ?? "Too many comments")")
                }
                return
            }
            
            print("✅ CommentViewModel: Rate limit check passed, proceeding with comment upload")
            
            // Create a temporary comment object with essential fields
            let currentTime = Timestamp()
            let newComment = Comment(
                caption: caption,
                timestamp: currentTime,
                uid: currentUid,
                likes: 0,
                replyCount: 0,
                isActive: true,
                createdAt: currentTime,
                updatedAt: currentTime,
                version: 1,
                podId: podId,
                isReported: false
            )
            
            // Add the new comment to the beginning of the array immediately
            DispatchQueue.main.async {
                self.comments.insert(newComment, at: 0)
            }
            
            self.service.uploadComment(pod, caption: caption) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.didUploadComment = true
                
                // Record successful comment attempt for rate limiting
                self.commentRateLimiter.recordCommentAttempt(podId: podId) { rateLimitSuccess in
                    if rateLimitSuccess {
                        print("📊 CommentViewModel: Recorded comment attempt successfully")
                    } else {
                        print("⚠️ CommentViewModel: Failed to record comment attempt")
                    }
                }
                
                // Fetch the user data for the new comment
                self.userService.fetchUser(withUid: currentUid) { [weak self] result in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let user):
                            if let index = self.comments.firstIndex(where: { $0.uid == currentUid && $0.caption == caption }) {
                                self.comments[index].user = user
                            }
                        case .failure(let error):
                            print("Error fetching user for comment: \(error.localizedDescription)")
                        }
                    }
                }
                
                // Create notification for the pod creator
                self.notificationService.createNotification(
                    type: .comment,
                    senderId: currentUid,
                    recipientId: self.pod.userId,
                    contentId: self.pod.id,
                    commentText: caption
                ) { _ in }
            } else {
                // Remove the comment if upload failed
                DispatchQueue.main.async {
                    if let index = self.comments.firstIndex(where: { $0.uid == currentUid && $0.caption == caption }) {
                        self.comments.remove(at: index)
                    }
                }
            }
            }
        }
    }
    
    func fetchComments() {
        service.fetchComments(pod) { [weak self] comments in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.comments = comments
                self.hasMoreComments = comments.count == 10 // If we got less than 10 comments, we've reached the end
                self.isLoading = false // Comments have been loaded
                
                // Batch user fetches to reduce UI blocking
                let uniqueUserIds = Set(comments.map { $0.uid })
                var userResults: [String: User] = [:]
                var completedFetches = 0
                let totalFetches = uniqueUserIds.count
                
                for uid in uniqueUserIds {
                    self.userService.fetchUser(withUid: uid) { [weak self] result in
                        guard let self = self else { return }
                        
                        switch result {
                        case .success(let user):
                            userResults[uid] = user
                        case .failure(let error):
                            print("Error fetching user for comment: \(error.localizedDescription)")
                        }
                        completedFetches += 1
                        
                        // Only update UI when all fetches are complete
                        if completedFetches == totalFetches {
                            DispatchQueue.main.async {
                                for i in 0 ..< self.comments.count {
                                    if let user = userResults[self.comments[i].uid] {
                                        self.comments[i].user = user
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func loadMoreComments() {
        guard !isLoadingMore && hasMoreComments, let lastComment = comments.last else { return }
        
        isLoadingMore = true
        
        service.fetchComments(pod, lastComment: lastComment) { [weak self] newComments in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.comments.append(contentsOf: newComments)
                self.hasMoreComments = newComments.count == 10
                self.isLoadingMore = false
                
                // Batch user fetches for new comments
                let newUserIds = Set(newComments.map { $0.uid })
                var userResults: [String: User] = [:]
                var completedFetches = 0
                let totalFetches = newUserIds.count
                
                for uid in newUserIds {
                    self.userService.fetchUser(withUid: uid) { [weak self] result in
                        guard let self = self else { return }
                        
                        switch result {
                        case .success(let user):
                            userResults[uid] = user
                        case .failure(let error):
                            print("Error fetching user for new comment: \(error.localizedDescription)")
                        }
                        completedFetches += 1
                        
                        // Only update UI when all fetches are complete
                        if completedFetches == totalFetches {
                            DispatchQueue.main.async {
                                for i in 0 ..< self.comments.count {
                                    if let user = userResults[self.comments[i].uid] {
                                        self.comments[i].user = user
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Delete Function
    
    func deleteComment(_ comment: Comment, completion: @escaping(Bool) -> Void) {
        service.deleteComment(comment, pod: pod) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // Remove the comment from the local array
                    self?.comments.removeAll { $0.id == comment.id }
                }
                completion(success)
            }
        }
    }
}
