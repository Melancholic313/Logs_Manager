import Foundation
import AppKit
import Combine

@MainActor
final class AppActivityState: ObservableObject {
    static let shared = AppActivityState()

    @Published private(set) var hasVisibleWindow = true
    @Published private(set) var isLowPriority = false

    func refresh() {
        let visible = NSApp.windows.contains { $0.isVisible }
        hasVisibleWindow = visible
        isLowPriority = !visible
    }
}
