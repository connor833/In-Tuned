//
//  ContentView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/31/23.
//

import SwiftUI

struct ContentView: View {
    @State private var showMenu = false
    @State var isActive: Bool = false
    @StateObject private var mediaBarManager = MediaBarManager.shared
    @StateObject private var playerManager = PlayerManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                SplashView()
                    .navigationBarTitleDisplayMode(.inline)
                
                // MediaBar positioned above tab bar - only show when content is playing
                VStack {
                    Spacer()
                    
                    if mediaBarManager.isVisible && playerManager.currentPod != nil {
                        MediaBar()
                            .padding(.bottom, 60) // Position above tab bar with extra space for enhanced styling
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .zIndex(1000)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
