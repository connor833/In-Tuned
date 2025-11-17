//
//  RepostViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import Foundation
import Firebase

class RepostViewModel: ObservableObject {
    @Published var reposts: [Repost] = []
    @Published var isLoading = false
    @Published var hasReposted = false
    
    private let repostService = RepostService()
    private let userService = UserService()
    private let podService = PodService()
    
    // Create a repost with error handling
    func createRepost(podId: String, originalUserId: String, caption: String?, completion: @escaping (Result<Void, RepostService.RepostServiceError>) -> Void) {
        repostService.createRepost(podId: podId, originalUserId: originalUserId, caption: caption) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.hasReposted = true
                    completion(.success(()))
                case .failure(let error):
                    print("❌ Failed to create repost: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Legacy method for backward compatibility
    func createRepost(podId: String, originalUserId: String, caption: String?, completion: @escaping() -> Void) {
        createRepost(podId: podId, originalUserId: originalUserId, caption: caption) { result in
            completion() // Ignore result for legacy compatibility
        }
    }
    
    // Fetch user's reposts
    func fetchUserReposts(userId: String) {
        isLoading = true
        repostService.fetchUserReposts(userId: userId) { reposts in
            DispatchQueue.main.async {
                self.reposts = reposts
                self.isLoading = false
            }
        }
    }
    
    // Check if user has reposted a specific pod
    func checkIfUserReposted(podId: String) {
        repostService.checkIfUserReposted(podId: podId) { hasReposted in
            DispatchQueue.main.async {
                self.hasReposted = hasReposted
            }
        }
    }
    
    // Delete a repost with error handling
    func deleteRepost(podId: String, completion: @escaping (Result<Void, RepostService.RepostServiceError>) -> Void) {
        repostService.deleteRepost(podId: podId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.hasReposted = false
                    completion(.success(()))
                case .failure(let error):
                    print("❌ Failed to delete repost: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Legacy method for backward compatibility
    func deleteRepost(podId: String, completion: @escaping() -> Void) {
        deleteRepost(podId: podId) { result in
            completion() // Ignore result for legacy compatibility
        }
    }
} 