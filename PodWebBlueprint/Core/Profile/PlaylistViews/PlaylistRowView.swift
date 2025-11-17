//
//  PodRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher
import Firebase

struct PlaylistRowView: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail with modern styling
            KFImage(URL(string: playlist.thumbnailUrl))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 48)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // Title with modern typography
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("\(playlist.podCount) \(playlist.podCount == 1 ? "pod" : "pods")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct PlaylistRowView_Previews: PreviewProvider {
    static var previews: some View {
        PlaylistRowView(playlist: PreviewClass().previewPlaylist)
    }
}
