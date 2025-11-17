//
//  PodWebBlueprintApp.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/31/23.
//

import SwiftUI
import Firebase

@main
struct PodWebBlueprintApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var deepLinkDestination: DeepLinkDestination?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(DeepLinkManager(destination: deepLinkDestination))
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .withAnnouncements() // ✨ Shows announcements on app launch
                .onAppear {
                    // App startup logic can go here
                }
                .onReceive(NotificationCenter.default.publisher(for: .sessionRevoked)) { _ in
                    // Handle session revocation by forcing the user to login screen
                    print("🚫 MainApp: Session revoked, clearing user ID")
                    UserDefaults.standard.set("", forKey: "uid")
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotificationTapped"))) { notification in
                    // Handle deep linking from push notifications
                    if let userInfo = notification.userInfo,
                       let screen = userInfo["screen"] as? String,
                       let action = userInfo["action"] as? String {
                        
                        print("🔗 Deep link received - Screen: \(screen), Action: \(action)")
                        
                        // Set the deep link destination
                        deepLinkDestination = DeepLinkDestination(
                            screen: screen,
                            action: action,
                            userInfo: userInfo
                        )
                    }
                }
        }
    }
}

// MARK: - Deep Link Models

struct DeepLinkDestination: Equatable {
    let screen: String
    let action: String
    let userInfo: [AnyHashable: Any]
    
    // Implement Equatable manually since [AnyHashable: Any] doesn't conform to Equatable
    static func == (lhs: DeepLinkDestination, rhs: DeepLinkDestination) -> Bool {
        return lhs.screen == rhs.screen && 
               lhs.action == rhs.action
    }
}

class DeepLinkManager: ObservableObject {
    @Published var destination: DeepLinkDestination?
    
    init(destination: DeepLinkDestination?) {
        self.destination = destination
    }
    
    func clearDestination() {
        destination = nil
    }
}
