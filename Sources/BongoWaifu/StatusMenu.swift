import AppKit
import ServiceManagement
import WaifuCore

/// NSMenuItem that runs a closure.
private final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool = false, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
        state = checked ? .on : .off
    }

    required init(coder: NSCoder) { fatalError() }

    @objc private func run() { handler() }
}

/// Menu-bar item; the same menu is shown when right-clicking the character.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let model: CompanionModel
    private let store: CharacterStore
    private let overlay: OverlayController
    private let input: InputMonitor

    init(model: CompanionModel, store: CharacterStore, overlay: OverlayController, input: InputMonitor) {
        self.model = model
        self.store = store
        self.overlay = overlay
        self.input = input
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Bongo Waifu")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for item in buildItems() { menu.addItem(item) }
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        for item in buildItems() { menu.addItem(item) }
        return menu
    }

    private func buildItems() -> [NSMenuItem] {
        var items: [NSMenuItem] = []
        let header = NSMenuItem(title: "Bongo Waifu — \(model.character.name)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        items.append(header)
        let stats = NSMenuItem(
            title: "Today \(model.todayKeys.formatted()) keys · Total \(model.totalKeys.formatted()) · \(model.currentWPM) WPM",
            action: nil, keyEquivalent: "")
        stats.isEnabled = false
        items.append(stats)

        if !input.isTrusted {
            items.append(.separator())
            items.append(ActionItem("⚠️ Grant Accessibility Access to React to Typing…") { [input] in input.requestAccess() })
        }

        items.append(.separator())
        items.append(submenu("Character", store.characters.map { c in
            ActionItem("\(c.name) — \(c.tagline)", checked: c.id == model.character.id) { [model] in model.setCharacter(c) }
        }))
        items.append(submenu("Size", CompanionSize.allCases.map { size in
            ActionItem(size.label, checked: size == model.size) { [model, overlay] in
                model.size = size
                overlay.applySize()
            }
        }))
        items.append(submenu("Chattiness", Chattiness.allCases.map { level in
            ActionItem(level.label, checked: level == model.chattiness) { [model] in model.chattiness = level }
        }))
        items.append(ActionItem("Fun Facts", checked: model.funFacts) { [model] in model.funFacts.toggle() })
        items.append(ActionItem("Click-Through (can't drag or pet)", checked: overlay.clickThrough) { [overlay] in
            overlay.clickThrough.toggle()
        })

        items.append(.separator())
        items.append(ActionItem(overlay.isVisible ? "Hide Waifu" : "Show Waifu", key: "h") { [overlay] in
            overlay.isVisible ? overlay.hide() : overlay.show()
        })
        items.append(ActionItem("Reset Position") { [overlay] in overlay.resetPosition() })

        items.append(.separator())
        items.append(ActionItem("Open Characters Folder…") {
            NSWorkspace.shared.open(CharacterStore.packsDirectory)
        })
        items.append(ActionItem("Reload Characters") { [weak self] in self?.reloadCharacters() })

        items.append(.separator())
        let loginEnabled = SMAppService.mainApp.status == .enabled
        items.append(ActionItem("Launch at Login", checked: loginEnabled) {
            do {
                if loginEnabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
            } catch {
                Self.alert("Couldn't change login item", error.localizedDescription)
            }
        })
        items.append(ActionItem("Quit Bongo Waifu", key: "q") { NSApp.terminate(nil) })
        return items
    }

    private func submenu(_ title: String, _ children: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu()
        for child in children { menu.addItem(child) }
        item.submenu = menu
        return item
    }

    private func reloadCharacters() {
        store.reload()
        model.setCharacter(store.character(id: model.character.id))
        if !store.loadErrors.isEmpty {
            Self.alert("Some character packs couldn't be loaded", store.loadErrors.joined(separator: "\n"))
        }
    }

    private static func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
