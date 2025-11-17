import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import CoreLocation
import Network
import Darwin

/// Comprehensive session management system for tracking user sessions across devices
class SessionManager: ObservableObject {
    // MARK: - Singleton Instance
    
    static let shared = SessionManager()
    
    // MARK: - Published Properties
    
    @Published var currentSession: UserSession?
    @Published var activeDevices: [DeviceSession] = []
    @Published var sessionExpiresAt: Date?
    @Published var isSessionValid: Bool = false
    @Published var securityAlerts: [SecurityAlert] = []
    
    // MARK: - Private Properties
    
    /// Flag to prevent duplicate force logout executions
    private var isForceLogoutInProgress = false
    
    /// Flag to track if force logout monitoring is already set up
    private var isForceLogoutMonitoringSetup = false
    
    /// Flag to prevent duplicate session creation calls
    private var isSessionCreationInProgress = false
    
    /// Network monitor for connectivity changes
    private var networkMonitor: NWPathMonitor?
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private var sessionTimer: Timer?
    private var locationManager: CLLocationManager?
    
    // MARK: - Session Configuration
    
    /// Maximum session duration (30 days - much more user-friendly)
    private let maxSessionDuration: TimeInterval = 30 * 24 * 60 * 60
    
    /// Maximum concurrent sessions per user
    private let maxConcurrentSessions = 5
    
    /// Session timeout warning threshold (1 day before expiry)
    private let sessionWarningThreshold: TimeInterval = 24 * 60 * 60
    
    /// Inactivity timeout (7 days - only for truly abandoned sessions)
    private let inactivityTimeout: TimeInterval = 7 * 24 * 60 * 60
    
    // MARK: - Initialization
    
    /// Private initializer to prevent external instantiation - use SessionManager.shared instead
    private init() {
        // Setup session monitoring
        setupSessionMonitoring()
        
        // Start network monitoring
        setupNetworkMonitoring()
    }
    
    deinit {
        sessionTimer?.invalidate()
        networkMonitor?.cancel()
    }
    
    // MARK: - Safe Initialization
    
    /// Safely initializes the SessionManager when Firebase is ready
    private func ensureInitialized() {
        // Only initialize once
        if networkMonitor == nil {
            setupNetworkMonitoring()
        }
        if sessionTimer == nil {
            startSessionTimer()
        }
    }
    
    // MARK: - Session Management
    
    /// Creates a new user session with comprehensive tracking
    func createSession(for user: FirebaseAuth.User) async throws {
        // Prevent duplicate session creation calls
        guard !isSessionCreationInProgress else {
            print("⏭️ SessionManager: Session creation already in progress, skipping duplicate call")
            return
        }
        
        isSessionCreationInProgress = true
        defer { isSessionCreationInProgress = false }
        
        let uid = user.uid
        let callStack = Thread.callStackSymbols.prefix(3).map { $0.components(separatedBy: " ").last ?? "unknown" }
        print("🔐 SessionManager: createSession called from: \(callStack)")
        
        // Reset force logout state for new session
        isForceLogoutInProgress = false
        isForceLogoutMonitoringSetup = false
        
        // Get device information
        let deviceInfo = getCurrentDeviceInfo()
        
        print("🔐 SessionManager: Creating session for user \(uid) on device \(deviceInfo.deviceId)")
        
        // First, perform session cleanup to remove any stale duplicates
        await performSessionMaintenance(userId: uid, currentDeviceId: deviceInfo.deviceId)
        
        // Check if a session already exists for this user and device
        if let existingSession = await getExistingSession(userId: uid, deviceId: deviceInfo.deviceId) {
            print("✅ SessionManager: Found existing session \(existingSession.sessionId) for device \(deviceInfo.deviceId)")
            
            // Update the existing session with current device info to keep it fresh
            let updatedSession = UserSession(
                copying: existingSession,
                deviceName: deviceInfo.deviceName,
                deviceType: deviceInfo.deviceType,
                appVersion: deviceInfo.appVersion,
                osVersion: deviceInfo.osVersion,
                lastActivity: Date()
            )
            
            try? await updateSession(updatedSession)
            
            // Use updated session
            await MainActor.run {
                self.currentSession = updatedSession
                self.sessionExpiresAt = updatedSession.expiresAt
                self.isSessionValid = true
            }
            
            // Ensure SessionManager is fully initialized
            ensureInitialized()
            
            // Log session restoration
            await logSessionEvent(.restored, session: updatedSession)
            return
        }
        
        print("🆕 SessionManager: No existing session found, creating new session")
        
        // Get location information
        let location = await getCurrentLocation()
        
        // Create session document
        let session = UserSession(
            userId: uid,
            deviceId: deviceInfo.deviceId,
            deviceName: deviceInfo.deviceName,
            deviceType: deviceInfo.deviceType,
            appVersion: deviceInfo.appVersion,
            osVersion: deviceInfo.osVersion,
            ipAddress: await getCurrentIPAddress(),
            location: location,
            userAgent: deviceInfo.userAgent,
            createdAt: Date(),
            lastActivity: Date(),
            expiresAt: Date().addingTimeInterval(maxSessionDuration),
            isActive: true,
            securityFlags: []
        )
        
        print("🔐 SessionManager: Created new session with ID: \(session.sessionId)")
        
        // Store session in Firestore
        try await storeSession(session)
        
        // Update local state
        let finalSession = session
        let finalExpiresAt = session.expiresAt
        await MainActor.run {
            self.currentSession = finalSession
            self.sessionExpiresAt = finalExpiresAt
            self.isSessionValid = true
        }
        
        // Ensure SessionManager is fully initialized
        ensureInitialized()
        
        // Log session creation
        await logSessionEvent(.created, session: session)
    }
    
    /// Performs session maintenance to clean up duplicates and stale sessions
    private func performSessionMaintenance(userId: String, currentDeviceId: String) async {
        do {
            let allSessions = try await getAllUserSessions(userId: userId)
            let now = Date()
            
            print("🧹 SessionManager: Performing session maintenance - found \(allSessions.count) sessions")
            
            // Group sessions by device ID
            var sessionsByDevice: [String: [UserSession]] = [:]
            for session in allSessions {
                sessionsByDevice[session.deviceId, default: []].append(session)
            }
            
            // Clean up each device's sessions
            for (deviceId, deviceSessions) in sessionsByDevice {
                let activeSessions = deviceSessions.filter { $0.isActive }
                
                if activeSessions.count > 1 {
                    print("🧹 SessionManager: Found \(activeSessions.count) active sessions for device \(deviceId)")
                    
                    // Keep only the most recent session
                    let mostRecent = activeSessions.max(by: { $0.lastActivity < $1.lastActivity })!
                    
                    for session in activeSessions {
                        if session.sessionId != mostRecent.sessionId {
                            print("🧹 SessionManager: Deactivating older duplicate session: \(session.sessionId)")
                            try await deactivateSession(session)
                        }
                    }
                }
                
                // Also clean up expired sessions
                for session in deviceSessions {
                    if session.expiresAt < now || 
                       (!session.isActive && now.timeIntervalSince(session.lastActivity) > inactivityTimeout) {
                        print("🧹 SessionManager: Cleaning up expired/inactive session: \(session.sessionId)")
                        try await deleteSession(session)
                    }
                }
            }
            
        } catch {
            print("❌ SessionManager: Failed to perform session maintenance: \(error)")
        }
    }
    
    /// Refreshes the current session and extends its validity
    func refreshSession() async throws {
        guard let session = currentSession else {
            throw SessionError.noActiveSession
        }
        
        print("🔄 SessionManager: Refreshing session \(session.sessionId)")
        
        // Create a copy of the session with updated values using the copying initializer
        let updatedSession = UserSession(
            copying: session,
            lastActivity: Date(),
            expiresAt: Date().addingTimeInterval(maxSessionDuration)
        )
        
        print("✅ SessionManager: Session refreshed, keeping same ID: \(updatedSession.sessionId)")
        
        // Update session in Firestore
        try await updateSession(updatedSession)
        
        // Update local state
        let finalSession = updatedSession
        let finalExpiresAt = updatedSession.expiresAt
        await MainActor.run {
            self.currentSession = finalSession
            self.sessionExpiresAt = finalExpiresAt
        }
        
        // Log session refresh
        await logSessionEvent(.refreshed, session: updatedSession)
    }
    
    /// Invalidates the current session
    func invalidateSession() async throws {
        guard let session = currentSession else {
            throw SessionError.noActiveSession
        }
        
        // Mark session as inactive in Firestore
        try await deactivateSession(session)
        
        // Clear local state
        await MainActor.run {
            self.currentSession = nil
            self.sessionExpiresAt = nil
            self.isSessionValid = false
        }
        
        // Stop session monitoring
        stopSessionTimer()
        
        // Reset force logout monitoring state
        isForceLogoutInProgress = false
        isForceLogoutMonitoringSetup = false
        isSessionCreationInProgress = false
        
        // Log session invalidation
        await logSessionEvent(.invalidated, session: session)
    }
    
    /// Logs out user from all devices
    func logoutFromAllDevices() async throws {
        guard let uid = currentSession?.userId else {
            throw SessionError.noActiveSession
        }
        
        print("🚫 SessionManager: Logging out from ALL devices for user \(uid)")
        
        // Use Cloud Function to force logout from ALL devices immediately
        try await revokeAllUserSessions(userId: uid)
        
        // Clear local state immediately
        await MainActor.run {
            self.currentSession = nil
            self.sessionExpiresAt = nil
            self.isSessionValid = false
            self.activeDevices = []
        }
        
        // Stop session monitoring
        stopSessionTimer()
        
        // Reset force logout monitoring state
        isForceLogoutInProgress = false
        isForceLogoutMonitoringSetup = false
        isSessionCreationInProgress = false
        
        // Force logout from Firebase Auth
        try Auth.auth().signOut()
        print("✅ SessionManager: Successfully logged out from all devices")
        
        // Post notification for UI to handle
        NotificationCenter.default.post(name: Foundation.Notification.Name.sessionRevoked, object: nil)
    }
    
    /// Gets all active sessions for the current user
    func refreshActiveDevices() async throws {
        guard let uid = currentSession?.userId else {
            throw SessionError.noActiveSession
        }
        
        let sessions = try await getAllUserSessions(userId: uid)
        let deviceSessions = sessions.map { DeviceSession(from: $0) }
        
        let finalDeviceSessions = deviceSessions
        await MainActor.run {
            self.activeDevices = finalDeviceSessions
        }
    }
    
    /// Gets an existing session for a user and device if it exists with improved deduplication
    private func getExistingSession(userId: String, deviceId: String) async -> UserSession? {
        do {
            print("🔍 SessionManager: Looking for existing session for user \(userId) on device \(deviceId)")
            let sessions = try await getAllUserSessions(userId: userId)
            print("📊 SessionManager: Found \(sessions.count) total sessions for user")
            
            // First, try exact device ID match
            let exactMatch = sessions.first { $0.deviceId == deviceId && $0.isActive }
            if let session = exactMatch {
                print("✅ SessionManager: Found exact device ID match: \(session.sessionId)")
                
                // Check for and cleanup any duplicate sessions for this device
                await cleanupDuplicateSessions(userId: userId, deviceId: deviceId, keepSession: session)
                
                return session
            }
            
            // If no exact match, check for potential duplicates with same device but different metadata
            let potentialDuplicates = sessions.filter { 
                $0.deviceId == deviceId && $0.isActive 
            }
            
            if potentialDuplicates.count > 1 {
                print("⚠️ SessionManager: Found \(potentialDuplicates.count) duplicate sessions for device \(deviceId)")
                
                // Keep the most recent session and deactivate others
                let mostRecentSession = potentialDuplicates.max(by: { $0.lastActivity < $1.lastActivity })!
                
                for session in potentialDuplicates {
                    if session.sessionId != mostRecentSession.sessionId {
                        print("🧹 SessionManager: Deactivating duplicate session: \(session.sessionId)")
                        try? await deactivateSession(session)
                    }
                }
                
                return mostRecentSession
            }
            
            print("❌ SessionManager: No existing active session found for device \(deviceId)")
            
            // Enhanced debugging - log all sessions with device details
            for (index, session) in sessions.enumerated() {
                print("📋 Session \(index): ID=\(session.sessionId), Device=\(session.deviceId), Name=\(session.deviceName), Type=\(session.deviceType), Active=\(session.isActive)")
            }
            
            return nil
        } catch {
            print("❌ SessionManager: Failed to get existing session: \(error)")
            return nil
        }
    }
    
    /// Cleans up duplicate sessions for the same device
    private func cleanupDuplicateSessions(userId: String, deviceId: String, keepSession: UserSession) async {
        do {
            let allSessions = try await getAllUserSessions(userId: userId)
            let duplicates = allSessions.filter { 
                $0.deviceId == deviceId && 
                $0.isActive && 
                $0.sessionId != keepSession.sessionId 
            }
            
            if !duplicates.isEmpty {
                print("🧹 SessionManager: Cleaning up \(duplicates.count) duplicate sessions for device \(deviceId)")
                
                for duplicate in duplicates {
                    print("🧹 SessionManager: Deactivating duplicate session: \(duplicate.sessionId) (Name: \(duplicate.deviceName), Type: \(duplicate.deviceType))")
                    try await deactivateSession(duplicate)
                }
            }
        } catch {
            print("❌ SessionManager: Failed to cleanup duplicate sessions: \(error)")
        }
    }
    
    /// Revokes a specific device session and forces logout
    func revokeDeviceSession(deviceId: String) async throws {
        guard let uid = currentSession?.userId else {
            throw SessionError.noActiveSession
        }
        
        print("🚫 SessionManager: Revoking device session for device \(deviceId)")
        
        // Check if this is the current device
        let isCurrentDevice = currentSession?.deviceId == deviceId
        
        // Deactivate the specific session
        try await deactivateSessionByDevice(userId: uid, deviceId: deviceId)
        print("✅ SessionManager: Successfully deactivated session for device \(deviceId)")
        
        if isCurrentDevice {
            print("🚫 SessionManager: Revoking current device - forcing Firebase Auth logout")
            try await forceLogoutCurrentUser()
        } else {
            print("🚫 SessionManager: Revoking remote device - creating force logout command")
            // For remote devices, create a force logout command to ensure immediate logout
            try await createRemoteDeviceForceLogoutCommand(userId: uid, targetDeviceId: deviceId)
        }
        
        // Refresh active devices list to show updated state
        print("🔄 SessionManager: Refreshing active devices list after revocation")
        try await refreshActiveDevices()
        print("✅ SessionManager: Active devices list refreshed, now showing \(activeDevices.count) devices")
        
        // Log device revocation
        await logSessionEvent(.deviceRevoked, session: currentSession, deviceId: deviceId)
        
        // Post notification to trigger UI update
        NotificationCenter.default.post(name: NSNotification.Name("DeviceSessionRevoked"), object: deviceId)
    }
    
    /// Forces logout of the current user by signing them out from Firebase Auth
    private func forceLogoutCurrentUser() async throws {
        guard Auth.auth().currentUser != nil else {
            print("⚠️ SessionManager: No current Firebase user to force logout")
            return
        }
        
        let userId = Auth.auth().currentUser!.uid
        
        do {
            print("🚫 SessionManager: Force logging out user \(userId)")
            
            // Sign out from Firebase Auth - this immediately logs the user out
            try Auth.auth().signOut()
            print("✅ SessionManager: Successfully signed out user from Firebase Auth")
            
            // Clear local session state
            await MainActor.run {
                self.currentSession = nil
                self.sessionExpiresAt = nil
                self.isSessionValid = false
                self.activeDevices = []
            }
            
            // Stop session monitoring
            stopSessionTimer()
            
            // Post notification for UI to handle the forced logout
            NotificationCenter.default.post(name: Foundation.Notification.Name.sessionRevoked, object: nil)
            
        } catch {
            print("❌ SessionManager: Failed to force logout user: \(error)")
            throw SessionError.forceLogoutFailed
        }
    }
    
    /// Revokes all user sessions using Cloud Function to force logout on all devices
    private func revokeAllUserSessions(userId: String) async throws {
        print("🚫 SessionManager: Revoking all sessions for user \(userId) using Cloud Function")
        
        do {
            let functions = Functions.functions()
            let revokeSessions = functions.httpsCallable("revokeUserSessions")
            
            let data: [String: Any] = ["targetUserId": userId]
            
            print("📡 SessionManager: Calling Cloud Function 'revokeUserSessions' with data: \(data)")
            let result = try await revokeSessions.call(data)
            print("✅ SessionManager: Cloud Function successfully revoked all user sessions")
            
            // Parse the result if needed
            if let resultData = result.data as? [String: Any],
               let sessionsRevoked = resultData["sessionsRevoked"] as? Int {
                print("📊 SessionManager: \(sessionsRevoked) sessions were revoked")
            }
            
            // Also log the full result for debugging
            print("📋 SessionManager: Cloud Function result: \(result.data ?? "nil")")
            
            // Create a real-time force logout command for other devices
            try await createForceLogoutCommand(userId: userId)
            
        } catch {
            print("❌ SessionManager: Failed to revoke user sessions via Cloud Function: \(error)")
            print("❌ SessionManager: Error details: \(error.localizedDescription)")
            throw SessionError.forceLogoutFailed
        }
    }
    
    /// Creates a real-time force logout command that other devices will listen to
    private func createForceLogoutCommand(userId: String) async throws {
        print("📡 SessionManager: Creating real-time force logout command for user \(userId)")
        
        // Clean up old force logout commands first
        try await cleanupOldForceLogoutCommands(userId: userId)
        
        let forceLogoutData: [String: Any] = [
            "userId": userId,
            "timestamp": FieldValue.serverTimestamp(),
            "type": "forceLogout",
            "deviceId": currentSession?.deviceId ?? "unknown"
        ]
        
        try await db.collection("forceLogoutCommands").addDocument(data: forceLogoutData)
        print("✅ SessionManager: Force logout command created successfully")
    }
    
    /// Creates a real-time force logout command for a specific remote device
    private func createRemoteDeviceForceLogoutCommand(userId: String, targetDeviceId: String) async throws {
        print("📡 SessionManager: Creating real-time force logout command for remote device \(targetDeviceId)")
        
        // Clean up old force logout commands first
        try await cleanupOldForceLogoutCommands(userId: userId)
        
        let forceLogoutData: [String: Any] = [
            "userId": userId,
            "timestamp": FieldValue.serverTimestamp(),
            "type": "forceLogout",
            "deviceId": targetDeviceId
        ]
        
        try await db.collection("forceLogoutCommands").addDocument(data: forceLogoutData)
        print("✅ SessionManager: Remote force logout command created successfully")
    }
    
    /// Cleans up old force logout commands to prevent interference with new logins
    private func cleanupOldForceLogoutCommands(userId: String) async throws {
        let cutoffTime = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
        
        let oldCommandsRef = db.collection("forceLogoutCommands")
            .whereField("userId", isEqualTo: userId)
            .whereField("timestamp", isLessThan: cutoffTime)
        
        let snapshot = try await oldCommandsRef.getDocuments()
        
        if !snapshot.documents.isEmpty {
            let batch = db.batch()
            for doc in snapshot.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
            print("🧹 SessionManager: Cleaned up \(snapshot.documents.count) old force logout commands")
        }
    }
    
    // MARK: - Security Monitoring
    
    /// Checks for suspicious session activity
    func checkSecurityAnomalies() async throws {
        guard let session = currentSession else { return }
        
        var alerts: [SecurityAlert] = []
        
        // Check for location anomalies
        if let location = session.location {
            let isLocationAnomaly = await checkLocationAnomaly(location: location)
            if isLocationAnomaly {
                alerts.append(SecurityAlert(
                    type: .locationAnomaly,
                    severity: .high,
                    message: "Unusual login location detected",
                    timestamp: Date(),
                    details: "Login from \(location.city ?? "unknown location")"
                ))
            }
        }
        
        // Check for concurrent session anomalies
        let concurrentSessions = activeDevices.filter { $0.isActive }.count
        if concurrentSessions > maxConcurrentSessions {
            alerts.append(SecurityAlert(
                type: .tooManySessions,
                severity: .medium,
                message: "Too many active sessions",
                timestamp: Date(),
                details: "\(concurrentSessions) active sessions detected"
            ))
        }
        
        // Check for session age anomalies
        let sessionAge = Date().timeIntervalSince(session.createdAt)
        if sessionAge > maxSessionDuration {
            alerts.append(SecurityAlert(
                type: .sessionTooOld,
                severity: .medium,
                message: "Session has been active too long",
                timestamp: Date(),
                details: "Session active for \(Int(sessionAge / 3600)) hours"
            ))
        }
        
        // Update security alerts
        let finalAlerts = alerts
        await MainActor.run {
            self.securityAlerts = finalAlerts
        }
        
        // Store alerts in Firestore
        for alert in alerts {
            try await storeSecurityAlert(alert, for: session.userId)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupSessionMonitoring() {
        // Monitor app state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        // Setup real-time force logout monitoring
        setupForceLogoutMonitoring()
    }
    
    /// Sets up real-time monitoring for force logout commands
    private func setupForceLogoutMonitoring() {
        // Prevent duplicate setup
        guard !isForceLogoutMonitoringSetup else {
            print("⏭️ SessionManager: Force logout monitoring already set up, skipping")
            return
        }
        
        guard let currentUser = Auth.auth().currentUser else { return }
        
        print("🔧 SessionManager: Setting up force logout monitoring for user: \(currentUser.uid)")
        
        let forceLogoutRef = db.collection("forceLogoutCommands")
            .whereField("userId", isEqualTo: currentUser.uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
        
        forceLogoutRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ SessionManager: Error monitoring force logout commands: \(error)")
                return
            }
            
            guard let snapshot = snapshot, !snapshot.documents.isEmpty else { return }
            
            // Only process force logout commands that are newer than our current session
            guard let currentSession = self.currentSession else { return }
            
            if let latestCommand = snapshot.documents.first,
               let commandTimestamp = latestCommand.data()["timestamp"] as? Timestamp,
               let commandDeviceId = latestCommand.data()["deviceId"] as? String {
                
                // Check if this is a device-specific force logout command
                let isDeviceSpecificCommand = commandDeviceId != currentSession.deviceId
                let isGeneralCommand = commandDeviceId == currentSession.deviceId
                
                // Process the command if:
                // 1. It's newer than our session creation
                // 2. AND either it's a general logout command OR it's specifically targeting this device
                if commandTimestamp.dateValue() > currentSession.createdAt && 
                   (isGeneralCommand || isDeviceSpecificCommand) {
                    
                    // Prevent duplicate executions
                    guard !self.isForceLogoutInProgress else {
                        print("⏭️ SessionManager: Force logout already in progress, skipping duplicate")
                        return
                    }
                    
                    if isDeviceSpecificCommand {
                        print("🚫 SessionManager: Device-specific force logout command detected for device \(commandDeviceId) - logging out immediately")
                    } else {
                        print("🚫 SessionManager: General force logout command detected - logging out immediately")
                    }
                    
                    Task { @MainActor in
                        await self.handleForceLogout()
                    }
                } else {
                    print("⏭️ SessionManager: Ignoring force logout command (session is newer)")
                }
            }
        }
        
        // Mark monitoring as set up
        isForceLogoutMonitoringSetup = true
        print("✅ SessionManager: Force logout monitoring set up successfully")
    }
    
    /// Handles force logout from another device
    private func handleForceLogout() async {
        print("🚫 SessionManager: Executing force logout from another device")
        
        // Set flag to prevent duplicate executions
        isForceLogoutInProgress = true
        
        // Ensure we're on main thread for UI updates
        await MainActor.run {
            // Clear local state
            self.currentSession = nil
            self.sessionExpiresAt = nil
            self.isSessionValid = false
            self.activeDevices = []
        }
        
        // Stop session monitoring
        stopSessionTimer()
        
        // Sign out from Firebase Auth
        try? Auth.auth().signOut()
        
        // Post notification for UI to handle
        NotificationCenter.default.post(name: Foundation.Notification.Name.sessionRevoked, object: nil)
        
        print("✅ SessionManager: Force logout completed")
    }
    
    private func setupNetworkMonitoring() {
        do {
            networkMonitor = NWPathMonitor()
            networkMonitor?.pathUpdateHandler = { [weak self] path in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleNetworkChange(path: path)
                }
            }
            networkMonitor?.start(queue: DispatchQueue.global())
        } catch {
            print("SessionManager: Failed to setup network monitoring: \(error)")
        }
    }
    
    private func startSessionTimer() {
        do {
            sessionTimer?.invalidate()
            // Check session status every 5 minutes instead of every minute
            sessionTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.checkSessionStatus()
                }
            }
        } catch {
            print("SessionManager: Failed to setup session timer: \(error)")
        }
    }
    
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    @objc private func appDidBecomeActive() {
        Task { @MainActor in
            await handleAppBecameActive()
        }
    }
    
    @objc private func appDidEnterBackground() {
        Task { @MainActor in
            await handleAppEnteredBackground()
        }
    }
    
    private func handleAppBecameActive() async {
        print("📱 SessionManager: App became active")
        
        // Check if session is still valid
        await checkSessionStatus()
        
        // Only refresh session if it's been more than 1 hour since last refresh
        // This prevents excessive session updates every time the app becomes active
        if let session = currentSession {
            let timeSinceLastRefresh = Date().timeIntervalSince(session.lastActivity)
            let refreshThreshold: TimeInterval = 60 * 60 // 1 hour
            
            print("⏰ SessionManager: Time since last refresh: \(timeSinceLastRefresh/60) minutes")
            
            if timeSinceLastRefresh > refreshThreshold {
                print("🔄 SessionManager: Refreshing session (threshold exceeded)")
                try? await refreshSession()
            } else {
                print("📝 SessionManager: Just updating last activity (threshold not exceeded)")
                // Just update last activity without full refresh
                let updatedSession = UserSession(
                    copying: session,
                    lastActivity: Date()
                )
                try? await updateSession(updatedSession)
            }
        } else {
            print("⚠️ SessionManager: No current session to refresh")
        }
    }
    
    private func handleAppEnteredBackground() async {
        // Update last activity
        if let session = currentSession {
            let updatedSession = UserSession(
                copying: session,
                lastActivity: Date()
            )
            try? await updateSession(updatedSession)
        }
    }
    
    private func handleNetworkChange(path: NWPath) async {
        // Check for network anomalies
        if path.status == .satisfied {
            // Network is available, check for IP changes
            if let session = currentSession {
                let newIP = await getCurrentIPAddress()
                if newIP != session.ipAddress {
                    // IP address changed, log the event
                    await logSessionEvent(.ipChanged, session: session, details: "IP changed from \(session.ipAddress ?? "unknown") to \(newIP ?? "unknown")")
                }
            }
        }
    }
    
    private func checkSessionStatus() async {
        guard let session = currentSession else { return }
        
        let now = Date()
        
        // Check if session has expired (only after 30 days)
        if now > session.expiresAt {
            await MainActor.run {
                self.isSessionValid = false
            }
            
            // Invalidate expired session
            try? await invalidateSession()
            
            // Post notification for UI to handle
            NotificationCenter.default.post(name: Foundation.Notification.Name.sessionExpired, object: nil)
            return
        }
        
        // Check for inactivity timeout (only after 7 days of no activity)
        let timeSinceLastActivity = now.timeIntervalSince(session.lastActivity)
        if timeSinceLastActivity > inactivityTimeout {
            await MainActor.run {
                self.isSessionValid = false
            }
            
            // Invalidate inactive session
            try? await invalidateSession()
            
            // Post notification for UI to handle
            NotificationCenter.default.post(name: Foundation.Notification.Name.sessionInactive, object: nil)
            return
        }
        
        // Check if session is approaching expiry (1 day warning)
        let timeUntilExpiry = session.expiresAt.timeIntervalSince(now)
        if timeUntilExpiry < sessionWarningThreshold {
            // Post warning notification
            NotificationCenter.default.post(name: Foundation.Notification.Name.sessionExpiringSoon, object: nil)
        }
    }
    
    // MARK: - Device Information
    
    private func getCurrentDeviceInfo() -> DeviceInfo {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Get stable device ID - this is the primary identifier
        let stableDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Get device information with improved fallback handling
        let deviceName = getStableDeviceName()
        let deviceType = getStableDeviceType()
        
        print("📱 SessionManager: Device Info - ID: \(stableDeviceId), Name: \(deviceName), Type: \(deviceType)")
        
        return DeviceInfo(
            deviceId: stableDeviceId,
            deviceName: deviceName,
            deviceType: deviceType,
            appVersion: "\(appVersion) (\(buildNumber))",
            osVersion: "\(device.systemName) \(device.systemVersion)",
            userAgent: "PodWebBlueprint/\(appVersion) (\(device.systemName) \(device.systemVersion))"
        )
    }
    
    /// Gets a stable device name that doesn't change over time
    private func getStableDeviceName() -> String {
        let device = UIDevice.current
        let userGivenName = device.name
        
        // If we have a user-given name and it's not generic, use it
        if !userGivenName.isEmpty && 
           userGivenName != "iPhone" && 
           userGivenName != "iPad" && 
           userGivenName != "iPod touch" {
            return userGivenName
        }
        
        // Otherwise, use a consistent generic name based on device type
        return getDeviceDisplayName()
    }
    
    /// Gets a stable device type that doesn't fall back to "arm64"
    private func getStableDeviceType() -> String {
        let device = UIDevice.current
        
        // Try to get specific device model first
        if let modelIdentifier = getDeviceModelIdentifier() {
            let readableModel = getReadableDeviceModel(from: modelIdentifier)
            
            // Only use the readable model if it's not just the raw identifier
            if readableModel != modelIdentifier {
                return readableModel
            }
            
            // If it's a raw identifier, check if it looks like a proper device identifier
            if modelIdentifier.contains("iPhone") || 
               modelIdentifier.contains("iPad") || 
               modelIdentifier.contains("iPod") ||
               modelIdentifier.contains("MacBook") ||
               modelIdentifier.contains("iMac") ||
               modelIdentifier.contains("Mac") {
                return modelIdentifier
            }
        }
        
        // Fallback to generic but stable device type based on interface idiom
        switch device.userInterfaceIdiom {
        case .phone:
            return "iPhone"
        case .pad:
            return "iPad"
        case .mac:
            return "Mac"
        case .tv:
            return "Apple TV"
        case .carPlay:
            return "CarPlay"
        default:
            return device.model // This should be stable (iPhone, iPad, etc.)
        }
    }
    
    private func getDeviceModelIdentifier() -> String? {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
    
    private func getReadableDeviceModel(from identifier: String) -> String {
        // Map device identifiers to readable names
        let deviceMap: [String: String] = [
            // iPhone
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,6": "iPhone SE (3rd gen)",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            
            // iPad
            "iPad13,1": "iPad Air (4th gen)",
            "iPad13,2": "iPad Air (4th gen)",
            "iPad13,4": "iPad Pro 11-inch (3rd gen)",
            "iPad13,5": "iPad Pro 11-inch (3rd gen)",
            "iPad13,6": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,7": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,8": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,9": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,10": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,11": "iPad Pro 12.9-inch (5th gen)",
            
            // Mac
            "MacBookAir10,1": "MacBook Air (M1)",
            "MacBookPro17,1": "MacBook Pro 13-inch (M1)",
            "MacBookPro18,1": "MacBook Pro 14-inch (M1 Pro)",
            "MacBookPro18,2": "MacBook Pro 16-inch (M1 Pro)",
            "MacBookPro18,3": "MacBook Pro 14-inch (M1 Max)",
            "MacBookPro18,4": "MacBook Pro 16-inch (M1 Max)",
            "iMac21,1": "iMac 24-inch (M1)",
            "MacPro7,1": "Mac Pro (2019)",
            "Macmini9,1": "Mac mini (M1)"
        ]
        
        return deviceMap[identifier] ?? identifier
    }
    
    private func getDeviceDisplayName() -> String {
        let device = UIDevice.current
        
        // Try to get a more descriptive name
        if device.userInterfaceIdiom == .phone {
            return "iPhone"
        } else if device.userInterfaceIdiom == .pad {
            return "iPad"
        } else if device.userInterfaceIdiom == .mac {
            return "Mac"
        } else if device.userInterfaceIdiom == .tv {
            return "Apple TV"
        } else if device.userInterfaceIdiom == .carPlay {
            return "CarPlay"
        } else {
            return device.model
        }
    }
    
    private func getCurrentLocation() async -> LocationInfo? {
        // Get IP address first
        guard let ipAddress = await getCurrentIPAddress() else {
            return nil
        }
        
        // Use IP geolocation service to get location info
        return await getLocationFromIP(ipAddress)
    }
    
    private func getCurrentIPAddress() async -> String? {
        // Try to get IP address from multiple sources
        if let ip = await getIPFromService("https://api.ipify.org") {
            return ip
        }
        
        if let ip = await getIPFromService("https://ipinfo.io/ip") {
            return ip
        }
        
        return nil
    }
    
    private func getIPFromService(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return ip
            }
        } catch {
            print("Failed to get IP from \(urlString): \(error)")
        }
        
        return nil
    }
    
    private func getLocationFromIP(_ ipAddress: String) async -> LocationInfo? {
        let urlString = "https://ipinfo.io/\(ipAddress)/json"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let json = json else { return nil }
            
            let city = json["city"] as? String
            let country = json["country"] as? String
            let timezone = json["timezone"] as? String
            let loc = json["loc"] as? String
            
            var latitude: Double?
            var longitude: Double?
            
            if let loc = loc {
                let components = loc.components(separatedBy: ",")
                if components.count == 2 {
                    latitude = Double(components[0])
                    longitude = Double(components[1])
                }
            }
            
            return LocationInfo(
                latitude: latitude,
                longitude: longitude,
                city: city,
                country: country,
                timezone: timezone
            )
            
        } catch {
            print("Failed to get location from IP \(ipAddress): \(error)")
            return nil
        }
    }
    
    private func checkLocationAnomaly(location: LocationInfo) async -> Bool {
        // This would implement location anomaly detection
        // For now, return false
        return false
    }
    
    // MARK: - Firestore Operations
    
    private func storeSession(_ session: UserSession) async throws {
        print("💾 SessionManager: Storing new session \(session.sessionId) to Firestore")
        let sessionRef = db.collection("userSessions").document(session.sessionId)
        try await sessionRef.setData(session.toDictionary())
        print("✅ SessionManager: Successfully stored session \(session.sessionId)")
    }
    
    private func updateSession(_ session: UserSession) async throws {
        print("📝 SessionManager: Updating existing session \(session.sessionId) in Firestore")
        let sessionRef = db.collection("userSessions").document(session.sessionId)
        try await sessionRef.setData(session.toDictionary(), merge: true)
        print("✅ SessionManager: Successfully updated session \(session.sessionId)")
    }
    
    private func deactivateSession(_ session: UserSession) async throws {
        let sessionRef = db.collection("userSessions").document(session.sessionId)
        try await sessionRef.updateData([
            "isActive": false,
            "deactivatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    /// Permanently deletes a session from Firestore (for expired/stale sessions)
    private func deleteSession(_ session: UserSession) async throws {
        print("🗑️ SessionManager: Permanently deleting session \(session.sessionId)")
        let sessionRef = db.collection("userSessions").document(session.sessionId)
        try await sessionRef.delete()
    }
    
    private func deactivateSessionByDevice(userId: String, deviceId: String) async throws {
        let sessionsRef = db.collection("userSessions")
        let query = sessionsRef.whereField("userId", isEqualTo: userId)
            .whereField("deviceId", isEqualTo: deviceId)
            .whereField("isActive", isEqualTo: true)
        
        let snapshot = try await query.getDocuments()
        for document in snapshot.documents {
            try await document.reference.updateData([
                "isActive": false,
                "deactivatedAt": FieldValue.serverTimestamp()
            ])
        }
    }
    
    private func getAllUserSessions(userId: String) async throws -> [UserSession] {
        let sessionsRef = db.collection("userSessions")
        let query = sessionsRef.whereField("userId", isEqualTo: userId)
            .whereField("isActive", isEqualTo: true)
            .order(by: "lastActivity", descending: true)
        
        let snapshot = try await query.getDocuments()
        var sessions: [UserSession] = []
        
        for document in snapshot.documents {
            do {
                let session = try document.data(as: UserSession.self)
                sessions.append(session)
            } catch {
                print("Failed to decode session document \(document.documentID): \(error)")
                // Continue with other documents instead of failing completely
            }
        }
        
        return sessions
    }
    
    private func storeSecurityAlert(_ alert: SecurityAlert, for userId: String) async throws {
        let alertRef = db.collection("users").document(userId).collection("securityAlerts")
        try await alertRef.addDocument(data: alert.toDictionary())
    }
    
    private func logSessionEvent(_ event: SessionEvent, session: UserSession?, deviceId: String? = nil, details: String? = nil) async {
        let eventData: [String: Any] = [
            "eventType": event.rawValue,
            "userId": session?.userId ?? "unknown",
            "deviceId": deviceId ?? session?.deviceId ?? "unknown",
            "timestamp": FieldValue.serverTimestamp(),
            "details": details ?? "",
            "sessionId": session?.sessionId ?? "unknown"
        ]
        
        do {
            let eventsRef = db.collection("sessionEvents")
            try await eventsRef.addDocument(data: eventData)
        } catch {
            print("Failed to log session event: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// User session information
struct UserSession: Codable, Identifiable {
    let id = UUID()
    var sessionId: String
    let userId: String
    let deviceId: String
    let deviceName: String
    let deviceType: String
    let appVersion: String
    let osVersion: String
    let ipAddress: String?
    let location: LocationInfo?
    let userAgent: String
    let createdAt: Date
    var lastActivity: Date
    var expiresAt: Date
    var isActive: Bool
    var securityFlags: [String]
    
    enum CodingKeys: String, CodingKey {
        case sessionId, userId, deviceId, deviceName, deviceType, appVersion, osVersion, ipAddress, location, userAgent, createdAt, lastActivity, expiresAt, isActive, securityFlags
    }
    
    init(userId: String, deviceId: String, deviceName: String, deviceType: String, appVersion: String, osVersion: String, ipAddress: String?, location: LocationInfo?, userAgent: String, createdAt: Date, lastActivity: Date, expiresAt: Date, isActive: Bool, securityFlags: [String]) {
        self.sessionId = UUID().uuidString
        self.userId = userId
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.ipAddress = ipAddress
        self.location = location
        self.userAgent = userAgent
        self.createdAt = createdAt
        self.lastActivity = lastActivity
        self.expiresAt = expiresAt
        self.isActive = isActive
        self.securityFlags = securityFlags
    }
    
    /// Copying initializer for updating sessions while preserving the session ID
    init(copying session: UserSession, deviceName: String? = nil, deviceType: String? = nil, appVersion: String? = nil, osVersion: String? = nil, lastActivity: Date? = nil, expiresAt: Date? = nil, isActive: Bool? = nil) {
        self.sessionId = session.sessionId // Keep the same session ID
        self.userId = session.userId
        self.deviceId = session.deviceId
        self.deviceName = deviceName ?? session.deviceName
        self.deviceType = deviceType ?? session.deviceType
        self.appVersion = appVersion ?? session.appVersion
        self.osVersion = osVersion ?? session.osVersion
        self.ipAddress = session.ipAddress
        self.location = session.location
        self.userAgent = session.userAgent
        self.createdAt = session.createdAt
        self.lastActivity = lastActivity ?? session.lastActivity
        self.expiresAt = expiresAt ?? session.expiresAt
        self.isActive = isActive ?? session.isActive
        self.securityFlags = session.securityFlags
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.sessionId = try container.decode(String.self, forKey: .sessionId)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.deviceId = try container.decode(String.self, forKey: .deviceId)
        self.deviceName = try container.decode(String.self, forKey: .deviceName)
        self.deviceType = try container.decode(String.self, forKey: .deviceType)
        self.appVersion = try container.decode(String.self, forKey: .appVersion)
        self.osVersion = try container.decode(String.self, forKey: .osVersion)
        self.ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        self.location = try container.decodeIfPresent(LocationInfo.self, forKey: .location)
        self.userAgent = try container.decode(String.self, forKey: .userAgent)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.lastActivity = try container.decode(Date.self, forKey: .lastActivity)
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        self.isActive = try container.decode(Bool.self, forKey: .isActive)
        self.securityFlags = try container.decode([String].self, forKey: .securityFlags)
    }
    
    /// Creates a copy of an existing session with updated values
    init(copying session: UserSession, lastActivity: Date? = nil, expiresAt: Date? = nil, isActive: Bool? = nil) {
        self.sessionId = session.sessionId // Keep the same session ID
        self.userId = session.userId
        self.deviceId = session.deviceId
        self.deviceName = session.deviceName
        self.deviceType = session.deviceType
        self.appVersion = session.appVersion
        self.osVersion = session.osVersion
        self.ipAddress = session.ipAddress
        self.location = session.location
        self.userAgent = session.userAgent
        self.createdAt = session.createdAt
        self.lastActivity = lastActivity ?? session.lastActivity
        self.expiresAt = expiresAt ?? session.expiresAt
        self.isActive = isActive ?? session.isActive
        self.securityFlags = session.securityFlags
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "sessionId": sessionId,
            "userId": userId,
            "deviceId": deviceId,
            "deviceName": deviceName,
            "deviceType": deviceType,
            "appVersion": appVersion,
            "osVersion": osVersion,
            "ipAddress": ipAddress ?? "",
            "location": location?.toDictionary() ?? [:],
            "userAgent": userAgent,
            "createdAt": createdAt,
            "lastActivity": lastActivity,
            "expiresAt": expiresAt,
            "isActive": isActive,
            "securityFlags": securityFlags
        ]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encode(osVersion, forKey: .osVersion)
        try container.encodeIfPresent(ipAddress, forKey: .ipAddress)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(userAgent, forKey: .userAgent)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastActivity, forKey: .lastActivity)
        try container.encode(expiresAt, forKey: .expiresAt)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(securityFlags, forKey: .securityFlags)
    }
}

/// Device session information for UI display
struct DeviceSession: Identifiable {
    let id = UUID()
    let deviceId: String
    let deviceName: String
    let deviceType: String
    let appVersion: String
    let osVersion: String
    let ipAddress: String?
    let location: LocationInfo?
    let lastActivity: Date
    let createdAt: Date
    let isActive: Bool
    let isCurrentDevice: Bool
    
    init(from session: UserSession) {
        self.deviceId = session.deviceId
        self.deviceName = session.deviceName
        self.deviceType = session.deviceType
        self.appVersion = session.appVersion
        self.osVersion = session.osVersion
        self.ipAddress = session.ipAddress
        self.location = session.location
        self.lastActivity = session.lastActivity
        self.createdAt = session.createdAt
        self.isActive = session.isActive
        self.isCurrentDevice = SessionManager.shared.currentSession?.deviceId == session.deviceId
    }
}

/// Device information
struct DeviceInfo {
    let deviceId: String
    let deviceName: String
    let deviceType: String
    let appVersion: String
    let osVersion: String
    let userAgent: String
}

/// Location information
struct LocationInfo: Codable {
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let country: String?
    let timezone: String?
    
    func toDictionary() -> [String: Any] {
        return [
            "latitude": latitude ?? 0.0,
            "longitude": longitude ?? 0.0,
            "city": city ?? "",
            "country": country ?? "",
            "timezone": timezone ?? ""
        ]
    }
}

/// Security alert information
struct SecurityAlert: Identifiable {
    let id = UUID()
    let type: SecurityAlertType
    let severity: SecuritySeverity
    let message: String
    let timestamp: Date
    let details: String
    
    func toDictionary() -> [String: Any] {
        return [
            "type": type.rawValue,
            "severity": severity.rawValue,
            "message": message,
            "timestamp": timestamp,
            "details": details
        ]
    }
}

/// Security alert types
enum SecurityAlertType: String, CaseIterable {
    case locationAnomaly = "location_anomaly"
    case tooManySessions = "too_many_sessions"
    case sessionTooOld = "session_too_old"
    case ipChanged = "ip_changed"
    case deviceRevoked = "device_revoked"
}

/// Security severity levels
enum SecuritySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// Session events for logging
enum SessionEvent: String, CaseIterable {
    case created = "created"
    case restored = "restored"
    case refreshed = "refreshed"
    case invalidated = "invalidated"
    case logoutAllDevices = "logout_all_devices"
    case deviceRevoked = "device_revoked"
    case ipChanged = "ip_changed"
}

/// Session management errors
enum SessionError: Error, LocalizedError {
    case noActiveSession
    case sessionExpired
    case sessionInactive
    case tooManySessions
    case deviceNotFound
    case forceLogoutFailed
    
    var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active session"
        case .sessionExpired:
            return "Session has expired"
        case .sessionInactive:
            return "Session is inactive"
        case .tooManySessions:
            return "Too many active sessions"
        case .deviceNotFound:
            return "Device not found"
        case .forceLogoutFailed:
            return "Failed to force logout user"
        }
    }
}

// MARK: - Notification Names

extension Foundation.Notification.Name {
    static let sessionExpired = Foundation.Notification.Name("sessionExpired")
    static let sessionInactive = Foundation.Notification.Name("sessionInactive")
    static let sessionExpiringSoon = Foundation.Notification.Name("sessionExpiringSoon")
    static let sessionRevoked = Foundation.Notification.Name("sessionRevoked")
}
