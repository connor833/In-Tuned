//
//  ReplyRowViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 6/11/25.
//

import Foundation
import SwiftUI
import FirebaseAuth

class ReplyRowViewModel: ObservableObject {
    
    @Published var reply: Comment
    @Published var isDeleting = false
    @Published var isUserBlocked: Bool = false // Add blocking state
    private let service = CommentService()
    private let blockService = BlockService() // Add blocking service
    
    let parentComment: Comment
    let pod: Pod
    
    init(reply: Comment, parentComment: Comment, pod: Pod) {
        self.reply = reply
        self.parentComment = parentComment
        self.pod = pod
        checkIfUserLikedReply()
        checkBlockingStatus() // Add blocking check
    }
    
    var isLiked: Bool {
        return reply.didLike ?? false
    }
    
    func toggleLike() {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        // Add haptic feedback immediately
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        if isLiked {
            unlikeReply()
        } else {
            likeReply()
        }
    }
    
    func likeReply() {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        // Optimistic UI update - change immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            self.reply.didLike = true
            self.reply.likes += 1
        }
        
        // Background service call
        service.likeReply(parentComment, reply: reply, pod: pod) {
            // Service call completed successfully
            // No need to revert since we're using optimistic updates
        }
    }
    
    func unlikeReply() {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        // Optimistic UI update - change immediately
        withAnimation(.easeInOut(duration: 0.2)) {
            self.reply.didLike = false
            self.reply.likes = max(0, self.reply.likes - 1)
        }
        
        // Background service call
        service.unlikeReply(parentComment, reply: reply, pod: pod) {
            // Service call completed successfully
            // No need to revert since we're using optimistic updates
        }
    }
    
    func checkIfUserLikedReply() {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { return }
        
        service.checkIfUserLikedReply(reply) { didLike in
            self.reply.didLike = didLike
        }
    }
    
    // MARK: - Delete Function
    
    func deleteReply(completion: @escaping(Bool) -> Void) {
        // Prevent interaction if user is blocked
        guard !isUserBlocked else { 
            completion(false)
            return 
        }
        
        isDeleting = true
        
        service.deleteReply(reply, parentComment: parentComment, pod: pod) { [weak self] success in
            DispatchQueue.main.async {
                self?.isDeleting = false
                completion(success)
            }
        }
    }
    
    // MARK: - Blocking Methods
    
    private func checkBlockingStatus() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Check if current user has blocked the reply author
        blockService.checkIfUserIsBlocked(userId: reply.uid) { isBlocked in
            DispatchQueue.main.async {
                self.isUserBlocked = isBlocked
            }
        }
    }
}
