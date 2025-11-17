import SwiftUI
import Firebase
import FirebaseFunctions
import FirebaseAuth

/// A view model that handles user authentication and user session management.
/// This class is responsible for managing user authentication state, user data,
/// and providing authentication-related functionality throughout the app.
class AuthViewModel: ObservableObject {
    // MARK: - Singleton
    
    /// Shared instance of AuthViewModel for app-wide access
    static let shared = AuthViewModel()
    
    // MARK: - Published Properties
    
    /// The current Firebase Auth user session
    @Published var userSession: FirebaseAuth.User?
    
    /// Indicates whether a user has been authenticated
    @Published var didAuthenticateUser = false
    
    /// Indicates whether to show onboarding
    @Published var showOnboarding = false
    
    /// The current user's data
    @Published var currentUser: User?
    
    /// Indicates if a logout operation is in progress
    @Published var isLoggingOut = false
    
    /// Indicates if the auth system is still initializing and loading user data
    @Published var isLoading = true
    
    /// Temporary user session used during registration
    private var tempUserSession: FirebaseAuth.User?
    
    /// Flag to prevent auth state listener from interfering during registration
    private var isRegistering = false
    
    // MARK: - AppStorage Property
    
    /// User ID stored in UserDefaults for persistence
    @AppStorage("uid") var userID = ""
    
    // MARK: - Dependencies
    
    /// Service for user-related operations
    private let service = UserService()
    
    /// Service for handling file uploads
    private let uploader = StorageUploader()
    
    /// Session manager for tracking user sessions
    private let sessionManager = SessionManager.shared
    
    /// Service for migrating user data models
    private let migrationService = MigrationService()
    
    /// Rate limiter for authentication attempts
    private let authRateLimiter = AuthRateLimiter.shared
    
    // MARK: - Caching Properties
    
    /// Timestamp of last user data fetch for caching
    private var lastUserFetch: Date?
    
    /// Cache timeout duration (5 minutes)
    private let cacheTimeout: TimeInterval = 300
    
    /// Auth state listener handle
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    
    /// Initializes a new AuthViewModel
    init() {
        self.userSession = Auth.auth().currentUser
        self.tempUserSession = Auth.auth().currentUser
        
        // Setup auth state listener for reactive updates
        setupAuthStateListener()
        
        // Initialize loading state based on whether we have a session
        if userSession != nil {
            // We have a session, need to fetch user data to determine final state
            fetchUser()
        } else {
            // No session, we can immediately show login
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isLoading = false
            }
        }
    }
    
    deinit {
        // Clean up auth state listener
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Management
    
    /// Sets up Firebase auth state listener for reactive updates
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.handleAuthStateChange(user)
            }
        }
    }
    
    /// Handles Firebase auth state changes
    private func handleAuthStateChange(_ user: FirebaseAuth.User?) {
        print("🔄 AuthViewModel: Auth state changed - user: \(user?.uid ?? "nil")")
        print("🔄 AuthViewModel: Previous userSession: \(userSession?.uid ?? "nil")")
        print("🔄 AuthViewModel: isRegistering: \(isRegistering)")
        
        // Don't interfere during registration process
        if isRegistering {
            print("🔄 AuthViewModel: Ignoring auth state change during registration")
            return
        }
        
        // Update userSession to match Firebase state
        self.userSession = user
        print("🔄 AuthViewModel: Set userSession to: \(user?.uid ?? "nil")")
        
        if user != nil {
            print("✅ AuthViewModel: User signed in - UID: \(user!.uid)")
            
            // Check if this is a new user (created within last 30 seconds)
            let now = Date()
            let userCreationTime = user!.metadata.creationDate ?? now
            let isNewUser = now.timeIntervalSince(userCreationTime) < 30.0
            
            if isNewUser {
                print("🆕 AuthViewModel: New user detected - showing onboarding")
                self.showOnboarding = true
                print("🆕 AuthViewModel: Set showOnboarding = \(self.showOnboarding)")
            } else {
                print("🔄 AuthViewModel: Existing user - showOnboarding = \(self.showOnboarding)")
            }
            
            // Mark user as authenticated
            self.didAuthenticateUser = true
            
            // Set userID in UserDefaults
            withAnimation {
                self.userID = user!.uid
                print("✅ AuthViewModel: Set userID to: \(user!.uid)")
            }
            
            // User signed in - fetch user data if needed
            fetchUserIfNeeded()
            
            // 🔑 Register for remote notifications (APNS will trigger FCM when ready)
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
            
            // 💬 Start listening for unread messages
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                MessageBadgeManager.shared.startListeningForUnreadMessages()
            }
            
            // 🔔 Start listening for unread notifications
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                NotificationBadgeManager.shared.startListeningForUnreadNotifications()
            }
            
            // 🧪 Debug: Verify FCM token registration (with longer delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.verifyFCMToken()
            }
            
            // 🔐 Create session for the authenticated user
            Task {
                do {
                    try await sessionManager.createSession(for: user!)
                    print("✅ AuthViewModel: Session created successfully for user: \(user!.uid)")
                } catch {
                    print("❌ AuthViewModel: Failed to create session: \(error)")
                }
            }
        } else {
            print("🚫 AuthViewModel: User signed out")
            // User signed out - clear all data
            self.currentUser = nil
            self.didAuthenticateUser = false
            self.showOnboarding = false
            self.lastUserFetch = nil
            
            // Clear userID from UserDefaults
            withAnimation {
                self.userID = ""
            }
            
            // Set loading to false since we know the user state (signed out)
            self.isLoading = false
            
            // Additional cleanup is handled in performCompleteCleanup()
            // This ensures we don't duplicate cleanup operations
            print("✅ AuthViewModel: Auth state listener cleanup complete")
        }
    }
    
    // MARK: - Authentication Methods
    
    /// Signs in a user with email and password
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - completion: Completion handler with success status and any error
    func login(withEmail email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        print("🔐 AuthViewModel: Starting login for email: \(email)")
        
        // Check rate limits before attempting login
        print("🔍 AuthViewModel: Checking rate limits for \(email)")
        authRateLimiter.canAttemptLogin(email: email) { [weak self] allowed, reason, lockoutTime in
            guard let self = self else { return }
            
            print("🔍 AuthViewModel: Rate limit check result - allowed: \(allowed), reason: \(reason ?? "none"), lockoutTime: \(lockoutTime ?? 0)")
            
            if !allowed {
                print("🚫 AuthViewModel: Login blocked by rate limiter - \(reason ?? "Unknown reason")")
                
                // Create custom error with rate limiting info
                let rateLimitError = NSError(
                    domain: "AuthRateLimitError",
                    code: 429,
                    userInfo: [
                        NSLocalizedDescriptionKey: reason ?? "Too many login attempts. Please try again later.",
                        "lockoutTime": lockoutTime ?? 0
                    ]
                )
                
                DispatchQueue.main.async {
                    completion(false, rateLimitError)
                }
                return
            }
            
            print("✅ AuthViewModel: Rate limit check passed, attempting Firebase login")
            
            // Proceed with Firebase authentication
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ AuthViewModel: Login failed with error: \(error)")
                    
                    // Record failed attempt for rate limiting
                    self.authRateLimiter.recordFailedLogin(email: email) { success in
                        if success {
                            print("📊 AuthViewModel: Recorded failed login attempt")
                        }
                    }
                    
                    // Convert Firebase error to user-friendly message
                    let userFriendlyError = self.convertFirebaseErrorToUserFriendly(error)
                    
                    DispatchQueue.main.async {
                        completion(false, userFriendlyError)
                    }
                    return
                }
                
                guard let user = result?.user else { 
                    print("❌ AuthViewModel: Login succeeded but no user returned")
                    let noUserError = NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned from login"])
                    
                    DispatchQueue.main.async {
                        completion(false, noUserError)
                    }
                    return 
                }
                
                print("✅ AuthViewModel: Login succeeded for user: \(user.uid)")
                
                // Record successful login (resets rate limiting counters)
                self.authRateLimiter.recordSuccessfulLogin(email: email) { success in
                    if success {
                        print("📊 AuthViewModel: Recorded successful login, reset rate limiting")
                    }
                }
                
                // Email verification is handled during signup with code verification
                // No need to check email verification on login
                print("✅ AuthViewModel: Login complete - auth state listener will handle the rest")
                
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            }
        }
    }
    
    /// Registers a new user with Firebase Auth and creates their account
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - fullname: User's full name
    ///   - username: User's chosen username
    ///   - completion: Completion handler with success status and any error
    func register(withEmail email: String, password: String, fullname: String, username: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                // Convert Firebase error to user-friendly message
                let userFriendlyError = self?.convertFirebaseErrorToUserFriendly(error) ?? error
                completion(false, userFriendlyError)
                return
            }
            
            guard let user = result?.user else { return }
            self?.tempUserSession = user
            
            // Call cloud function to create account atomically
            let functions = Functions.functions()
            let createAccount = functions.httpsCallable("createAccount")
            
            let data: [String: Any] = [
                "email": email,
                "username": username,
                "fullname": fullname.isEmpty ? nil : fullname,
                "password": password
            ]
            
            createAccount.call(data) { [weak self] result, error in
                if let error = error {
                    // If account creation fails, delete the Firebase Auth user
                    user.delete { deleteError in
                        // Cleanup failed - log silently
                    }
                    
                    completion(false, error)
                    return
                }
                
                // Don't set userSession or didAuthenticateUser yet - wait for email verification
                // The user will be signed in but not fully authenticated until email is verified
                withAnimation {
                    self?.userID = user.uid
                }
                completion(true, nil)
            }
        }
    }
    
    /// Signs out the current user
    func signOut(completion: @escaping () -> Void = {}) {
        print("🚫 AuthViewModel: Starting sign out process")
        
        // Set logging out state immediately
        DispatchQueue.main.async {
            self.isLoggingOut = true
        }
        
        // Clear all state immediately for instant UI feedback
        DispatchQueue.main.async {
            self.currentUser = nil
            self.didAuthenticateUser = false
            self.showOnboarding = false
            self.lastUserFetch = nil
            self.userSession = nil
            
            withAnimation {
                self.userID = ""
            }
        }
        
        // Complete cleanup of all services
        self.performCompleteCleanup()
        
        // Sign out from Firebase - auth state listener will handle the rest
        do {
            try Auth.auth().signOut()
            print("✅ AuthViewModel: Firebase sign out successful")
        } catch {
            print("❌ AuthViewModel: Firebase sign out failed: \(error)")
        }
        
        // Call completion after a brief delay to ensure UI updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isLoggingOut = false
            completion()
        }
    }
    
    // MARK: - Email Verification
    
    /// Sends email verification to the current user
    /// - Parameter completion: Completion handler with success status and any error
    func sendEmailVerification(completion: @escaping (Bool, Error?) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(false, NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]))
            return
        }
        
        user.sendEmailVerification { error in
            completion(error == nil, error)
        }
    }
    
    /// Checks if the current user's email is verified
    /// - Returns: True if email is verified, false otherwise
    func isEmailVerified() -> Bool {
        return Auth.auth().currentUser?.isEmailVerified ?? false
    }
    
    /// Reloads the current user to get updated verification status
    /// - Parameter completion: Completion handler with success status and any error
    func reloadUser(completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().currentUser?.reload { error in
            completion(error == nil, error)
        }
    }
    
    /// Completes the registration process after email verification
    func completeRegistration() {
        guard let user = Auth.auth().currentUser else { return }
        
        // Let Firebase auth state listener handle the state changes
        print("✅ AuthViewModel: Registration complete, auth state listener will handle the rest")
    }
    
    /// Completes the onboarding process
    func completeOnboarding() {
        print("✅ AuthViewModel: Completing onboarding")
        
        DispatchQueue.main.async {
            self.showOnboarding = false
            print("✅ AuthViewModel: showOnboarding set to false")
            print("✅ AuthViewModel: userSession = \(self.userSession?.uid ?? "nil")")
            print("✅ AuthViewModel: didAuthenticateUser = \(self.didAuthenticateUser)")
            
            // Fetch user data after onboarding completion
            self.fetchUserIfNeeded()
        }
    }
    
    /// Performs complete cleanup of all services on logout
    private func performCompleteCleanup() {
        print("🚫 AuthViewModel: Starting complete cleanup of all services")
        
        // 1. Clean up FCM token and notifications
        FCMService.shared.completeFCMCleanup()
        
        // 2. Clean up notification badge manager
        NotificationBadgeManager.shared.completeCleanup()
        
        // 3. Clean up message badge manager
        MessageBadgeManager.shared.completeCleanup()
        
        // 4. Clean up session manager
        Task {
            do {
                try await sessionManager.invalidateSession()
                print("✅ AuthViewModel: Session invalidated successfully")
            } catch {
                print("❌ AuthViewModel: Failed to invalidate session: \(error)")
            }
        }
        
        // 5. Clear any cached data
        self.lastUserFetch = nil
        
        print("✅ AuthViewModel: Complete cleanup finished")
    }
    
    // MARK: - Email Code Verification
    
    /// Sends a verification code to the specified email
    /// - Parameters:
    ///   - email: Email address to send code to
    ///   - completion: Completion handler with success status and any error
    func sendEmailVerificationCode(email: String, completion: @escaping (Bool, Error?) -> Void) {
        print("📧 [AuthViewModel] Sending verification code to: \(email)")
        
        // For now, we'll use a simple approach with a cloud function
        // In production, you'd want to use a service like SendGrid, Twilio, or AWS SES
        let functions = Functions.functions()
        let sendCode = functions.httpsCallable("sendVerificationCode")
        
        let data: [String: Any] = [
            "email": email
        ]
        
        sendCode.call(data) { result, error in
            if let error = error {
                print("❌ [AuthViewModel] Failed to send verification code: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("✅ [AuthViewModel] Verification code sent successfully")
                completion(true, nil)
            }
        }
    }
    
    /// Verifies the email code and creates the account
    /// - Parameters:
    ///   - email: User's email address
    ///   - code: Verification code entered by user
    ///   - username: User's chosen username
    ///   - fullname: User's full name
    ///   - password: User's password
    ///   - birthday: User's birthday
    ///   - completion: Completion handler with success status and any error
    func verifyEmailCodeAndRegister(
        email: String,
        code: String,
        username: String,
        fullname: String,
        password: String,
        birthday: Date,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // First verify the code
        let functions = Functions.functions()
        let verifyCode = functions.httpsCallable("verifyEmailCode")
        
        let verifyData: [String: Any] = [
            "email": email,
            "code": code
        ]
        
        verifyCode.call(verifyData) { [weak self] result, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            // Code is valid, now create the account
            self?.createAccountAfterVerification(
                email: email,
                username: username,
                fullname: fullname,
                password: password,
                birthday: birthday,
                completion: completion
            )
        }
    }
    
    /// Creates the account after email verification
    private func createAccountAfterVerification(
        email: String,
        username: String,
        fullname: String,
        password: String,
        birthday: Date,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        // Set flag to prevent auth state listener from interfering
        self.isRegistering = true
        print("🔄 AuthViewModel: Starting registration - isRegistering = true")
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.isRegistering = false
                print("🔄 AuthViewModel: Registration failed - isRegistering = false")
                // Convert Firebase error to user-friendly message
                let userFriendlyError = self?.convertFirebaseErrorToUserFriendly(error) ?? error
                completion(false, userFriendlyError)
                return
            }
            
            guard let user = result?.user else { 
                self?.isRegistering = false
                completion(false, NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned from registration"]))
                return 
            }
            
            // Call cloud function to create account atomically
            let functions = Functions.functions()
            let createAccount = functions.httpsCallable("createAccount")
            
            let data: [String: Any] = [
                "email": email,
                "username": username,
                "fullname": fullname.isEmpty ? nil : fullname,
                "password": password,
                "birthday": birthday.timeIntervalSince1970
            ]
            
            createAccount.call(data) { [weak self] result, error in
                if let error = error {
                    // If account creation fails, delete the Firebase Auth user
                    user.delete { deleteError in
                        // Cleanup failed - log silently
                    }
                    
                    self?.isRegistering = false
                    completion(false, error)
                    return
                }
                
                // Account created successfully - manually set onboarding for new users
                print("✅ AuthViewModel: Account created successfully")
                
                // For new users, immediately set onboarding state
                DispatchQueue.main.async {
                    self?.showOnboarding = true
                    self?.userSession = user
                    self?.didAuthenticateUser = true
                    self?.userID = user.uid
                    print("🆕 AuthViewModel: New user - set showOnboarding = true")
                }
                
                // Clear registration flag immediately
                self?.isRegistering = false
                print("🔄 AuthViewModel: Registration complete - isRegistering = false")
                
                completion(true, nil)
            }
        }
    }
    
    // MARK: - User Data Management
    
    /// Fetches user data only if needed (cache miss or expired)
    func fetchUserIfNeeded() {
        guard shouldRefreshUser() else { 
            print("🔄 AuthViewModel: User data is fresh, skipping fetch")
            return 
        }
        fetchUser()
    }
    
    /// Checks if user data should be refreshed based on cache timeout
    private func shouldRefreshUser() -> Bool {
        guard userSession?.uid != nil else { 
            print("🔄 AuthViewModel: No user session, skipping fetch")
            return false 
        }
        
        // Always fetch if we don't have user data
        guard currentUser != nil else { 
            print("🔄 AuthViewModel: No current user data, fetching")
            return true 
        }
        
        // Check cache expiration
        guard let lastFetch = lastUserFetch else { 
            print("🔄 AuthViewModel: No last fetch timestamp, fetching")
            return true 
        }
        
        let timeSinceLastFetch = Date().timeIntervalSince(lastFetch)
        let shouldRefresh = timeSinceLastFetch > cacheTimeout
        
        if shouldRefresh {
            print("🔄 AuthViewModel: Cache expired (\(Int(timeSinceLastFetch))s ago), fetching")
        } else {
            print("🔄 AuthViewModel: Cache fresh (\(Int(timeSinceLastFetch))s ago), skipping")
        }
        
        return shouldRefresh
    }
    
    /// Fetches the current user's data from Firestore
    func fetchUser() {
        guard let uid = self.userSession?.uid else { 
            print("❌ AuthViewModel: Cannot fetch user - no userSession")
            return 
        }
        
        print("🔄 AuthViewModel: Fetching user data for UID: \(uid)")
        lastUserFetch = Date()
        
        // First, check if user needs migration
        migrationService.migrateCurrentUserIfNeeded { [weak self] migrationSuccess in
            if migrationSuccess {
                print("✅ AuthViewModel: User migration completed successfully")
            } else {
                print("⚠️ AuthViewModel: User migration failed or not needed")
            }
            
            // Fetch user data regardless of migration status
            self?.service.fetchUser(withUid: uid) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let user):
                        self?.updateUser(user)
                        print("✅ AuthViewModel: User data fetched successfully - username: \(user.username)")
                    case .failure(let error):
                        print("❌ AuthViewModel: Error fetching user data: \(error.localizedDescription)")
                        // Handle error appropriately - could show error state or retry
                    }
                    
                    // Set loading to false after user data fetch completes (success or failure)
                    self?.isLoading = false
                }
            }
        }
    }
    
    /// Updates the current user data
    /// - Parameter user: The user object to update with
    private func updateUser(_ user: User) {
        self.currentUser = user
        print("🔄 AuthViewModel: Updated currentUser - username: \(user.username)")
    }
    
    /// Forces a fresh fetch of user data (bypasses cache)
    func refreshUser() {
        lastUserFetch = nil
        fetchUser()
    }
    
    // MARK: - Terms Acceptance Management
    
    /// Updates user's terms acceptance status
    /// - Parameters:
    ///   - termsAccepted: Whether user accepted terms of service
    ///   - privacyAccepted: Whether user accepted privacy policy
    ///   - marketingAccepted: Whether user accepted marketing communications
    ///   - completion: Completion handler with success status and error
    func updateTermsAcceptance(
        termsAccepted: Bool,
        privacyAccepted: Bool,
        marketingAccepted: Bool,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        guard let uid = userSession?.uid else {
            completion(false, NSError(domain: "AuthViewModel", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        // Update the current user object
        if var user = currentUser {
            if termsAccepted && privacyAccepted {
                user.termsAcceptedAt = Timestamp()
            }
            user.lastUpdated = Timestamp()
            
            // Update the user in Firestore
            do {
                try Firestore.firestore().collection("users")
                    .document(uid)
                    .setData(from: user) { error in
                        if let error = error {
                            print("❌ AuthViewModel: Error updating terms acceptance: \(error)")
                            completion(false, error)
                        } else {
                            print("✅ AuthViewModel: Terms acceptance updated successfully")
                            // Update local user object
                            DispatchQueue.main.async {
                                self.currentUser = user
                            }
                            completion(true, nil)
                        }
                    }
            } catch {
                print("❌ AuthViewModel: Error encoding user: \(error)")
                completion(false, error)
            }
        } else {
            completion(false, NSError(domain: "AuthViewModel", code: 404, userInfo: [NSLocalizedDescriptionKey: "User data not found"]))
        }
    }
    
    /// Checks if current user has accepted terms
    var hasAcceptedTerms: Bool {
        return currentUser?.termsAcceptedAt != nil
    }
    
    // MARK: - Profile Image Management
    
    /// Uploads a profile image for the current user
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - completion: Completion handler with success status and the uploaded image URL
    func uploadProfileImage(_ image: UIImage, completion: @escaping (Bool, String?) -> Void) {
        guard let uid = userSession?.uid else {
            completion(false, nil)
            return
        }
        
        uploader.uploadImage(image: image, progressHandler: { progress in
            // Progress tracking if needed in the future
        }, completion: { [weak self] profileImageUrl in
            Firestore.firestore().collection("users")
                .document(uid)
                .updateData(["profileImageUrl": profileImageUrl]) { error in
                    if let error = error {
                        print("Error updating Firestore: \(error)")
                        completion(false, nil)
                    } else {
                        completion(true, profileImageUrl)
                    }
                }
        })
    }
    
    // MARK: - Username Management
    
    /// Checks if a username is available (via cloud function)
    /// - Parameters:
    ///   - username: The username to check
    ///   - completion: Completion handler with whether the username is in use
    func checkUsername(username: String, completion: @escaping (Bool) -> Void) {
        let functions = Functions.functions()
        let checkUsername = functions.httpsCallable("checkUsernameAvailability")
        
        let data: [String: Any] = ["username": username]
        
        checkUsername.call(data) { result, error in
            if let error = error {
                print("Error checking username availability: \(error.localizedDescription)")
                completion(true) // Assume taken on error to be safe
                return
            }
            
            if let data = result?.data as? [String: Any],
               let available = data["available"] as? Bool {
                completion(!available) // Return true if username is in use
            } else {
                completion(true) // Assume taken on unexpected response
            }
        }
    }
    
    // MARK: - Legacy username methods (kept for compatibility)
    // Note: These are now handled atomically by cloud functions
    
    /// Deletes a username from the database (legacy method)
    /// - Parameter username: The username to delete
    func deleteUsername(username: String) {
        service.deleteUsername(username: username)
    }
    
    /// Adds a username to the database (legacy method)
    /// - Parameter username: The username to add
    func addUsername(username: String) {
        service.addUsername(username: username)
    }
    
    // MARK: - Utility Methods
    
    /// Generates a random verification code
    /// - Returns: A 6-digit verification code as a string
    func generateVerificationCode() -> String {
        let length = 6
        let characters = "0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    /// Checks if the user is currently authenticated
    /// - Returns: True if user is authenticated, false otherwise
    func isUserAuthenticated() -> Bool {
        // Check if we have a valid user session
        guard let userSession = userSession else { return false }
        
        // Additional validation: ensure the user ID is not empty
        guard !userID.isEmpty else { return false }
        
        // Check if the user session is still valid (not expired)
        // Firebase Auth handles token refresh automatically, so if userSession exists, it's valid
        return true
    }
    
    /// Gets the current authenticated user session with completion handler
    /// - Parameter completion: Completion handler with the user session and authentication status
    func getCurrentUserSession(completion: @escaping (FirebaseAuth.User?, Bool) -> Void) {
        // If we already have a user session, return it immediately
        if let session = userSession {
            completion(session, true)
            return
        }
        
        // If no session but we have a stored userID, check if Firebase Auth has a current user
        if !userID.isEmpty {
            let currentUser = Auth.auth().currentUser
            if let currentUser = currentUser {
                // Update our userSession and return
                self.userSession = currentUser
                completion(currentUser, true)
                return
            }
        }
        
        // No authenticated user found
        completion(nil, false)
    }
    
    // MARK: - FCM Token Verification
    
    /// Verifies FCM token registration for debugging
    private func verifyFCMToken() {
        guard let uid = userSession?.uid else { return }
        
        // Small delay to allow token registration to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            FCMService.shared.getFCMToken(forUser: uid) { token in
                if let token = token, !token.isEmpty {
                    print("✅ FCM Token verified for user \(uid)")
                    print("🔑 Token: \(token.prefix(50))...")
                } else {
                    print("❌ WARNING: No FCM token found for user \(uid)")
                    print("💡 User will NOT receive push notifications!")
                }
            }
        }
    }
    
    /// Manual test function to check FCM token for any user
    /// - Parameter userId: The user ID to check (optional, defaults to current user)
    func testFCMToken(for userId: String? = nil) {
        let targetUserId = userId ?? userSession?.uid ?? ""
        
        guard !targetUserId.isEmpty else {
            print("❌ No user ID provided for FCM token test")
            return
        }
        
        print("🧪 Testing FCM token for user: \(targetUserId)")
        
        FCMService.shared.getFCMToken(forUser: targetUserId) { token in
            DispatchQueue.main.async {
                if let token = token, !token.isEmpty {
                    print("✅ FCM Token exists!")
                    print("🔑 Token: \(token.prefix(50))...")
                    print("📱 User WILL receive push notifications")
                } else {
                    print("❌ No FCM token found!")
                    print("💡 User will NOT receive push notifications")
                    print("🔧 Make sure user has:")
                    print("   - Allowed notification permissions")
                    print("   - Logged into the app successfully")
                    print("   - Called FCMService.shared.updateFCMToken()")
                    print("🚀 Try the 'Force FCM Registration' button to fix this automatically!")
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    /// Converts Firebase authentication errors to user-friendly messages
    /// - Parameter error: The Firebase authentication error
    /// - Returns: A user-friendly error with appropriate message
    private func convertFirebaseErrorToUserFriendly(_ error: Error) -> NSError {
        guard let nsError = error as NSError? else {
            return NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred. Please try again."])
        }
        
        let errorCode = nsError.code
        var userFriendlyMessage: String
        
        switch errorCode {
        case 17004: // ERROR_INVALID_CREDENTIAL
            userFriendlyMessage = "Incorrect email or password. Please try again."
        case 17007: // ERROR_USER_DISABLED
            userFriendlyMessage = "This account has been disabled. Please contact support."
        case 17008: // ERROR_OPERATION_NOT_ALLOWED
            userFriendlyMessage = "Email/password sign-in is not enabled. Please contact support."
        case 17009: // ERROR_TOO_MANY_REQUESTS
            userFriendlyMessage = "Too many failed attempts. Please try again later."
        case 17010: // ERROR_USER_NOT_FOUND
            userFriendlyMessage = "Incorrect email or password. Please try again."
        case 17011: // ERROR_WRONG_PASSWORD
            userFriendlyMessage = "Incorrect email or password. Please try again."
        case 17012: // ERROR_INVALID_EMAIL
            userFriendlyMessage = "Please enter a valid email address."
        case 17014: // ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL
            userFriendlyMessage = "An account already exists with this email address using a different sign-in method."
        case 17020: // ERROR_NETWORK_REQUEST_FAILED
            userFriendlyMessage = "Network error. Please check your internet connection and try again."
        case 17021: // ERROR_REQUIRES_RECENT_LOGIN
            userFriendlyMessage = "This operation requires recent authentication. Please sign in again."
        case 17025: // ERROR_WEAK_PASSWORD
            userFriendlyMessage = "Password is too weak. Please choose a stronger password."
        case 17026: // ERROR_EMAIL_ALREADY_IN_USE
            userFriendlyMessage = "An account with this email address already exists. Please sign in instead."
        default:
            // For unknown errors, provide a generic message but log the actual error
            print("🔍 Unknown Firebase auth error code: \(errorCode), message: \(nsError.localizedDescription)")
            userFriendlyMessage = "Incorrect email or password. Please try again."
        }
        
        return NSError(
            domain: "AuthError",
            code: errorCode,
            userInfo: [
                NSLocalizedDescriptionKey: userFriendlyMessage,
                "originalError": nsError
            ]
        )
    }
}
