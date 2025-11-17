//
//  UserSavedPodsView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI

struct UserSavedPodsView: View {
    let user: User
    @EnvironmentObject var userViewModel: UserViewModel
    @Environment(\.presentationMode) var mode
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Button {
                    mode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Color("textColor"))
                        .font(.title2)
                }
                
                Spacer()
                
                Text("Saved Pods")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Empty space for balance
                Image(systemName: "chevron.left")
                    .foregroundColor(.clear)
                    .font(.title2)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Content
            if userViewModel.shouldShowNoSavedPodsMessage {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "archivebox")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No saved pods yet")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Save pods you like to find them later")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(userViewModel.savedPods) { pod in
                            if pod.isDeleted == true {
                                DeletedPodRowView(pod: pod) {
                                    if let podId = pod.id {
                                        userViewModel.removeOrphanedSavedPod(podId: podId)
                                    }
                                }
                                .onAppear {
                                    // Trigger pagination when reaching the last item
                                    if pod == userViewModel.savedPods.last && userViewModel.hasMoreSavedPods && !userViewModel.isFetchingSavedPods {
                                        userViewModel.fetchNextPageOfSavedPods()
                                    }
                                }
                            } else {
                                PodRowViewThin(pod: pod)
                                    .onAppear {
                                        // Trigger pagination when reaching the last item
                                        if pod == userViewModel.savedPods.last && userViewModel.hasMoreSavedPods && !userViewModel.isFetchingSavedPods {
                                            userViewModel.fetchNextPageOfSavedPods()
                                        }
                                    }
                            }
                        }
                        
                        // Loading indicator for saved pod pagination
                        if userViewModel.isFetchingSavedPods && userViewModel.hasMoreSavedPods {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading more saved pods...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                        }
                        
                        // End of content indicator for saved pods
                        if !userViewModel.hasMoreSavedPods && !userViewModel.savedPods.isEmpty {
                            Text("No more saved pods to load")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
                .refreshable {
                    userViewModel.refreshSavedPods()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Ensure the singleton is set up with the correct user
            userViewModel.setup(user: user)
        }
    }
}

struct UserSavedPodsView_Previews: PreviewProvider {
    static var previews: some View {
        UserSavedPodsView(user: PreviewClass().previewUser)
    }
} 