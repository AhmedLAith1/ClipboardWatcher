//
//  AppDelegate.swift
//  ClipboardWatcher
//
//  Created by Ahmed Laith on 19/07/2025.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var clipboardWatcher: ClipboardWatcher!
    var menu: NSMenu!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.prohibited)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
        }

        menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")) // Placeholder
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu

        clipboardWatcher = ClipboardWatcher()

        // Update menu when clipboard changes
        clipboardWatcher.onUpdate = { [weak self] history in
            self?.reloadClipboardMenu(history)
        }
    }

    func reloadClipboardMenu(_ history: [String]) {
        menu.removeAllItems()

        if history.isEmpty {
            menu.addItem(NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: ""))
        } else {
            for item in history.prefix(80) {
                let shortened = item.prefix(40).replacingOccurrences(of: "\n", with: " ")
                let menuItem = NSMenuItem(title: String(shortened), action: #selector(copyFromHistory), keyEquivalent: "")
                menuItem.representedObject = item
                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }

    @objc func copyFromHistory(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else { return }

        let pb = NSPasteboard.general
        let current = pb.string(forType: .string)

        if current == text {
            print("⚠️ Skipped: same as current clipboard")
            return
        }

        pb.clearContents()
        pb.setString(text, forType: .string)
        clipboardWatcher.skipNextChange = true
        print("🔁 Re-copied: \(text)")
    }
    
    


    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}

