//
//  AppDelegate.swift
//  ClipboardWatcher
//
//  Created by Ahmed Laith on 19/07/2025.
//

import Cocoa

class HoverableLabel: NSTextField {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { self.removeTrackingArea($0) }

        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }

    override func mouseEntered(with event: NSEvent) {
        if let text = self.stringValue as String? {
            (NSApp.delegate as? AppDelegate)?.showPopover(for: self, with: text)
        }
    }

    override func mouseExited(with event: NSEvent) {
        (NSApp.delegate as? AppDelegate)?.popover.performClose(nil)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var clipboardWatcher: ClipboardWatcher!
    var statusMenu: NSMenu!
    var popover = NSPopover()
    var lastHistory: [String] = []
    var trackingTimer: Timer?
    func makeCustomMenuItem(title: String, representedObject: Any, isImage: Bool) -> NSMenuItem {
        let menuItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 24))

        let shortTitle = title.count > 100 ? String(title.prefix(100)) + "..." : title
        let label = NSTextField(labelWithString: shortTitle)
        label.frame = NSRect(x: 8, y: 4, width: 200, height: 16)
        label.isEditable = false
        label.drawsBackground = false
        label.isBordered = false
        label.lineBreakMode = .byTruncatingTail
        label.toolTip = title
        label.setAccessibilityIdentifier(title) // ✅ النص الكامل للنسخ
        label.isSelectable = false
        label.wantsLayer = true

        let gesture = NSClickGestureRecognizer(target: self, action: #selector(copyFromLabel(_:)))
        label.addGestureRecognizer(gesture)

        let deleteButton = CustomButton(title: "🗑", target: self, action: #selector(deleteItemFromHistory))
        deleteButton.frame = NSRect(x: 230, y: 2, width: 24, height: 20)
        deleteButton.isBordered = false
        deleteButton.representedObject = representedObject

        if isImage, let fileURL = representedObject as? URL,
           let img = NSImage(contentsOf: fileURL) {
            let imgView = NSImageView(image: img)
            imgView.frame = NSRect(x: 8, y: 4, width: 20, height: 16)
            container.addSubview(imgView)
            label.frame.origin.x = 32
        }

        label.identifier = NSUserInterfaceItemIdentifier(rawValue: title)
        label.tag = isImage ? 1 : 0

        container.addSubview(label)
        container.addSubview(deleteButton)
        menuItem.view = container

        return menuItem
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.prohibited)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard")
            button.image?.isTemplate = true
            button.action = #selector(toggleMenu)
            button.target = self
        }

        statusMenu = NSMenu()
        clipboardWatcher = ClipboardWatcher()

        clipboardWatcher.onUpdate = { [weak self] history in
            guard history != self?.lastHistory else { return }
            self?.lastHistory = history

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.reloadClipboardMenu(history)
            }
        }

        reloadClipboardMenu(clipboardWatcher.history)
    }

    @objc func toggleMenu() {
        if let button = statusItem.button {
            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            startHoverTimer()
        }
    }

    func startHoverTimer() {
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(checkMouseHover), userInfo: nil, repeats: true)
    }

    @objc func checkMouseHover() {
        guard let menuWindow = NSApp.windows.first(where: { String(describing: type(of: $0)).contains("NSMenuWindow") }) else { return }

        let mouseLocation = NSEvent.mouseLocation
        let localPoint = menuWindow.convertPoint(fromScreen: mouseLocation)

        for item in statusMenu.items {
            guard let container = item.view else { continue }

            let windowPoint = container.convert(localPoint, from: nil)
            if container.bounds.contains(windowPoint),
               let label = container.subviews.compactMap({ $0 as? NSTextField }).first {
                showPopover(for: label, with: label.stringValue)
                return
            }
        }

        popover.performClose(nil)
    }

    func showPopover(for view: NSView, with text: String) {
        let vc = NSViewController()
        let textField = NSTextField(labelWithString: text)
        textField.lineBreakMode = .byWordWrapping
        textField.preferredMaxLayoutWidth = 300
        textField.frame = NSRect(x: 10, y: 10, width: 280, height: 40)

        vc.view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        vc.view.addSubview(textField)

        popover.contentViewController = vc
        popover.behavior = .transient
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .maxX)
    }

    @objc func copyFromLabel(_ sender: NSClickGestureRecognizer) {
        guard let label = sender.view as? NSTextField else { return }

        let text = label.accessibilityIdentifier() ?? label.stringValue
        let pb = NSPasteboard.general
        pb.clearContents()

        if label.tag == 1 {
            let filename = text
            let fileURL = clipboardWatcher.getImageSaveFolder().appendingPathComponent(filename)
            if let image = NSImage(contentsOf: fileURL) {
                pb.writeObjects([image])
                clipboardWatcher.skipNextChange = true
                print("✅ Copied image from label:", filename)
            }
        } else {
            pb.setString(text, forType: .string)
            clipboardWatcher.skipNextChange = true
            print("✅ Copied text from label:", text)
        }

        statusMenu.cancelTracking()
    }

    @objc func deleteItemFromHistory(_ sender: NSButton) {
        guard let button = sender as? CustomButton,
              let object = button.representedObject else { return }

        clipboardWatcher.history.removeAll { $0 == (object as? String) || "\($0)" == "\(object)" }

        if let fileURL = object as? URL {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑 Deleted image file:", fileURL.lastPathComponent)
            } catch {
                print("❌ Error deleting image:", error)
            }
        }

        clipboardWatcher.saveHistory()
        reloadClipboardMenu(clipboardWatcher.history)
    }
    func reloadClipboardMenu(_ history: [String]) {
        statusMenu.removeAllItems()

        if history.isEmpty {
            statusMenu.addItem(NSMenuItem(title: "No clipboard history", action: nil, keyEquivalent: ""))
        } else {
            for item in history.prefix(80) {
                if item.hasPrefix("[Image] ") {
                    let filename = item.replacingOccurrences(of: "[Image] ", with: "")
                    let fileURL = clipboardWatcher.getImageSaveFolder().appendingPathComponent(filename)
                    statusMenu.addItem(makeCustomMenuItem(title: filename, representedObject: fileURL, isImage: true))
                } else {
                    statusMenu.addItem(makeCustomMenuItem(title: item, representedObject: item, isImage: false))
                }
            }

            // ✅ زر "حذف الكل"
            let clearAllItem = NSMenuItem(title: "Clear All", action: #selector(clearAllHistory), keyEquivalent: "")
            clearAllItem.target = self
            statusMenu.addItem(NSMenuItem.separator())
            statusMenu.addItem(clearAllItem)
        }

        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    }
    @objc func clearAllHistory() {
        // حذف الملفات (الصور)
        for item in clipboardWatcher.history {
            if item.hasPrefix("[Image] ") {
                let filename = item.replacingOccurrences(of: "[Image] ", with: "")
                let fileURL = clipboardWatcher.getImageSaveFolder().appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        clipboardWatcher.history.removeAll()
        clipboardWatcher.saveHistory()
        reloadClipboardMenu(clipboardWatcher.history)
    }


    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
