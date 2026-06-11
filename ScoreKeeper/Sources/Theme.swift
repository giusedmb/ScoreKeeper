import SwiftUI
import UIKit

extension Color {
    // Apple-inspired Color Palette
    public static let appAccent = Color.blue
    public static let appBackground = Color.black
    public static let cardBackground = Color(white: 0.08)
    public static let cardStroke = Color.white.opacity(0.06)
    
    public static let trophyGold = Color(red: 1.0, green: 0.73, blue: 0.0) // Premium Apple-style Gold
    public static let scorePositive = Color(red: 0.18, green: 0.8, blue: 0.44) // iOS Green
    public static let scoreNegative = Color(red: 1.0, green: 0.23, blue: 0.18) // iOS Red
}

// MARK: - Haptic Utility
public enum HapticFeedbackType: Sendable {
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
}

@MainActor
public func triggerHaptic(_ type: HapticFeedbackType) {
    switch type {
    case .impact(let style):
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    case .notification(let feedbackType):
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(feedbackType)
    }
}

@MainActor
public func triggerRoundWinHaptics() {
    let generator = UINotificationFeedbackGenerator()
    generator.prepare()
    generator.notificationOccurred(.success)
}

@MainActor
public func triggerGameWinHaptics() {
    let medium = UIImpactFeedbackGenerator(style: .medium)
    let heavy = UIImpactFeedbackGenerator(style: .heavy)
    
    medium.prepare()
    heavy.prepare()
    
    // Tap...
    medium.impactOccurred()
    
    // Tap...
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        medium.impactOccurred()
    }
    // Tap...
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
        medium.impactOccurred()
    }
    // BOOM!
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
        heavy.impactOccurred()
    }
}
