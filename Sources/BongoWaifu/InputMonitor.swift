import AppKit
import ApplicationServices
import WaifuCore

/// Global keyboard and mouse listener. Only the *kind* of key is reported; characters are never read.
@MainActor
final class InputMonitor {
    var onKey: ((KeyKind, Bool) -> Void)?
    var onClick: (() -> Void)?
    var onTrustChanged: ((Bool) -> Void)?

    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private var trustTimer: Timer?

    var isTrusted: Bool { AXIsProcessTrusted() }

    func start() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.onClick?() }
        }
        if isTrusted {
            installKeyMonitor()
        } else {
            waitForTrust()
        }
    }

    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        waitForTrust()
    }

    private func waitForTrust() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.isTrusted else { return }
                timer.invalidate()
                self.trustTimer = nil
                self.installKeyMonitor()
                self.onTrustChanged?(true)
            }
        }
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let kind = Self.kind(forKeyCode: event.keyCode)
            let isRepeat = event.isARepeat
            MainActor.assumeIsolated { self?.onKey?(kind, isRepeat) }
        }
    }

    nonisolated static func kind(forKeyCode code: UInt16) -> KeyKind {
        switch code {
        case 51, 117: return .backspace // delete, forward delete
        case 36, 76: return .enter      // return, keypad enter
        default: return .normal
        }
    }
}
