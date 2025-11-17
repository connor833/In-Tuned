//
//  UsernameValidator.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 8/13/24.
//

import Foundation

/// Comprehensive username validation utility that ensures security and data integrity
struct UsernameValidator {
    
    // MARK: - Validation Constants
    
    /// Minimum username length
    static let minLength = 3
    
    /// Maximum username length
    static let maxLength = 20
    
    /// Allowed characters for usernames (alphanumeric and underscore only)
    static let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
    
    /// Reserved usernames that should not be allowed
    static let reservedUsernames: Set<String> = [
        "admin", "administrator", "root", "system", "support", "help", "info",
        "contact", "mail", "webmaster", "noreply", "no-reply", "test", "demo",
        "example", "sample", "guest", "anonymous", "anon", "user", "users",
        "account", "accounts", "profile", "profiles", "settings", "config",
        "configuration", "api", "app", "application", "service", "services",
        "bot", "robot", "automated", "auto", "script", "crawler", "spider",
        "null", "undefined", "none", "empty", "deleted", "removed", "banned",
        "suspended", "moderator", "mod", "staff", "team", "official", "verified",
        "premium", "vip", "gold", "silver", "bronze", "beta", "alpha", "dev",
        "development", "staging", "production", "live", "online", "offline",
        "error", "404", "500", "403", "401", "400", "500", "maintenance",
        "down", "up", "status", "health", "monitor", "logging", "debug",
        "localhost", "127.0.0.1", "0.0.0.0", "255.255.255.255", "loopback",
        "internal", "external", "public", "private", "secret", "hidden",
        "invisible", "ghost", "shadow", "dark", "light", "white", "black",
        "red", "green", "blue", "yellow", "orange", "purple", "pink", "brown",
        "gray", "grey", "cyan", "magenta", "lime", "navy", "teal", "olive",
        "maroon", "coral", "indigo", "violet", "azure", "beige", "ivory",
        "khaki", "lavender", "mint", "peach", "plum", "salmon", "tan", "wheat"
    ]
    
    // MARK: - Validation Methods
    
    /// Validates a username and returns detailed validation results
    /// - Parameter username: The username to validate
    /// - Returns: UsernameValidationResult with detailed feedback
    static func validate(_ username: String) -> UsernameValidationResult {
        
        // Check for empty username
        guard !username.isEmpty else {
            return UsernameValidationResult(
                isValid: false,
                errorType: .empty,
                errorMessage: "Username cannot be empty"
            )
        }
        
        // Check minimum length
        guard username.count >= minLength else {
            return UsernameValidationResult(
                isValid: false,
                errorType: .tooShort,
                errorMessage: "Username must be at least \(minLength) characters long"
            )
        }
        
        // Check maximum length
        guard username.count <= maxLength else {
            return UsernameValidationResult(
                isValid: false,
                errorType: .tooLong,
                errorMessage: "Username cannot exceed \(maxLength) characters"
            )
        }
        
        // Check for spaces
        guard !username.contains(" ") else {
            return UsernameValidationResult(
                isValid: false,
                errorType: .containsSpaces,
                errorMessage: "Username cannot contain spaces"
            )
        }
        
        // Check for tabs and newlines
        guard !username.contains("\t") && !username.contains("\n") && !username.contains("\r") else {
            return UsernameValidationResult(
                isValid: false,
                errorType: .containsWhitespace,
                errorMessage: "Username cannot contain tabs or line breaks"
            )
        }
        
        // Check for special characters (only allow alphanumeric and underscore)
        let invalidCharacters = username.unicodeScalars.filter { !allowedCharacters.contains($0) }
        guard invalidCharacters.isEmpty else {
            let invalidChars = String(invalidCharacters)
            return UsernameValidationResult(
                isValid: false,
                errorType: .invalidCharacters,
                errorMessage: "Username can only contain letters, numbers, and underscores. Invalid characters: \(invalidChars)"
            )
        }
        
        // Check if username starts with a number (optional restriction)
        if let firstChar = username.first, firstChar.isNumber {
            return UsernameValidationResult(
                isValid: false,
                errorType: .startsWithNumber,
                errorMessage: "Username cannot start with a number"
            )
        }
        
        // Check if username starts with underscore (optional restriction)
        if username.hasPrefix("_") {
            return UsernameValidationResult(
                isValid: false,
                errorType: .startsWithUnderscore,
                errorMessage: "Username cannot start with an underscore"
            )
        }
        
        // Check if username ends with underscore (optional restriction)
        if username.hasSuffix("_") {
            return UsernameValidationResult(
                isValid: false,
                errorType: .endsWithUnderscore,
                errorMessage: "Username cannot end with an underscore"
            )
        }
        
        // Check for consecutive underscores
        if username.contains("__") {
            return UsernameValidationResult(
                isValid: false,
                errorType: .consecutiveUnderscores,
                errorMessage: "Username cannot contain consecutive underscores"
            )
        }
        
        // Check for reserved usernames
        let lowercaseUsername = username.lowercased()
        if reservedUsernames.contains(lowercaseUsername) {
            return UsernameValidationResult(
                isValid: false,
                errorType: .reserved,
                errorMessage: "This username is reserved and cannot be used"
            )
        }
        
        // Check for potentially offensive patterns
        if containsOffensivePatterns(lowercaseUsername) {
            return UsernameValidationResult(
                isValid: false,
                errorType: .potentiallyOffensive,
                errorMessage: "Username may contain inappropriate content"
            )
        }
        
        // Check for excessive numbers (more than 50% of characters)
        let numberCount = username.filter { $0.isNumber }.count
        let numberPercentage = Double(numberCount) / Double(username.count)
        if numberPercentage > 0.5 {
            return UsernameValidationResult(
                isValid: false,
                errorType: .tooManyNumbers,
                errorMessage: "Username cannot be more than 50% numbers"
            )
        }
        
        // All validations passed
        return UsernameValidationResult(
            isValid: true,
            errorType: nil,
            errorMessage: nil
        )
    }
    
    /// Quick validation check that returns just a boolean
    /// - Parameter username: The username to validate
    /// - Returns: True if username is valid, false otherwise
    static func isValid(_ username: String) -> Bool {
        return validate(username).isValid
    }
    
    /// Sanitizes a username by removing invalid characters and normalizing
    /// - Parameter username: The username to sanitize
    /// - Returns: Sanitized username or nil if too many characters were removed
    static func sanitize(_ username: String) -> String? {
        // Remove invalid characters
        let sanitized = username.unicodeScalars.filter { allowedCharacters.contains($0) }
        let sanitizedString = String(sanitized)
        
        // Check if sanitization removed too many characters
        let originalLength = username.count
        let sanitizedLength = sanitizedString.count
        let removalPercentage = Double(originalLength - sanitizedLength) / Double(originalLength)
        
        // If more than 30% of characters were removed, return nil
        if removalPercentage > 0.3 {
            return nil
        }
        
        return sanitizedString
    }
    
    // MARK: - Helper Methods
    
    /// Checks if username contains potentially offensive patterns
    /// - Parameter username: The username to check
    /// - Returns: True if potentially offensive patterns are detected
    private static func containsOffensivePatterns(_ username: String) -> Bool {
        // Use InputSanitizer's profanity detection for consistency
        // This ensures the same word list and normalization logic is used across the app
        return InputSanitizer.containsProfanity(username)
    }
    
    /// Generates a list of validation suggestions for an invalid username
    /// - Parameter username: The invalid username
    /// - Returns: Array of suggestion strings
    static func getSuggestions(for username: String) -> [String] {
        var suggestions: [String] = []
        
        // Remove spaces
        if username.contains(" ") {
            suggestions.append(username.replacingOccurrences(of: " ", with: ""))
        }
        
        // Remove special characters
        let sanitized = username.unicodeScalars.filter { allowedCharacters.contains($0) }
        if sanitized.count != username.count {
            suggestions.append(String(sanitized))
        }
        
        // Add underscore between words
        if username.contains(" ") {
            suggestions.append(username.replacingOccurrences(of: " ", with: "_"))
        }
        
        // Remove consecutive underscores
        if username.contains("__") {
            suggestions.append(username.replacingOccurrences(of: "__", with: "_"))
        }
        
        // Remove leading/trailing underscores
        if username.hasPrefix("_") || username.hasSuffix("_") {
            suggestions.append(username.trimmingCharacters(in: CharacterSet(charactersIn: "_")))
        }
        
        // Limit suggestions to 5
        return Array(suggestions.prefix(5))
    }
}

// MARK: - Validation Result Types

/// Result of username validation with detailed error information
struct UsernameValidationResult {
    let isValid: Bool
    let errorType: UsernameValidationError?
    let errorMessage: String?
    
    /// Convenience initializer for valid usernames
    static func valid() -> UsernameValidationResult {
        return UsernameValidationResult(isValid: true, errorType: nil, errorMessage: nil)
    }
    
    /// Convenience initializer for invalid usernames
    static func invalid(_ errorType: UsernameValidationError, message: String) -> UsernameValidationResult {
        return UsernameValidationResult(isValid: false, errorType: errorType, errorMessage: message)
    }
}

/// Types of username validation errors
enum UsernameValidationError: CaseIterable {
    case empty
    case tooShort
    case tooLong
    case containsSpaces
    case containsWhitespace
    case invalidCharacters
    case startsWithNumber
    case startsWithUnderscore
    case endsWithUnderscore
    case consecutiveUnderscores
    case reserved
    case potentiallyOffensive
    case tooManyNumbers
    
    /// User-friendly error message for each error type
    var userMessage: String {
        switch self {
        case .empty:
            return "Username cannot be empty"
        case .tooShort:
            return "Username is too short"
        case .tooLong:
            return "Username is too long"
        case .containsSpaces:
            return "Username cannot contain spaces"
        case .containsWhitespace:
            return "Username cannot contain tabs or line breaks"
        case .invalidCharacters:
            return "Username contains invalid characters"
        case .startsWithNumber:
            return "Username cannot start with a number"
        case .startsWithUnderscore:
            return "Username cannot start with an underscore"
        case .endsWithUnderscore:
            return "Username cannot end with an underscore"
        case .consecutiveUnderscores:
            return "Username cannot contain consecutive underscores"
        case .reserved:
            return "Username is reserved"
        case .potentiallyOffensive:
            return "Username may be inappropriate"
        case .tooManyNumbers:
            return "Username has too many numbers"
        }
    }
}
