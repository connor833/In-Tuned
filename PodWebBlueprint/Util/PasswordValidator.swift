import Foundation

/// Comprehensive password validation utility that ensures strong password security
/// Implements industry-standard password requirements to prevent brute force attacks
struct PasswordValidator {
    
    // MARK: - Password Requirements
    
    /// Minimum password length (industry standard: 8+ characters)
    static let minLength = 8
    
    /// Maximum password length (reasonable limit)
    static let maxLength = 128
    
    /// Minimum number of uppercase letters required
    static let minUppercase = 1
    
    /// Minimum number of lowercase letters required
    static let minLowercase = 1
    
    /// Minimum number of digits required
    static let minDigits = 1
    
    /// Minimum number of special characters required
    static let minSpecialChars = 1
    
    /// Maximum number of consecutive identical characters allowed
    static let maxConsecutiveIdentical = 3
    
    /// Maximum number of sequential characters allowed (e.g., "123", "abc")
    static let maxSequentialChars = 3
    
    /// Common weak passwords that should be blocked
    static let commonWeakPasswords: Set<String> = [
        "password", "123456", "123456789", "qwerty", "abc123", "password123",
        "admin", "letmein", "welcome", "monkey", "dragon", "master", "football",
        "baseball", "superman", "trustno1", "butterfly", "dragon", "master",
        "hello", "freedom", "whatever", "qwerty123", "admin123", "login",
        "passw0rd", "abc123", "111111", "123123", "admin123", "password1",
        "12345678", "qwertyuiop", "1234567890", "password123", "admin123",
        "letmein123", "welcome123", "monkey123", "dragon123", "master123"
    ]
    
    // MARK: - Validation Result
    
    /// Result of password validation with detailed feedback
    struct ValidationResult {
        let isValid: Bool
        let strength: PasswordStrength
        let errorMessage: String?
        let suggestions: [String]
        
        static func success(strength: PasswordStrength) -> ValidationResult {
            return ValidationResult(
                isValid: true,
                strength: strength,
                errorMessage: nil,
                suggestions: []
            )
        }
        
        static func failure(errorMessage: String, suggestions: [String] = []) -> ValidationResult {
            return ValidationResult(
                isValid: false,
                strength: .weak,
                errorMessage: errorMessage,
                suggestions: suggestions
            )
        }
    }
    
    /// Password strength levels
    enum PasswordStrength: String, CaseIterable {
        case weak = "Weak"
        case fair = "Fair"
        case good = "Good"
        case strong = "Strong"
        case veryStrong = "Very Strong"
        
        var color: String {
            switch self {
            case .weak: return "red"
            case .fair: return "orange"
            case .good: return "yellow"
            case .strong: return "green"
            case .veryStrong: return "blue"
            }
        }
        
        var description: String {
            switch self {
            case .weak: return "Too weak - easily guessable"
            case .fair: return "Fair - could be stronger"
            case .good: return "Good - meets basic requirements"
            case .strong: return "Strong - good security"
            case .veryStrong: return "Very strong - excellent security"
            }
        }
    }
    
    // MARK: - Main Validation Method
    
    /// Validates a password and returns comprehensive results
    /// - Parameter password: The password to validate
    /// - Returns: ValidationResult with detailed feedback and suggestions
    static func validate(_ password: String) -> ValidationResult {
        
        // Check for empty password
        guard !password.isEmpty else {
            return ValidationResult.failure(
                errorMessage: "Password cannot be empty",
                suggestions: ["Enter a password"]
            )
        }
        
        // Check minimum length
        guard password.count >= minLength else {
            return ValidationResult.failure(
                errorMessage: "Password must be at least \(minLength) characters long",
                suggestions: ["Add more characters to meet the minimum length"]
            )
        }
        
        // Check maximum length
        guard password.count <= maxLength else {
            return ValidationResult.failure(
                errorMessage: "Password cannot exceed \(maxLength) characters",
                suggestions: ["Shorten your password"]
            )
        }
        
        // Check for common weak passwords
        let lowercasePassword = password.lowercased()
        if commonWeakPasswords.contains(lowercasePassword) {
            return ValidationResult.failure(
                errorMessage: "This password is too common and easily guessable",
                suggestions: [
                    "Avoid common passwords like 'password' or '123456'",
                    "Use a unique combination of letters, numbers, and symbols"
                ]
            )
        }
        
        // Check character type requirements
        let uppercaseCount = password.filter { $0.isUppercase }.count
        let lowercaseCount = password.filter { $0.isLowercase }.count
        let digitCount = password.filter { $0.isNumber }.count
        let specialCharCount = password.filter { !$0.isLetter && !$0.isNumber }.count
        
        var errors: [String] = []
        var suggestions: [String] = []
        
        if uppercaseCount < minUppercase {
            errors.append("Include at least \(minUppercase) uppercase letter")
            suggestions.append("Add uppercase letters (A-Z)")
        }
        
        if lowercaseCount < minLowercase {
            errors.append("Include at least \(minLowercase) lowercase letter")
            suggestions.append("Add lowercase letters (a-z)")
        }
        
        if digitCount < minDigits {
            errors.append("Include at least \(minDigits) number")
            suggestions.append("Add numbers (0-9)")
        }
        
        if specialCharCount < minSpecialChars {
            errors.append("Include at least \(minSpecialChars) special character")
            suggestions.append("Add special characters (!@#$%^&*)")
        }
        
        // Check for consecutive identical characters
        if containsConsecutiveIdentical(password) {
            errors.append("Avoid consecutive identical characters")
            suggestions.append("Don't repeat the same character multiple times in a row")
        }
        
        // Check for sequential characters
        if containsSequentialChars(password) {
            errors.append("Avoid sequential characters")
            suggestions.append("Don't use patterns like '123' or 'abc'")
        }
        
        // Check for keyboard patterns
        if containsKeyboardPatterns(password) {
            errors.append("Avoid keyboard patterns")
            suggestions.append("Don't use patterns like 'qwerty' or 'asdf'")
        }
        
        // If there are validation errors, return them
        if !errors.isEmpty {
            let errorMessage = errors.joined(separator: ". ")
            return ValidationResult.failure(
                errorMessage: errorMessage,
                suggestions: suggestions
            )
        }
        
        // Calculate password strength
        let strength = calculateStrength(
            password: password,
            uppercaseCount: uppercaseCount,
            lowercaseCount: lowercaseCount,
            digitCount: digitCount,
            specialCharCount: specialCharCount
        )
        
        return ValidationResult.success(strength: strength)
    }
    
    /// Quick validation check that returns just a boolean
    /// - Parameter password: The password to validate
    /// - Returns: True if password is valid, false otherwise
    static func isValid(_ password: String) -> Bool {
        return validate(password).isValid
    }
    
    /// Gets password strength without full validation
    /// - Parameter password: The password to check
    /// - Returns: PasswordStrength level
    static func getStrength(_ password: String) -> PasswordStrength {
        let uppercaseCount = password.filter { $0.isUppercase }.count
        let lowercaseCount = password.filter { $0.isLowercase }.count
        let digitCount = password.filter { $0.isNumber }.count
        let specialCharCount = password.filter { !$0.isLetter && !$0.isNumber }.count
        
        return calculateStrength(
            password: password,
            uppercaseCount: uppercaseCount,
            lowercaseCount: lowercaseCount,
            digitCount: digitCount,
            specialCharCount: specialCharCount
        )
    }
    
    // MARK: - Helper Methods
    
    /// Calculates password strength based on various factors
    private static func calculateStrength(
        password: String,
        uppercaseCount: Int,
        lowercaseCount: Int,
        digitCount: Int,
        specialCharCount: Int
    ) -> PasswordStrength {
        
        var score = 0
        
        // Length score
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        if password.count >= 20 { score += 1 }
        
        // Character variety score
        if uppercaseCount > 0 { score += 1 }
        if lowercaseCount > 0 { score += 1 }
        if digitCount > 0 { score += 1 }
        if specialCharCount > 0 { score += 1 }
        
        // Bonus for multiple character types
        let uniqueCharTypes = [uppercaseCount, lowercaseCount, digitCount, specialCharCount].filter { $0 > 0 }.count
        if uniqueCharTypes >= 3 { score += 1 }
        if uniqueCharTypes >= 4 { score += 1 }
        
        // Penalty for weak patterns
        if containsConsecutiveIdentical(password) { score -= 1 }
        if containsSequentialChars(password) { score -= 1 }
        if containsKeyboardPatterns(password) { score -= 1 }
        
        // Determine strength based on score
        switch score {
        case 0...2: return .weak
        case 3...4: return .fair
        case 5...6: return .good
        case 7...8: return .strong
        default: return .veryStrong
        }
    }
    
    /// Checks for consecutive identical characters
    private static func containsConsecutiveIdentical(_ password: String) -> Bool {
        for i in 0..<(password.count - maxConsecutiveIdentical + 1) {
            let startIndex = password.index(password.startIndex, offsetBy: i)
            let endIndex = password.index(startIndex, offsetBy: maxConsecutiveIdentical)
            let substring = password[startIndex..<endIndex]
            
            if substring.allSatisfy({ $0 == substring.first }) {
                return true
            }
        }
        return false
    }
    
    /// Checks for sequential characters
    private static func containsSequentialChars(_ password: String) -> Bool {
        let lowercasePassword = password.lowercased()
        
        for i in 0..<(lowercasePassword.count - maxSequentialChars + 1) {
            let startIndex = lowercasePassword.index(lowercasePassword.startIndex, offsetBy: i)
            let endIndex = lowercasePassword.index(startIndex, offsetBy: maxSequentialChars)
            let substring = lowercasePassword[startIndex..<endIndex]
            
            // Check for sequential letters (abc, bcd, etc.)
            if substring.count == maxSequentialChars {
                let chars = Array(substring)
                if chars.allSatisfy({ $0.isLetter }) {
                    let firstChar = chars[0]
                    let expectedSequence = String((0..<maxSequentialChars).map { 
                        Character(UnicodeScalar(firstChar.asciiValue! + UInt8($0)))
                    })
                    if substring == expectedSequence {
                        return true
                    }
                }
                
                // Check for sequential numbers (123, 234, etc.)
                if chars.allSatisfy({ $0.isNumber }) {
                    let firstNum = Int(String(chars[0]))!
                    let expectedSequence = (0..<maxSequentialChars).map { 
                        String(firstNum + $0)
                    }.joined()
                    if substring == expectedSequence {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    /// Checks for keyboard patterns
    private static func containsKeyboardPatterns(_ password: String) -> Bool {
        let lowercasePassword = password.lowercased()
        
        let keyboardPatterns = [
            "qwerty", "asdf", "zxcv", "123456", "abcdef",
            "qaz", "wsx", "edc", "rfv", "tgb", "yhn", "ujm", "ik"
        ]
        
        return keyboardPatterns.contains { pattern in
            lowercasePassword.contains(pattern)
        }
    }
    
    /// Generates password suggestions based on common patterns
    static func generateSuggestions() -> [String] {
        return [
            "Use a mix of uppercase and lowercase letters",
            "Include numbers and special characters",
            "Avoid common words and patterns",
            "Make it at least 8 characters long",
            "Consider using a passphrase",
            "Don't use personal information",
            "Use unique passwords for each account"
        ]
    }
    
    /// Generates a strong password example (for demonstration only)
    static func generateExample() -> String {
        let uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let lowercase = "abcdefghijklmnopqrstuvwxyz"
        let digits = "0123456789"
        let special = "!@#$%^&*()_+-=[]{}|;:,.<>?"
        
        var password = ""
        
        // Ensure at least one of each required type
        password += String(uppercase.randomElement()!)
        password += String(lowercase.randomElement()!)
        password += String(digits.randomElement()!)
        password += String(special.randomElement()!)
        
        // Fill remaining length with random characters
        let allChars = uppercase + lowercase + digits + special
        for _ in 0..<4 {
            password += String(allChars.randomElement()!)
        }
        
        // Shuffle the password
        return String(password.shuffled())
    }
}
