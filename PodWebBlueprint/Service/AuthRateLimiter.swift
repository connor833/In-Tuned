//
//  AuthRateLimiter.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/15/25.
//

import Foundation
import Firebase
import FirebaseFunctions

/// Authentication rate limiting service that uses Firebase Functions for server-side validation
/// This prevents client-side bypassing and ensures consistent rate limiting across all clients
class AuthRateLimiter: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = AuthRateLimiter()
    
    // MARK: - Private Properties
    
    private let functions = Functions.functions(region: "us-central1")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Login Rate Limiting
    
    /// Checks if login attempt is allowed for given email
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with allow status and any lockout info
    func canAttemptLogin(email: String, completion: @escaping (Bool, String?, TimeInterval?) -> Void) {
        // Use Firebase Functions for server-side rate limiting
        let checkFunction = functions.httpsCallable("checkLoginRateLimit")
        
        checkFunction.call(["email": email]) { result, error in
            if let error = error {
                print("🔍 AuthRateLimiter: Firebase Functions error: \(error)")
                
                // Parse Firebase Functions error - check multiple possible domains
                if let nsError = error as NSError? {
                    print("🔍 AuthRateLimiter: Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("🔍 AuthRateLimiter: Error userInfo: \(nsError.userInfo)")
                    
                    // Check for rate limiting errors (code 8 = resource exhausted)
                    if nsError.code == 8 {
                        // Extract lockout time from error details
                        var lockoutTime: TimeInterval = 0
                        if let details = nsError.userInfo["details"] as? [String: Any],
                           let time = details["lockoutTime"] as? TimeInterval {
                            lockoutTime = time
                        }
                        
                        let reason = nsError.localizedDescription
                        print("🚫 AuthRateLimiter: Rate limited - \(reason), lockout: \(lockoutTime) seconds")
                        completion(false, reason, lockoutTime)
                        return
                    }
                    
                    // Also check for any error that contains rate limiting keywords
                    let errorMessage = nsError.localizedDescription.lowercased()
                    if errorMessage.contains("locked") || errorMessage.contains("too many") || errorMessage.contains("rate limit") {
                        var lockoutTime: TimeInterval = 0
                        if let details = nsError.userInfo["details"] as? [String: Any],
                           let time = details["lockoutTime"] as? TimeInterval {
                            lockoutTime = time
                        }
                        
                        let reason = nsError.localizedDescription
                        print("🚫 AuthRateLimiter: Rate limited (keyword match) - \(reason), lockout: \(lockoutTime) seconds")
                        completion(false, reason, lockoutTime)
                        return
                    }
                }
                
                // For other errors, allow the attempt (fail open)
                print("⚠️ AuthRateLimiter: Non-rate-limiting error, allowing attempt: \(error.localizedDescription)")
                completion(true, nil, nil)
                return
            }
            
            // Rate limit check passed
            print("✅ AuthRateLimiter: Rate limit check passed")
            completion(true, nil, nil)
        }
    }
    
    /// Records a failed login attempt
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with success status
    func recordFailedLogin(email: String, completion: @escaping (Bool) -> Void) {
        let recordFunction = functions.httpsCallable("recordFailedLogin")
        
        print("📝 AuthRateLimiter: Recording failed login for \(email)")
        
        recordFunction.call(["email": email]) { result, error in
            if let error = error {
                print("❌ AuthRateLimiter: Error recording failed login: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("✅ AuthRateLimiter: Failed login recorded successfully")
            completion(true)
        }
    }
    
    /// Records a successful login attempt (resets counters)
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with success status
    func recordSuccessfulLogin(email: String, completion: @escaping (Bool) -> Void) {
        let recordFunction = functions.httpsCallable("recordSuccessfulLogin")
        
        recordFunction.call(["email": email]) { result, error in
            if let error = error {
                print("❌ AuthRateLimiter: Error recording successful login: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    // MARK: - Registration Rate Limiting
    
    /// Checks if registration attempt is allowed
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with allow status and reason
    func canAttemptRegistration(email: String, completion: @escaping (Bool, String?) -> Void) {
        let checkFunction = functions.httpsCallable("checkRegistrationRateLimit")
        
        checkFunction.call(["email": email]) { result, error in
            if let error = error {
                if let nsError = error as NSError?, nsError.domain == "FIRFunctionsErrorDomain", nsError.code == 8 {
                    completion(false, nsError.localizedDescription)
                    return
                }
                
                // For other errors, allow the attempt (fail open)
                print("⚠️ AuthRateLimiter: Error checking registration rate limit: \(error.localizedDescription)")
                completion(true, nil)
                return
            }
            
            completion(true, nil)
        }
    }
    
    /// Records a registration attempt
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with success status
    func recordRegistrationAttempt(email: String, completion: @escaping (Bool) -> Void) {
        let recordFunction = functions.httpsCallable("recordRegistrationAttempt")
        
        recordFunction.call(["email": email]) { result, error in
            if let error = error {
                print("❌ AuthRateLimiter: Error recording registration attempt: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(true)
        }
    }
    
    // MARK: - Password Reset Rate Limiting
    
    /// Checks if password reset attempt is allowed
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with allow status and reason
    func canAttemptPasswordReset(email: String, completion: @escaping (Bool, String?) -> Void) {
        let checkFunction = functions.httpsCallable("checkPasswordResetRateLimit")
        
        checkFunction.call(["email": email]) { result, error in
            if let error = error {
                if let nsError = error as NSError?, nsError.domain == "FIRFunctionsErrorDomain", nsError.code == 8 {
                    completion(false, nsError.localizedDescription)
                    return
                }
                
                // For other errors, allow the attempt (fail open)
                print("⚠️ AuthRateLimiter: Error checking password reset rate limit: \(error.localizedDescription)")
                completion(true, nil)
                return
            }
            
            completion(true, nil)
        }
    }
    
    /// Records a password reset attempt
    /// - Parameters:
    ///   - email: User's email address
    ///   - completion: Completion handler with success status
    func recordPasswordResetAttempt(email: String, completion: @escaping (Bool) -> Void) {
        let recordFunction = functions.httpsCallable("recordPasswordResetAttempt")
        
        recordFunction.call(["email": email]) { result, error in
            if let error = error {
                print("❌ AuthRateLimiter: Error recording password reset attempt: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(true)
        }
    }
}