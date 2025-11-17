//
//  InputSanitizer.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 8/13/24.
//

import Foundation

/// Comprehensive input sanitizer for iOS app security
/// Handles real threats: length limits, excessive newlines, special characters, spam prevention
struct InputSanitizer {
    
    // MARK: - Input Types and Limits
    
    enum InputType {
        case podTitle
        case podDescription
        case playlistTitle
        case playlistDescription
        case userBio
        case comment
        case message
        case fullName
        case link
        case tag
        
        var maxLength: Int {
            switch self {
            case .podTitle: return 200
            case .podDescription: return 1000
            case .playlistTitle: return 100
            case .playlistDescription: return 500
            case .userBio: return 500
            case .comment: return 500
            case .message: return 1000
            case .fullName: return 100
            case .link: return 200
            case .tag: return 50
            }
        }
        
        var maxNewlines: Int {
            switch self {
            case .podTitle: return 0
            case .podDescription: return 20
            case .playlistTitle: return 0
            case .playlistDescription: return 10
            case .userBio: return 10
            case .comment: return 5
            case .message: return 20
            case .fullName: return 0
            case .link: return 0
            case .tag: return 0
            }
        }
        
        var maxSpecialCharacters: Int {
            switch self {
            case .podTitle: return 20
            case .podDescription: return 100
            case .playlistTitle: return 20
            case .playlistDescription: return 50
            case .userBio: return 50
            case .comment: return 50
            case .message: return 100
            case .fullName: return 30
            case .link: return 50
            case .tag: return 10
            }
        }
    }
    
    // MARK: - Main Sanitization Method
    
    /// Sanitizes input based on type and returns validation result
    /// - Parameters:
    ///   - input: Raw input string
    ///   - type: Type of input being sanitized
    /// - Returns: SanitizationResult with success status and cleaned text
    static func sanitize(_ input: String, type: InputType) -> SanitizationResult {
        
        // Check for completely empty input (allow spaces and newlines)
        guard !input.isEmpty else {
            return SanitizationResult(
                isValid: false,
                sanitizedText: "",
                errorMessage: "Input cannot be empty"
            )
        }
        
        // Check length
        if input.count > type.maxLength {
            return SanitizationResult(
                isValid: false,
                sanitizedText: "",
                errorMessage: "Input cannot exceed \(type.maxLength) characters"
            )
        }
        
        // For pod titles and descriptions, be permissive with spaces and special characters
        // BUT check for profanity since this is public content
        if type == .podTitle || type == .podDescription {
            // Only check for excessive newlines
            let newlineCount = input.filter { $0 == "\n" }.count
            if newlineCount > type.maxNewlines {
                return SanitizationResult(
                    isValid: false,
                    sanitizedText: "",
                    errorMessage: "Too many line breaks (max \(type.maxNewlines))"
                )
            }
            
            // Check for profanity (public content)
            if containsProfanity(input) {
                let fieldName = type == .podTitle ? "pod title" : "pod description"
                return SanitizationResult(
                    isValid: false,
                    sanitizedText: "",
                    errorMessage: "Your \(fieldName) contains inappropriate language. Please use appropriate language for your public content."
                )
            }
            
            // Check for spam patterns
            if containsSpamPatterns(input) {
                return SanitizationResult(
                    isValid: false,
                    sanitizedText: "",
                    errorMessage: "Input contains spam patterns"
                )
            }
            
            // Clean and normalize the text (but preserve spaces)
            let cleanedText = cleanText(input, type: type)
            
            return SanitizationResult(
                isValid: true,
                sanitizedText: cleanedText,
                errorMessage: nil
            )
        }
        
        // For user bios, full names, and playlists, be permissive with spaces and special characters
        // BUT check for profanity since these are public profile/content fields
        if type == .userBio || type == .fullName || type == .playlistTitle || type == .playlistDescription {
            // Only check for excessive newlines
            let newlineCount = input.filter { $0 == "\n" }.count
            if newlineCount > type.maxNewlines {
                return SanitizationResult(
                    isValid: false,
                    sanitizedText: "",
                    errorMessage: "Too many line breaks (max \(type.maxNewlines))"
                )
            }
            
            // Check for profanity (public profile/playlist content)
            if containsProfanity(input) {
                let fieldName: String
                switch type {
                case .userBio: fieldName = "bio"
                case .fullName: fieldName = "name"
                case .playlistTitle: fieldName = "playlist title"
                case .playlistDescription: fieldName = "playlist description"
                default: fieldName = "field"
                }
                return SanitizationResult(
                    isValid: false,
                    sanitizedText: "",
                    errorMessage: "Your \(fieldName) contains inappropriate language. Please use appropriate language for your public content."
                )
            }
            
            // Check for spam patterns
            if containsSpamPatterns(input) {
                return SanitizationResult(
                    isValid: false,
                    sanitizedText: "",
                    errorMessage: "Input contains spam patterns"
                )
            }
            
            // Clean and normalize the text (but preserve spaces)
            let cleanedText = cleanText(input, type: type)
            
            return SanitizationResult(
                isValid: true,
                sanitizedText: cleanedText,
                errorMessage: nil
            )
        }
        
        // For other input types, keep existing validation
        // Check for excessive newlines
        let newlineCount = input.filter { $0 == "\n" }.count
        if newlineCount > type.maxNewlines {
            return SanitizationResult(
                isValid: false,
                sanitizedText: "",
                errorMessage: "Too many line breaks (max \(type.maxNewlines))"
            )
        }
        
        // Check for excessive special characters
        let specialCharCount = input.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count
        if specialCharCount > type.maxSpecialCharacters {
            return SanitizationResult(
                isValid: false,
                sanitizedText: "",
                errorMessage: "Too many special characters (max \(type.maxSpecialCharacters))"
            )
        }
        
        // Check for profanity (for comments, messages, and tags)
        if type == .comment || type == .message || type == .tag {
            if containsProfanity(input) {
                let errorMsg: String
                switch type {
                case .comment: errorMsg = "Cannot post comment. Please remove inappropriate language."
                case .message: errorMsg = "Cannot send message. Please remove inappropriate language."
                case .tag: errorMsg = "Tag contains inappropriate language. Please use appropriate keywords."
                default: errorMsg = "Input contains inappropriate language."
                }
                return SanitizationResult(
                    isValid: false,
                    sanitizedText: "",
                    errorMessage: errorMsg
                )
            }
        }
        
        // Check for spam patterns
        if containsSpamPatterns(input) {
            return SanitizationResult(
                isValid: false,
                sanitizedText: "",
                errorMessage: "Input contains spam patterns"
            )
        }
        
        // Check for excessive repetition
        if containsExcessiveRepetition(input) {
            return SanitizationResult(
                isValid: false,
                sanitizedText: "",
                errorMessage: "Input contains excessive repetition"
            )
        }
        
        // Clean and normalize the text
        let cleanedText = cleanText(input, type: type)
        
        // Final check: ensure cleaned text isn't just whitespace
        if cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return SanitizationResult(
                isValid: false,
                sanitizedText: "",
                errorMessage: "Input cannot be just spaces or empty after cleaning"
            )
        }
        
        return SanitizationResult(
            isValid: true,
            sanitizedText: cleanedText,
            errorMessage: nil
        )
    }
    
    // MARK: - Profanity Filtering
    
    /// English profanity word list
    /// Curated list of obvious profanity - can be expanded later
    private static let profanityList: Set<String> = [
        // Common profanity (keeping it minimal and obvious)
        "fuck", "shit", "bitch", "asshole", "bastard", "damn", "crap",
        "pussy", "dick", "cock", "piss", "cunt", "whore", "slut",
        "fag", "faggot", "nigger", "nigga", "retard", "retarded",
        // Add more as needed
    ]
    
    /// Normalizes text to catch evasion attempts (l33t speak, spacing, special chars)
    /// Examples: "f u c k" → "fuck", "sh1t" → "shit", "b!tch" → "bitch"
    private static func normalizeForProfanityCheck(_ input: String) -> String {
        var normalized = input.lowercased()
        
        // Remove all spaces (catches "f u c k", "s h i t")
        normalized = normalized.replacingOccurrences(of: " ", with: "")
        
        // Replace common l33t speak substitutions
        normalized = normalized.replacingOccurrences(of: "0", with: "o")
        normalized = normalized.replacingOccurrences(of: "1", with: "i")
        normalized = normalized.replacingOccurrences(of: "3", with: "e")
        normalized = normalized.replacingOccurrences(of: "4", with: "a")
        normalized = normalized.replacingOccurrences(of: "5", with: "s")
        normalized = normalized.replacingOccurrences(of: "7", with: "t")
        normalized = normalized.replacingOccurrences(of: "8", with: "b")
        normalized = normalized.replacingOccurrences(of: "@", with: "a")
        normalized = normalized.replacingOccurrences(of: "$", with: "s")
        
        // Remove common separators and special characters (catches "f*ck", "sh!t", "b-tch")
        normalized = normalized.replacingOccurrences(of: "*", with: "")
        normalized = normalized.replacingOccurrences(of: "!", with: "i")
        normalized = normalized.replacingOccurrences(of: "-", with: "")
        normalized = normalized.replacingOccurrences(of: "_", with: "")
        normalized = normalized.replacingOccurrences(of: ".", with: "")
        normalized = normalized.replacingOccurrences(of: ",", with: "")
        
        return normalized
    }
    
    /// Checks if input contains profanity
    /// Uses normalization to catch common evasion attempts
    /// Made internal so UsernameValidator can use the same profanity detection
    static func containsProfanity(_ input: String) -> Bool {
        let normalized = normalizeForProfanityCheck(input)
        
        // Check if any profanity word exists in the normalized text
        for word in profanityList {
            if normalized.contains(word) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Text Cleaning Methods
    
    /// Cleans and normalizes text based on input type
    private static func cleanText(_ input: String, type: InputType) -> String {
        var cleaned = input
        
        // For pod titles, descriptions, user bios, full names, and playlists, be very gentle with space handling
        if type == .podTitle || type == .podDescription || type == .userBio || type == .fullName || type == .playlistTitle || type == .playlistDescription {
            // Only collapse multiple consecutive spaces into single spaces
            cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            
            // Remove excessive newlines (keep within limits)
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            
            // Don't trim leading/trailing spaces for pod content, bio, and full names - preserve user intent
            // Only normalize line endings
            cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
            cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
            
            return cleaned
        }
        
        // For other input types, use existing cleaning logic
        // Remove excessive whitespace (but preserve normal spacing)
        // Only collapse multiple spaces into single spaces, don't remove all spaces
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        // Remove excessive newlines (keep within limits)
        cleaned = cleaned.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        // Trim leading/trailing whitespace only
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize line endings
        cleaned = cleaned.replacingOccurrences(of: "\r\n", with: "\n")
        cleaned = cleaned.replacingOccurrences(of: "\r", with: "\n")
        
        return cleaned
    }
    
    /// Checks for spam patterns in text
    private static func containsSpamPatterns(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        
        // Check for excessive repetition of characters
        let patterns = [
            "aaaa", "bbbb", "cccc", "dddd", "eeee", "ffff", "gggg", "hhhh", "iiii", "jjjj",
            "kkkk", "llll", "mmmm", "nnnn", "oooo", "pppp", "qqqq", "rrrr", "ssss", "tttt",
            "uuuu", "vvvv", "wwww", "xxxx", "yyyy", "zzzz", "0000", "1111", "2222", "3333",
            "4444", "5555", "6666", "7777", "8888", "9999"
        ]
        
        return patterns.contains { lowercased.contains($0) }
    }
    
    /// Checks for excessive repetition in text
    private static func containsExcessiveRepetition(_ input: String) -> Bool {
        let words = input.components(separatedBy: .whitespaces)
        let wordCount = words.count
        
        if wordCount < 3 { return false }
        
        // Check if more than 50% of words are the same
        let wordFrequency = Dictionary(grouping: words, by: { $0.lowercased() })
        let mostFrequentCount = wordFrequency.values.map { $0.count }.max() ?? 0
        
        return Double(mostFrequentCount) / Double(wordCount) > 0.5
    }
    
    // MARK: - Quick Validation Methods
    
    /// Quick validation check that returns just a boolean
    static func isValid(_ input: String, type: InputType) -> Bool {
        return sanitize(input, type: type).isValid
    }
    
    /// Quick sanitization that returns just the cleaned text
    static func clean(_ input: String, type: InputType) -> String {
        let result = sanitize(input, type: type)
        // If sanitization fails, return original input to prevent data loss
        // This allows users to continue typing even if validation fails
        return result.isValid ? result.sanitizedText : input
    }
    
    // MARK: - Specific Input Type Methods
    
    /// Sanitizes pod title specifically
    static func sanitizePodTitle(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .podTitle)
    }
    
    /// Sanitizes pod description specifically
    static func sanitizePodDescription(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .podDescription)
    }
    
    /// Sanitizes user bio specifically
    static func sanitizeUserBio(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .userBio)
    }
    
    /// Sanitizes comment text specifically
    static func sanitizeComment(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .comment)
    }
    
    /// Sanitizes message text specifically
    static func sanitizeMessage(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .message)
    }
    
    /// Sanitizes full name specifically
    static func sanitizeFullName(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .fullName)
    }
    
    /// Sanitizes link text specifically
    static func sanitizeLink(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .link)
    }
    
    /// Sanitizes tag text specifically
    static func sanitizeTag(_ input: String) -> SanitizationResult {
        return sanitize(input, type: .tag)
    }
}

// MARK: - Result Types

/// Result of input sanitization
struct SanitizationResult {
    let isValid: Bool
    let sanitizedText: String
    let errorMessage: String?
    
    /// Convenience initializer for valid input
    static func valid(_ text: String) -> SanitizationResult {
        return SanitizationResult(isValid: true, sanitizedText: text, errorMessage: nil)
    }
    
    /// Convenience initializer for invalid input
    static func invalid(_ message: String) -> SanitizationResult {
        return SanitizationResult(isValid: false, sanitizedText: "", errorMessage: message)
    }
}
