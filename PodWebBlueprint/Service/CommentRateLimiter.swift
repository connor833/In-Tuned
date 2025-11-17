import Foundation
import FirebaseFunctions

/// Service for client-side interaction with server-side comment rate limiting functions.
class CommentRateLimiter {
    static let shared = CommentRateLimiter()
    private let functions = Functions.functions(region: "us-central1")

    private init() {}

    /// Checks if a comment attempt is allowed by calling the Firebase Function.
    /// - Parameters:
    ///   - podId: The ID of the pod being commented on
    ///   - completion: Completion handler with allow status and any error message
    func canAttemptComment(podId: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 CommentRateLimiter: Checking comment rate limit for pod: \(podId)")
        
        functions.httpsCallable("checkCommentRateLimit").call(["podId": podId]) { result, error in
            if let error = error {
                print("🔍 CommentRateLimiter: Firebase Functions error: \(error)")
                
                // Parse Firebase Functions error
                if let nsError = error as NSError? {
                    print("🔍 CommentRateLimiter: Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("🔍 CommentRateLimiter: Error userInfo: \(nsError.userInfo)")
                    
                    // Check for rate limiting errors (code 8 = resource exhausted)
                    if nsError.code == 8 {
                        let reason = nsError.localizedDescription
                        print("🚫 CommentRateLimiter: Rate limited - \(reason)")
                        completion(false, reason)
                        return
                    }
                    
                    // Also check for any error that contains rate limiting keywords
                    let errorMessage = nsError.localizedDescription.lowercased()
                    if errorMessage.contains("too many") || errorMessage.contains("rate limit") || errorMessage.contains("wait") {
                        let reason = nsError.localizedDescription
                        print("🚫 CommentRateLimiter: Rate limited (keyword match) - \(reason)")
                        completion(false, reason)
                        return
                    }
                }
                
                // For other errors, allow the attempt (fail open)
                print("⚠️ CommentRateLimiter: Non-rate-limiting error, allowing attempt: \(error.localizedDescription)")
                completion(true, nil)
                return
            }
            
            // Rate limit check passed
            print("✅ CommentRateLimiter: Rate limit check passed")
            completion(true, nil)
        }
    }

    /// Records a comment attempt by calling the Firebase Function.
    /// - Parameters:
    ///   - podId: The ID of the pod being commented on
    ///   - completion: Completion handler with success status
    func recordCommentAttempt(podId: String, completion: @escaping (Bool) -> Void) {
        print("📝 CommentRateLimiter: Recording comment attempt for pod: \(podId)")
        
        functions.httpsCallable("recordCommentAttempt").call(["podId": podId]) { result, error in
            if let error = error {
                print("❌ CommentRateLimiter: Error recording comment attempt: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("✅ CommentRateLimiter: Comment attempt recorded successfully")
            completion(true)
        }
    }
}
