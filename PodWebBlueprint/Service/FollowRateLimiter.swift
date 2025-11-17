import Foundation
import FirebaseFunctions
import FirebaseAuth

/// Service for client-side interaction with server-side follow/unfollow rate limiting functions.
class FollowRateLimiter {
    static let shared = FollowRateLimiter()
    private let functions = Functions.functions(region: "us-central1")

    private init() {}

    /// Checks if a follow/unfollow attempt is allowed by calling the Firebase Function.
    /// - Parameters:
    ///   - targetUserId: The ID of the user being followed/unfollowed
    ///   - completion: Completion handler with allow status and any error message
    func canAttemptFollowUnfollow(targetUserId: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔍 FollowRateLimiter: Checking follow/unfollow rate limit for user: \(targetUserId)")
        
        // Check if user is authenticated before making the call
        guard Auth.auth().currentUser != nil else {
            print("⚠️ FollowRateLimiter: User not authenticated, allowing attempt")
            completion(true, nil)
            return
        }
        
        functions.httpsCallable("checkFollowUnfollowRateLimit").call(["targetUserId": targetUserId]) { result, error in
            if let error = error {
                print("🔍 FollowRateLimiter: Firebase Functions error: \(error)")
                
                // Parse Firebase Functions error
                if let nsError = error as NSError? {
                    print("🔍 FollowRateLimiter: Error domain: \(nsError.domain), code: \(nsError.code)")
                    print("🔍 FollowRateLimiter: Error userInfo: \(nsError.userInfo)")
                    
                    // Check for rate limiting errors (code 8 = resource exhausted)
                    if nsError.code == 8 {
                        let reason = nsError.localizedDescription
                        print("🚫 FollowRateLimiter: Rate limited - \(reason)")
                        completion(false, reason)
                        return
                    }
                    
                    // Also check for any error that contains rate limiting keywords
                    let errorMessage = nsError.localizedDescription.lowercased()
                    if errorMessage.contains("too many") || errorMessage.contains("wait") {
                        let reason = nsError.localizedDescription
                        print("🚫 FollowRateLimiter: Rate limited (keyword match) - \(reason)")
                        completion(false, reason)
                        return
                    }
                }
                
                // For other errors, allow the attempt (fail open)
                print("⚠️ FollowRateLimiter: Non-rate-limiting error, allowing attempt: \(error.localizedDescription)")
                completion(true, nil)
                return
            }
            
            // Rate limit check passed
            print("✅ FollowRateLimiter: Rate limit check passed")
            completion(true, nil)
        }
    }

    /// Records a follow/unfollow attempt by calling the Firebase Function.
    /// - Parameters:
    ///   - targetUserId: The ID of the user being followed/unfollowed
    ///   - action: The action taken ("follow" or "unfollow")
    ///   - completion: Completion handler with success status
    func recordFollowUnfollowAttempt(targetUserId: String, action: String, completion: @escaping (Bool) -> Void) {
        print("📝 FollowRateLimiter: Recording \(action) attempt for user: \(targetUserId)")
        
        // Check if user is authenticated before making the call
        guard Auth.auth().currentUser != nil else {
            print("⚠️ FollowRateLimiter: User not authenticated, skipping record attempt")
            completion(false)
            return
        }
        
        functions.httpsCallable("recordFollowUnfollowAttempt").call([
            "targetUserId": targetUserId,
            "action": action
        ]) { result, error in
            if let error = error {
                print("❌ FollowRateLimiter: Error recording \(action) attempt: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            print("✅ FollowRateLimiter: \(action) attempt recorded successfully")
            completion(true)
        }
    }
}
