//
//  FollowRequestsView.swift
//  PodWebBlueprint
//
//  Created by Assistant on Follow Requests Implementation
//

import SwiftUI
import Kingfisher

struct FollowRequestsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = FollowRequestsViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
            // Navigation Header with cool back button
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
                
                Text("Follow Requests")
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
            
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                Spacer()
            } else if viewModel.followRequests.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Follow Requests")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("When people request to follow you, they'll appear here")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.followRequests) { user in
                            FollowRequestRowView(
                                user: user,
                                onAction: { action in
                                    switch action {
                                    case .accept:
                                        viewModel.acceptFollowRequest(from: user)
                                    case .reject:
                                        viewModel.rejectFollowRequest(from: user)
                                    }
                                },
                                isLoading: viewModel.loadingUsers.contains(user.id ?? "")
                            )
                            .padding(.horizontal)
                            
                            Divider()
                                .padding(.leading, 70) // Align with the text content
                        }
                    }
                }
            }
            }
            .onAppear {
                viewModel.fetchFollowRequests()
            }
            .navigationBarBackButtonHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}



class FollowRequestsViewModel: ObservableObject {
    @Published var followRequests: [User] = []
    @Published var isLoading = false
    @Published var loadingUsers: Set<String> = []
    
    private let userService = UserService()
    
    func fetchFollowRequests() {
        isLoading = true
        userService.fetchFollowRequests { users in
            DispatchQueue.main.async {
                self.followRequests = users
                self.isLoading = false
            }
        }
    }
    
    func acceptFollowRequest(from user: User) {
        guard let userId = user.id else { return }
        
        DispatchQueue.main.async {
            self.loadingUsers.insert(userId)
        }
        
        userService.acceptFollowRequest(from: user) { success in
            DispatchQueue.main.async {
                self.loadingUsers.remove(userId)
                if success {
                    // Remove the user from the follow requests list
                    self.followRequests.removeAll { $0.id == user.id }
                }
            }
        }
    }
    
    func rejectFollowRequest(from user: User) {
        guard let userId = user.id else { return }
        
        DispatchQueue.main.async {
            self.loadingUsers.insert(userId)
        }
        
        userService.rejectFollowRequest(from: user) { success in
            DispatchQueue.main.async {
                self.loadingUsers.remove(userId)
                if success {
                    // Remove the user from the follow requests list
                    self.followRequests.removeAll { $0.id == user.id }
                }
            }
        }
    }
}

#Preview {
    FollowRequestsView()
} 