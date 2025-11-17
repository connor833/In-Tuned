//
//  UserPreferences.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/22/24.
//

import Foundation
import Firebase
import Combine

// MARK: - Category Preference Model
struct CategoryPreference: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var category: String
    var weight: Double
    var lastInteracted: Date
    
    init(category: String, weight: Double = 0.5) {
        self.id = UUID().uuidString
        self.category = category
        self.weight = weight
        self.lastInteracted = Date()
    }
    
    static func == (lhs: CategoryPreference, rhs: CategoryPreference) -> Bool {
        return lhs.id == rhs.id &&
               lhs.category == rhs.category &&
               lhs.weight == rhs.weight &&
               lhs.lastInteracted == rhs.lastInteracted
    }
}

// MARK: - Keyword Preference Model
struct KeywordPreference: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var keyword: String
    var weight: Double
    var category: String
    var lastInteracted: Date
    
    init(keyword: String, weight: Double = 0.5, category: String) {
        self.id = UUID().uuidString
        self.keyword = keyword
        self.weight = weight
        self.category = category
        self.lastInteracted = Date()
    }
    
    static func == (lhs: KeywordPreference, rhs: KeywordPreference) -> Bool {
        return lhs.id == rhs.id &&
               lhs.keyword == rhs.keyword &&
               lhs.weight == rhs.weight &&
               lhs.category == rhs.category &&
               lhs.lastInteracted == rhs.lastInteracted
    }
}

// MARK: - Main User Preferences Model
struct UserPreferences: Codable, Equatable {
    var selectedCategories: [CategoryPreference]
    var selectedKeywords: [KeywordPreference]
    
    // Version tracking for migrations
    var version: Int? = nil
    var categorizationVersion: String = "1.0"
    var lastUpdated: Date = Date()
    var createdAt: Date = Date()
    
    // Constants
    static let maxKeywords = 5
    static let maxWeight = 1.0
    static let minWeight = 0.1
    static let clickBoost = 0.1
    
    init() {
        // Initialize with default categories and keywords
        selectedCategories = []
        selectedKeywords = []
        version = 1  // Set version to 1 for new users
        setupDefaultPreferences()
    }
    
    // MARK: - Default Preferences Setup
    
    private mutating func setupDefaultPreferences() {
        // All 20 categories for comprehensive user preferences
        let allCategories = [
            "Technology", "Science", "Business", "Finance", "Entertainment",
            "Music", "Gaming", "Health & Fitness", "Food & Travel", "Education",
            "News & Politics", "Sports", "Fashion & Beauty", "Lifestyle", "Comedy",
            "Art & Design", "Books & Literature", "Social Issues", "Environment", "History"
        ]
        
        // Give users all categories with equal starting weight
        for category in allCategories {
            selectedCategories.append(CategoryPreference(category: category, weight: 0.5))
        }
        
        // Pick 5 random keywords from ALL categories for variety
        let aiProcessor = AIProcessor()
        var allKeywords: [String] = []
        
        for category in allCategories {
            let keywords = aiProcessor.getKeywords(for: category)
            allKeywords.append(contentsOf: keywords)
        }
        
        // Randomly select 5 keywords from the entire keyword pool
        let shuffledKeywords = allKeywords.shuffled()
        let selectedKeywordsList = Array(shuffledKeywords.prefix(Self.maxKeywords))
        
        for keyword in selectedKeywordsList {
            // Find which category this keyword belongs to
            let category = findCategoryForKeyword(keyword, in: allCategories, aiProcessor: aiProcessor)
            selectedKeywords.append(KeywordPreference(keyword: keyword, weight: 0.5, category: category))
        }
        
        // Ensure we have exactly 5 keywords
        while selectedKeywords.count < Self.maxKeywords {
            let remainingKeywords = allKeywords.filter { keyword in
                !selectedKeywords.contains { $0.keyword == keyword }
            }
            if let randomKeyword = remainingKeywords.randomElement() {
                let category = findCategoryForKeyword(randomKeyword, in: allCategories, aiProcessor: aiProcessor)
                selectedKeywords.append(KeywordPreference(keyword: randomKeyword, weight: 0.5, category: category))
            } else {
                break
            }
        }
    }
    
    private func findCategoryForKeyword(_ keyword: String, in categories: [String], aiProcessor: AIProcessor) -> String {
        for category in categories {
            let categoryKeywords = aiProcessor.getKeywords(for: category)
            if categoryKeywords.contains(keyword) {
                return category
            }
        }
        return categories.first ?? "Technology"
    }
    
    // MARK: - Utility Functions
    
    func getTopCategories(limit: Int = 5) -> [CategoryPreference] {
        return Array(selectedCategories.sorted { $0.weight > $1.weight }.prefix(limit))
    }
    
    func getTopKeywords(limit: Int = 5) -> [KeywordPreference] {
        return Array(selectedKeywords.sorted { $0.weight > $1.weight }.prefix(limit))
    }
    
    func getCategoryWeight(for category: String) -> Double {
        return selectedCategories.first { $0.category == category }?.weight ?? 0.0
    }
    
    func getKeywordWeight(for keyword: String) -> Double {
        return selectedKeywords.first { $0.keyword == keyword }?.weight ?? 0.0
    }
    
    func hasCategory(_ category: String) -> Bool {
        return selectedCategories.contains { $0.category == category }
    }
    
    func hasKeyword(_ keyword: String) -> Bool {
        return selectedKeywords.contains { $0.keyword == keyword }
    }
    
    // MARK: - Version Management
    
    /// Returns the current version, defaulting to 1 if nil
    func getCurrentVersion() -> Int {
        return version ?? 1
    }
    
    /// Checks if preferences need migration
    func needsMigration() -> Bool {
        return getCurrentVersion() < 2  // Update this when you add version 2
    }
    
    /// Creates a copy with updated version
    func withVersion(_ newVersion: Int) -> UserPreferences {
        var updated = self
        updated.version = newVersion
        return updated
    }
}
