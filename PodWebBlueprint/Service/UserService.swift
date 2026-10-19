//
//  UserService.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/20/22.
//


import Firebase
import FirebaseFunctions
import FirebaseFirestore
import UIKit
import FirebaseAuth
struct UserService {
    var collectionRef = Firestore.firestore().collection("users")
    private let blockService = BlockService()
    func fetchUser(withUid uid: String, completion: @escaping(Result<User, Error>) -> Void) {
        print("[UserService] Fetching user with UID: \(uid)")
        Firestore.firestore().collection("users")
            .document(uid)
            .getDocument { snapshot, error in
                if let error = error {
                    print("[UserService] Error fetching user with UID \(uid): \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                guard let snapshot = snapshot, snapshot.exists else {
                    let error = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document with UID \(uid) does not exist"])
                    print("[UserService] User document with UID \(uid) does not exist")
                    completion(.failure(error))
                    return
                }
                do {
                    let user = try snapshot.data(as: User.self)
                    print("[UserService] Successfully fetched user: \(user.username)")
                    completion(.success(user))
                } catch {
                    print("[UserService] Error parsing user data for UID \(uid): \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }
    func searchUsers(query: String, lastDocument: DocumentSnapshot? = nil, completion: @escaping ([User], DocumentSnapshot?) -> Void) {
            var queryRef = collectionRef
                .whereField("username", isGreaterThanOrEqualTo: query.lowercased())
                .whereField("username", isLessThan: query.lowercased() + "~")
                .order(by: "username")
                .limit(to: 25)
            if let lastDocument = lastDocument {
                queryRef = queryRef.start(afterDocument: lastDocument)
            }
            queryRef.getDocuments { snapshot, error in
                    guard let documents = snapshot?.documents else {
                        print("Error fetching documents: \(error?.localizedDescription ?? "Unknown error")")
                        completion([], nil)
                        return
                    }
                    let resultUsers = documents.compactMap { try? $0.data(as: User.self) }
                        .filter { user in
                            let isDeleted = user.isDeleted ?? false
                            let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                            if isDeleted {
                                print("[UserService] Filtering out deleted account: \(user.username)")
                            }
                            if isAnonymous {
                                print("[UserService] Filtering out anonymous account: \(user.username)")
                            }
                            return !isDeleted && !isAnonymous
                        }
                    let sortedUsers = resultUsers.sorted { user1, user2 in
                        let user1ExactMatch = user1.username.lowercased() == query.lowercased()
                        let user2ExactMatch = user2.username.lowercased() == query.lowercased()
                        if user1ExactMatch != user2ExactMatch {
                            return user1ExactMatch
                        }
                        let user1StartsWith = user1.username.lowercased().hasPrefix(query.lowercased())
                        let user2StartsWith = user2.username.lowercased().hasPrefix(query.lowercased())
                        if user1StartsWith != user2StartsWith {
                            return user1StartsWith
                        }
                        let user1Followers = user1.followers
                        let user2Followers = user2.followers
                        if user1Followers != user2Followers {
                            return user1Followers > user2Followers
                        }
                        if user1.isVerified != user2.isVerified {
                            return user1.isVerified
                        }
                        if let user1Created = user1.createdAt, let user2Created = user2.createdAt {
                            return user1Created.dateValue() > user2Created.dateValue()
                        }
                        return false
                    }
                    let topResults = Array(sortedUsers.prefix(10))
                    print("[UserService] Search results: \(resultUsers.count) found, \(topResults.count) returned after popularity sorting")
                    guard let currentUid = Auth.auth().currentUser?.uid else {
                        let lastDocument = documents.last
                        completion(topResults, lastDocument)
                        return
                    }
                    Firestore.firestore().collection("users").document(currentUid).getDocument { snapshot, error in
                        if let userData = snapshot?.data(),
                           let blockedUsers = userData["blockedUsers"] as? [String] {
                            let filteredUsers = resultUsers.filter { user in
                                let isBlocked = blockedUsers.contains(user.uid)
                                if isBlocked {
                                    print("[UserService] Filtering out blocked user: \(user.uid)")
                                }
                                return !isBlocked
                            }
                            let lastDocument = documents.last
                            let sortedFilteredUsers = filteredUsers.sorted { user1, user2 in
                                let user1Followers = user1.followers
                                let user2Followers = user2.followers
                                return user1Followers > user2Followers
                            }
                            let topFilteredResults = Array(sortedFilteredUsers.prefix(10))
                            completion(topFilteredResults, lastDocument)
                        } else {
                            let lastDocument = documents.last
                            completion(topResults, lastDocument)
                        }
                    }
                }
        }
    func fetchUsers(limit: Int = 20, lastDocument: DocumentSnapshot? = nil, completion: @escaping(Result<([User], DocumentSnapshot?), Error>) -> Void) {
        print("[UserService] Fetching users with limit: \(limit)")
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            print("[UserService] Error: User not authenticated")
            completion(.failure(error))
            return
        }
        var query = Firestore.firestore().collection("users")
            .order(by: "username")
            .limit(to: limit)
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        query.getDocuments { snapshot, error in
            if let error = error {
                print("[UserService] Error fetching users: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            guard let documents = snapshot?.documents else {
                let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No documents returned"])
                print("[UserService] Error: No documents returned")
                completion(.failure(error))
                return
            }
            let users = documents.compactMap { document -> User? in
                do {
                    let user = try document.data(as: User.self)
                    guard user.id != currentUserId else { return nil }
                    return user
                } catch {
                    print("[UserService] Error parsing user data: \(error.localizedDescription)")
                    return nil
                }
            }
            print("[UserService] Successfully parsed \(users.count) users")
            Firestore.firestore().collection("users").document(currentUserId).getDocument { snapshot, error in
                if let error = error {
                    print("[UserService] Error fetching current user for blocking check: \(error.localizedDescription)")
                    let lastDocument = documents.last
                    completion(.success((users, lastDocument)))
                    return
                }
                if let userData = snapshot?.data(),
                   let blockedUsers = userData["blockedUsers"] as? [String] {
                    let filteredUsers = users.filter { user in
                        let isBlocked = blockedUsers.contains(user.uid)
                        if isBlocked {
                            print("[UserService] Filtering out blocked user: \(user.uid)")
                        }
                        return !isBlocked
                    }
                    let lastDocument = documents.last
                    print("[UserService] Successfully filtered users: \(filteredUsers.count) after blocking")
                    completion(.success((filteredUsers, lastDocument)))
                } else {
                    let lastDocument = documents.last
                    print("[UserService] No blocking data available, returning all users: \(users.count)")
                    completion(.success((users, lastDocument)))
                }
            }
        }
    }
    func searchUsers(query: String, limit: Int = 20, completion: @escaping(Result<[User], Error>) -> Void) {
        print("[UserService] Searching users with query: '\(query)', limit: \(limit)")
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            print("[UserService] Error: User not authenticated")
            completion(.failure(error))
            return
        }
        Task {
            let canSearch = await SearchRateLimiter.shared.canPerformSearch(userId: currentUserId)
            if !canSearch {
                await SearchRateLimiter.shared.recordBlockedSearch(userId: currentUserId, reason: "Rate limit exceeded")
                await MainActor.run {
                    let error = NSError(domain: "UserService", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limit exceeded"])
                    print("[UserService] Error: Rate limit exceeded")
                    completion(.failure(error))
                }
                return
            }
            await SearchRateLimiter.shared.recordSearch(userId: currentUserId)
            Firestore.firestore().collection("users")
                .whereField("username", isGreaterThanOrEqualTo: query)
                .whereField("username", isLessThan: query + "z")
                .limit(to: limit)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("[UserService] Error searching users: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    guard let documents = snapshot?.documents else {
                        let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No documents returned"])
                        print("[UserService] Error: No documents returned")
                        completion(.failure(error))
                        return
                    }
                    let users = documents.compactMap { document -> User? in
                        do {
                            let user = try document.data(as: User.self)
                            guard user.id != currentUserId else { return nil }
                            let isDeleted = user.isDeleted ?? false
                            if isDeleted {
                                print("[UserService] Filtering out deleted account: \(user.username)")
                                return nil
                            }
                            if user.username.lowercased().hasPrefix("anon_") {
                                print("[UserService] Filtering out anonymous account: \(user.username)")
                                return nil
                            }
                            return user
                        } catch {
                            print("[UserService] Error parsing user data: \(error.localizedDescription)")
                            return nil
                        }
                    }
                    print("[UserService] Successfully parsed \(users.count) users from search")
                    Firestore.firestore().collection("users").document(currentUserId).getDocument { snapshot, error in
                        if let error = error {
                            print("[UserService] Error fetching current user for blocking check: \(error.localizedDescription)")
                            completion(.success(users))
                            return
                        }
                        if let userData = snapshot?.data() {
                            let blockedUsers = userData["blockedUsers"] as? [String] ?? []
                            let blockedBy = userData["blockedBy"] as? [String] ?? []
                            let allBlockedUserIds = Set(blockedUsers + blockedBy)
                            let filteredUsers = users.filter { user in
                                let isBlocked = allBlockedUserIds.contains(user.uid)
                                if isBlocked {
                                    if blockedUsers.contains(user.uid) {
                                        print("[UserService] Filtering out user you blocked: \(user.uid)")
                                    } else if blockedBy.contains(user.uid) {
                                        print("[UserService] Filtering out user who blocked you: \(user.uid)")
                                    }
                                }
                                return !isBlocked
                            }
                            print("[UserService] Filtered \(users.count) users down to \(filteredUsers.count) using comprehensive blocking check")
                            completion(.success(filteredUsers))
                        } else {
                            print("[UserService] No blocking data available, returning all users: \(users.count)")
                            completion(.success(users))
                        }
                    }
                }
        }
    }
    func fetchUserPlaylists(uid: String, completion: @escaping([Playlist]) -> Void) {
        Firestore.firestore().collection("users").document(uid).collection("user-playlists")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("[UserService] Error fetching user playlist references: \(error?.localizedDescription ?? "Unknown error")")
                    completion([])
                    return
                }
                if documents.isEmpty {
                    completion([])
                    return
                }
                let playlistIds = documents.compactMap { document -> String? in
                    let data = document.data()
                    return data["playlistId"] as? String
                }
                if playlistIds.isEmpty {
                    completion([])
                    return
                }
                let group = DispatchGroup()
                var playlists: [Playlist] = []
                for playlistId in playlistIds {
                    group.enter()
                    Firestore.firestore().collection("playlists").document(playlistId)
                        .getDocument { snapshot, error in
                            defer { group.leave() }
                            if let error = error {
                                print("[UserService] Error fetching playlist \(playlistId): \(error.localizedDescription)")
                                return
                            }
                            guard let document = snapshot, document.exists else {
                                print("[UserService] Playlist \(playlistId) not found in global collection")
                                return
                            }
                            do {
                                let playlist = try document.data(as: Playlist.self)
                                playlists.append(playlist)
                            } catch {
                                print("[UserService] Error decoding playlist \(playlistId): \(error.localizedDescription)")
                            }
                        }
                }
                group.notify(queue: .main) {
                    let sortedPlaylists = playlists.sorted { playlist1, playlist2 in
                        let date1 = playlist1.createdAt?.dateValue() ?? Date.distantPast
                        let date2 = playlist2.createdAt?.dateValue() ?? Date.distantPast
                        return date1 > date2
                    }
                    print("[UserService] Fetched \(sortedPlaylists.count) playlists from global collection")
                    completion(sortedPlaylists)
                }
            }
    }
    func followUser(user: User, completion: @escaping(Bool, String?) -> Void) {
        print("[UserService] Starting follow user: \(user.username)")
        guard let userId = user.id else {
            print("[UserService] Error: User ID is nil")
            completion(false, "User ID is nil")
            return
        }
        FollowRateLimiter.shared.canAttemptFollowUnfollow(targetUserId: userId) { allowed, reason in
            if !allowed {
                print("[UserService] Follow blocked by rate limiter - \(reason ?? "Unknown reason")")
                completion(false, "RATE_LIMITED")
                return
            }
            print("[UserService] Rate limit check passed, proceeding with follow")
            let functions = Functions.functions()
            let followUserFunction = functions.httpsCallable("followUser")
            let data = ["userId": userId]
            followUserFunction.call(data) { result, error in
                if let error = error {
                    print("[UserService] Error calling followUser cloud function: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                if let data = result?.data as? [String: Any],
                   let success = data["success"] as? Bool,
                   success {
                    print("[UserService] User followed successfully via cloud function: \(user.username)")
                    FollowRateLimiter.shared.recordFollowUnfollowAttempt(targetUserId: userId, action: "follow") { rateLimitSuccess in
                        if rateLimitSuccess {
                            print("[UserService] Recorded follow attempt successfully")
                        } else {
                            print("[UserService] Failed to record follow attempt")
                        }
                    }
                    completion(true, nil)
                } else {
                    print("[UserService] Failed to follow user via cloud function: \(user.username)")
                    completion(false, "Failed to follow user")
                }
            }
        }
    }
    func unfollowUser(user: User, completion: @escaping(Bool, String?) -> Void) {
        print("[UserService] Starting unfollow user: \(user.username)")
        guard let userId = user.id else {
            print("[UserService] Error: User ID is nil")
            completion(false, "User ID is nil")
            return
        }
        FollowRateLimiter.shared.canAttemptFollowUnfollow(targetUserId: userId) { allowed, reason in
            if !allowed {
                print("[UserService] Unfollow blocked by rate limiter - \(reason ?? "Unknown reason")")
                completion(false, "RATE_LIMITED")
                return
            }
            print("[UserService] Rate limit check passed, proceeding with unfollow")
            let functions = Functions.functions()
            let unfollowUserFunction = functions.httpsCallable("unfollowUser")
            let data = ["userId": userId]
            unfollowUserFunction.call(data) { result, error in
                if let error = error {
                    print("[UserService] Error calling unfollowUser cloud function: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                    return
                }
                if let data = result?.data as? [String: Any],
                   let success = data["success"] as? Bool,
                   success {
                    print("[UserService] User unfollowed successfully via cloud function: \(user.username)")
                    FollowRateLimiter.shared.recordFollowUnfollowAttempt(targetUserId: userId, action: "unfollow") { rateLimitSuccess in
                        if rateLimitSuccess {
                            print("[UserService] Recorded unfollow attempt successfully")
                        } else {
                            print("[UserService] Failed to record unfollow attempt")
                        }
                    }
                    completion(true, nil)
                } else {
                    print("[UserService] Failed to unfollow user via cloud function: \(user.username)")
                    completion(false, "Failed to unfollow user")
                }
            }
        }
    }
    func removeFollower(user: User, completion: @escaping(Bool) -> Void) {
        print("[UserService] Starting remove follower: \(user.username)")
        guard let userId = user.id else {
            print("[UserService] Error: User ID is nil")
            completion(false)
            return
        }
        let functions = Functions.functions()
        let removeFollowerFunction = functions.httpsCallable("removeFollower")
        let data = ["userId": userId]
        removeFollowerFunction.call(data) { result, error in
            if let error = error {
                print("[UserService] Error calling removeFollower cloud function: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("[UserService] Follower removed successfully via cloud function: \(user.username)")
                completion(true)
            } else {
                print("[UserService] Failed to remove follower via cloud function: \(user.username)")
                completion(false)
            }
        }
    }
    func checkIfUserIsFollowed(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-following")
            .document(userId).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                completion(snapshot.exists)
            }
    }
    func checkIfCurrentUserIsFollowed(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("user-following")
            .document(uid).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                print("CHECK IF CURRENT USER IS FOLLOWED \(snapshot.exists)")
                completion(snapshot.exists)
            }
    }
    func createPlaylist(title: String, podIds: [String], thumbnailUrl: String, description: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }
        let playlistId = UUID().uuidString
        let playlistData: [String: Any] = [
            "title": title,
            "thumbnailUrl": thumbnailUrl,
            "userId": uid,
            "likes": 0,
            "version": 1,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "description": description ?? "",
            "podCount": podIds.count,
            "isPublic": true,
            "isActive": true
        ]
        let globalPlaylistRef = Firestore.firestore().collection("playlists").document(playlistId)
        globalPlaylistRef.setData(playlistData) { error in
            if let error = error {
                print("Error adding playlist to global collection: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            let playlistPodsCollectionRef = globalPlaylistRef.collection("playlist-pods")
            var successCount = 0
            var errorOccurred = false
            for podId in podIds {
                let podDocRef = playlistPodsCollectionRef.document(podId)
                podDocRef.setData([:]) { error in
                    if let error = error {
                        print("Error adding pod to playlist: \(error.localizedDescription)")
                        errorOccurred = true
                    } else {
                        print("Pod added to playlist successfully.")
                        successCount += 1
                    }
                    if successCount + (errorOccurred ? 0 : 0) == podIds.count {
                        self.addPlaylistReferenceToUser(uid: uid, playlistId: playlistId) { success in
                            if success {
                                print("Playlist created successfully in global collection with user reference")
                                completion(true, nil)
                            } else {
                                print("Failed to add playlist reference to user")
                                completion(false, NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to add playlist reference to user."]))
                            }
                        }
                    }
                }
            }
        }
    }
    private func addPlaylistReferenceToUser(uid: String, playlistId: String, completion: @escaping (Bool) -> Void) {
        let userPlaylistRef = Firestore.firestore().collection("users").document(uid).collection("user-playlists").document(playlistId)
        let referenceData: [String: Any] = [
            "playlistId": playlistId,
            "createdAt": FieldValue.serverTimestamp()
        ]
        userPlaylistRef.setData(referenceData) { error in
            if let error = error {
                print("Error adding playlist reference to user: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Playlist reference added to user subcollection")
                completion(true)
            }
        }
    }
    func deletePlaylist(withPlaylistId playlistId: String, uid: String, completion: @escaping (Bool, Error?) -> Void) {
        let globalPlaylistRef = Firestore.firestore().collection("playlists").document(playlistId)
        globalPlaylistRef.delete { error in
            if let error = error {
                print("[UserService] Error deleting playlist from global collection: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            let userPlaylistRef = Firestore.firestore().collection("users").document(uid).collection("user-playlists").document(playlistId)
            userPlaylistRef.delete { error in
                if let error = error {
                    print("[UserService] Error deleting playlist reference from user: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("[UserService] Playlist deleted successfully from global collection and user reference")
                    completion(true, nil)
                }
            }
        }
    }
    func fetchUserFollowing(forUid uid: String, lastUser: User? = nil, limit: Int = 10, completion: @escaping([User]) -> Void) {
        var followedUsers = [User]()
        let group = DispatchGroup()
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-following")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                if documents.isEmpty {
                    completion([])
                    return
                }
                var shouldStartCollecting = lastUser == nil
                var collectedCount = 0
                documents.forEach { doc in
                    let userId = doc.documentID
                    if !shouldStartCollecting && userId == lastUser?.uid {
                        shouldStartCollecting = true
                        return
                    }
                    if shouldStartCollecting && collectedCount < limit {
                        group.enter()
                        collectedCount += 1
                        Firestore.firestore().collection("users")
                            .document(userId)
                            .getDocument { snapshot, _ in
                                defer { group.leave() }
                                guard let user = try? snapshot?.data(as: User.self) else { return }
                                followedUsers.append(user)
                            }
                    }
                }
                group.notify(queue: .main) {
                    let sortedUsers = followedUsers.sorted { user1, user2 in
                        user1.followers > user2.followers
                    }
                    completion(sortedUsers)
                }
            }
    }
    func fetchUserFollowers(forUid uid: String, lastUser: User? = nil, limit: Int = 10, completion: @escaping([User]) -> Void) {
        var followers = [User]()
        let group = DispatchGroup()
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("user-followers")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                if documents.isEmpty {
                    completion([])
                    return
                }
                var shouldStartCollecting = lastUser == nil
                var collectedCount = 0
                documents.forEach { doc in
                    let userId = doc.documentID
                    if !shouldStartCollecting && userId == lastUser?.uid {
                        shouldStartCollecting = true
                        return
                    }
                    if shouldStartCollecting && collectedCount < limit {
                        group.enter()
                        collectedCount += 1
                        Firestore.firestore().collection("users")
                            .document(userId)
                            .getDocument { snapshot, _ in
                                defer { group.leave() }
                                guard let user = try? snapshot?.data(as: User.self) else { return }
                                followers.append(user)
                            }
                    }
                }
                group.notify(queue: .main) {
                    let sortedUsers = followers.sorted { user1, user2 in
                        user1.followers > user2.followers
                    }
                    completion(sortedUsers)
                }
            }
    }
    func addFriend(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        self.createFriendshipAndConversation(uid: uid, userId: userId) {
            completion(true)
        }
    }
    private func ensureFriendshipDocuments(uid: String, userId: String, completion: @escaping() -> Void) {
        let data = ["email": "", "username": "", "fullname": "", "uid": userId, "followers": 0, "profileImageUrl": "", "isVerified": false, "following": 0, "podCount": 0] as [String: Any]
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .document(userId)
            .setData(data)
        let currentData = ["email": "", "username": "", "fullname": "", "uid": uid, "followers": 0, "profileImageUrl": "", "isVerified": false, "following": 0, "podCount": 0] as [String: Any]
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("friends")
            .document(uid)
            .setData(currentData) { _ in
                completion()
            }
    }
    private func createFriendshipAndConversation(uid: String, userId: String, completion: @escaping() -> Void) {
        fetchUser(withUid: uid) { result in
            switch result {
            case .success(let currentUser):
            let userData = ["email": currentUser.email, "username": currentUser.username, "fullname": currentUser.fullname, "uid": currentUser.uid, "followers": currentUser.followers, "profileImageUrl": currentUser.profileImageUrl, "isVerified": currentUser.isVerified, "following": currentUser.following, "podCount": currentUser.podCount] as [String: Any]
                Firestore.firestore().collection("users")
                    .document(uid)
                    .collection("friends")
                    .document(userId)
                    .setData(userData)
                Firestore.firestore().collection("users")
                    .document(userId)
                    .collection("friends")
                    .document(uid)
                    .setData(userData) { _ in
                        let conversationService = ConversationService()
                        conversationService.createConversation(participants: [uid, userId]) { conversationId in
                            if let conversationId = conversationId {
                                print("Conversation created successfully: \(conversationId)")
                            } else {
                                print("Failed to create conversation")
                            }
                            completion()
                        }
                    }
            case .failure(let error):
                print("Error fetching current user for friendship: \(error.localizedDescription)")
                completion()
            }
        }
    }
    func unaddFriend(user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .document(userId)
            .delete()
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("friends")
            .document(uid)
            .delete() { _ in
                completion(true)
            }
    }
    func removeFriendship(with user: User, completion: @escaping(Bool) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let userId = user.id else { return }
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .document(userId)
            .delete()
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("friends")
            .document(uid)
            .delete() { _ in
                print("Friendship removed for users \(uid) and \(userId)")
                completion(true)
            }
    }
    func fetchFriends(withUid uid: String, completion: @escaping([User]) -> Void) {
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("friends")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else { return }
                let users = documents.compactMap({ try? $0.data(as: User.self)})
                completion(users)
            }
    }
    func isUsernameInUse(username: String, completion: @escaping(Bool) -> Void) {
        Firestore.firestore().collection("usernames")
            .document(username).getDocument { snapshot, _ in
                guard let snapshot = snapshot else { return }
                completion(snapshot.exists)
            }
    }
    func addUsername(username: String) {
        Firestore.firestore().collection("usernames")
            .document(username)
            .setData([:])
    }
    func deleteUsername(username: String) {
        Firestore.firestore().collection("usernames")
            .document(username)
            .delete()
    }
    func editProfile(withUid uid: String, fullname: String, username: String, bio: String, link: String, completion: @escaping(Result<User, Error>) -> Void) {
        print("[UserService] Starting profile edit for user: \(uid)")
        print("[UserService] New username: \(username), fullname: \(fullname)")
        guard !username.isEmpty else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Username cannot be empty"])
            print("[UserService] Error: Username cannot be empty")
            completion(.failure(error))
            return
        }
        guard username.count >= 3 else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Username must be at least 3 characters"])
            print("[UserService] Error: Username must be at least 3 characters")
            completion(.failure(error))
            return
        }
        guard !fullname.isEmpty else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Full name cannot be empty"])
            print("[UserService] Error: Full name cannot be empty")
            completion(.failure(error))
            return
        }
        guard bio.count <= 500 else {
            let error = NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bio must be 500 characters or less"])
            print("[UserService] Error: Bio must be 500 characters or less")
            completion(.failure(error))
            return
        }
        fetchUser(withUid: uid) { result in
            switch result {
            case .success(let currentUser):
                if currentUser.username.lowercased() != username.lowercased() {
                    print("[UserService] Username changed, checking availability: \(username)")
                    self.isUsernameInUse(username: username) { isInUse in
                        if isInUse {
                            let error = NSError(domain: "UserService", code: 409, userInfo: [NSLocalizedDescriptionKey: "Username is already taken"])
                            print("[UserService] Error: Username is already taken")
                            completion(.failure(error))
                            return
                        }
                        print("[UserService] Username available, proceeding with update")
                        self.updateProfile(uid: uid, fullname: fullname, username: username, bio: bio, link: link, completion: completion)
                    }
                } else {
                    print("[UserService] Username unchanged, proceeding with update")
                    self.updateProfile(uid: uid, fullname: fullname, username: username, bio: bio, link: link, completion: completion)
                }
            case .failure(let error):
                print("[UserService] Error fetching current user: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    private func updateProfile(uid: String, fullname: String, username: String, bio: String, link: String, completion: @escaping(Result<User, Error>) -> Void) {
        print("[UserService] Starting profile update for user: \(uid)")
        fetchUser(withUid: uid) { result in
            switch result {
            case .success(let currentUser):
                var updatedUser = currentUser
                updatedUser.username = username
                updatedUser.fullname = fullname
                updatedUser.bio = bio
                updatedUser.link = link
                updatedUser.lastUpdated = Timestamp()
                let userRef = Firestore.firestore().collection("users").document(uid)
                Firestore.firestore().runTransaction { transaction, errorPointer in
                    let userDoc: DocumentSnapshot
                    do {
                        userDoc = try transaction.getDocument(userRef)
                    } catch let fetchError as NSError {
                        errorPointer?.pointee = fetchError
                        return nil
                    }
                    guard userDoc.exists else {
                        let error = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User document not found"])
                        errorPointer?.pointee = error
                        return nil
                    }
                    guard let currentUserData = try? userDoc.data(as: User.self) else {
                        let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user data"])
                        errorPointer?.pointee = error
                        return nil
                    }
                    if let currentVersion = currentUser.version,
                       let fetchedVersion = currentUserData.version,
                       currentVersion != fetchedVersion {
                        let error = NSError(domain: "UserService", code: 409, userInfo: [NSLocalizedDescriptionKey: "User was updated by another client. Please refresh and try again."])
                        errorPointer?.pointee = error
                        return nil
                    }
                    do {
                        try transaction.setData(from: updatedUser, forDocument: userRef)
                        return updatedUser
                    } catch {
                        errorPointer?.pointee = error as NSError
                        return nil
                    }
                } completion: { result, error in
                if let error = error {
                        print("[UserService] Error updating profile: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else if let updatedUser = result as? User {
                        print("[UserService] Profile updated successfully")
                        completion(.success(updatedUser))
                } else {
                        let error = NSError(domain: "UserService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unexpected error during profile update"])
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                print("[UserService] Error fetching current user for update: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    func checkIfUsersAreFriends(withUid uid: String, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("friends")
            .document(uid)
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot, snapshot.exists else {
                    completion(false)
                    return
                }
                Firestore.firestore().collection("users")
                    .document(uid)
                    .collection("friends")
                    .document(currentUid)
                    .getDocument { snapshot, _ in
                        guard let snapshot = snapshot else {
                            completion(false)
                            return
                        }
                        completion(snapshot.exists)
                    }
            }
    }
    func handleMutualFollow(withUid uid: String, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        let functions = Functions.functions()
        let handleMutualFollowFunction = functions.httpsCallable("handleMutualFollow")
        let data = ["userId": uid]
        handleMutualFollowFunction.call(data) { result, error in
            if let error = error {
                print("Error calling handleMutualFollow cloud function: \(error)")
                completion(false)
                return
            }
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                print("Mutual follow handled successfully via cloud function")
                completion(true)
            } else {
                print("Failed to handle mutual follow via cloud function")
                completion(false)
            }
        }
    }
    func handlePrivateToPublicTransition(completion: @escaping(Bool, String, Int) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false, "User not authenticated", 0)
            return
        }
        let functions = Functions.functions()
        let handleTransitionFunction = functions.httpsCallable("handlePrivateToPublicTransition")
        handleTransitionFunction.call() { result, error in
            if let error = error {
                print("Error calling handlePrivateToPublicTransition cloud function: \(error)")
                completion(false, "Failed to process follow requests", 0)
                return
            }
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool,
               success {
                let acceptedCount = data["acceptedCount"] as? Int ?? 0
                let message = data["message"] as? String ?? "Transition completed"
                print("Private-to-public transition completed: \(message)")
                completion(true, message, acceptedCount)
            } else {
                print("Failed to process private-to-public transition")
                completion(false, "Failed to process follow requests", 0)
            }
        }
    }
    func sendFollowRequest(to user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        guard let userId = user.id else {
            completion(false)
            return
        }
        fetchUser(withUid: currentUid) { result in
            switch result {
            case .success(let currentUser):
                let requestData = [
                    "requesterId": currentUid,
                    "requesterUsername": currentUser.username,
                    "requesterFullname": currentUser.fullname,
                    "requesterProfileImageUrl": currentUser.profileImageUrl,
                "timestamp": Date(),
                "status": "pending"
                ] as [String: Any]
                Firestore.firestore().collection("users")
                    .document(userId)
                    .collection("follow-requests")
                    .document(currentUid)
                    .setData(requestData) { error in
                        if let error = error {
                            print("Error sending follow request: \(error)")
                            completion(false)
                        } else {
                            let notificationService = NotificationService()
                            notificationService.createNotification(
                                type: .followRequest,
                                senderId: currentUid,
                                recipientId: userId,
                                completion: { notificationSuccess in
                                    if notificationSuccess {
                                        print("Follow request notification sent successfully")
                                    } else {
                                        print("Failed to send follow request notification")
                                    }
                                    completion(true)
                                }
                            )
                        }
                    }
            case .failure(let error):
                print("Error fetching current user for follow request: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    func checkIfFollowRequestSent(to user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        guard let userId = user.id else {
            completion(false)
            return
        }
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("follow-requests")
            .document(currentUid)
            .getDocument { snapshot, _ in
                guard let snapshot = snapshot else {
                    completion(false)
                    return
                }
                completion(snapshot.exists)
            }
    }
    func fetchFollowRequests(completion: @escaping([User]) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("follow-requests")
            .getDocuments { snapshot, _ in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                let requesterIds = documents.compactMap { document -> String? in
                    let data = document.data()
                    return data["requesterId"] as? String
                }
                let group = DispatchGroup()
                var users: [User] = []
                for requesterId in requesterIds {
                    group.enter()
                    self.fetchUser(withUid: requesterId) { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let fetchedUser):
                                users.append(fetchedUser)
                            case .failure(let error):
                                print("Error fetching follow request user: \(error.localizedDescription)")
                            }
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    let filteredUsers = users.filter { user in
                        let isDeleted = user.isDeleted ?? false
                        let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                        return !isDeleted && !isAnonymous
                    }
                    completion(filteredUsers)
                }
            }
    }
    func acceptFollowRequest(from user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        guard let userId = user.id else {
            completion(false)
            return
        }
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("follow-requests")
            .document(userId)
            .delete { error in
                if let error = error {
                    print("Error removing follow request: \(error)")
                    completion(false)
                    return
                }
                let functions = Functions.functions()
                let acceptFollowRequestFunction = functions.httpsCallable("acceptFollowRequest")
                let data = ["requesterId": userId]
                acceptFollowRequestFunction.call(data) { result, error in
                    if let error = error {
                        print("Error calling acceptFollowRequest cloud function: \(error)")
                        completion(false)
                        return
                    }
                    if let data = result?.data as? [String: Any],
                       let success = data["success"] as? Bool,
                       success {
                        print("Follow request accepted successfully")
                        completion(true)
                    } else {
                        print("Failed to accept follow request via cloud function")
                        completion(false)
                    }
                }
            }
    }
    func rejectFollowRequest(from user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        guard let userId = user.id else {
            completion(false)
            return
        }
        Firestore.firestore().collection("users")
            .document(currentUid)
            .collection("follow-requests")
            .document(userId)
            .delete { error in
                if let error = error {
                    print("Error rejecting follow request: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
    }
    func cancelFollowRequest(to user: User, completion: @escaping(Bool) -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        guard let userId = user.id else {
            completion(false)
            return
        }
        Firestore.firestore().collection("users")
            .document(userId)
            .collection("follow-requests")
            .document(currentUid)
            .delete { error in
                if let error = error {
                    print("Error canceling follow request: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
    }
    func countUserPods(withUid uid: String, completion: @escaping(Int) -> Void) {
        Firestore.firestore().collection("pods")
            .whereField("userId", isEqualTo: uid)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error counting user pods: \(error.localizedDescription)")
                    completion(0)
                    return
                }
                let count = snapshot?.documents.count ?? 0
                completion(count)
            }
    }
    func anonymizeUserAccount(completion: @escaping (Bool, Error?, String?) -> Void) {
        guard Auth.auth().currentUser != nil else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(false, error, nil)
            return
        }
        let functions = Functions.functions()
        let anonymizeFunction = functions.httpsCallable("anonymizeUserAccount")
        print("Starting account anonymization process...")
        anonymizeFunction.call([:]) { result, error in
            if let error = error {
                print("Error calling anonymizeUserAccount cloud function: \(error)")
                var userFriendlyMessage = "Failed to anonymize account. Please try again."
                let functionsError = error as NSError?
                if let errorDetails = functionsError?.userInfo["details"] as? String {
                    switch errorDetails {
                    case "User account not found":
                        userFriendlyMessage = "Account not found. Please contact support."
                    case "Unable to generate available username after multiple attempts":
                        userFriendlyMessage = "Unable to generate a unique username. Please try again."
                    default:
                        userFriendlyMessage = "Account anonymization failed: \(errorDetails)"
                    }
                } else if functionsError?.code == 16 {
                    userFriendlyMessage = "Authentication failed. Please log in again."
                }
                let processedError = NSError(domain: "UserService", code: functionsError?.code ?? -1, userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
                completion(false, processedError, nil)
                return
            }
            if let data = result?.data as? [String: Any],
               let success = data["success"] as? Bool {
                if success {
                    let podsDeleted = data["podsDeleted"] as? Int ?? 0
                    let message = data["message"] as? String ?? "Account anonymized successfully"
                    let authDeleted = data["authDeleted"] as? Bool ?? false
                    let summary = "Account anonymized successfully!\n• \(podsDeleted) pods deleted\n• Personal data cleared\n• Email freed for reuse"
                    print("Account anonymization completed: \(podsDeleted) pods deleted, auth deleted: \(authDeleted)")
                    completion(true, nil, summary)
                } else {
                    let errorMessage = data["message"] as? String ?? "Unknown error occurred"
                    let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    completion(false, error, nil)
                }
            } else {
                let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                completion(false, error, nil)
            }
        }
    }
    func downloadAccountData(completion: @escaping (Bool, Error?, [String: Any]?) -> Void) {
        guard Auth.auth().currentUser != nil else {
            let error = NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
            completion(false, error, nil)
            return
        }
        let functions = Functions.functions()
        let downloadFunction = functions.httpsCallable("downloadAccountData")
        print("Starting account data download...")
        downloadFunction.call([:]) { result, error in
            if let error = error {
                print("Error calling downloadAccountData cloud function: \(error)")
                var userFriendlyMessage = "Failed to download account data. Please try again."
                let functionsError = error as NSError?
                if let errorDetails = functionsError?.userInfo["details"] as? String {
                    if errorDetails.contains("once per month") {
                        userFriendlyMessage = errorDetails
                    } else {
                        userFriendlyMessage = "Account data download failed: \(errorDetails)"
                    }
                } else if functionsError?.code == 16 {
                    userFriendlyMessage = "Authentication failed. Please log in again."
                } else if functionsError?.code == 8 {
                    userFriendlyMessage = "Monthly download limit reached. Please try again next month."
                }
                let processedError = NSError(domain: "UserService", code: functionsError?.code ?? -1, userInfo: [NSLocalizedDescriptionKey: userFriendlyMessage])
                completion(false, processedError, nil)
                return
            }
            print("DEBUG: Raw response data: \(result?.data ?? "nil")")
            if let data = result?.data as? [String: Any] {
                print("DEBUG: Parsed data keys: \(Array(data.keys))")
                if let success = data["success"] as? Bool {
                    if success {
                        if let downloadInfo = data["downloadInfo"] as? [String: Any],
                           let userData = data["data"] as? [String: Any] {
                            print("Account data exported and uploaded successfully")
                            print("File: \(downloadInfo["fileName"] as? String ?? "Unknown")")
                            print("Download URL: \(downloadInfo["downloadUrl"] as? String ?? "No URL")")
                            print("Expires: \(downloadInfo["expiresAt"] as? String ?? "Unknown")")
                            self.storeDownloadInfo(downloadInfo: downloadInfo)
                            if let accountInfo = userData["accountInfo"] as? [String: Any] {
                                print("\n" + String(repeating: "=", count: 60))
                                print("ACCOUNT DATA EXPORT SUMMARY")
                                print(String(repeating: "=", count: 60))
                                print("ACCOUNT INFORMATION:")
                                print("   • Username: \(accountInfo["username"] as? String ?? "Unknown")")
                                print("   • Full Name: \(accountInfo["fullname"] as? String ?? "Unknown")")
                                print("   • Email: \(accountInfo["email"] as? String ?? "Unknown")")
                                print("   • Bio: \(accountInfo["bio"] as? String ?? "No bio")")
                                print("   • Followers: \(accountInfo["followersCount"] as? Int ?? 0)")
                                print("   • Following: \(accountInfo["followingCount"] as? Int ?? 0)")
                                print("   • Pods Created: \(accountInfo["podsCreatedCount"] as? Int ?? 0)")
                                print("   • Account Created: \(accountInfo["accountCreatedAt"] as? String ?? "Unknown")")
                            }
                            if let exportInfo = userData["exportInfo"] as? [String: Any] {
                                print("\n EXPORT STATISTICS:")
                                print("   • Total Pods: \(exportInfo["totalPods"] as? Int ?? 0)")
                                print("   • Total Followers: \(exportInfo["totalFollowers"] as? Int ?? 0)")
                                print("   • Total Following: \(exportInfo["totalFollowing"] as? Int ?? 0)")
                                print("   • Total Conversations: \(exportInfo["totalConversations"] as? Int ?? 0)")
                                print("   • Total Messages: \(exportInfo["totalMessages"] as? Int ?? 0)")
                                print("   • Total Comments: \(exportInfo["totalComments"] as? Int ?? 0)")
                                print("   • Total Playlists: \(exportInfo["totalPlaylists"] as? Int ?? 0)")
                                print("   • Total Notifications: \(exportInfo["totalNotifications"] as? Int ?? 0)")
                            }
                            print(String(repeating: "=", count: 60))
                            completion(true, nil, userData)
                        } else if let userData = data["data"] as? [String: Any] {
                            print("Account data collected successfully (upload failed, processing locally)")
                            self.createAndDownloadJSONFile(data: userData)
                            completion(true, nil, userData)
                        } else {
                            let errorMessage = data["message"] as? String ?? "Unknown error occurred"
                            let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                            completion(false, error, nil)
                        }
                    } else {
                        let errorMessage = data["message"] as? String ?? "Unknown error occurred"
                        let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        completion(false, error, nil)
                    }
                } else {
                    let error = NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                    completion(false, error, nil)
                }
            }
        }
    }
    private func storeDownloadInfo(downloadInfo: [String: Any]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let userDataRef = Firestore.firestore().collection("users").document(uid).collection("user-data")
        let lastDownloadData: [String: Any] = [
            "exportDate": downloadInfo["exportDate"] as? String ?? "",
            "fileName": downloadInfo["fileName"] as? String ?? "",
            "fileSize": downloadInfo["fileSize"] as? Int ?? 0,
            "expiresAt": downloadInfo["expiresAt"] as? String ?? "",
            "downloadUrl": downloadInfo["downloadUrl"] as? String ?? ""
        ]
        userDataRef.document("lastDownload").setData(lastDownloadData) { error in
            if let error = error {
                print("Error storing last download info: \(error)")
            } else {
                print("Last download info stored successfully")
            }
        }
    }
    func fetchLatestDownloadInfo(completion: @escaping ([String: Any]?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        let userDataRef = Firestore.firestore().collection("users").document(uid).collection("user-data")
        userDataRef.document("lastDownload").getDocument { snapshot, error in
            if let error = error {
                print("Error fetching last download info: \(error)")
                completion(nil)
                return
            }
            guard let data = snapshot?.data() else {
                completion(nil)
                return
            }
            completion(data)
        }
    }
    func canDownloadData(completion: @escaping (Bool, String?) -> Void) {
        fetchLatestDownloadInfo { downloadInfo in
            guard let downloadInfo = downloadInfo else {
                completion(true, nil)
                return
            }
            guard let exportDateString = downloadInfo["exportDate"] as? String else {
                completion(true, nil)
                return
            }
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let exportDate = dateFormatter.date(from: exportDateString) else {
                completion(true, nil)
                return
            }
            let calendar = Calendar.current
            let now = Date()
            let daysSinceLastDownload = calendar.dateComponents([.day], from: exportDate, to: now).day ?? 0
            if daysSinceLastDownload >= 30 {
                completion(true, nil)
            } else {
                let daysRemaining = 30 - daysSinceLastDownload
                completion(false, "You can download your data again in \(daysRemaining) days")
            }
        }
    }
    func createAndDownloadJSONFile(data: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) else {
            print("Error creating JSON data")
            return
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "account_data_export_\(timestamp).json"
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Error accessing documents directory")
            return
        }
        let fileURL = documentsPath.appendingPathComponent(filename)
        do {
            try jsonData.write(to: fileURL)
            print("JSON file created: \(fileURL.path)")
            let downloadInfo: [String: Any] = [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "fileName": filename,
                "fileSize": jsonData.count,
                "expiresAt": ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())
            ]
            self.storeDownloadInfo(downloadInfo: downloadInfo)
            DispatchQueue.main.async {
                self.shareJSONFile(fileURL: fileURL, filename: filename)
            }
        } catch {
            print("Error writing JSON file: \(error)")
        }
    }
    private func shareJSONFile(fileURL: URL, filename: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("Error accessing root view controller")
                return
            }
            var topViewController = rootViewController
            while let presented = topViewController.presentedViewController {
                topViewController = presented
            }
            if topViewController != rootViewController {
                print("Another view controller is already being presented, waiting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.presentShareSheet(fileURL: fileURL, filename: filename, rootViewController: topViewController, window: window)
                }
                return
            }
            self.presentShareSheet(fileURL: fileURL, filename: filename, rootViewController: rootViewController, window: window)
        }
    }
    private func presentShareSheet(fileURL: URL, filename: String, rootViewController: UIViewController, window: UIWindow) {
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        activityViewController.setValue("Account Data Export - \(filename)", forKey: "subject")
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        rootViewController.present(activityViewController, animated: true) {
            print("Share sheet presented for JSON file: \(filename)")
        }
    }
    func fetchLatestDataDownload(completion: @escaping (DataDownload?) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(nil)
            return
        }
        Firestore.firestore().collection("users")
            .document(uid)
            .collection("data-downloads")
            .order(by: "exportDate", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching latest data download: \(error)")
                    completion(nil)
                    return
                }
                guard let document = snapshot?.documents.first else {
                    completion(nil)
                    return
                }
                do {
                    let download = try document.data(as: DataDownload.self)
                    completion(download)
                } catch {
                    print("Error decoding data download: \(error)")
                    completion(nil)
                }
            }
    }
}
