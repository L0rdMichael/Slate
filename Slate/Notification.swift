//
//  Notification.swift
//  Slate
//
//  Created by MICHAEL on 22/09/2025.
//

import UserNotifications
import UserNotifications
import SwiftUI

// Inside your TaskManager or a new NotificationsManager class
func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            print("Notification permission granted.")
        } else {
            print("Notification permission denied.")
        }
    }
}



