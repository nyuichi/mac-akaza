import Cocoa

class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let tabView = NSTabView()

        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = "一般"
        generalTab.view = GeneralSettingsView()
        tabView.addTabViewItem(generalTab)

        let dictTab = NSTabViewItem(identifier: "userdict")
        dictTab.label = "ユーザー辞書"
        dictTab.view = UserDictionaryView()
        tabView.addTabViewItem(dictTab)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Akaza 設定"
        window.contentView = tabView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}
