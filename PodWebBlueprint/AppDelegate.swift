import UIKit
import Firebase
import UserNotifications
import FirebaseMessaging
import FirebaseAuth

// Extension to access bundle entitlements
extension Bundle {
    var entitlements: [String: Any]? {
        guard let path = self.path(forResource: "PodWebBlueprint", ofType: "entitlements") else {
            return nil
        }
        return NSDictionary(contentsOfFile: path) as? [String: Any]
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseConfig.configure()
        
        // Set up app lifecycle notifications for badge management
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        // Configure AppCheck for development
        #if DEBUG

        #else
        // For production, you would configure with proper App Check tokens
        // AppCheck.setAppCheckProviderFactory(DeviceCheckProviderFactory())
        #endif
        
        // Set up FCM
        Messaging.messaging().delegate = self
        
        // Initialize Google AdMob
       // MobileAds.shared.start(completionHandler: nil)
        
        // Set up background app refresh for upload queue
        setupBackgroundAppRefresh()
        
        // Request permission for notifications
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if granted {
                    print("✅ Notification permission granted")
                    print("🔄 Now registering for remote notifications...")
                } else if let error = error {
                    print("❌ Error requesting notification permission: \(error.localizedDescription)")
                } else {
                    print("❌ Notification permission denied by user")
                }
            }
        )
        
        #if targetEnvironment(simulator)
        // Simulator - APNS will not work
        #else
        // Real device - check entitlements before registering
        if let entitlements = Bundle.main.entitlements {
            if let apsEnv = entitlements["aps-environment"] as? String {
                // aps-environment found
            }
        }
        #endif
        
        application.registerForRemoteNotifications()
        
        // Update badge count on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if Auth.auth().currentUser != nil {
                BadgeManager.shared.updateBadgeCount()
            }
        }
        
        return true
    }
    
    // Handle FCM token refresh
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        print("✅ FCM Token received in AppDelegate: \(token)")
        
        // Update token in Firestore if user is logged in
        if let uid = Auth.auth().currentUser?.uid {
            let db = Firestore.firestore()
            db.collection("users")
                .document(uid)
                .updateData(["fcmToken": token]) { error in
                    if let error = error {
                        print("❌ AppDelegate: Error updating FCM token: \(error.localizedDescription)")
                    } else {
                        print("✅ AppDelegate: FCM token successfully saved to Firestore")
                    }
                }
        } else {
            print("⚠️  FCM token received but no user logged in - will save when user logs in")
        }
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        print("Received notification in foreground: \(userInfo)")
        
        // Update badge count immediately when notification is received
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            BadgeManager.shared.updateBadgeCount()
        }
        
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        print("Notification tapped with userInfo: \(userInfo)")
        
        // Update badge count when notification is tapped
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            BadgeManager.shared.updateBadgeCount()
        }
        
        // Extract navigation data from the notification
        let notificationData: [String: Any] = [
            "type": userInfo["type"] as? String ?? "",
            "senderId": userInfo["senderId"] as? String ?? "",
            "contentId": userInfo["contentId"] as? String ?? "",
            "notificationId": userInfo["notificationId"] as? String ?? "",
            "screen": userInfo["screen"] as? String ?? "",
            "action": userInfo["action"] as? String ?? ""
        ]
        
        // Post notification for deep linking
        NotificationCenter.default.post(
            name: NSNotification.Name("NotificationTapped"),
            object: nil,
            userInfo: notificationData
        )
        
        completionHandler()
    }
    
    // MARK: - App Lifecycle
    
    @objc func applicationDidBecomeActive() {
        // Update badge count when app becomes active
        if let uid = Auth.auth().currentUser?.uid {
            BadgeManager.shared.updateBadgeCount()
        }
    }
    
    // Handle successful registration for remote notifications
    func application(_ application: UIApplication,
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("🎉 === APNS REGISTRATION SUCCESS ===")
        print("✅ Device Token Length: \(deviceToken.count) bytes")
        print("✅ Device Token: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
        
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNS token set successfully - FCM can now generate tokens")
        
        // Post notification that APNS is ready
        NotificationCenter.default.post(name: NSNotification.Name("APNSTokenReady"), object: nil)
        
        // Trigger FCM token generation now that APNS is ready
        if Auth.auth().currentUser != nil {
            print("🔄 Requesting FCM token now that APNS is ready...")
            FCMService.shared.updateFCMToken()
        }
        
        print("=== END APNS REGISTRATION SUCCESS ===")
    }
    

    
    // Handle failed registration for remote notifications
    func application(_ application: UIApplication,
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ === APNS REGISTRATION FAILED ===")
        print("❌ Error: \(error.localizedDescription)")
        print("❌ Error code: \((error as NSError).code)")
        print("❌ Error domain: \((error as NSError).domain)")
        print("=== END APNS REGISTRATION FAILED ===")
    }
    
    // Handle receiving remote notification
    func application(_ application: UIApplication,
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📱 Received remote notification: \(userInfo)")
        
        // Update badge count when remote notification is received
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            BadgeManager.shared.updateBadgeCount()
        }
        
        completionHandler(.newData)
    }
    
    // MARK: - Background App Refresh
    
    private func setupBackgroundAppRefresh() {
        // Enable background app refresh for the app
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        print("🔄 Background app refresh enabled")
    }
    
    // Handle background app refresh
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("🔄 Background app refresh triggered")
        
        // Check if user is logged in
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No user logged in for background refresh")
            completionHandler(.noData)
            return
        }
        
        // Create User object for retry operations
        let user = User(
            uid: currentUser.uid,
            username: currentUser.displayName ?? "User",
            fullname: currentUser.displayName ?? "User",
            profileImageUrl: currentUser.photoURL?.absoluteString ?? "",
            email: currentUser.email ?? "",
            isVerified: false
        )
        
        // Retry interrupted uploads in background
        let uploadQueue = UploadQueueManager()
        uploadQueue.retryInterruptedUploads()
        
        print("✅ Background app refresh completed - retrying interrupted uploads")
        completionHandler(.newData)
    }
}
