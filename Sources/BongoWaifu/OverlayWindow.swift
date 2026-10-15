import AppKit
import SwiftUI

/// Borderless, transparent, always-on-top panel that never steals focus.
final class OverlayPanel: NSPanel {
    init(size: CGSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that handles drag-to-move, click-to-pet and right-click menu itself,
/// so SwiftUI content never needs to be interactive.
final class CompanionHostingView: NSHostingView<CompanionView> {
    var onClick: ((CGPoint) -> Void)?
    var onDragEnd: (() -> Void)?
    var menuProvider: (() -> NSMenu)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let startMouse = NSEvent.mouseLocation
        let startOrigin = window.frame.origin
        var moved = false
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type != .leftMouseUp {
            let mouse = NSEvent.mouseLocation
            let dx = mouse.x - startMouse.x
            let dy = mouse.y - startMouse.y
            if !moved && hypot(dx, dy) < 3 { continue }
            moved = true
            window.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
        }
        if moved {
            onDragEnd?()
        } else {
            onClick?(convert(event.locationInWindow, from: nil))
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
}

/// Owns the panel: placement, resizing, and toggling mouse pass-through.
@MainActor
final class OverlayController {
    let panel: OverlayPanel
    let hostingView: CompanionHostingView
    private let model: CompanionModel
    private let settings: Settings
    private var hoverTimer: Timer?

    var clickThrough: Bool {
        didSet {
            settings.clickThrough = clickThrough
            updateMousePassThrough()
        }
    }

    init(model: CompanionModel, settings: Settings) {
        self.model = model
        self.settings = settings
        self.clickThrough = settings.clickThrough
        let size = CompanionLayout.windowSize(scale: model.size.scale)
        panel = OverlayPanel(size: size)
        hostingView = CompanionHostingView(rootView: CompanionView(model: model))
        hostingView.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hostingView

        hostingView.onDragEnd = { [weak self] in self?.savePosition() }
        hostingView.onClick = { [weak self] point in self?.handleClick(at: point) }

        if let origin = settings.windowOrigin, NSScreen.screens.contains(where: { $0.frame.contains(origin) }) {
            panel.setFrameOrigin(origin)
        } else {
            resetPosition()
        }

        // Only intercept the mouse while it's over the character or her bubble,
        // so the transparent parts of the window never block clicks.
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateMousePassThrough() }
        }
    }

    func show() { panel.orderFrontRegardless() }
    func hide() { panel.orderOut(nil) }
    var isVisible: Bool { panel.isVisible }

    func resetPosition() {
        guard let screen = NSScreen.main else { return }
        let size = panel.frame.size
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - 24, y: visible.minY))
        savePosition()
    }

    func applySize() {
        let size = CompanionLayout.windowSize(scale: model.size.scale)
        var frame = panel.frame
        // Keep the bottom-center anchored so she stays on the same spot of the desk.
        frame.origin.x += (frame.width - size.width) / 2
        frame.size = size
        panel.setFrame(frame, display: true)
        hostingView.frame = NSRect(origin: .zero, size: size)
        savePosition()
    }

    private func savePosition() {
        settings.windowOrigin = panel.frame.origin
    }

    /// Feed the cursor position to the rig so her head and eyes follow it.
    private func updateGaze() {
        let s = model.size.scale
        let frame = panel.frame
        let head = CGPoint(x: frame.midX, y: frame.minY + (CompanionLayout.character - 100) * s)
        let mouse = NSEvent.mouseLocation
        model.rig.gaze = CGPoint(x: (mouse.x - head.x) / 450, y: -(mouse.y - head.y) / 450)
    }

    private func handleClick(at point: CGPoint) {
        let s = model.size.scale
        if point.y > CompanionLayout.character * s {
            model.dismissBubble()
        } else {
            model.petted()
        }
    }

    private func updateMousePassThrough() {
        updateGaze()
        if clickThrough {
            panel.ignoresMouseEvents = true
            return
        }
        let s = model.size.scale
        let mouse = panel.convertPoint(fromScreen: NSEvent.mouseLocation)
        let characterBox = CGRect(x: (CompanionLayout.width - CompanionLayout.character) / 2 * s, y: 0,
                                  width: CompanionLayout.character * s, height: (CompanionLayout.character - 20) * s)
        let bubbleBox = CGRect(x: 0, y: CompanionLayout.character * s,
                               width: CompanionLayout.width * s, height: CompanionLayout.bubbleArea * s)
        let over = characterBox.contains(mouse) || (model.bubble != nil && bubbleBox.contains(mouse))
        if panel.ignoresMouseEvents == over { panel.ignoresMouseEvents = !over }
    }
}
