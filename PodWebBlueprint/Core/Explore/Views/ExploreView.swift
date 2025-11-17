//
//  ExploreView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 10/3/25.
//

import SwiftUI

struct ExploreView: View {
    @StateObject private var viewModel: ExploreViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Navigation state
    @State private var navigateToTrending = false
    @State private var navigateToNew = false
    @State private var navigateToTopCharts = false
    @State private var navigateToFeatured = false
    
    init(user: User? = nil) {
        _viewModel = StateObject(wrappedValue: ExploreViewModel(currentUser: user))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - Category Chips Section
                CategoryChipsView()
                
                Divider()
                    .padding(.horizontal, 20)
                
                // MARK: - Trending Now Section
                ZStack {
                    NavigationLink(
                        destination: ExploreSectionDetailView(section: .trending),
                        isActive: $navigateToTrending
                    ) {
                        EmptyView()
                    }
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .allowsHitTesting(false)
                    
                    SectionPreviewView(
                        title: "Trending Now",
                        icon: "flame.fill",
                        color: .orange,
                        pods: viewModel.trendingPods,
                        seeAllAction: {
                            navigateToTrending = true
                        }
                    )
                }
                
                // MARK: - New & Noteworthy Section
                ZStack {
                    NavigationLink(
                        destination: ExploreSectionDetailView(section: .newAndNoteworthy),
                        isActive: $navigateToNew
                    ) {
                        EmptyView()
                    }
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .allowsHitTesting(false)
                    
                    SectionPreviewView(
                        title: "New & Noteworthy",
                        icon: "sparkles",
                        color: .purple,
                        pods: viewModel.newPods,
                        seeAllAction: {
                            navigateToNew = true
                        }
                    )
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // MARK: - Top Charts Section
                ZStack {
                    NavigationLink(
                        destination: ExploreSectionDetailView(section: .topCharts),
                        isActive: $navigateToTopCharts
                    ) {
                        EmptyView()
                    }
                    .frame(width: 0, height: 0)
                    .opacity(0)
                    .allowsHitTesting(false)
                    
                    TopChartsPreviewView(
                        pods: viewModel.topChartsPods,
                        seeAllAction: {
                            navigateToTopCharts = true
                        }
                    )
                }
                
                Divider()
                    .padding(.horizontal, 20)
                
                // MARK: - Featured Section
                if !viewModel.featuredPods.isEmpty {
                    ZStack {
                        NavigationLink(
                            destination: ExploreSectionDetailView(section: .featured),
                            isActive: $navigateToFeatured
                        ) {
                            EmptyView()
                        }
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        .allowsHitTesting(false)
                        
                        SectionPreviewView(
                            title: "Featured",
                            icon: "star.fill",
                            color: .yellow,
                            pods: viewModel.featuredPods,
                            seeAllAction: {
                                navigateToFeatured = true
                            }
                        )
                    }
                    
                    Divider()
                        .padding(.horizontal, 20)
                }
                
                // MARK: - Browse by Mood Section
                MoodSelectorView()
                
                // Bottom spacing
                Spacer(minLength: 40)
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            viewModel.refresh()
        }
        .onAppear {
            if viewModel.trendingPods.isEmpty {
                viewModel.loadExploreHome()
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.trendingPods.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading explore content...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.9))
            }
        }
    }
}

#Preview {
    ExploreView()
        .environmentObject(AuthViewModel.shared)
}
