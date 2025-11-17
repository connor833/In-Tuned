//
//  UserPreferencesService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/22/24.
//

import Foundation
import Firebase
import FirebaseFirestore

class UserPreferencesService {
    private let db = Firestore.firestore()
    
    // MARK: - Load User Preferences
    
    func loadUserPreferences(userId: String) async throws -> UserPreferences {
        let preferencesRef = db.collection("users").document(userId).collection("user-preferences").document("preferences")
        
        let document = try await preferencesRef.getDocument()
        
        if document.exists {
            // Load data manually to avoid Codable issues
            let data = document.data() ?? [:]
            var preferences = UserPreferences()
            
            // Load categories from data
            if let categoriesData = data["selectedCategories"] as? [[String: Any]] {
                preferences.selectedCategories = categoriesData.compactMap { categoryData in
                    guard let category = categoryData["category"] as? String,
                          let weight = categoryData["weight"] as? Double else { return nil }
                    
                    var categoryPref = CategoryPreference(
                        category: category,
                        weight: weight
                    )
                    
                    // Handle timestamp conversion from Firestore
                    if let timestamp = categoryData["lastInteracted"] as? Timestamp {
                        categoryPref.lastInteracted = timestamp.dateValue()
                    } else if let timestampNumber = categoryData["lastInteracted"] as? Double {
                        categoryPref.lastInteracted = Date(timeIntervalSince1970: timestampNumber)
                    } else if let timestampNumber = categoryData["lastInteracted"] as? Int {
                        categoryPref.lastInteracted = Date(timeIntervalSince1970: TimeInterval(timestampNumber) / 1000.0)
                    }
                    
                    return categoryPref
                }
            }
            
            // Load keywords from data
            if let keywordsData = data["selectedKeywords"] as? [[String: Any]] {
                preferences.selectedKeywords = keywordsData.compactMap { keywordData in
                    guard let keyword = keywordData["keyword"] as? String,
                          let weight = keywordData["weight"] as? Double,
                          let category = keywordData["category"] as? String else { return nil }
                    
                    var keywordPref = KeywordPreference(
                        keyword: keyword,
                        weight: weight,
                        category: category
                    )
                    
                    // Handle timestamp conversion from Firestore
                    if let timestamp = keywordData["lastInteracted"] as? Timestamp {
                        keywordPref.lastInteracted = timestamp.dateValue()
                    } else if let timestampNumber = keywordData["lastInteracted"] as? Double {
                        keywordPref.lastInteracted = Date(timeIntervalSince1970: timestampNumber)
                    } else if let timestampNumber = keywordData["lastInteracted"] as? Int {
                        keywordPref.lastInteracted = Date(timeIntervalSince1970: TimeInterval(timestampNumber) / 1000.0)
                    }
                    
                    return keywordPref
                }
            }
            
            // Load other fields
            if let version = data["categorizationVersion"] as? String {
                preferences.categorizationVersion = version
            }
            if let lastUpdated = data["lastUpdated"] as? Timestamp {
                preferences.lastUpdated = lastUpdated.dateValue()
            } else if let lastUpdatedNumber = data["lastUpdated"] as? Double {
                preferences.lastUpdated = Date(timeIntervalSince1970: lastUpdatedNumber)
            }
            if let createdAt = data["createdAt"] as? Timestamp {
                preferences.createdAt = createdAt.dateValue()
            } else if let createdAtNumber = data["createdAt"] as? Double {
                preferences.createdAt = Date(timeIntervalSince1970: createdAtNumber)
            }
            
            print("✅ Loaded existing user preferences for user: \(userId)")
            return preferences
        } else {
            print("📝 No preferences found for user: \(userId), creating defaults")
            let defaultPreferences = UserPreferences()
            try await saveUserPreferences(defaultPreferences, userId: userId)
            return defaultPreferences
        }
    }
    
    // MARK: - Save User Preferences
    
    func saveUserPreferences(_ preferences: UserPreferences, userId: String) async throws {
        let preferencesRef = db.collection("users").document(userId).collection("user-preferences").document("preferences")
        
        do {
            // Manually create dictionary with proper Firestore timestamps
            var dict: [String: Any] = [
                "categorizationVersion": preferences.categorizationVersion,
                "lastUpdated": Timestamp(date: preferences.lastUpdated),
                "createdAt": Timestamp(date: preferences.createdAt)
            ]
            
            // Convert categories with proper timestamps
            var categoriesArray: [[String: Any]] = []
            for category in preferences.selectedCategories {
                categoriesArray.append([
                    "id": category.id,
                    "category": category.category,
                    "weight": category.weight,
                    "lastInteracted": Timestamp(date: category.lastInteracted)
                ])
            }
            dict["selectedCategories"] = categoriesArray
            
            // Convert keywords with proper timestamps
            var keywordsArray: [[String: Any]] = []
            for keyword in preferences.selectedKeywords {
                keywordsArray.append([
                    "id": keyword.id,
                    "keyword": keyword.keyword,
                    "weight": keyword.weight,
                    "category": keyword.category,
                    "lastInteracted": Timestamp(date: keyword.lastInteracted)
                ])
            }
            dict["selectedKeywords"] = keywordsArray
            
            print("⚠️ WARNING: saveUserPreferences called - this will overwrite ALL preferences!")
            print("🔍 Categories being saved: \(preferences.selectedCategories.count)")
            print("🔍 Keywords being saved: \(preferences.selectedKeywords.count)")
            
            try await preferencesRef.setData(dict)
            print("✅ User preferences saved successfully for user: \(userId)")
        } catch {
            print("❌ Error saving user preferences: \(error)")
            throw error
        }
    }
    
    // MARK: - Update Category Weight
    
    func updateCategoryWeight(for category: String, userId: String) async throws {
        let preferencesRef = db.collection("users").document(userId).collection("user-preferences").document("preferences")
        
        // Get current preferences to find the category index
        let document = try await preferencesRef.getDocument()
        guard document.exists else {
            print("❌ No preferences found for user: \(userId)")
            return
        }
        
        let data = document.data() ?? [:]
        guard let categoriesData = data["selectedCategories"] as? [[String: Any]] else {
            print("❌ No categories found in preferences")
            return
        }
        
        // Find the category index
        guard let categoryIndex = categoriesData.firstIndex(where: { $0["category"] as? String == category }) else {
            print("⚠️ Category '\(category)' not found in user preferences")
            return
        }
        
        // SAFETY CHECK - Don't update if we don't have all 20 categories
        guard categoriesData.count >= 20 else {
            print("🚨 DANGER: Only \(categoriesData.count) categories found, expected 20. Skipping update to prevent data loss!")
            return
        }
        
        print("🔍 Before update - Categories count: \(categoriesData.count)")
        print("🔍 Updating category '\(category)' at index \(categoryIndex)")
        
        // Load the full preferences, update in memory, then save back
        var fullPreferences = try await loadUserPreferences(userId: userId)
        
        // Find the category to boost
        guard let boostIndex = fullPreferences.selectedCategories.firstIndex(where: { $0.category == category }) else {
            print("⚠️ Category '\(category)' not found in loaded preferences")
            return
        }
        
        // Get current weight and calculate new weight
        let currentWeight = fullPreferences.selectedCategories[boostIndex].weight
        let boostAmount = UserPreferences.clickBoost
        let newWeight = min(UserPreferences.maxWeight, currentWeight + boostAmount)
        
        print("🔍 Current weight: \(currentWeight) -> New weight: \(newWeight)")
        
        // Boost the interacted category
        fullPreferences.selectedCategories[boostIndex].weight = newWeight
        fullPreferences.selectedCategories[boostIndex].lastInteracted = Date()
        
        // Only decay other categories if we actually boosted the target category
        if newWeight > currentWeight {
            // Decay other categories proportionally to maintain relative differences
            let decayFactor = 0.95 // Reduce other categories by 5%
            
            for i in fullPreferences.selectedCategories.indices {
                if i != boostIndex {
                    let oldWeight = fullPreferences.selectedCategories[i].weight
                    let decayedWeight = oldWeight * decayFactor
                    let finalWeight = max(UserPreferences.minWeight, decayedWeight)
                    
                    fullPreferences.selectedCategories[i].weight = finalWeight
                    
                    print("🔍 Decayed category '\(fullPreferences.selectedCategories[i].category)': \(oldWeight) -> \(finalWeight)")
                }
            }
            print("🔍 Applied decay to other categories since '\(category)' weight increased")
        } else {
            print("🔍 Category '\(category)' already at max weight (\(newWeight)), skipping decay to prevent suppression")
        }
        
        // Update lastUpdated timestamp
        fullPreferences.lastUpdated = Date()
        
        // Save the updated preferences back
        try await saveUserPreferences(fullPreferences, userId: userId)
        print("✅ Updated category weight for '\(category)' to \(newWeight) with normalization applied")
    }
    
    // MARK: - Update Keyword Preferences from Pod
    
    func updateKeywordPreferences(from pod: Pod, userId: String) async throws {
        guard let podCategory = pod.category,
              let podKeywords = pod.keywords else {
            print("⚠️ Pod missing category or keywords, skipping preference update")
            return
        }
        
        let preferencesRef = db.collection("users").document(userId).collection("user-preferences").document("preferences")
        
        // Get current preferences to work with
        let document = try await preferencesRef.getDocument()
        guard document.exists else {
            print("❌ No preferences found for user: \(userId)")
            return
        }
        
        let data = document.data() ?? [:]
        guard let keywordsData = data["selectedKeywords"] as? [[String: Any]] else {
            print("❌ No keywords found in preferences")
            return
        }
        
        // SAFETY CHECK - Don't update if we don't have any keywords
        guard !keywordsData.isEmpty else {
            print("🚨 DANGER: No keywords found in preferences. Skipping update to prevent data loss!")
            return
        }
        
        // Load the full preferences, update in memory, then save back
        var fullPreferences = try await loadUserPreferences(userId: userId)
        
        // Step 1: Boost weights of existing keywords that match the new pod
        var anyKeywordBoosted = false // Track if any keywords were actually boosted
        
        for podKeyword in podKeywords {
            if let index = fullPreferences.selectedKeywords.firstIndex(where: { $0.keyword == podKeyword }) {
                let currentWeight = fullPreferences.selectedKeywords[index].weight
                let newWeight = min(UserPreferences.maxWeight, currentWeight + UserPreferences.clickBoost)
                
                // Only count as boosted if the weight actually increased
                if newWeight > currentWeight {
                    anyKeywordBoosted = true
                }
                
                print("🔍 Boosting existing keyword '\(podKeyword)': \(currentWeight) -> \(newWeight)")
                
                fullPreferences.selectedKeywords[index].weight = newWeight
                fullPreferences.selectedKeywords[index].lastInteracted = Date()
                
                print("✅ Boosted keyword '\(podKeyword)' weight to \(newWeight)")
            }
        }
        
        // Step 2: Always consider replacing the lowest-weight keyword with a better one from the pod
        // Find the lowest-weight keyword in user preferences to potentially replace
        if let lowestWeightIndex = fullPreferences.selectedKeywords.enumerated().min(by: { $0.element.weight < $1.element.weight })?.offset {
            let lowestWeightKeyword = fullPreferences.selectedKeywords[lowestWeightIndex]
            let lowestWeight = lowestWeightKeyword.weight
            
            print("🔍 Lowest-weight keyword: '\(lowestWeightKeyword.keyword)' (weight: \(lowestWeight))")
            
            // Find the best keyword from the pod to potentially replace it with
            var bestReplacementKeyword: String?
            var bestReplacementWeight: Double = 0.0
            
            for podKeyword in podKeywords {
                let podKeywordWeight = getKeywordWeightInCategory(podKeyword, category: podCategory)
                
                // Consider replacing if:
                // 1. It's a new keyword (user doesn't have it), OR
                // 2. It's an existing keyword but with higher weight in the pod
                let shouldConsiderReplacement = !fullPreferences.selectedKeywords.contains { $0.keyword == podKeyword } ||
                                             podKeywordWeight > lowestWeight
                
                if shouldConsiderReplacement && podKeywordWeight > bestReplacementWeight {
                    bestReplacementKeyword = podKeyword
                    bestReplacementWeight = podKeywordWeight
                }
            }
            
            // Replace if we found a better keyword
            if let replacementKeyword = bestReplacementKeyword, bestReplacementWeight > lowestWeight {
                print("🔍 Replacing '\(lowestWeightKeyword.keyword)' (weight: \(lowestWeight)) with '\(replacementKeyword)' (pod weight: \(bestReplacementWeight))")
                
                // Replace the lowest-weight keyword with the better one
                fullPreferences.selectedKeywords[lowestWeightIndex] = KeywordPreference(
                    keyword: replacementKeyword,
                    weight: 0.5, // Start with neutral weight
                    category: podCategory
                )
                
                print("✅ Replaced '\(lowestWeightKeyword.keyword)' with '\(replacementKeyword)'")
            } else {
                print("🔍 No better replacement found for '\(lowestWeightKeyword.keyword)'")
            }
        }
        
        // Step 3: Apply normalization (decay) only if keywords were actually boosted
        if anyKeywordBoosted {
            print("🔍 Keywords were boosted, applying normalization to maintain relative differences")
            
            // Find which keywords were boosted so we don't decay them
            let boostedKeywords = podKeywords.filter { podKeyword in
                fullPreferences.selectedKeywords.contains { $0.keyword == podKeyword }
            }
            
            // Decay non-boosted keywords to maintain relative differences
            let decayFactor = 0.95 // Reduce other keywords by 5%
            
            for i in fullPreferences.selectedKeywords.indices {
                let keyword = fullPreferences.selectedKeywords[i].keyword
                
                // Don't decay keywords that were just boosted
                if !boostedKeywords.contains(keyword) {
                    let oldWeight = fullPreferences.selectedKeywords[i].weight
                    let decayedWeight = oldWeight * decayFactor
                    let finalWeight = max(UserPreferences.minWeight, decayedWeight)
                    
                    fullPreferences.selectedKeywords[i].weight = finalWeight
                    
                    print("🔍 Decayed keyword '\(keyword)': \(oldWeight) -> \(finalWeight)")
                }
            }
            print("✅ Applied keyword normalization")
        } else {
            print("🔍 No keywords were boosted, skipping normalization to prevent suppression")
        }
        
        // Update lastUpdated timestamp
        fullPreferences.lastUpdated = Date()
        
        // Save the updated preferences back
        try await saveUserPreferences(fullPreferences, userId: userId)
        
        print("✅ Keyword preferences updated successfully")
    }
    
    // Helper function to get keyword weight within a category
    private func getKeywordWeightInCategory(_ keyword: String, category: String) -> Double {
        // This would ideally come from your AIProcessor or a predefined weight system
        // For now, return a default weight based on category importance
        let categoryWeights: [String: Double] = [
            "Technology": 0.9,
            "Science": 0.8,
            "Business": 0.7,
            "Entertainment": 0.6,
            "Health & Fitness": 0.8,
            "Music": 0.7,
            "Gaming": 0.6,
            "Education": 0.8,
            "News & Politics": 0.7,
            "Sports": 0.6
        ]
        
        return categoryWeights[category] ?? 0.5
    }
    
    // MARK: - Category Management (REMOVED - Users now have all categories by default)
    
    // Note: addCategory and removeCategory functions removed since:
    // 1. Users start with all 20 categories
    // 2. Categories are comprehensive and don't need manual management
    // 3. Only keyword preferences change based on user interactions
    
    // MARK: - Migration Support
    
    func checkMigrationStatus(userId: String) async throws -> (migrated: Bool, version: String) {
        let preferencesRef = db.collection("users").document(userId).collection("user-preferences").document("preferences")
        
        let document = try await preferencesRef.getDocument()
        
        if !document.exists {
            return (migrated: false, version: "none")
        }
        
        let data = document.data()
        let version = data?["categorizationVersion"] as? String ?? "unknown"
        let isMigrated = version == "1.0"
        
        return (migrated: isMigrated, version: version)
    }
    
    // MARK: - Migration Function (Temporary - Delete after use)
    
    func migrateUserPreferences(userId: String) async throws {
        print("🚀 Starting migration for user: \(userId)")
        
        let preferencesRef = db.collection("users").document(userId).collection("user-preferences").document("preferences")
        
        // Force migration for all users to get the new 20-category structure
        // Create new preferences structure with all 20 categories
        let newPreferences = UserPreferences()
        
        // Save the new preferences
        try await saveUserPreferences(newPreferences, userId: userId)
        
        print("✅ Successfully migrated user \(userId) to new 20-category preferences structure")
    }
    
    func migrateAllUsers() async throws {
        print("🚀 Starting migration for all users...")
        
        let usersCollection = db.collection("users")
        let snapshot = try await usersCollection.getDocuments()
        
        var successCount = 0
        var errorCount = 0
        
        for document in snapshot.documents {
            let userId = document.documentID
            do {
                try await migrateUserPreferences(userId: userId)
                successCount += 1
            } catch {
                print("❌ Failed to migrate user \(userId): \(error)")
                errorCount += 1
            }
        }
        
        print("✅ Migration complete! Success: \(successCount), Errors: \(errorCount)")
    }
    
    // MARK: - Pod Migration (Temporary - Delete after use)
    
    func migrateAllPods() async throws {
        print("🚀 Starting migration for all pods...")
        
        let podsCollection = db.collection("pods")
        let snapshot = try await podsCollection.getDocuments()
        
        let aiProcessor = AIProcessor()
        var successCount = 0
        var errorCount = 0
        
        for document in snapshot.documents {
            let podId = document.documentID
            
            do {
                // Get existing pod data
                var pod = try document.data(as: Pod.self)
                pod.id = podId
                
                // Process through AI to get new category and keywords
                let processedPod = aiProcessor.processPod(
                    title: pod.title,
                    description: pod.description,
                    userTags: pod.keywords // Use existing keywords as user tags if available
                )
                
                // Update pod with new AI-generated data
                var updatedPod = pod
                updatedPod.category = processedPod.category
                updatedPod.keywords = processedPod.keywords
                
                // Save updated pod back to Firebase - only update the fields we changed
                try await podsCollection.document(podId).updateData([
                    "category": processedPod.category ?? "",
                    "keywords": processedPod.keywords ?? []
                ])
                
             
                successCount += 1
                
            } catch {
                print("❌ Failed to migrate pod \(podId): \(error)")
                errorCount += 1
            }
        }
        
        print("✅ Pod migration complete! Success: \(successCount), Errors: \(errorCount)")
    }
    
    // MARK: - Utility Functions
    
    func getUserPreferencesRef(userId: String) -> DocumentReference {
        return db.collection("users").document(userId).collection("user-preferences").document("preferences")
    }
    
}
