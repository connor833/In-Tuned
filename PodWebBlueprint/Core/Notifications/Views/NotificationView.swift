//
//  NotificationsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 5/25/25.
//

import SwiftUI

struct NotificationView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                // Header with cool back button
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
                    
                    NavigationLink(destination: FollowRequestsView()
                        .navigationBarBackButtonHidden(true)) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .foregroundColor(Color("accentColor"))
                            .font(.title2)
                    }
                    .padding()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No notifications yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        
                        Text("When you get notifications, they'll show up here")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.notifications) { notification in
                                NotificationRowView(notification: notification, viewModel: viewModel)
                            }
                        }
                    }
                    .refreshable {
                        viewModel.refreshNotifications()
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Clear the app badge immediately when notifications screen opens
                BadgeManager.shared.clearBadgeCount()
                
                // Mark notifications as read after a delay so users can see the gray state
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    viewModel.markAllAsRead()
                }
            }
        }

    }
}

#Preview {
    NotificationView()
}
