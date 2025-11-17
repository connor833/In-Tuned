//
//  NotificationSettingsViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

class NotificationSettingsViewModel: ObservableObject {
    @Published var likesEnabled = true
    @Published var commentsEnabled = true
    @Published var followsEnabled = true
    @Published var followRequestsEnabled = true
    @Published var repostsEnabled = true
    @Published var messagesEnabled = true
    @Published var newPodsEnabled = true
    @Published var trendingEnabled = false
    @Published var appUpdatesEnabled = true
    @Published var maintenanceEnabled = true
    @Published var quietHoursEnabled = false
    @Published var quietHoursStart = Date()
    @Published var quietHoursEnd = Date()
    
    private let db = Firestore.firestore()
    private var userId: String {
        Auth.auth().currentUser?.uid ?? ""
    }
    
    init() {
        // Set default quiet hours times
        let calendar = Calendar.current
        let now = Date()
        
        // Set start time to 10 PM today
        var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startComponents.hour = 22
        startComponents.minute = 0
        startComponents.second = 0
        quietHoursStart = calendar.date(from: startComponents) ?? now
        
        // Set end time to 8 AM tomorrow
        var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endComponents.hour = 8
        endComponents.minute = 0
        endComponents.second = 0
        quietHoursEnd = calendar.date(from: endComponents) ?? now
    }
    
    func loadSettings() {
        guard !userId.isEmpty else { return }
        
        let settingsRef = db.collection("users").document(userId).collection("settings").document("notifications")
        
        settingsRef.getDocument { [weak self] document, error in
            if let error = error {
                print("Error loading notification settings: \(error)")
                return
            }
            
            if let document = document, document.exists {
                DispatchQueue.main.async {
                    self?.likesEnabled = document.data()?["likesEnabled"] as? Bool ?? true
                    self?.commentsEnabled = document.data()?["commentsEnabled"] as? Bool ?? true
                    self?.followsEnabled = document.data()?["followsEnabled"] as? Bool ?? true
                    self?.followRequestsEnabled = document.data()?["followRequestsEnabled"] as? Bool ?? true
                    self?.repostsEnabled = document.data()?["repostsEnabled"] as? Bool ?? true
                    self?.messagesEnabled = document.data()?["messagesEnabled"] as? Bool ?? true
                    self?.newPodsEnabled = document.data()?["newPodsEnabled"] as? Bool ?? true
                    self?.trendingEnabled = document.data()?["trendingEnabled"] as? Bool ?? false
                    self?.appUpdatesEnabled = document.data()?["appUpdatesEnabled"] as? Bool ?? true
                    self?.maintenanceEnabled = document.data()?["maintenanceEnabled"] as? Bool ?? true
                    self?.quietHoursEnabled = document.data()?["quietHoursEnabled"] as? Bool ?? false
                    
                    if let startTimestamp = document.data()?["quietHoursStart"] as? Timestamp {
                        let startDate = startTimestamp.dateValue()
                        // Validate the date is reasonable (not too far in the past)
                        if startDate > Date(timeIntervalSince1970: 0) {
                            self?.quietHoursStart = startDate
                        }
                    }
                    if let endTimestamp = document.data()?["quietHoursEnd"] as? Timestamp {
                        let endDate = endTimestamp.dateValue()
                        // Validate the date is reasonable (not too far in the past)
                        if endDate > Date(timeIntervalSince1970: 0) {
                            self?.quietHoursEnd = endDate
                        }
                    }
                }
            }
        }
    }
    
    func saveSettings() {
        guard !userId.isEmpty else { return }
        
        let settingsRef = db.collection("users").document(userId).collection("settings").document("notifications")
        
        // Create safe timestamps for quiet hours
        let calendar = Calendar.current
        let now = Date()
        
        // Create start time (10 PM today)
        var startComponents = calendar.dateComponents([.year, .month, .day], from: now)
        startComponents.hour = 22
        startComponents.minute = 0
        startComponents.second = 0
        let safeStartTime = calendar.date(from: startComponents) ?? now
        
        // Create end time (8 AM tomorrow)
        var endComponents = calendar.dateComponents([.year, .month, .day], from: now)
        endComponents.hour = 8
        endComponents.minute = 0
        endComponents.second = 0
        let safeEndTime = calendar.date(from: endComponents) ?? now
        
        // Use the safe times if quiet hours are enabled, otherwise use current values
        let finalStartTime = quietHoursEnabled ? quietHoursStart : safeStartTime
        let finalEndTime = quietHoursEnabled ? quietHoursEnd : safeEndTime
        
        let settings: [String: Any] = [
            "likesEnabled": likesEnabled,
            "commentsEnabled": commentsEnabled,
            "followsEnabled": followsEnabled,
            "followRequestsEnabled": followRequestsEnabled,
            "repostsEnabled": repostsEnabled,
            "messagesEnabled": messagesEnabled,
            "newPodsEnabled": newPodsEnabled,
            "trendingEnabled": trendingEnabled,
            "appUpdatesEnabled": appUpdatesEnabled,
            "maintenanceEnabled": maintenanceEnabled,
            "quietHoursEnabled": quietHoursEnabled,
            "quietHoursStart": Timestamp(date: finalStartTime),
            "quietHoursEnd": Timestamp(date: finalEndTime),
            "lastUpdated": Timestamp(date: Date())
        ]
        
        settingsRef.setData(settings) { error in
            if let error = error {
                print("Error saving notification settings: \(error)")
            } else {
                print("Notification settings saved successfully")
            }
        }
    }
    
    // Helper method to check if notifications should be sent based on quiet hours
    func shouldSendNotification() -> Bool {
        guard quietHoursEnabled else { return true }
        
        let now = Date()
        let calendar = Calendar.current
        
        // Get current time components
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTimeInMinutes = currentHour * 60 + currentMinute
        
        // Get quiet hours time components
        let startHour = calendar.component(.hour, from: quietHoursStart)
        let startMinute = calendar.component(.minute, from: quietHoursStart)
        let startTimeInMinutes = startHour * 60 + startMinute
        
        let endHour = calendar.component(.hour, from: quietHoursEnd)
        let endMinute = calendar.component(.minute, from: quietHoursEnd)
        let endTimeInMinutes = endHour * 60 + endMinute
        
        // Check if current time is within quiet hours
        if startTimeInMinutes <= endTimeInMinutes {
            // Same day quiet hours (e.g., 10 PM to 8 AM)
            return currentTimeInMinutes < startTimeInMinutes || currentTimeInMinutes > endTimeInMinutes
        } else {
            // Overnight quiet hours (e.g., 10 PM to 8 AM next day)
            return currentTimeInMinutes < startTimeInMinutes && currentTimeInMinutes > endTimeInMinutes
        }
    }
} 
