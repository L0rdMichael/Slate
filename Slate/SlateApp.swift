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
    @State private var isMenuBarExtraVisible: Bool = true // State to control visibility

    private var menuBarTitle: String {
        if let topTask = taskManager.todayTasks.first {
            let timeInfo: String
            if topTask.isTimed {
                let remaining = max(0, topTask.duration - topTask.elapsed)
                timeInfo = formatTimeCompact(remaining) 
            } else {
                timeInfo = formatTimeCompact(topTask.elapsed) 
            }
            return timeInfo
        }
        return ""
    }

    var body: some Scene {
        MenuBarExtra(isInserted: $isMenuBarExtraVisible) { 
            ContentView(taskManager: taskManager)
        } label: {
            HStack {
                Image(systemName: "checklist")
                Text(menuBarTitle)
                    .font(.system(size: 14, weight: .bold))
             
            }
        }
        .menuBarExtraStyle(.window)
    }
}

func formatTimeCompact(_ totalSeconds: TimeInterval) -> String {
    let hours = Int(totalSeconds) / 3600
    let minutes = (Int(totalSeconds) % 3600) / 60
    if hours > 0 {
        return "\(hours)hr \(minutes)m"
    } else {
        return "\(minutes)m"
    }
}
