//
//  CommentRowViewModel.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/25/22.
//

import Foundation
import SwiftUI
import Firebase
import FirebaseAuth

class CommentRowViewModel: ObservableObject {
    
    @Published var comment: Comment
    @Published var replyComments = [Comment]()
    @Published var isLoadingMore = false
    @Published var hasMoreReplies = true
    @Published var isDeleting = false
    @Published var isUserBlocked: Bool = false // Add blocking state
    private let service = CommentService()
    private let userService = UserService()
    private let blockService = BlockService() // Add blocking service
    
    var count = 0
    
    let pod: Pod
    
    init(comment: Comment, pod: Pod) {
        self.comment = comment
        self.pod = pod
        checkIfUserLikedComment()
    }
    
    func replyToComment(pod: Pod, caption: String) {
        print("replying to comment")
        print("self reply count \(self.comment.replyCount)")
        
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Create a temporary reply object with essential fields
        let currentTime = Timestamp()
        let newReply = Comment(
            caption: caption,
            timestamp: currentTime,
            uid: currentUid,
            likes: 0,
            replyCount: 0,
            isActive: true,
            createdAt: currentTime,
            updatedAt: currentTime,
            version: 1,
            podId: pod.id,
            isReported: false
        )
        
        // Add the new reply to the beginning of the array immediately
        DispatchQueue.main.async {
            self.replyComments.insert(newReply, at: 0)
            // Update the reply count on the parent comment
            self.comment.replyCount += 1
        }
        
        service.replyToComment(comment, pod: pod, caption: caption) { [weak self] in
            guard let self = self else { return }
            print("replied to comment")
            
            // Fetch the user data for the new reply
            self.userService.fetchUser(withUid: currentUid) { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let user):
                        if let index = self.replyComments.firstIndex(where: { $0.uid == currentUid && $0.caption == caption }) {
                            self.replyComments[index].user = user
                        }
                    case .failure(let error):
                        print("Error fetching user for reply: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func fetchReplies() {
        print("FETCH REPLIES")
        service.fetchCommentReplies(pod, comment: comment) { [weak self] comments in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.replyComments = comments
                self.hasMoreReplies = comments.count == 10 // If we got less than 10 replies, we've reached the end
    
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
                                for i in 0 ..< self.replyComments.count {
                                    if let user = userResults[self.replyComments[i].uid] {
                                        self.replyComments[i].user = user
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Check likes for all replies
                for reply in comments {
                    self.checkIfUserLikedReply(reply: reply)
                }
            }
        }
    }
    
    func loadMoreReplies() {
        guard !isLoadingMore && hasMoreReplies, let lastReply = replyComments.last else { return }
        
        isLoadingMore = true
        
        service.fetchCommentReplies(pod, comment: comment, lastReply: lastReply) { [weak self] newReplies in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.replyComments.append(contentsOf: newReplies)
                self.hasMoreReplies = newReplies.count == 10
                self.isLoadingMore = false
                
                // Batch user fetches for new replies
                let newUserIds = Set(newReplies.map { $0.uid })
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
                            print("Error fetching user for new reply: \(error.localizedDescription)")
                        }
                        completedFetches += 1
                        
                        // Only update UI when all fetches are complete
                        if completedFetches == totalFetches {
                            DispatchQueue.main.async {
                                for i in 0 ..< self.replyComments.count {
                                    if let user = userResults[self.replyComments[i].uid] {
                                        self.replyComments[i].user = user
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Check likes for new replies
                for reply in newReplies {
                    self.checkIfUserLikedReply(reply: reply)
                }
            }
        }
    }
    
    func likeComment(comment: Comment, pod: Pod) {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        // Optimistic UI update - change immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            self.comment.didLike = true
            self.comment.likes = self.comment.likes + 1
        }
        
        // Background service call
        service.likeComment(comment, pod: pod) {
            // Service call completed successfully
            // No need to revert since we're using optimistic updates
        }
    }
    
    func unlikeComment(comment: Comment, pod: Pod) {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        // Optimistic UI update - change immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            self.comment.didLike = false
            self.comment.likes = max(0, self.comment.likes - 1)
        }
        
        // Background service call
        service.unlikeComment(comment, pod: pod) {
            // Service call completed successfully
            // No need to revert since we're using optimistic updates
        }
    }
    
    var isLiked: Bool {
            return comment.didLike ?? false
        }


    func toggleLike(comment: Comment, pod: Pod) {
            print("Like button clicked for comment: \(comment.caption)")
            
            // Prevent interaction if user is blocked
            guard !isUserBlocked else { return }
            
            // Add haptic feedback immediately
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            if isLiked {
                print("Unliking comment")
                unlikeComment(comment: comment, pod: pod)
            } else {
                print("Liking comment")
                likeComment(comment: comment, pod: pod)
            }
        }
    
    func checkIfUserLikedComment() {
        service.checkIfUserLikedComment(comment) { didLike in
            if didLike {
                self.comment.didLike = true
            }
        }
    }
    
    func toggleReplyLike(reply: Comment) {
        print("Like button clicked for reply: \(reply.caption)")
        
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        if reply.didLike ?? false {
            print("Unliking reply")
            unlikeReply(reply: reply)
        } else {
            print("Liking reply")
            likeReply(reply: reply)
        }
    }
    
    func checkIfUserLikedReply(reply: Comment) {
        service.checkIfUserLikedReply(reply) { didLike in
            if let index = self.replyComments.firstIndex(where: { $0.id == reply.id }) {
                self.replyComments[index].didLike = didLike
            }
        }
    }

    func likeReply(reply: Comment) {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        service.likeReply(comment, reply: reply, pod: pod) {
            withAnimation {
                if let index = self.replyComments.firstIndex(where: { $0.id == reply.id }) {
                    self.replyComments[index].didLike = true
                    self.replyComments[index].likes += 1
                }
            }
        }
    }
    
    func unlikeReply(reply: Comment) {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        service.unlikeReply(comment, reply: reply, pod: pod) {
            withAnimation {
                if let index = self.replyComments.firstIndex(where: { $0.id == reply.id }) {
                    self.replyComments[index].didLike = false
                    self.replyComments[index].likes = max(0, self.replyComments[index].likes - 1)
                }
            }
        }
    }
    
    // MARK: - Delete Functions
    
    func deleteComment(completion: @escaping(Bool) -> Void) {
        isDeleting = true
        
        service.deleteComment(comment, pod: pod) { [weak self] success in
            DispatchQueue.main.async {
                self?.isDeleting = false
                completion(success)
            }
        }
    }
    
    func deleteReply(_ reply: Comment, completion: @escaping(Bool) -> Void) {
        service.deleteReply(reply, parentComment: comment, pod: pod) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    // Remove the reply from the local array
                    self?.replyComments.removeAll { $0.id == reply.id }
                    // Update the reply count on the parent comment
                    self?.comment.replyCount = max(0, (self?.comment.replyCount ?? 0) - 1)
                }
                completion(success)
            }
        }
    }
    
    // MARK: - Blocking Methods
    
    private func checkBlockingStatus() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Check if current user has blocked the comment author
        blockService.checkIfUserIsBlocked(userId: comment.uid) { isBlocked in
            DispatchQueue.main.async {
                self.isUserBlocked = isBlocked
            }
        }
    }
    
}
