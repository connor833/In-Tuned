//
//  MoodDetailView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct MoodDetailView: View {
    let mood: PodMood
    @StateObject private var viewModel = ExploreSectionViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Mood header
                VStack(spacing: 12) {
                    Text(mood.emoji)
                        .font(.system(size: 60))
                    
                    Text(mood.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(mood.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                
                // Pods list
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.pods.isEmpty {
                        // Loading state
                        VStack(spacing: 16) {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Finding pods for your mood...")
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
                            Text(mood.emoji)
                                .font(.system(size: 50))
                            
                            Text("No pods match this mood yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Check back later for new content")
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
        .navigationTitle(mood.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            viewModel.loadPods(for: mood)
        }
        .onAppear {
            if viewModel.pods.isEmpty {
                viewModel.loadPods(for: mood)
            }
        }
    }
}
