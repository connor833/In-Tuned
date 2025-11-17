//
//  ExploreSectionDetailView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct ExploreSectionDetailView: View {
    let section: ExploreSection
    @StateObject private var viewModel = ExploreSectionViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.isLoading && viewModel.pods.isEmpty {
                    // Loading state
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading \(section.rawValue.lowercased())...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    
                } else if viewModel.pods.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: section.icon)
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        
                        Text("No pods found")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Check back later for new content")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 400)
                    
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
                    }
                }
            }
        }
        .navigationTitle(section.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            viewModel.loadPods(for: section)
        }
        .onAppear {
            if viewModel.pods.isEmpty {
                viewModel.loadPods(for: section)
            }
        }
    }
}

#Preview {
    NavigationView {
        ExploreSectionDetailView(section: .trending)
    }
}
