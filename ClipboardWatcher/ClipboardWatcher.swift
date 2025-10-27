//
//  ClipboardWatcher.swift
//  ClipboardWatcher
//
//  Created by Ahmed Laith on 19/07/2025.
//

import Cocoa

class ClipboardWatcher {
    private var changeCount = NSPasteboard.general.changeCount
    private var timer: Timer?
    var history: [String] = []

    var onUpdate: (([String]) -> Void)?
    var skipNextChange = false

    let maxItems = 80
    let historyKey = "clipboard_history"

    init() {
        loadHistory()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let pb = NSPasteboard.general

            if self.skipNextChange {
                self.skipNextChange = false
                self.changeCount = pb.changeCount
                return
            }

            if pb.changeCount != self.changeCount {
                self.changeCount = pb.changeCount

                // ✅ تحقق إن كانت الصورة موجودة
                if let image = NSImage(pasteboard: pb) {
                    self.handleCopiedImage(image)
                    return
                }

                // ✅ تحقق إن كان نص موجود
                if let copied = pb.string(forType: .string) {
                    if let index = self.history.firstIndex(of: copied) {
                        // ✅ النص موجود مسبقًا → حذفه
                        self.history.remove(at: index)
                    }

                    // ✅ أضفه في الأعلى
                    self.history.insert(copied, at: 0)

                    if self.history.count > self.maxItems {
                        self.history.removeLast()
                    }

                    self.saveHistory()
                    self.onUpdate?(self.history)
                }
            }
        }
    }
    func handleCopiedImage(_ image: NSImage) {
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            print("❌ Failed to convert image to PNG")
            return
        }

        let filename = "clipboard_image_\(Date().timeIntervalSince1970).png"
        let folder = getImageSaveFolder()
        let fileURL = folder.appendingPathComponent(filename)

        do {
            try pngData.write(to: fileURL)
            print("✅ Image saved to:", fileURL.path)

            let label = "[Image] \(filename)"
            self.history.insert(label, at: 0)
            if self.history.count > self.maxItems {
                self.history.removeLast()
            }
            self.saveHistory()
            self.onUpdate?(self.history)

        } catch {
            print("❌ Failed to save image:", error)
        }
    }

    func getImageSaveFolder() -> URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipboardWatcher")
            .appendingPathComponent("Images")

        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
        return folder
    }


    func loadHistory() {
        if let saved = UserDefaults.standard.stringArray(forKey: historyKey) {
            history = saved
        }
    }

    func saveHistory() {
        UserDefaults.standard.set(history, forKey: historyKey)
    }

    deinit {
        timer?.invalidate()
    }
}
