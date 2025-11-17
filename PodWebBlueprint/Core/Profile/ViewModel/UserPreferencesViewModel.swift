//
//  UserPreferencesViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/22/24.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class UserPreferencesViewModel: ObservableObject {
    @Published var userPreferences: UserPreferences?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userPreferencesService = UserPreferencesService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Initialize with empty preferences
        userPreferences = UserPreferences()
    }
    
    // MARK: - Load User Preferences
    
    func loadUserPreferences(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let preferences = try await userPreferencesService.loadUserPreferences(userId: userId)
            userPreferences = preferences
            print("✅ User preferences loaded successfully")
        } catch {
            errorMessage = "Failed to load preferences: \(error.localizedDescription)"
            print("❌ Error loading user preferences: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Update Category Weight
    
    func updateCategoryWeight(for category: String, userId: String) async {
        guard let currentPreferences = userPreferences else {
            print("❌ No user preferences loaded")
            return
        }
        
        do {
            try await userPreferencesService.updateCategoryWeight(for: category, userId: userId)
            
            // Update local state
            if let index = currentPreferences.selectedCategories.firstIndex(where: { $0.category == category }) {
                let newWeight = min(UserPreferences.maxWeight, currentPreferences.selectedCategories[index].weight + UserPreferences.clickBoost)
                userPreferences?.selectedCategories[index].weight = newWeight
                userPreferences?.selectedCategories[index].lastInteracted = Date()
                userPreferences?.lastUpdated = Date()
            }
            
            print("✅ Category weight updated locally")
        } catch {
            errorMessage = "Failed to update category weight: \(error.localizedDescription)"
            print("❌ Error updating category weight: \(error)")
        }
    }
    
    // MARK: - Update Keyword Preferences from Pod
    
    func updateKeywordPreferences(from pod: Pod, userId: String) async {
        guard let currentPreferences = userPreferences else {
            print("❌ No user preferences loaded")
            return
        }
        
        do {
            try await userPreferencesService.updateKeywordPreferences(from: pod, userId: userId)
            
            // Reload preferences to get updated state
            await loadUserPreferences(userId: userId)
            
            print("✅ Keyword preferences updated successfully")
        } catch {
            errorMessage = "Failed to update keyword preferences: \(error.localizedDescription)"
            print("❌ Error updating keyword preferences: \(error)")
        }
    }
    
    // MARK: - Pod Interaction (Combined Update)
    
    func handlePodInteraction(pod: Pod, userId: String) async {
        print("🚀 Handling pod interaction for: \(pod.title ?? "Unknown")")
        
        // Update both category and keyword preferences
        await updateCategoryWeight(for: pod.category ?? "Unknown", userId: userId)
        await updateKeywordPreferences(from: pod, userId: userId)
        
        print("✅ Pod interaction handled successfully")
    }
    
    // MARK: - Utility Functions
    
    func getTopCategories(limit: Int = 5) -> [String] {
        // Return just the category names for easier use in queries
        return userPreferences?.selectedCategories
            .sorted { $0.weight > $1.weight }
            .prefix(limit)
            .map { $0.category } ?? []
    }
    
    func getTopKeywords(limit: Int = 5) -> [String] {
        // Return just the keyword names for easier use in queries
        return userPreferences?.selectedKeywords
            .sorted { $0.weight > $1.weight }
            .prefix(limit)
            .map { $0.keyword } ?? []
    }
    
    func getCategoryWeight(for category: String) -> Double {
        return userPreferences?.getCategoryWeight(for: category) ?? 0.0
    }
    
    func getKeywordWeight(for keyword: String) -> Double {
        return userPreferences?.getKeywordWeight(for: keyword) ?? 0.0
    }
    
    func hasCategory(_ category: String) -> Bool {
        return userPreferences?.hasCategory(category) ?? false
    }
    
    func hasKeyword(_ keyword: String) -> Bool {
        return userPreferences?.hasKeyword(keyword) ?? false
    }
    
    // MARK: - Migration Support
    
    func checkMigrationStatus(userId: String) async -> (migrated: Bool, version: String) {
        do {
            return try await userPreferencesService.checkMigrationStatus(userId: userId)
        } catch {
            print("❌ Error checking migration status: \(error)")
            return (migrated: false, version: "error")
        }
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - State Management
    
    var isPreferencesLoaded: Bool {
        return userPreferences != nil
    }
    
    var categoriesCount: Int {
        return userPreferences?.selectedCategories.count ?? 0
    }
    
    var keywordsCount: Int {
        return userPreferences?.selectedKeywords.count ?? 0
    }
    
    // MARK: - Debug Functions
    
    func printCurrentPreferences() {
        guard let preferences = userPreferences else {
            print("📱 No preferences loaded")
            return
        }
        
        print("📱 Current User Preferences:")
        print("Categories (\(preferences.selectedCategories.count)):")
        for category in preferences.selectedCategories.sorted(by: { $0.weight > $1.weight }) {
            print("  - \(category.category): \(String(format: "%.2f", category.weight))")
        }
        
        print("Keywords (\(preferences.selectedKeywords.count)):")
        for keyword in preferences.selectedKeywords.sorted(by: { $0.weight > $1.weight }) {
            print("  - \(keyword.keyword) (\(keyword.category)): \(String(format: "%.2f", keyword.weight))")
        }
        
        print("Version: \(preferences.categorizationVersion)")
        print("Last Updated: \(preferences.lastUpdated)")
    }
}
