//
//  FollowRequestRowView.swift
//  PodWebBlueprint
//
//  Created by Assistant on Follow Request Row Implementation
//

import SwiftUI
import Kingfisher

struct FollowRequestRowView: View {
    let user: User
    let onAction: (FollowRequestAction) -> Void
    let isLoading: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Profile Image with modern styling
            NavigationLink(destination: ProfileView(user: user)) {
                if !user.profileImageUrl.isEmpty {
                    KFImage(URL(string: user.profileImageUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // User Info with modern typography
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(user.fullname ?? user.username)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(.systemBlue))
                    }
                }
                
                Text("@\(user.username)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Modern square action buttons
            HStack(spacing: 12) {
                // Accept button - Green check
                Button {
                    onAction(.accept)
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isLoading)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isLoading ? Color.gray : Color.green)
                        .shadow(
                            color: isLoading ? Color.clear : Color.green.opacity(0.3),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                )
                .buttonStyle(PlainButtonStyle())
                
                // Reject button - Red X
                Button {
                    onAction(.reject)
                } label: {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isLoading)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isLoading ? Color.gray : Color.red)
                        .shadow(
                            color: isLoading ? Color.clear : Color.red.opacity(0.3),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                )
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

enum FollowRequestAction {
    case accept
    case reject
}

