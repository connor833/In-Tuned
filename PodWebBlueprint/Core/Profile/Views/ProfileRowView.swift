//
//  ProfileRowview.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher

struct ProfileRowView: View {
    @State var isLoading = false
    
    let user: User
    
    init(user: User) {
        self.user = user
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Profile Image with modern styling
            if user.profileImageUrl != "" {
                KFImage(URL(string: user.profileImageUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            
            // User Info Section
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(user.fullname ?? user.username)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if user.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(.systemBlue))
                    }
                }
                
                Text("@\(user.username)")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Bio preview if available
                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            
            Spacer()
            
            // Follow indicator or action button
            VStack {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.04),
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .redacted(reason: isLoading ? .placeholder : [])
    }
}

struct ProfileRowview_Previews: PreviewProvider {
    static var previews: some View {
        ProfileRowView(user: PreviewClass().previewUser)
    }
}
