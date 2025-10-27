//
//  ClipboardWatcherApp.swift
//  ClipboardWatcher
//
//  Created by Ahmed Laith on 19/07/2025.
//

import SwiftUI

@main
struct ClipboardWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
