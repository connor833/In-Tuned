import UIKit

/// Haptic feedback manager for providing tactile responses to user interactions
public class HapticManager {
    public static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - Haptic Feedback Types
    
    /// Light impact feedback - perfect for likes, saves, and button taps
    public func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    /// Medium impact feedback - for more significant interactions
    public func mediumImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    /// Heavy impact feedback - for major actions
    public func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
    
    /// Success feedback - for successful actions
    public func success() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.success)
    }
    
    /// Warning feedback - for warnings
    public func warning() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    /// Error feedback - for errors
    public func error() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.prepare()
        notificationFeedback.notificationOccurred(.error)
    }
    
    /// Selection feedback - for selection changes
    public func selection() {
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.prepare()
        selectionFeedback.selectionChanged()
    }
}
