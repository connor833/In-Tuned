import SwiftUI

class MediaBarManager: ObservableObject {
    static let shared = MediaBarManager()
    
    @Published var isVisible = false
    @Published var shouldShowPlayerView = false
    @Published var isAnimating = false
    @Published var animationOffset: CGFloat = 100 // Start off-screen
    
    private init() {}
    
    func hide() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
            animationOffset = 100
        }
    }
    
    func show() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = true
            animationOffset = 0
        }
    }
    
    func requestPlayerView() {
        withAnimation(.easeInOut(duration: 0.2)) {
            shouldShowPlayerView = true
        }
    }
    
    func dismissPlayerView() {
        withAnimation(.easeInOut(duration: 0.2)) {
            shouldShowPlayerView = false
        }
    }
    
    func animateIn() {
        isAnimating = true
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
            isVisible = true
            animationOffset = 0
        }
        
        // Reset animation state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isAnimating = false
        }
    }
    
    func animateOut() {
        isAnimating = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0)) {
            isVisible = false
            animationOffset = 100
        }
        
        // Reset animation state after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.isAnimating = false
        }
    }
}
