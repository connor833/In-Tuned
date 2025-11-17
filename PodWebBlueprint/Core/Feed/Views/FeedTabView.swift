//
//  FeedTabView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Firebase

struct FeedTabView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @State private var selectedFilter: FeedFilterViewModel = .foryou
    @Namespace var animation
    
    var body: some View {
        VStack {
            HStack {
                FeedFilterBar.padding()

                NavigationLink {
                    if let user = feedViewModel.currentUser {
                        SearchView(user: user)
                    } else {
                        Text("Loading...")
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .fontWeight(.bold)
                        .padding(.vertical, -16)
                        .padding()
                }
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if selectedFilter == .following {
                        if feedViewModel.isFetchingFollowItems {
                            // Show clean loading state while fetching
                            VStack(spacing: 20) {
                                Spacer()
                                
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                    .scaleEffect(1.5)
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else if feedViewModel.followedItems.isEmpty {
                            // Only show "no content" if we're not fetching and there's truly no content
                            VStack(spacing: 20) {
                                Spacer()
                                
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                
                                Text("No content to show")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Follow some users to see their pods here")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                
                                NavigationLink {
                                    if let user = feedViewModel.currentUser {
                                        SearchView(user: user)
                                    } else {
                                        Text("Loading...")
                                    }
                                } label: {
                                    Text("Discover Users")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color("accentColor"))
                                        .cornerRadius(8)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding()
                        } else {
                            ForEach(Array(feedViewModel.followedItems.enumerated()), id: \.element.id) { index, item in
                                // Display either PodRowView or RepostRowView based on item type
                                if item.isRepost {
                                    RepostRowView(repost: item.repostData!)
                                        .onAppear {
                                            // Load next page when approaching the end
                                            if index == feedViewModel.followedItems.count - 1 {
                                                feedViewModel.fetchNextPageOfFollowItems()
                                            }
                                        }
                                } else {
                                    PodRowView(pod: item.pod)
                                        .onAppear {
                                            // Load next page when approaching the end
                                            if index == feedViewModel.followedItems.count - 1 {
                                                feedViewModel.fetchNextPageOfFollowItems()
                                            }
                                        }
                                }
                            }
                            
                            // Loading indicator for follow items
                            if feedViewModel.isFetchingFollowItems && feedViewModel.hasMoreFollowItems {
                                ProgressView()
                                    .padding(.top)
                            } else if !feedViewModel.hasMoreFollowItems && !feedViewModel.followedItems.isEmpty {
                                Text("No more posts to load")
                                    .padding(.top)
                            }
                        }
                    } else if selectedFilter == .foryou {
                        ForEach(feedViewModel.pods.indices, id: \.self) { index in
                            PodRowView(pod: feedViewModel.pods[index])
                                .onAppear {
                                    // Trigger pagination when reaching the 3rd-to-last item for smoother loading
                                    if index >= feedViewModel.pods.count - 3 && 
                                       feedViewModel.hasMorePods && 
                                       !feedViewModel.isFetching {
                                        feedViewModel.fetchNextPageOfPods()
                                    }
                                }
                        }

                        // Show loading indicator at the bottom
                        if feedViewModel.isFetching && feedViewModel.hasMorePods {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading more...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                        } else if !feedViewModel.hasMorePods && !feedViewModel.pods.isEmpty {
                            Text("No more posts to load")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 16)
                        }
                    }
                }
            }
            .refreshable {
                if selectedFilter == .following {
                    feedViewModel.refreshFollowItems()
                } else {
                    feedViewModel.refreshForYouFeed()
                }
            }
        }
        .onAppear {
            // Load both tabs' data immediately for better UX - behave identically
            if feedViewModel.pods.isEmpty {
                feedViewModel.fetchFirstPageOfPods()
            }
            
            // Always refresh following items when returning to feed tab (like for you pods)
            feedViewModel.checkAndRefreshFollowItemsIfNeeded()
            
            // Start real-time listener for follow items if not already active
            if selectedFilter == .following {
                feedViewModel.startFollowItemsListener()
            }
        }
        .onChange(of: selectedFilter) { newValue in
            if newValue == .following {
                // Use caching method instead of direct fetch
                feedViewModel.checkAndRefreshFollowItemsIfNeeded()
                // Start real-time listener when switching to following
                feedViewModel.startFollowItemsListener()
            } else {
                // Stop real-time listener when switching away from following
                feedViewModel.stopFollowItemsListener()
            }
        }
        .onDisappear {
            // Only stop listener when navigating away from following tab
            if selectedFilter == .following {
                feedViewModel.stopFollowItemsListener()
            }
        }
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    handleSwipe(translation: gesture.translation.width)
                }
        )
    }

    private func handleSwipe(translation: CGFloat) {
        let minDragTranslationForSwipe: CGFloat = 50
        if translation > minDragTranslationForSwipe {
            withAnimation {
                selectedFilter = .following
            }
        } else if translation < -minDragTranslationForSwipe {
            withAnimation {
                selectedFilter = .foryou
            }
        }
    }

    var FeedFilterBar: some View {
        HStack(spacing: 0) {
            ForEach(FeedFilterViewModel.allCases, id: \.rawValue) { item in
                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3)) {
                        selectedFilter = item
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 16, weight: selectedFilter == item ? .semibold : .medium))
                        .foregroundColor(selectedFilter == item ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(
            ZStack {
                // Background container
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: 12,
                        x: 0,
                        y: 4
                    )
                
                // Animated selection indicator
                HStack(spacing: 0) {
                    ForEach(FeedFilterViewModel.allCases, id: \.rawValue) { item in
                        if selectedFilter == item {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color("accentColor").opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                                .matchedGeometryEffect(id: "selectedTab", in: animation)
                        } else {
                            Color.clear
                        }
                    }
                }
                .padding(4)
            }
        )
    }
}
