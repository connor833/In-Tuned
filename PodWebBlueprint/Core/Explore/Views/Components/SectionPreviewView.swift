//
//  SectionPreviewView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct SectionPreviewView: View {
    let title: String
    let icon: String
    let color: Color
    let pods: [Pod]
    let seeAllAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: {
                    print("👆 [SeeAllButton] Tapped for section: \(title)")
                    seeAllAction()
                }) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color("accentColor"))
                }
                .buttonStyle(SeeAllButtonStyle())
            }
            .padding(.horizontal, 20)
            
            // Horizontal scrolling pods
            if pods.isEmpty {
                HStack {
                    Spacer()
                    Text("No pods available")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                PodCardsScrollView(pods: pods)
            }
        }
    }
}

struct PodCardsScrollView: View {
    let pods: [Pod]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(pods) { pod in
                    if let url = URL(string: pod.fileUrl) {
                        NavigationLink(destination: PlayerView(url: url, pod: pod)) {
                            PodCardView(pod: pod)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollContentBackground(.hidden)
    }
}

struct PodCardView: View {
    let pod: Pod
    @State private var imageLoadAttempts = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with retry logic for poor connections
            AsyncImage(url: URL(string: pod.thumbnailUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    // Retry on failure for poor connections
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "waveform")
                                .foregroundColor(.gray)
                        )
                        .onAppear {
                            // Retry up to 2 times with delay
                            if imageLoadAttempts < 2 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + Double(imageLoadAttempts + 1)) {
                                    imageLoadAttempts += 1
                                }
                            }
                        }
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "waveform")
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 150, height: 150)
            .cornerRadius(12)
            .clipped()
            
            // Title
            Text(pod.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(width: 150, alignment: .leading)
            
            // Stats
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("\(pod.likes)")
                        .font(.system(size: 12, weight: .medium))
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                    Text("\(pod.views)")
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .foregroundColor(.secondary)
        }
        .frame(width: 158, height: 220) // Fixed frame for consistent tap target
        .padding(4)
        .contentShape(Rectangle()) // Ensure entire area is tappable
    }
}

struct SeeAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            // Removed animation for instant tap response
    }
}

#Preview {
    NavigationView {
        ScrollView {
            SectionPreviewView(
                title: "Trending Now",
                icon: "flame.fill",
                color: .orange,
                pods: [],
                seeAllAction: {}
            )
        }
    }
}
