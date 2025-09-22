//
//  SlateApp.swift
//  Slate
//
//  Created by MICHAEL on 22/09/2025.
//

import SwiftUI

//@main
//struct SlateApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
//    }
//}

@main
struct SlateApp: App {
    @StateObject private var taskManager = TaskManager()

    var body: some Scene {
        // This creates the icon in the menu bar.
        MenuBarExtra {
            ContentView(taskManager: taskManager)
        } label: {
            // The icon that appears in the menu bar.
            Image(systemName: "checklist")
        }
        .menuBarExtraStyle(.window) // Use a popover-style window
    }
}
