//
//  AIConfig.swift
//  PodWebBlueprint
//
//  Configuration for AI services
//

import Foundation

struct AIConfig {
    // MARK: - OpenAI Configuration
    
    /// OpenAI API Key - Consider moving to environment variables or secure storage in production
    static let openAIAPIKey = "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"
    
    // MARK: - Feature Flags
    
    static let useOpenAIForCategorization = true
    static let enableFallbackToLocalProcessor = true
    /// Enable detailed logging for AI categorization debugging
    static let enableDebugging = true
    
    // MARK: - Request Configuration
    
    /// Use GPT-4o-mini for better categorization accuracy at lower cost
    static let openAIModel = "gpt-4o-mini"
    static let requestTimeout: TimeInterval = 30.0
    static let maxRetries = 3
    /// Lower temperature for more consistent categorization
    static let temperature: Double = 0.1
    /// Increased tokens for better keyword generation
    static let maxTokens = 200
    
    // MARK: - Categorization Configuration
    
    /// The exact 20 categories that OpenAI must choose from
    static let validCategories = [
        "Technology", "Science", "Business", "Finance", "Entertainment",
        "Music", "Gaming", "Health & Fitness", "Food & Travel", "Education", 
        "News & Politics", "Sports", "Fashion & Beauty", "Lifestyle", "Comedy",
        "Art & Design", "Books & Literature", "Social Issues", "Environment", "History"
    ]
    
    /// Number of keywords to generate
    static let keywordCount = 5
}
