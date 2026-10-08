import SwiftUI
import AppKit
import UserNotifications

@main
struct LogsManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = LogStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var monitor = BackgroundMonitor()
    @StateObject private var logExplanation = LogExplanationPresenter()

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(monitor)
                .environmentObject(logExplanation)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button(L10n.ru("Обновить логи", en: "Refresh Logs")) {
                    store.refresh(windowMinutes: settings.windowMinutes)
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.isLoading)
            }
        }

        MenuBarExtra {
            StatusMenuView()
                .environmentObject(settings)
                .environmentObject(monitor)
        } label: {
            Image(nsImage: JournalIcon.templateImage())
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shouldTerminateOnQuit = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        SystemLoadHistoryStore.shared.start()

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            let hasVisibleWindow = NSApp.windows.contains { $0.isVisible }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
            Task { @MainActor in
                AppActivityState.shared.refresh()
            }
        }

        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = roundedDockIcon(from: icon)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.shouldTerminateOnQuit {
            return .terminateNow
        }

        for window in sender.windows {
            window.close()
        }
        sender.setActivationPolicy(.accessory)
        AppActivityState.shared.refresh()
        return .terminateCancel
    }

    private func roundedDockIcon(from source: NSImage) -> NSImage {
        let size = NSSize(width: 128, height: 128)
        let rounded = NSImage(size: size)
        rounded.lockFocus()

        let margin = size.width * 0.10
        let iconRect = NSRect(
            x: margin,
            y: margin,
            width: size.width - margin * 2,
            height: size.height - margin * 2
        )
        let cornerRadius = iconRect.width * 0.225
        let path = NSBezierPath(
            roundedRect: iconRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        source.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.restoreGraphicsState()

        rounded.unlockFocus()
        return rounded
    }
}
