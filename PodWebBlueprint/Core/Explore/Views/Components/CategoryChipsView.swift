//
//  CategoryChipsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct CategoryChipsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse Categories")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PodCategory.allCases) { category in
                        NavigationLink(destination: CategoryDetailView(category: category)) {
                            CategoryChip(category: category)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollContentBackground(.hidden)
        }
    }
}

struct CategoryChip: View {
    let category: PodCategory
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 14, weight: .semibold))
            
            Text(category.rawValue)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(minWidth: 120, minHeight: 50) // Increased tap target
        .background(
            LinearGradient(
                gradient: Gradient(colors: [category.color, category.color.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .shadow(color: category.color.opacity(0.3), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle()) // Ensure entire area is tappable
    }
}

#Preview {
    NavigationView {
        CategoryChipsView()
    }
}
