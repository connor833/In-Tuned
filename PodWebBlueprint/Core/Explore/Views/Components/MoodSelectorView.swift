//
//  MoodSelectorView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct MoodSelectorView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Mood")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PodMood.allCases) { mood in
                    NavigationLink(destination: MoodDetailView(mood: mood)) {
                        MoodCard(mood: mood)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct MoodCard: View {
    let mood: PodMood
    
    var body: some View {
        VStack(spacing: 8) {
            // Emoji/Icon
            Text(mood.emoji)
                .font(.system(size: 40))
            
            // Mood name
            Text(mood.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 140) // Increased tap target
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .contentShape(Rectangle()) // Ensure entire area is tappable
    }
}

#Preview {
    NavigationView {
        ScrollView {
            MoodSelectorView()
        }
    }
}
