//
//  CommentService.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/25/22.
//

import Foundation
import Firebase
import FirebaseFunctions
import FirebaseAuth

struct CommentService {
    private let blockService = BlockService() // Add blocking service
    
    // MARK: - Engagement Metrics
    
    private func incrementPodComments(podId: String) {
        guard !podId.isEmpty else { return }
        
        Task {
            do {
                let functions = Functions.functions()
                let incrementComments = functions.httpsCallable("incrementPodComments")
                let result = try await incrementComments.call(["podId": podId])
                print("✅ Successfully incremented comments for pod: \(podId)")
            } catch {
                print("❌ Error incrementing pod comments: \(error.localizedDescription)")
            }
        }
    }
    
    private func decrementPodComments(podId: String) {
        guard !podId.isEmpty else { return }
        
        Task {
            do {
                let functions = Functions.functions()
                let decrementComments = functions.httpsCallable("decrementPodComments")
                let result = try await decrementComments.call(["podId": podId])
                print("✅ Successfully decremented comments for pod: \(podId)")
            } catch {
                print("❌ Error decrementing pod comments: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Uploading Comments

    func uploadComment(_ pod: Pod, caption: String, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let podId = pod.id else { return }

        let currentTime = Timestamp()
        
        // Prepare comment data with essential production fields
        let data = [
            "uid": uid,
            "caption": caption,
            "replyCount": 0,
            "likes": 0,
            "timestamp": currentTime,
            
            // Essential production fields
            "isActive": true,
            "createdAt": currentTime,
            "updatedAt": currentTime,
            "version": 1,
            
            // Content reference and moderation
            "podId": podId,
            "isReported": false
        ] as [String: Any]

        // Upload comment data to Firestore
        Firestore.firestore().collection("pods")
            .document(podId)
            .collection("pod-comments")
            .document()
            .setData(data) { error in
                if let error = error {
                    print("Error uploading comment: \(error.localizedDescription)")
                } else {
                    // Increment comments count for the pod
                    self.incrementPodComments(podId: podId)
                }
                completion(true)
            }
    }

    // MARK: - Fetching Comments

    func fetchComments(_ pod: Pod, lastComment: Comment? = nil, limit: Int = 10, completion: @escaping([Comment]) -> Void) {
        guard let podId = pod.id else { return }

        var query = Firestore.firestore().collection("pods")
            .document(podId)
            .collection("pod-comments")
            .order(by: "likes", descending: true)
            .limit(to: limit)

        // If we have a last comment, start after it
        if let lastComment = lastComment {
            query = query.start(after: [lastComment.likes])
        }

        // Fetch comments for a particular pod
        query.getDocuments { snapshot, _ in
            guard let documents = snapshot?.documents else { return }
            // Convert Firestore documents to Comment objects
            let comments = documents.compactMap({ try? $0.data(as: Comment.self) })
            
            // Use quick array check from current user for ongoing app usage
            guard let currentUid = Auth.auth().currentUser?.uid else {
                completion(comments)
                return
            }
            
            // Get current user's blocking data for comprehensive filtering
            Firestore.firestore().collection("users").document(currentUid).getDocument { snapshot, error in
                if let userData = snapshot?.data() {
                    let blockedUsers = userData["blockedUsers"] as? [String] ?? []
                    let blockedBy = userData["blockedBy"] as? [String] ?? []
                    
                    // Combine both arrays for comprehensive filtering
                    let allBlockedUserIds = Set(blockedUsers + blockedBy)
                    
                    // Filter out comments from users that current user has blocked OR users that have blocked current user
                    let filteredComments = comments.filter { comment in
                        let isBlocked = allBlockedUserIds.contains(comment.uid)
                        if isBlocked {
                            if blockedUsers.contains(comment.uid) {
                                print("[CommentService] Filtering out comment from user you blocked: \(comment.uid)")
                            } else if blockedBy.contains(comment.uid) {
                                print("[CommentService] Filtering out comment from user who blocked you: \(comment.uid)")
                            }
                        }
                        return !isBlocked
                    }
                    
                    print("[CommentService] Filtered \(comments.count) comments down to \(filteredComments.count) using comprehensive blocking check")
                    
                    // Check like status for each comment
                    self.checkLikeStatusForComments(filteredComments, currentUid: currentUid, completion: completion)
                } else {
                    // Fallback to all comments if blocking data not available
                    self.checkLikeStatusForComments(comments, currentUid: currentUid, completion: completion)
                }
            }
        }
    }

    // MARK: - Fetching Comment Replies

    func fetchCommentReplies(_ pod: Pod, comment: Comment, lastReply: Comment? = nil, limit: Int = 10, completion: @escaping([Comment]) -> Void) {
        guard let podId = pod.id else { return }
        guard let commentId = comment.id else { return }

        var query = Firestore.firestore().collection("pods")
            .document(podId)
            .collection("pod-comments")
            .document(commentId)
            .collection("comment-replies")
            .order(by: "likes", descending: true)
            .limit(to: limit)

        // If we have a last reply, start after it
        if let lastReply = lastReply {
            query = query.start(after: [lastReply.likes])
        }

        // Fetch replies for a specific comment in a pod
        query.getDocuments { snapshot, _ in
            guard let documents = snapshot?.documents else { return }
            // Convert Firestore documents to Comment objects
            let comments = documents.compactMap({ try? $0.data(as: Comment.self) })
            
            // Use quick array check from current user for ongoing app usage
            guard let currentUid = Auth.auth().currentUser?.uid else {
                completion(comments)
                return
            }
            
            // Get current user's blocking data for comprehensive filtering
            Firestore.firestore().collection("users").document(currentUid).getDocument { snapshot, error in
                if let userData = snapshot?.data() {
                    let blockedUsers = userData["blockedUsers"] as? [String] ?? []
                    let blockedBy = userData["blockedBy"] as? [String] ?? []
                    
                    // Combine both arrays for comprehensive filtering
                    let allBlockedUserIds = Set(blockedUsers + blockedBy)
                    
                    // Filter out replies from users that current user has blocked OR users that have blocked current user
                    let filteredComments = comments.filter { comment in
                        let isBlocked = allBlockedUserIds.contains(comment.uid)
                        if isBlocked {
                            if blockedUsers.contains(comment.uid) {
                                print("[CommentService] Filtering out reply from user you blocked: \(comment.uid)")
                            } else if blockedBy.contains(comment.uid) {
                                print("[CommentService] Filtering out reply from user who blocked you: \(comment.uid)")
                            }
                        }
                        return !isBlocked
                    }
                    
                    print("[CommentService] Filtered \(comments.count) replies down to \(filteredComments.count) using comprehensive blocking check")
                    
                    // Check like status for each reply
                    self.checkLikeStatusForComments(filteredComments, currentUid: currentUid, completion: completion)
                } else {
                    // Fallback to all replies if blocking data not available
                    self.checkLikeStatusForComments(comments, currentUid: currentUid, completion: completion)
                }
            }
        }
    }

    // MARK: - Liking Comments

    func likeComment(_ comment: Comment, pod: Pod, completion: @escaping() -> Void) {
        guard let commentId = comment.id else { return }
        guard let podId = pod.id else { return }

        let functions = Functions.functions()
        let likeComment = functions.httpsCallable("likeComment")
        
        let data: [String: Any] = [
            "commentId": commentId,
            "podId": podId
        ]
        
        likeComment.call(data) { result, error in
            if let error = error {
                print("Error liking comment: \(error.localizedDescription)")
            } else {
                print("Comment liked successfully via cloud function")
            }
            completion()
        }
    }


    // MARK: - Liking Replies

    func likeReply(_ comment: Comment, reply: Comment, pod: Pod, completion: @escaping() -> Void) {
        guard let commentId = comment.id else { return }
        guard let replyId = reply.id else { return }
        guard let podId = pod.id else { return }

        let functions = Functions.functions()
        let likeReply = functions.httpsCallable("likeReply")
        
        let data: [String: Any] = [
            "commentId": commentId,
            "replyId": replyId,
            "podId": podId
        ]
        
        likeReply.call(data) { result, error in
            if let error = error {
                print("Error liking reply: \(error.localizedDescription)")
            } else {
                print("Reply liked successfully via cloud function")
            }
            completion()
        }
    }

    // MARK: - Unliking Replies

    func unlikeReply(_ comment: Comment, reply: Comment, pod: Pod, completion: @escaping() -> Void) {
        guard let commentId = comment.id else { return }
        guard let replyId = reply.id else { return }
        guard let podId = pod.id else { return }

        let functions = Functions.functions()
        let unlikeReply = functions.httpsCallable("unlikeReply")
        
        let data: [String: Any] = [
            "commentId": commentId,
            "replyId": replyId,
            "podId": podId
        ]
        
        unlikeReply.call(data) { result, error in
            if let error = error {
                print("Error unliking reply: \(error.localizedDescription)")
            } else {
                print("Reply unliked successfully via cloud function")
            }
            completion()
        }
    }

    // MARK: - Replying to Comments

    func replyToComment(_ comment: Comment, pod: Pod, caption: String, completion: @escaping() -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { 
            print("❌ CommentService: No authenticated user for reply")
            return 
        }
        guard let commentId = comment.id else { 
            print("❌ CommentService: No comment ID for reply")
            return 
        }
        guard let podId = pod.id else { 
            print("❌ CommentService: No pod ID for reply")
            return 
        }

        print("💬 CommentService: Creating reply to comment \(commentId) in pod \(podId)")

        let currentTime = Timestamp(date: Date())
        
        // Create complete reply data with all required fields
        let data: [String: Any] = [
            "uid": uid,
            "caption": caption,
            "likes": 0,
            "replyCount": 0,
            "timestamp": currentTime,
            "isActive": true,
            "createdAt": currentTime,
            "updatedAt": currentTime,
            "version": 1,
            "podId": podId,
            "isReported": false
        ]

        print("💬 CommentService: Reply data prepared, uploading to Firestore...")

        // Upload reply data to Firestore
        Firestore.firestore().collection("pods")
            .document(podId)
            .collection("pod-comments")
            .document(commentId)
            .collection("comment-replies")
            .addDocument(data: data) { error in
                if let error = error {
                    print("❌ CommentService: Error replying to comment: \(error.localizedDescription)")
                    completion()
                    return
                }
                
                print("✅ CommentService: Reply uploaded successfully, updating parent comment reply count...")
                
                // Update reply count in the original comment
                Firestore.firestore().collection("pods").document(podId).collection("pod-comments").document(commentId)
                    .updateData(["replyCount": FieldValue.increment(Int64(1))]) { updateError in
                        if let updateError = updateError {
                            print("❌ CommentService: Error updating reply count: \(updateError.localizedDescription)")
                        } else {
                            print("✅ CommentService: Reply count updated successfully")
                        }
                        completion()
                    }
            }
    }

    // MARK: - Unliking Comments

    func unlikeComment(_ comment: Comment, pod: Pod, completion: @escaping() -> Void) {
        guard let commentId = comment.id else { return }
        guard let podId = pod.id else { return }

        let functions = Functions.functions()
        let unlikeComment = functions.httpsCallable("unlikeComment")
        
        let data: [String: Any] = [
            "commentId": commentId,
            "podId": podId
        ]
        
        unlikeComment.call(data) { result, error in
            if let error = error {
                print("Error unliking comment: \(error.localizedDescription)")
            } else {
                print("Comment unliked successfully via cloud function")
            }
            completion()
        }
    }

    // MARK: - Deleting Comments

    func deleteComment(_ comment: Comment, pod: Pod, completion: @escaping(Bool) -> Void) {
        guard let commentId = comment.id else {
            completion(false)
            return
        }
        guard let podId = pod.id else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let commentRef = db.collection("pods").document(podId).collection("pod-comments").document(commentId)

        // Delete the comment document
        commentRef.delete { error in
            if let error = error {
                print("Error deleting comment: \(error.localizedDescription)")
                completion(false)
                return
            }

            // Decrement comments count for the pod
            self.decrementPodComments(podId: podId)

            // Clean up any user likes for this comment
            self.cleanupCommentLikes(commentId: commentId) {
                completion(true)
            }
        }
    }

    // MARK: - Deleting Replies

    func deleteReply(_ reply: Comment, parentComment: Comment, pod: Pod, completion: @escaping(Bool) -> Void) {
        guard let replyId = reply.id else {
            completion(false)
            return
        }
        guard let commentId = parentComment.id else {
            completion(false)
            return
        }
        guard let podId = pod.id else {
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let replyRef = db.collection("pods").document(podId).collection("pod-comments").document(commentId)
            .collection("comment-replies").document(replyId)

        // Delete the reply document
        replyRef.delete { error in
            if let error = error {
                print("Error deleting reply: \(error.localizedDescription)")
                completion(false)
                return
            }

            // Decrement the reply count in the parent comment
            let commentRef = db.collection("pods").document(podId).collection("pod-comments").document(commentId)
            commentRef.updateData([
                "replyCount": FieldValue.increment(Int64(-1))
            ]) { error in
                if let error = error {
                    print("Error updating reply count: \(error)")
                }
            }

            // Clean up any user likes for this reply
            self.cleanupCommentLikes(commentId: replyId) {
                completion(true)
            }
        }
    }

    // MARK: - Cleanup Comment Likes

    private func cleanupCommentLikes(commentId: String, completion: @escaping() -> Void) {
        let db = Firestore.firestore()
        
        // Since we can't efficiently query collection groups by document ID,
        // we'll skip the cleanup for now. The likes will be orphaned but won't affect functionality.
        // In a production app, you might want to implement a background job to clean these up periodically.
        
        print("Note: Comment likes cleanup skipped for comment ID: \(commentId)")
        completion()
        
        // Alternative approach: If you need to clean up likes, you could:
        // 1. Store the user IDs who liked the comment in the comment document itself
        // 2. Use that list to directly delete the like documents
        // 3. Or implement a background cleanup job
    }

    // MARK: - Checking If User Liked Comment

    func checkIfUserLikedComment(_ comment: Comment, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let commentId = comment.id else { return }

        // Check if the user liked the comment
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-comment-likes")
            .document(commentId).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                completion(snapshot.exists)
            }
    }
    
    /// Checks like status for multiple comments efficiently
    private func checkLikeStatusForComments(_ comments: [Comment], currentUid: String, completion: @escaping([Comment]) -> Void) {
        guard !comments.isEmpty else {
            completion(comments)
            return
        }
        
        // Get all comment IDs
        let commentIds = comments.compactMap { $0.id }
        
        // Batch fetch all like documents for the current user
        let userLikesRef = Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("user-comment-likes")
        
        // Use a dispatch group to wait for all queries to complete
        let group = DispatchGroup()
        var likedCommentIds = Set<String>()
        
        // Process comments in batches to avoid Firestore query limits
        let batchSize = 10
        for i in stride(from: 0, to: commentIds.count, by: batchSize) {
            let endIndex = min(i + batchSize, commentIds.count)
            let batch = Array(commentIds[i..<endIndex])
            
            group.enter()
            
            // Query for this batch of comment IDs
            userLikesRef.whereField(FieldPath.documentID(), in: batch).getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let documents = snapshot?.documents {
                    for document in documents {
                        likedCommentIds.insert(document.documentID)
                    }
                }
            }
        }
        
        // When all queries complete, update the comments with like status
        group.notify(queue: .main) {
            var updatedComments = comments
            for i in 0..<updatedComments.count {
                if let commentId = updatedComments[i].id {
                    updatedComments[i].didLike = likedCommentIds.contains(commentId)
                }
            }
            completion(updatedComments)
        }
    }

    // MARK: - Check If User Liked Reply

    func checkIfUserLikedReply(_ reply: Comment, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        guard let replyId = reply.id else {
            completion(false)
            return
        }

        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-comment-likes")
            .document(replyId)
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot else {
                    completion(false)
                    return
                }
                completion(snapshot.exists)
            }
    }
}
