//
//  CategoryDetailView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct CategoryDetailView: View {
    let category: PodCategory
    @StateObject private var viewModel = ExploreSectionViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pods list
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.pods.isEmpty {
                        // Loading state
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading \(category.rawValue.lowercased()) pods...")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        
                    } else if viewModel.pods.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: category.icon)
                                .font(.system(size: 50))
                                .foregroundColor(category.color)
                            
                            Text("No \(category.rawValue.lowercased()) pods yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Be the first to create content in this category")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        
                    } else {
                        // Content
                        ForEach(viewModel.pods) { pod in
                            NavigationLink {
                                if let url = URL(string: pod.fileUrl) {
                                    PlayerView(url: url, pod: pod)
                                }
                            } label: {
                                PodRowViewThin(pod: pod)
                                    .foregroundColor(Color("textColor"))
                            }
                            .onAppear {
                                // Load more when reaching the last few items
                                if pod.id == viewModel.pods.last?.id {
                                    viewModel.loadMore()
                                }
                            }
                        }
                        
                        // Loading more indicator at bottom
                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding()
                                Spacer()
                            }
                        }
                        
                        // End of results indicator
                        if !viewModel.hasMore && !viewModel.pods.isEmpty {
                            Text("No more pods to load")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
            }
        }
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.loadPods(for: category)
        }
        .onAppear {
            if viewModel.pods.isEmpty {
                viewModel.loadPods(for: category)
            }
        }
    }
}

#Preview {
    NavigationView {
        CategoryDetailView(category: .music)
    }
}
