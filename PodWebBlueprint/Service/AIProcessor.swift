//
//  AIProcessor.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/22/24.
//

import Foundation
import NaturalLanguage
import CoreML

class AIProcessor {
    
    // MARK: - Category and Keyword Definitions
    
    /// Master categorization system with 20 categories and 10 keywords each
    private let categorySystem: [String: [String]] = [
        "Technology": ["AI", "Machine Learning", "Programming", "Cybersecurity", "Blockchain", "Cloud Computing", "IoT", "Data Science", "Web Development", "Mobile Apps"],
        "Science": ["Physics", "Chemistry", "Biology", "Space", "Climate", "Research", "Discovery", "Innovation", "Laboratory", "Experiments"],
        "Business": ["Entrepreneurship", "Startups", "Management", "Marketing", "Strategy", "Leadership", "Innovation", "Growth", "Finance", "Networking"],
        "Finance": ["Investing", "Stocks", "Cryptocurrency", "Personal Finance", "Budgeting", "Real Estate", "Trading", "Retirement", "Taxes", "Insurance"],
        "Entertainment": ["Movies", "TV Shows", "Celebrity", "Streaming", "Awards", "Behind the Scenes", "Reviews", "Interviews", "Gossip", "Trends"],
        "Music": ["New Releases", "Artist Interviews", "Concerts", "Genres", "Production", "Industry News", "Reviews", "Playlists", "Collaborations", "Awards"],
        "Gaming": ["Video Games", "Esports", "Gaming News", "Reviews", "Streaming", "Competitive", "Indie Games", "Mobile Gaming", "PC Gaming", "Console Gaming"],
        "Health & Fitness": ["Exercise", "Nutrition", "Mental Health", "Wellness", "Workouts", "Healthy Eating", "Meditation", "Fitness Tips", "Medical News", "Wellness Trends"],
        "Food & Travel": ["Cooking", "Recipes", "Restaurants", "Destinations", "Travel Tips", "Culinary Arts", "Adventure", "Food Culture", "Travel Guides", "Local Cuisine"],
        "Education": ["Learning", "Skills", "Academic", "Online Courses", "Tutorials", "Study Tips", "Career Development", "Language Learning", "Professional Skills", "Personal Growth"],
        "News & Politics": ["Current Events", "Government", "Policy", "Elections", "International", "Breaking News", "Analysis", "Investigations", "Opinion", "Debates"],
        "Sports": ["Football", "Basketball", "Baseball", "Soccer", "Tennis", "Olympics", "Athletics", "Team Sports", "Individual Sports", "Sports News"],
        "Fashion & Beauty": ["Style Trends", "Beauty Tips", "Fashion Shows", "Makeup", "Skincare", "Hair", "Accessories", "Designers", "Street Style", "Beauty Products"],
        "Lifestyle": ["Home Decor", "Organization", "Productivity", "Self Care", "Relationships", "Parenting", "Pets", "Hobbies", "DIY Projects", "Life Tips"],
        "Comedy": ["Stand Up", "Sketch Comedy", "Podcasts", "Humor", "Jokes", "Comedy Shows", "Improv", "Satire", "Comedy Writing", "Comedians"],
        "Art & Design": ["Visual Arts", "Graphic Design", "Architecture", "Photography", "Digital Art", "Illustration", "Creative Process", "Art History", "Design Trends", "Portfolio"],
        "Books & Literature": ["Book Reviews", "Author Interviews", "Writing Tips", "Poetry", "Fiction", "Non Fiction", "Publishing", "Literary Analysis", "Reading Lists", "Book Clubs"],
        "Social Issues": ["Diversity", "Equality", "Social Justice", "Community", "Activism", "Human Rights", "Inclusion", "Social Change", "Advocacy", "Awareness"],
        "Environment": ["Sustainability", "Climate Change", "Conservation", "Green Living", "Renewable Energy", "Eco Friendly", "Nature", "Wildlife", "Environmental Policy", "Green Tech"],
        "History": ["Historical Events", "Ancient History", "World Wars", "Civilizations", "Historical Figures", "Archaeology", "Military History", "Cultural History", "Historical Analysis", "Timeline"]
    ]
    
    private let stopwords: Set<String> = [
        "i", "me", "my", "myself", "we", "our", "ours", "ourselves", "you", "your", "yours", "yourself", "yourselves",
        "he", "him", "his", "himself", "she", "her", "hers", "herself", "it", "its", "itself", "they", "them", "their",
        "theirs", "themselves", "what", "which", "who", "whom", "this", "that", "these", "those", "am", "is", "are",
        "was", "were", "be", "been", "being", "have", "has", "had", "having", "do", "does", "did", "doing", "a", "an",
        "the", "and", "but", "if", "or", "because", "as", "until", "while", "of", "at", "by", "for", "with", "about",
        "against", "between", "into", "through", "during", "before", "after", "above", "below", "to", "from", "up",
        "down", "in", "out", "on", "off", "over", "under", "again", "further", "then", "once", "here", "there", "when",
        "where", "why", "how", "all", "any", "both", "each", "few", "more", "most", "other", "some", "such", "no",
        "nor", "not", "only", "own", "same", "so", "than", "too", "very", "s", "t", "can", "will", "just", "don",
        "should", "now"
    ]
    
    private let tagger: NLTagger
    private let languageRecognizer: NLLanguageRecognizer
    
    init() {
        tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .lemma])
        languageRecognizer = NLLanguageRecognizer()
    }
    
    // MARK: - Main Processing Function
    
    /// Processes a pod by analyzing title, description, and user tags to determine category and keywords
    /// - Parameters:
    ///   - title: The pod title
    ///   - description: The pod description
    ///   - userTags: User-applied tags (optional)
    /// - Returns: A tuple containing the category and 5 selected keywords
    func processPod(title: String, description: String, userTags: [String]? = nil) -> (category: String, keywords: [String]) {
        if AIConfig.enableDebugging {
            print("🔧 [Local AI] Starting local categorization for: '\(title.prefix(50))...'")
        }
        
        // Combine all text sources for analysis
        let combinedText = "\(title) \(description) \(userTags?.joined(separator: " ") ?? "")"
        
        if AIConfig.enableDebugging {
            print("🔧 [Local AI] Analyzing \(combinedText.count) characters of content")
        }
        
        let startTime = Date()
        
        // Determine the best category
        let category = determineBestCategory(title: title, description: description, userTags: userTags)
        
        if AIConfig.enableDebugging {
            print("🔧 [Local AI] Category determined: '\(category)'")
        }
        
        // Select 5 most relevant keywords from the chosen category
        let keywords = selectRelevantKeywords(from: category, title: title, description: description, userTags: userTags)
        
        let duration = Date().timeIntervalSince(startTime)
        
        if AIConfig.enableDebugging {
            print("🔧 [Local AI] ✅ Processing complete - Duration: \(String(format: "%.3f", duration))s")
            print("🔧 [Local AI] Final result - Category: '\(category)' | Keywords: \(keywords)")
        }
        
        return (category, keywords)
    }
    
    // MARK: - Category Determination
    
    /// Determines the best category based on title, description, and user tags
    private func determineBestCategory(title: String, description: String, userTags: [String]?) -> String {
        var categoryScores: [String: Double] = [:]
        
        // Initialize all categories with 0 score
        for category in categorySystem.keys {
            categoryScores[category] = 0.0
        }
        
        // Score based on title (highest weight)
        let titleScore = analyzeTextForCategories(title)
        for (category, score) in titleScore {
            categoryScores[category, default: 0] += score * 3.0 // Title gets 3x weight
        }
        
        // Score based on description
        let descriptionScore = analyzeTextForCategories(description)
        for (category, score) in descriptionScore {
            categoryScores[category, default: 0] += score * 2.0 // Description gets 2x weight
        }
        
        // Score based on user tags (highest weight if provided)
        if let userTags = userTags, !userTags.isEmpty {
            let userTagScore = analyzeUserTagsForCategories(userTags)
            for (category, score) in userTagScore {
                categoryScores[category, default: 0] += score * 4.0 // User tags get 4x weight
            }
        }
        
        // Return the category with the highest score
        let bestCategory = categoryScores.max(by: { $0.value < $1.value })?.key ?? "Technology"
        return bestCategory
    }
    
    /// Analyzes text content for category relevance
    private func analyzeTextForCategories(_ text: String) -> [String: Double] {
        var categoryScores: [String: Double] = [:]
        let lowercasedText = text.lowercased()
        
        for (category, keywords) in categorySystem {
            var score = 0.0
            
            for keyword in keywords {
                let lowercasedKeyword = keyword.lowercased()
                
                // Exact match gets highest score
                if lowercasedText.contains(lowercasedKeyword) {
                    score += 10.0
                }
                
                // Partial word match gets medium score
                let words = lowercasedText.components(separatedBy: " ")
                for word in words {
                    if word.contains(lowercasedKeyword) || lowercasedKeyword.contains(word) {
                        score += 5.0
                    }
                }
                
                // Stemmed word matching
                if let stemmedKeyword = stemWord(lowercasedKeyword),
                   let stemmedText = stemWord(lowercasedText) {
                    if stemmedText.contains(stemmedKeyword) {
                        score += 3.0
                    }
                }
            }
            
            categoryScores[category] = score
        }
        
        return categoryScores
    }
    
    /// Analyzes user tags for category relevance
    private func analyzeUserTagsForCategories(_ userTags: [String]) -> [String: Double] {
        var categoryScores: [String: Double] = [:]
        
        for (category, keywords) in categorySystem {
            var score = 0.0
            
            for userTag in userTags {
                let lowercasedUserTag = userTag.lowercased()
                
                for keyword in keywords {
                    let lowercasedKeyword = keyword.lowercased()
                    
                    // Exact match gets highest score
                    if lowercasedUserTag == lowercasedKeyword {
                        score += 15.0
                    }
                    
                    // Partial match gets medium score
                    if lowercasedUserTag.contains(lowercasedKeyword) || lowercasedKeyword.contains(lowercasedUserTag) {
                        score += 8.0
                    }
                }
            }
            
            categoryScores[category] = score
        }
        
        return categoryScores
    }
    
    // MARK: - Keyword Selection
    
    /// Selects 5 most relevant keywords from the chosen category
    private func selectRelevantKeywords(from category: String, title: String, description: String, userTags: [String]?) -> [String] {
        guard let categoryKeywords = categorySystem[category] else {
            return ["AI", "Technology", "Innovation", "Innovation", "Innovation"] // Fallback keywords (5 total)
        }
        
        var keywordScores: [(keyword: String, score: Double)] = []
        let combinedText = "\(title) \(description) \(userTags?.joined(separator: " ") ?? "")"
        let lowercasedText = combinedText.lowercased()
        
        for keyword in categoryKeywords {
            var score = 0.0
            let lowercasedKeyword = keyword.lowercased()
            
            // Exact match in title gets highest score
            if title.lowercased().contains(lowercasedKeyword) {
                score += 20.0
            }
            
            // Exact match in description
            if description.lowercased().contains(lowercasedKeyword) {
                score += 15.0
            }
            
            // Exact match in user tags
            if let userTags = userTags {
                for userTag in userTags {
                    if userTag.lowercased() == lowercasedKeyword {
                        score += 25.0 // User tags get highest priority
                    }
                }
            }
            
            // Partial matches
            if lowercasedText.contains(lowercasedKeyword) {
                score += 10.0
            }
            
            // Stemmed matching
            if let stemmedKeyword = stemWord(lowercasedKeyword),
               let stemmedText = stemWord(lowercasedText) {
                if stemmedText.contains(stemmedKeyword) {
                    score += 5.0
                }
            }
            
            // Add semantic relevance based on word similarity
            let titleWords = title.lowercased().components(separatedBy: " ")
            let descriptionWords = description.lowercased().components(separatedBy: " ")
            
            for word in titleWords + descriptionWords {
                let wordSimilarity = calculateWordSimilarity(word: word, keyword: lowercasedKeyword)
                score += wordSimilarity
            }
            
            keywordScores.append((keyword, score))
        }
        
        // Sort by score and return top 5
        let topKeywords = keywordScores
            .sorted(by: { $0.score > $1.score })
            .prefix(5)
            .map { $0.keyword }
        
        // Ensure we always return exactly 5 keywords
        if topKeywords.count < 5 {
            let remainingKeywords = categoryKeywords.filter { !topKeywords.contains($0) }
            let additionalKeywords = Array(remainingKeywords.prefix(5 - topKeywords.count))
            return topKeywords + additionalKeywords
        }
        
        return Array(topKeywords)
    }
    
    // MARK: - Utility Functions
    
    /// Simple word stemming for better keyword matching
    private func stemWord(_ word: String) -> String? {
        // Basic stemming - remove common suffixes
        let suffixes = ["ing", "ed", "er", "est", "ly", "s", "es"]
        
        for suffix in suffixes {
            if word.hasSuffix(suffix) && word.count > suffix.count + 2 {
                let stemmed = String(word.dropLast(suffix.count))
                return stemmed
            }
        }
        
        return word
    }
    
    /// Calculates word similarity between two words
    private func calculateWordSimilarity(word: String, keyword: String) -> Double {
        let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)
        let cleanKeyword = keyword.trimmingCharacters(in: .punctuationCharacters)
        
        // Skip very short words
        if cleanWord.count < 3 || cleanKeyword.count < 3 {
            return 0.0
        }
        
        // Exact match
        if cleanWord == cleanKeyword {
            return 8.0
        }
        
        // Contains match
        if cleanWord.contains(cleanKeyword) || cleanKeyword.contains(cleanWord) {
            return 6.0
        }
        
        // Common prefixes/suffixes
        if cleanWord.hasPrefix(cleanKeyword.prefix(3)) || cleanKeyword.hasPrefix(cleanWord.prefix(3)) {
            return 3.0
        }
        
        // Length similarity
        let lengthDiff = abs(cleanWord.count - cleanKeyword.count)
        if lengthDiff <= 2 {
            return 1.0
        }
        
        return 0.0
    }
    
    // MARK: - Legacy Support (for backward compatibility)
    
    /// Legacy function for processing posts - now redirects to processPod
    func processPost(caption: String) -> (category: String, keywords: [String]) {
        return processPod(title: caption, description: "", userTags: nil)
    }
    
    /// Get all available categories
    func getAllCategories() -> [String] {
        return Array(categorySystem.keys)
    }
    
    /// Get keywords for a specific category
    func getKeywords(for category: String) -> [String] {
        return categorySystem[category] ?? []
    }
    
    /// Get the entire category system
    func getCategorySystem() -> [String: [String]] {
        return categorySystem
    }
    
    /// Debug function to see keyword scoring (for testing)
    func debugKeywordScoring(title: String, description: String, userTags: [String]?) -> [String: [(keyword: String, score: Double)]] {
        var debugResults: [String: [(keyword: String, score: Double)]] = [:]
        
        for (category, keywords) in categorySystem {
            var keywordScores: [(keyword: String, score: Double)] = []
            let combinedText = "\(title) \(description) \(userTags?.joined(separator: " ") ?? "")"
            let lowercasedText = combinedText.lowercased()
            
            for keyword in keywords {
                var score = 0.0
                let lowercasedKeyword = keyword.lowercased()
                
                // Exact match in title
                if title.lowercased().contains(lowercasedKeyword) {
                    score += 20.0
                }
                
                // Exact match in description
                if description.lowercased().contains(lowercasedKeyword) {
                    score += 15.0
                }
                
                // Exact match in user tags
                if let userTags = userTags {
                    for userTag in userTags {
                        if userTag.lowercased() == lowercasedKeyword {
                            score += 25.0
                        }
                    }
                }
                
                // Partial matches
                if lowercasedText.contains(lowercasedKeyword) {
                    score += 10.0
                }
                
                // Stemmed matching
                if let stemmedKeyword = stemWord(lowercasedKeyword),
                   let stemmedText = stemWord(lowercasedText) {
                    if stemmedText.contains(stemmedKeyword) {
                        score += 5.0
                    }
                }
                
                // Word similarity
                let titleWords = title.lowercased().components(separatedBy: " ")
                let descriptionWords = description.lowercased().components(separatedBy: " ")
                
                for word in titleWords + descriptionWords {
                    let wordSimilarity = calculateWordSimilarity(word: word, keyword: lowercasedKeyword)
                    score += wordSimilarity
                }
                
                keywordScores.append((keyword, score))
            }
            
            // Sort by score
            keywordScores.sort(by: { $0.score > $1.score })
            debugResults[category] = keywordScores
        }
        
        return debugResults
    }
}
