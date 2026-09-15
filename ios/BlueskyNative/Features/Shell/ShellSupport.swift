import Foundation
import Observation
import SwiftUI

/// Port of `TickEveryMinuteProvider` (`src/state/shell/tick-every-minute.tsx:9-15`): one clock
/// value, set at mount and every 60 seconds after. Relative times use this value as "now".
@MainActor
@Observable
final class MinuteTicker {
    private(set) var now: Date
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private let clock: @Sendable () -> Date

    init(clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
        now = clock()
    }

    func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, !Task.isCancelled else { return }
                self.now = self.clock()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}

/// A short message shown at the bottom of the screen (RN `Toast.show`).
struct ToastMessage: Identifiable, Equatable {
    enum Kind { case `default`, warning }

    let id = UUID()
    var text: String
    var kind: Kind = .default
}

/// Shell-level UI state that screens can change.
@MainActor
@Observable
final class ShellState {
    /// Title of a feature that is not ported, shown in a sheet.
    var notInShowcase: NotInShowcaseItem?
    var toast: ToastMessage?
    /// A link waiting for the RN link warning dialog.
    var linkWarning: PendingLink?
    /// A link waiting for the RN in-app browser consent dialog.
    var linkConsent: PendingLink?
    /// A URL for the system share sheet (RN `shareUrl`).
    var shareURL: IdentifiedURL?

    func showToast(_ text: String, kind: ToastMessage.Kind = .default) {
        toast = ToastMessage(text: text, kind: kind)
    }
}

struct NotInShowcaseItem: Identifiable, Hashable {
    var title: String
    var id: String { title }
}

struct PendingLink: Identifiable, Hashable {
    var uri: String
    var displayText: String
    /// True when the warning was opened by a long press: its button shares instead of opening
    /// (`LinkWarning.tsx:65-66,112`).
    var share = false
    var id: String { uri + "|" + displayText + (share ? "|share" : "") }
}

/// Faults the E2E build can inject so that Maestro can capture error states.
///
/// RN has no equivalent control, so these states are captured on the native build only;
/// PARITY.md records that. Only the `E2E` compilation condition (Debug) compiles the storage
/// and `arm`; in Release `consume` is a constant false (review finding A52).
@MainActor
@Observable
final class DebugFaults {
    enum Fault: Hashable {
        /// The next first-page load of a feed.
        case feedFirstPage
        /// The next `loadMore` page.
        case feedNextPage
        /// The next reload that starts with rows on screen (refresh, soft reset).
        case feedRefresh
        case thread
        case profile
    }

    #if E2E
    @ObservationIgnored private var armed: Set<Fault> = []

    func arm(_ fault: Fault) {
        armed.insert(fault)
    }

    /// Returns true once per `arm`.
    func consume(_ fault: Fault) -> Bool {
        armed.remove(fault) != nil
    }
    #else
    @inline(__always)
    func consume(_ fault: Fault) -> Bool { false }
    #endif
}

struct InjectedFault: LocalizedError {
    var errorDescription: String? { "Network request failed" }
}

/// Bottom toast, after RN `Toast` (`src/view/com/util/Toast.tsx`).
struct ToastView: View {
    var message: ToastMessage
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Space.sm) {
            if message.kind == .warning {
                Icon(.warning, size: IconSize.md, color: theme.palette.contrast0)
            }
            Text(message.text)
                .textStyle(size: FontSize.md, weight: FontWeight.medium, leading: Leading.snug)
                .foregroundStyle(theme.palette.contrast0)
        }
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .background(theme.palette.contrast900, in: RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Space.lg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
