//
//  MainTabView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedIndex = 0
    @State private var audioSheet = false
    @State private var audioPlaying = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State var isPlaying = false
    
    // MARK: - Persistent ViewModels
    @State private var userPreferences = UserPreferences()
    
    var body: some View {
        if let user = authViewModel.currentUser {
            TabView(selection: $selectedIndex) {
                FeedTabView()
                    .environmentObject(FeedViewModel.shared)
                    .onAppear {
                        // Setup the singleton with current user data
                        FeedViewModel.shared.setup(user: user, userPreferences: userPreferences)
                    }
                    .onTapGesture {
                        self.selectedIndex = 0
                    }
                    .tabItem {
                        Image(systemName: "house")
                        //Text("Home")
                    }.tag(0)
                
                ExploreView(user: user)
                    .environmentObject(authViewModel)
                    .onTapGesture {
                        self.selectedIndex = 1
                    }
                    .tabItem {
                        Image(systemName: "safari")
                    }.tag(1)
                
                MessageTabView(user: user)
                    .environmentObject(UserViewModel.shared)
                    .onAppear {
                        // Setup the singleton with current user data
                        UserViewModel.shared.setup(user: user)
                    }
                    .onTapGesture {
                        self.selectedIndex = 2
                        // Clear message badge when messages tab is opened
                        MessageBadgeManager.shared.clearUnreadMessageCount()
                    }
                    .tabItem {
                        MessageTabBadgeView()
                        //Text("Messages")
                    }.tag(2)
                
                UploadingPodsView()
                    .onTapGesture {
                        self.selectedIndex = 3
                    }
                    .tabItem {
                        Image(systemName: "arrow.up.circle")
                        //Text("Uploads")
                    }.tag(3)
                
                UserTabView(user: user)
                    .onTapGesture {
                        self.selectedIndex = 4
                        print("Main Tab View: \(user.username)")
                    }
                    .tabItem {
                        Image(systemName: "person")
                       // Text("Profile")
                    }.tag(4)
            }
            .accentColor(Color("textColor"))
            .onAppear {
                print("Main Tab View: \(user.username)")
            }
            .onChange(of: selectedIndex) { newIndex in
                if newIndex == 2 {
                    // Message tab selected - post notification to refresh
                    NotificationCenter.default.post(name: NSNotification.Name("MessageTabSelected"), object: nil)
                    // Clear message badge when messages tab is selected
                    MessageBadgeManager.shared.clearUnreadMessageCount()
                }
            }
            .onChange(of: deepLinkManager.destination) { destination in
                // Handle deep linking to notifications
                if let destination = destination,
                   destination.screen == "notifications" {
                    // Switch to messages tab (index 2) where notifications are accessed
                    selectedIndex = 2
                    
                    // Clear the deep link destination
                    deepLinkManager.clearDestination()
                    
                    // Post notification to open notifications screen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("OpenNotificationsFromDeepLink"),
                            object: nil
                        )
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeepLinkToProfile"))) { _ in
                // Handle deep linking to user's own profile tab
                print("🔗 DeepLinkToProfile: Switching to profile tab (index 4)")
                selectedIndex = 4
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UploadCompleted"))) { _ in
                // Refresh user profile when upload completes
                print("📱 Upload completed - refreshing user profile")
                // The UserTabView already listens for this notification and refreshes automatically
            }

            
        } else {
            LoginView()
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
