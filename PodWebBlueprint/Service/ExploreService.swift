//
//  ExploreService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import Foundation
import Firebase
import FirebaseFirestore

/// Service responsible for fetching explore content
/// Keeps all query logic separate from ViewModels
class ExploreService {
    
    // MARK: - Properties
    
    private let db = Firestore.firestore()
    private let currentUser: User?
    
    // MARK: - Initialization
    
    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }
    
    // MARK: - Trending Pods
    
    /// Fetch trending pods (past week, or latest if none)
    /// - Parameters:
    ///   - limit: Maximum number of pods to fetch
    ///   - completion: Completion handler with array of pods
    func fetchTrending(limit: Int = 20, completion: @escaping ([Pod]) -> Void) {
        print("🔥 [ExploreService] Fetching trending pods (limit: \(limit))")
        
        // Try past week first
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        db.collection("pods")
            .whereField("timestamp", isGreaterThan: Timestamp(date: oneWeekAgo))
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .order(by: "likes", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [ExploreService] Error fetching trending: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let pods = snapshot?.documents.compactMap { try? $0.data(as: Pod.self) } ?? []
                
                // If we have pods from past week, return them
                if !pods.isEmpty {
                    print("✅ [ExploreService] Fetched \(pods.count) trending pods from past week")
                    completion(pods)
                    return
                }
                
                // No pods from past week, fetch latest episodes regardless of date
                print("⚠️ [ExploreService] No trending pods from past week, fetching latest")
                self?.fetchLatestTrending(limit: limit, completion: completion)
            }
    }
    
    /// Fallback: Fetch latest trending pods without date restriction
    private func fetchLatestTrending(limit: Int, completion: @escaping ([Pod]) -> Void) {
        db.collection("pods")
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .order(by: "likes", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { snapshot, error in
                if let error = error {
                    print("❌ [ExploreService] Error fetching latest trending: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let pods = snapshot?.documents.compactMap { try? $0.data(as: Pod.self) } ?? []
                print("✅ [ExploreService] Fetched \(pods.count) latest trending pods (no date filter)")
                completion(pods)
            }
    }
    
    // MARK: - New & Noteworthy
    
    /// Fetch new and noteworthy pods (past week, or latest if none)
    /// - Parameters:
    ///   - limit: Maximum number of pods to fetch
    ///   - completion: Completion handler with array of pods
    func fetchNewAndNoteworthy(limit: Int = 20, completion: @escaping ([Pod]) -> Void) {
        print("✨ [ExploreService] Fetching new & noteworthy pods (limit: \(limit))")
        
        // Try past week first
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        db.collection("pods")
            .whereField("timestamp", isGreaterThan: Timestamp(date: oneWeekAgo))
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { [weak self] snapshot, error in
                if let error = error {
                    print("❌ [ExploreService] Error fetching new pods: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let pods = snapshot?.documents.compactMap { try? $0.data(as: Pod.self) } ?? []
                
                // If we have pods from past week, return them
                if !pods.isEmpty {
                    print("✅ [ExploreService] Fetched \(pods.count) new & noteworthy pods from past week")
                    completion(pods)
                    return
                }
                
                // No pods from past week, fetch latest episodes regardless of date
                print("⚠️ [ExploreService] No new pods from past week, fetching latest")
                self?.fetchLatestNew(limit: limit, completion: completion)
            }
    }
    
    /// Fallback: Fetch latest new pods without date restriction
    private func fetchLatestNew(limit: Int, completion: @escaping ([Pod]) -> Void) {
        db.collection("pods")
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { snapshot, error in
                if let error = error {
                    print("❌ [ExploreService] Error fetching latest new pods: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                let pods = snapshot?.documents.compactMap { try? $0.data(as: Pod.self) } ?? []
                print("✅ [ExploreService] Fetched \(pods.count) latest new & noteworthy pods (no date filter)")
                completion(pods)
            }
    }
    
    // MARK: - Top Charts
    
    /// Fetch top charts (all time, sorted by likes)
    /// - Parameters:
    ///   - limit: Maximum number of pods to fetch (default: 10 for charts)
    ///   - completion: Completion handler with array of pods
    func fetchTopCharts(limit: Int = 10, completion: @escaping ([Pod]) -> Void) {
        print("📊 [ExploreService] Fetching top charts (limit: \(limit))")
        
        db.collection("pods")
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "likes", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { snapshot, error in
                if let error = error {
                    print("❌ [ExploreService] Error fetching top charts: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [ExploreService] No top chart pods found")
                    completion([])
                    return
                }
                
                let pods = documents.compactMap { try? $0.data(as: Pod.self) }
                print("✅ [ExploreService] Fetched \(pods.count) top chart pods")
                completion(pods)
            }
    }
    
    // MARK: - Featured Pods
    
    /// Fetch featured/curated pods
    /// Note: For now uses high-quality pods. Later can use a 'featured' collection
    /// - Parameters:
    ///   - limit: Maximum number of pods to fetch
    ///   - completion: Completion handler with array of pods
    func fetchFeatured(limit: Int = 10, completion: @escaping ([Pod]) -> Void) {
        print("⭐ [ExploreService] Fetching featured pods (limit: \(limit))")
        
        // For now, fetch high-quality pods (high likes + recent)
        // TODO: Later implement admin-curated featured collection
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        
        db.collection("pods")
            .whereField("timestamp", isGreaterThan: Timestamp(date: thirtyDaysAgo))
            .whereField("isDeleted", isEqualTo: false)
            .whereField("likes", isGreaterThan: 10) // Minimum quality threshold
            .order(by: "likes", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { snapshot, error in
                if let error = error {
                    print("❌ [ExploreService] Error fetching featured: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [ExploreService] No featured pods found")
                    completion([])
                    return
                }
                
                let pods = documents.compactMap { try? $0.data(as: Pod.self) }
                print("✅ [ExploreService] Fetched \(pods.count) featured pods")
                completion(pods)
            }
    }
    
    // MARK: - By Category
    
    /// Fetch pods by specific category with pagination
    /// - Parameters:
    ///   - category: The category to filter by
    ///   - limit: Maximum number of pods to fetch
    ///   - lastDocument: Last document for pagination
    ///   - completion: Completion handler with array of pods and last document
    func fetchByCategory(_ category: PodCategory, limit: Int = 20, lastDocument: DocumentSnapshot? = nil, completion: @escaping ([Pod], DocumentSnapshot?) -> Void) {
        print("📂 [ExploreService] Fetching pods for category: \(category.rawValue) (limit: \(limit), paginated: \(lastDocument != nil))")
        
        var query = db.collection("pods")
            .whereField("category", isEqualTo: category.rawValue)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "likes", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        // Force server fetch for first page to get fresh engagement metrics
        query.getDocuments(source: lastDocument == nil ? .server : .default) { snapshot, error in
            if let error = error {
                print("❌ [ExploreService] Error fetching category \(category.rawValue): \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [ExploreService] No pods found for category: \(category.rawValue)")
                completion([], nil)
                return
            }
            
            let pods = documents.compactMap { try? $0.data(as: Pod.self) }
            let lastDoc = documents.last
            print("✅ [ExploreService] Fetched \(pods.count) pods for category: \(category.rawValue)")
            completion(pods, lastDoc)
        }
    }
    
    // MARK: - By Mood
    
    /// Fetch pods by mood/vibe with pagination
    /// - Parameters:
    ///   - mood: The mood to filter by
    ///   - limit: Maximum number of pods to fetch
    ///   - lastDocument: Last document for pagination
    ///   - completion: Completion handler with array of pods and last document
    func fetchByMood(_ mood: PodMood, limit: Int = 20, lastDocument: DocumentSnapshot? = nil, completion: @escaping ([Pod], DocumentSnapshot?) -> Void) {
        print("🎭 [ExploreService] Fetching pods for mood: \(mood.rawValue) (limit: \(limit), paginated: \(lastDocument != nil))")
        
        // Handle quick listen (duration-based)
        if mood == .quick {
            fetchQuickListens(limit: limit, lastDocument: lastDocument, completion: completion)
            return
        }
        
        // For other moods, fetch by matching categories
        let categories = mood.matchingCategories.map { $0.rawValue }
        
        guard !categories.isEmpty else {
            print("⚠️ [ExploreService] No categories match mood: \(mood.rawValue)")
            completion([], nil)
            return
        }
        
        var query = db.collection("pods")
            .whereField("category", in: categories)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "likes", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        // Force server fetch for first page to get fresh engagement metrics
        query.getDocuments(source: lastDocument == nil ? .server : .default) { snapshot, error in
            if let error = error {
                print("❌ [ExploreService] Error fetching mood \(mood.rawValue): \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [ExploreService] No pods found for mood: \(mood.rawValue)")
                completion([], nil)
                return
            }
            
            let pods = documents.compactMap { try? $0.data(as: Pod.self) }
            let lastDoc = documents.last
            print("✅ [ExploreService] Fetched \(pods.count) pods for mood: \(mood.rawValue)")
            completion(pods, lastDoc)
        }
    }
    
    // MARK: - Quick Listens (Duration-based)
    
    /// Fetch quick listen pods (under 10 minutes) with pagination
    /// - Parameters:
    ///   - limit: Maximum number of pods to fetch
    ///   - lastDocument: Last document for pagination
    ///   - completion: Completion handler with array of pods and last document
    private func fetchQuickListens(limit: Int, lastDocument: DocumentSnapshot? = nil, completion: @escaping ([Pod], DocumentSnapshot?) -> Void) {
        print("⚡ [ExploreService] Fetching quick listens (under 10 min, limit: \(limit), paginated: \(lastDocument != nil))")
        
        let maxDuration: TimeInterval = 10 * 60 // 10 minutes in seconds
        
        var query = db.collection("pods")
            .whereField("duration", isLessThan: maxDuration)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "duration", descending: false)
            .order(by: "likes", descending: true)
            .limit(to: limit)
        
        if let lastDocument = lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        
        // Force server fetch for first page to get fresh engagement metrics
        query.getDocuments(source: lastDocument == nil ? .server : .default) { snapshot, error in
            if let error = error {
                print("❌ [ExploreService] Error fetching quick listens: \(error.localizedDescription)")
                completion([], nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("⚠️ [ExploreService] No quick listen pods found")
                completion([], nil)
                return
            }
            
            let pods = documents.compactMap { try? $0.data(as: Pod.self) }
            let lastDoc = documents.last
            print("✅ [ExploreService] Fetched \(pods.count) quick listen pods")
            completion(pods, lastDoc)
        }
    }
    
    // MARK: - Hidden Gems (Future Enhancement)
    
    /// Fetch hidden gems (great content from smaller creators)
    /// High engagement rate but low follower count
    /// - Parameters:
    ///   - limit: Maximum number of pods to fetch
    ///   - completion: Completion handler with array of pods
    func fetchHiddenGems(limit: Int = 20, completion: @escaping ([Pod]) -> Void) {
        print("💎 [ExploreService] Fetching hidden gems (limit: \(limit))")
        
        // Fetch pods with good engagement but from newer creators
        db.collection("pods")
            .whereField("likes", isGreaterThan: 5) // Has some engagement
            .whereField("likes", isLessThan: 100) // Not super popular yet
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "likes", descending: true)
            .limit(to: limit)
            .getDocuments(source: .server) { snapshot, error in
                if let error = error {
                    print("❌ [ExploreService] Error fetching hidden gems: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [ExploreService] No hidden gems found")
                    completion([])
                    return
                }
                
                let pods = documents.compactMap { try? $0.data(as: Pod.self) }
                print("✅ [ExploreService] Fetched \(pods.count) hidden gems")
                completion(pods)
            }
    }
}
