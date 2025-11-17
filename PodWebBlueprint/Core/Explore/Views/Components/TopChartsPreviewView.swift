//
//  TopChartsPreviewView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct TopChartsPreviewView: View {
    let pods: [Pod]
    let seeAllAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("Top Charts")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: seeAllAction) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color("accentColor"))
                }
                .buttonStyle(TopChartsSeeAllButtonStyle())
            }
            .padding(.horizontal, 20)
            
            // Top 3 pods in ranked list
            if pods.isEmpty {
                HStack {
                    Spacer()
                    Text("No top charts available")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(pods.prefix(3).enumerated()), id: \.element.id) { index, pod in
                        TopChartRow(rank: index + 1, pod: pod)
                        
                        if index < 2 && index < pods.count - 1 {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
    }
}

struct TopChartRow: View {
    let rank: Int
    let pod: Pod
    @State private var imageLoadAttempts = 0
    
    var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
    
    var body: some View {
        NavigationLink {
            if let url = URL(string: pod.fileUrl) {
                PlayerView(url: url, pod: pod)
            }
        } label: {
            HStack(spacing: 12) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                    
                    Text("\(rank)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Thumbnail with retry logic
                AsyncImage(url: URL(string: pod.thumbnailUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .onAppear {
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
                                    .scaleEffect(0.7)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 50, height: 50)
                .cornerRadius(8)
                .clipped()
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(pod.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
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
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle()) // Ensure entire area is tappable
        }
        .buttonStyle(TopChartButtonStyle())
    }
}

struct TopChartsSeeAllButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct TopChartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    NavigationView {
        ScrollView {
            TopChartsPreviewView(pods: [], seeAllAction: {})
        }
    }
}
