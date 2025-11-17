//
//  Settings Screen.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/6/23.
//

import SwiftUI

struct SettingsScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var settingOptions = SettingOptions()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack {
            // Header with back button
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("accentColor"), lineWidth: 2)
                            )
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // ACCOUNT Section
                    Text("ACCOUNT")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Group {
                        NavigationLink(destination: ChangePasswordView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Change Password", imageName: "lock", destination: "ChangePassword"))
                        }
                        NavigationLink(destination: SessionManagementView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Session Management", imageName: "rectangle.stack.badge.person.crop", destination: "SessionManagement"))
                        }
                        NavigationLink(destination: AccountPrivacyView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Account Privacy", imageName: "person.crop.circle", destination: "AccountPrivacy"))
                        }
                        NavigationLink(destination: AccountSettingsView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Account Settings", imageName: "person.crop.circle", destination: "AccountSettings"))
                        }
                    }
                    
                    // CONTENT Section
                    Text("CONTENT")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Group {
                        NavigationLink(destination: NotificationSettingsView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Notifications", imageName: "bell", destination: "Notifications"))
                        }
                        NavigationLink(destination: LanguageSettings()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Language", imageName: "globe", destination: "Language"))
                        }
                        NavigationLink(destination: DisplaySettings()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Display", imageName: "display", destination: "Display"))
                        }
                        NavigationLink(destination: BlockedUsersView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: NSLocalizedString("Blocked Users", comment: ""), imageName: "slash.circle", destination: "BlockedUsers"))
                        }
                    }
                    
                    // PRIVACY & COMPLIANCE Section
                    Text("PRIVACY & COMPLIANCE")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Group {
                        NavigationLink(destination: CCPAComplianceView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "CCPA Rights", imageName: "hand.raised", destination: "CCPARights"))
                        }
                        NavigationLink(destination: TermsAndPoliciesView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Terms and Policies", imageName: "doc.text", destination: "TermsAndPolicies"))
                        }
                    }
                    
                    // SUPPORT Section
                    Text("SUPPORT")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    Group {
                        NavigationLink(destination: ReportProblemView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Report a Problem", imageName: "exclamationmark.triangle", destination: "ReportProblem"))
                        }
                        NavigationLink(destination: SupportView()
                            .navigationBarHidden(true)) {
                            SettingsRowView(option: SettingOption(title: "Support", imageName: "questionmark.circle", destination: "Support"))
                        }
                    }
                }
                .padding(.vertical)
            }
            
            Divider()
                .foregroundColor(.gray)
            Button {
                authViewModel.signOut {
                    presentationMode.wrappedValue.dismiss()
                }
            } label: {
                HStack {
                    if authViewModel.isLoggingOut {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(Color("accentColor"))
                    }
                    Text(authViewModel.isLoggingOut ? "Logging Out..." : "Log Out")
                        .foregroundColor(Color("accentColor"))
                        .font(.headline)
                }
            }
            .disabled(authViewModel.isLoggingOut)
        }
        .navigationBarHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetNavigationStack"))) { _ in
            // Immediately dismiss the entire settings navigation stack when account is deleted
            DispatchQueue.main.async {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

struct Settings_Screen_Previews: PreviewProvider {
    static var previews: some View {
        SettingsScreen()
    }
}
