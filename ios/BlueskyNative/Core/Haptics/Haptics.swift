import SwiftUI
import UIKit

/// `playHaptic` strength (`src/lib/haptics.ts:11-21`). On iOS RN maps each to
/// `ImpactFeedbackStyle[strength]`; the default is Medium.
enum HapticStrength: Sendable {
    case light, medium, heavy
}

/// Plays haptics. Views use it through the environment; tests use a recording fake.
protocol HapticsPlaying: Sendable {
    @MainActor func play(_ strength: HapticStrength)
}

/// Live haptics. RN's `disableHaptics` preference defaults to false and this slice has no
/// settings screen, so haptics are always on.
struct ImpactHaptics: HapticsPlaying {
    @MainActor
    func play(_ strength: HapticStrength) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = switch strength {
        case .light: .light
        case .medium: .medium
        case .heavy: .heavy
        }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

extension EnvironmentValues {
    @Entry var haptics: any HapticsPlaying = ImpactHaptics()
}
