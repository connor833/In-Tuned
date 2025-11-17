import SwiftUI
import UserNotifications

class NotificationManager: ObservableObject {

    // Request user authorization for notifications
    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                // Handle denied authorization
            }
        }
    }

    // Handle device token registration
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // Handle receiving FCM notifications
    func handleReceivedNotification(payload: [AnyHashable: Any]) {
        // Extract relevant information from the notification payload
        if let message = payload["message"] as? String,
           let sender = payload["sender"] as? String {
            // Display a local notification
            displayLocalNotification(title: "New Message", body: "You received a message from \(sender): \(message)")
        }
    }

    // Display a local notification
    func displayLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error displaying notification: \(error)")
            }
        }
    }
}
