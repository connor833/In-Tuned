import SwiftUI
import FirebaseAuth

struct SplashView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @AppStorage("uid") var userID = ""
    @State private var showMainContent = false
    @State private var showLoadingSpinner = false
    @State private var isAppEnabled = true
    @State private var isCheckingAppStatus = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                if !showMainContent || authViewModel.isLoading {
                    // Show splash screen with loading indicator
                    VStack(spacing: 20) {
                        Image("SplashIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                        
                        if authViewModel.isLoading && showLoadingSpinner {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                .scaleEffect(1.2)
                                .padding(.top, 10)
                        }
                    }
                } else {
                    // Navigate based on auth state
                    if let userSession = authViewModel.userSession {
                        // Show loading while fetching user data for existing users
                        if authViewModel.currentUser == nil && !authViewModel.showOnboarding {
                            Group {
                                if showLoadingSpinner {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                        .scaleEffect(1.5)
                                }
                            }
                            .onAppear {
                                print("🔄 SplashView: Loading user data...")
                                print("🔄 SplashView: userSession = \(userSession.uid)")
                                print("🔄 SplashView: currentUser = nil")
                            }
                        } else if authViewModel.showOnboarding {
                            OnboardingView()
                                .onAppear {
                                    print("🔄 SplashView: Navigating to OnboardingView")
                                    print("🔄 SplashView: userSession = \(userSession.uid)")
                                    print("🔄 SplashView: showOnboarding = \(authViewModel.showOnboarding)")
                                }
                        } else if !authViewModel.hasAcceptedTerms {
                            // User needs to accept terms
                            TermsAcceptanceView()
                                .onAppear {
                                    print("🔄 SplashView: Navigating to TermsAcceptanceView")
                                    print("🔄 SplashView: userSession = \(userSession.uid)")
                                    print("🔄 SplashView: hasAcceptedTerms = \(authViewModel.hasAcceptedTerms)")
                                }
                        } else {
                            // Onboarding completed and terms accepted - check app status
                            if isCheckingAppStatus {
                                // Show loading while checking app status
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                    .scaleEffect(1.2)
                            } else if !isAppEnabled {
                                // App is disabled - show maintenance to everyone
                                MaintenanceView()
                                    .onAppear {
                                        print("🔄 SplashView: App is in maintenance mode")
                                    }
                            } else {
                                // App is enabled - show MainTabView
                                MainTabView()
                                    .onAppear {
                                        print("🔄 SplashView: Navigating to MainTabView")
                                        print("🔄 SplashView: userSession = \(userSession.uid)")
                                        print("🔄 SplashView: currentUser = \(authViewModel.currentUser?.username ?? "nil")")
                                        print("🔄 SplashView: showOnboarding = \(authViewModel.showOnboarding)")
                                        print("🔄 SplashView: hasAcceptedTerms = \(authViewModel.hasAcceptedTerms)")
                                    }
                            }
                        }
                    } else {
                        LoginView()
                            .onAppear {
                                print("🔄 SplashView: Navigating to LoginView")
                                print("🔄 SplashView: userSession = nil")
                                print("🔄 SplashView: showOnboarding = \(authViewModel.showOnboarding)")
                            }
                    }
                }
            }
            .onAppear {
                // Check app status
                Task {
                    do {
                        let status = try await SystemControlService.shared.isAppEnabled()
                        await MainActor.run {
                            isAppEnabled = status
                            isCheckingAppStatus = false
                        }
                    } catch {
                        print("❌ Error checking app status: \(error.localizedDescription)")
                        // Default to enabled on error
                        await MainActor.run {
                            isAppEnabled = true
                            isCheckingAppStatus = false
                        }
                    }
                }
                
                // Show loading spinner after 2 seconds if still loading
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    if authViewModel.isLoading {
                        withAnimation {
                            showLoadingSpinner = true
                        }
                    }
                }
                
                // Simple timing based on auth status - but respect loading state
                let splashDuration: TimeInterval = authViewModel.userSession != nil ? 0.5 : 2.0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                    withAnimation {
                        showMainContent = true
                    }
                }
            }
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
