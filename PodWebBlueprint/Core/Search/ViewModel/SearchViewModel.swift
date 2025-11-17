//
//  SearchViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/14/23.
//

import SwiftUI
import Firebase

class SearchViewModel: ObservableObject {
    @Published var pods = [Pod]()
    @Published var users = [User]()
    @Published var searchText = ""
    @Published var isSearching = false
    @Published var isLoadingMore = false
    @Published var hasMorePods = true
    @Published var hasMoreUsers = true
    @Published var isTyping = false
    @Published var grid = false
    @Published var selectedFilter: SearchFilterViewModel = .pods
    @Published var recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    private let authViewModel: AuthViewModel
    
    let service = UserService()
    let podService = PodService()
    let blockService = BlockService() // Add blocking service
    
    var lastUserDocument: DocumentSnapshot?
    var lastPodDocument: DocumentSnapshot?
    
    var lastUserQuery = ""
    var lastPodQuery = ""
    
    // Pagination constants
    private let pageSize = 10
    
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
    }
    
    func fetchUsers() {
        service.fetchUsers { result in
            switch result {
            case .success(let (users, lastDocument)):
                self.users = users
                self.lastUserDocument = lastDocument
            case .failure(let error):
                print("Error fetching users: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchPods() {
        podService.fetchPods { pods in
            self.pods = pods
        }
    }
    
    func searchUsers(query: String, completion: @escaping() -> Void) {
        if lastUserQuery != query {
            lastUserDocument = nil
            users = []
            hasMoreUsers = true
        }
        self.lastUserQuery = query
        service.searchUsers(query: query, lastDocument: lastUserDocument) { users, lastDocument in
            // Use quick array check from current user for ongoing app usage
            guard let currentUser = self.authViewModel.currentUser else {
                self.users.append(contentsOf: users)
                self.lastUserDocument = lastDocument
                completion()
                return
            }
            
            // Comprehensive filtering - block list, deleted accounts, and anonymous accounts
            let filteredUsers = users.filter { user in
                let isBlockedByMe = currentUser.blockedUsers?.contains(user.uid) == true
                let hasBlockedMe = currentUser.blockedBy?.contains(user.uid) == true
                let isBlocked = isBlockedByMe || hasBlockedMe
                
                // Filter out deleted accounts
                let isDeleted = user.isDeleted ?? false
                // Filter out anonymous accounts (usernames starting with "anon_")
                let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                
                if isBlocked {
                    if isBlockedByMe {
                        print("[SearchViewModel] Filtering out user you blocked: \(user.uid)")
                    } else if hasBlockedMe {
                        print("[SearchViewModel] Filtering out user who blocked you: \(user.uid)")
                    }
                }
                if isDeleted {
                    print("[SearchViewModel] Filtering out deleted account: \(user.username)")
                }
                if isAnonymous {
                    print("[SearchViewModel] Filtering out anonymous account: \(user.username)")
                }
                
                return !isBlocked && !isDeleted && !isAnonymous
            }
            
            self.users.append(contentsOf: filteredUsers)
            self.lastUserDocument = lastDocument
            self.hasMoreUsers = lastDocument != nil
            completion()
        }
    }
    
    // MARK: - Load More Functions
    
    func loadMoreUsers(completion: @escaping() -> Void) {
        guard hasMoreUsers && !isLoadingMore && lastUserDocument != nil else {
            completion()
            return
        }
        
        isLoadingMore = true
        service.searchUsers(query: lastUserQuery, lastDocument: lastUserDocument) { users, lastDocument in
            DispatchQueue.main.async {
                guard let currentUser = self.authViewModel.currentUser else {
                    self.users.append(contentsOf: users)
                    self.lastUserDocument = lastDocument
                    self.hasMoreUsers = lastDocument != nil
                    self.isLoadingMore = false
                    completion()
                    return
                }
                
                // Comprehensive filtering - block list, deleted accounts, and anonymous accounts
                let filteredUsers = users.filter { user in
                    let isBlockedByMe = currentUser.blockedUsers?.contains(user.uid) == true
                    let hasBlockedMe = currentUser.blockedBy?.contains(user.uid) == true
                    let isBlocked = isBlockedByMe || hasBlockedMe
                    
                    // Filter out deleted accounts
                    let isDeleted = user.isDeleted ?? false
                    // Filter out anonymous accounts (usernames starting with "anon_")
                    let isAnonymous = user.username.lowercased().hasPrefix("anon_")
                    
                    return !isBlocked && !isDeleted && !isAnonymous
                }
                
                self.users.append(contentsOf: filteredUsers)
                self.lastUserDocument = lastDocument
                self.hasMoreUsers = lastDocument != nil
                self.isLoadingMore = false
                completion()
            }
        }
    }
    
    func loadMorePods(completion: @escaping() -> Void) {
        guard hasMorePods && !isLoadingMore && lastPodDocument != nil else {
            completion()
            return
        }
        
        isLoadingMore = true
        podService.searchPods(query: lastPodQuery, lastDocument: lastPodDocument) { pods, lastDocument in
            DispatchQueue.main.async {
                guard let currentUser = self.authViewModel.currentUser else {
                    self.pods.append(contentsOf: pods)
                    self.lastPodDocument = lastDocument
                    self.hasMorePods = lastDocument != nil
                    self.isLoadingMore = false
                    completion()
                    return
                }
                
                // Comprehensive blocking check
                let filteredPods = pods.filter { pod in
                    let isBlockedByMe = currentUser.blockedUsers?.contains(pod.userId) == true
                    let hasBlockedMe = currentUser.blockedBy?.contains(pod.userId) == true
                    return !(isBlockedByMe || hasBlockedMe)
                }
                
                self.pods.append(contentsOf: filteredPods)
                self.lastPodDocument = lastDocument
                self.hasMorePods = lastDocument != nil
                self.isLoadingMore = false
                completion()
            }
        }
    }
    
    func searchPods(query: String, completion: @escaping() -> Void) {
        if lastPodQuery != query {
            lastPodDocument = nil
            pods = []
            hasMorePods = true
        }
        self.lastPodQuery = query
        podService.searchPods(query: query, lastDocument: lastPodDocument) { pods, lastDocument in
            // Use quick array check from current user for ongoing app usage
            guard let currentUser = self.authViewModel.currentUser else {
                self.pods.append(contentsOf: pods)
                self.lastPodDocument = lastDocument
                completion()
                return
            }
            
            // Comprehensive blocking check - filter out pods from users that current user has blocked OR users that have blocked current user
            let filteredPods = pods.filter { pod in
                let isBlockedByMe = currentUser.blockedUsers?.contains(pod.userId) == true
                let hasBlockedMe = currentUser.blockedBy?.contains(pod.userId) == true
                let isBlocked = isBlockedByMe || hasBlockedMe
                
                if isBlocked {
                    if isBlockedByMe {
                        print("[SearchViewModel] Filtering out pod from user you blocked: \(pod.userId)")
                    } else if hasBlockedMe {
                        print("[SearchViewModel] Filtering out pod from user who blocked you: \(pod.userId)")
                    }
                }
                return !isBlocked
            }
            
            self.pods.append(contentsOf: filteredPods)
            self.lastPodDocument = lastDocument
            completion()
        }
    }
    
    
    
    
    
}
