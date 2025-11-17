//
//  NotificationSettingsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import SwiftUI
import Firebase

struct NotificationSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = NotificationSettingsViewModel()
    
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
                
                Text("Notifications")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    viewModel.saveSettings()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Save")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: Color("accentColor").opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Push Notifications Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Push Notifications")
                            .font(.headline)
                            .foregroundColor(Color("textColor"))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // Likes
                            NotificationToggleRow(
                                title: "Likes",
                                subtitle: "When someone likes your pod",
                                isOn: $viewModel.likesEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Comments
                            NotificationToggleRow(
                                title: "Comments",
                                subtitle: "When someone comments on your pod",
                                isOn: $viewModel.commentsEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Follows
                            NotificationToggleRow(
                                title: "New Followers",
                                subtitle: "When someone follows you",
                                isOn: $viewModel.followsEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Follow Requests
                            NotificationToggleRow(
                                title: "Follow Requests",
                                subtitle: "When someone requests to follow you",
                                isOn: $viewModel.followRequestsEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Reposts
                            NotificationToggleRow(
                                title: "Reposts",
                                subtitle: "When someone reposts your pod",
                                isOn: $viewModel.repostsEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Messages
                            NotificationToggleRow(
                                title: "Messages",
                                subtitle: "When someone sends you a message",
                                isOn: $viewModel.messagesEnabled
                            )
                        }
                        .background(Color("tabColor"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Content Recommendations Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Content Recommendations")
                            .font(.headline)
                            .foregroundColor(Color("textColor"))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // New Pods
                            NotificationToggleRow(
                                title: "New Pods",
                                subtitle: "Discover new content from creators you follow",
                                isOn: $viewModel.newPodsEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Trending
                            NotificationToggleRow(
                                title: "Trending Content",
                                subtitle: "Get notified about trending pods",
                                isOn: $viewModel.trendingEnabled
                            )
                        }
                        .background(Color("tabColor"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // App Updates Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("App Updates")
                            .font(.headline)
                            .foregroundColor(Color("textColor"))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // App Updates
                            NotificationToggleRow(
                                title: "App Updates",
                                subtitle: "Get notified about new features and updates",
                                isOn: $viewModel.appUpdatesEnabled
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Maintenance
                            NotificationToggleRow(
                                title: "Maintenance Alerts",
                                subtitle: "Important service notifications",
                                isOn: $viewModel.maintenanceEnabled
                            )
                        }
                        .background(Color("tabColor"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Notification Schedule
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Notification Schedule")
                            .font(.headline)
                            .foregroundColor(Color("textColor"))
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            // Quiet Hours
                            NotificationToggleRow(
                                title: "Quiet Hours",
                                subtitle: "Pause notifications during quiet hours",
                                isOn: $viewModel.quietHoursEnabled
                            )
                            
                            if viewModel.quietHoursEnabled {
                                Divider()
                                    .padding(.leading, 56)
                                
                                HStack {
                                    Spacer()
                                        .frame(width: 56)
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Start Time")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            
                                            Spacer()
                                            
                                            DatePicker("", selection: $viewModel.quietHoursStart, displayedComponents: .hourAndMinute)
                                                .labelsHidden()
                                        }
                                        
                                        HStack {
                                            Text("End Time")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            
                                            Spacer()
                                            
                                            DatePicker("", selection: $viewModel.quietHoursEnd, displayedComponents: .hourAndMinute)
                                                .labelsHidden()
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                        .background(Color("tabColor"))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.loadSettings()
        }
    }
}

struct NotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("textColor"))
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color("accentColor")))
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    NotificationSettingsView()
} 