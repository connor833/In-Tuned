//
//  Announcement.swift
//  PodWebBlueprint
//
//  Model for system-wide announcements and "What's New" messages
//

import Foundation
import FirebaseFirestore

struct Announcement: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let message: String
    let createdAt: Date
    let expiresAt: Date?
    let priority: Priority
    let imageURL: String?
    let actionButtonText: String?
    let actionButtonURL: String?
    let targetAudience: TargetAudience
    let minAppVersion: String?
    let maxAppVersion: String?
    
    enum Priority: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }
    
    enum TargetAudience: String, Codable {
        case all = "all"
        case newUsers = "new_users"      // Users created in last 30 days
        case existingUsers = "existing_users"  // Users created > 30 days ago
        case specific = "specific"        // Specific user IDs (would need additional field)
    }
    
    // Check if announcement is currently active
    var isActive: Bool {
        let now = Date()
        if let expires = expiresAt, now > expires {
            return false
        }
        return true
    }
    
    // Check if announcement applies to current app version
    func appliesTo(appVersion: String) -> Bool {
        if let minVersion = minAppVersion, appVersion.compare(minVersion, options: .numeric) == .orderedAscending {
            return false
        }
        if let maxVersion = maxAppVersion, appVersion.compare(maxVersion, options: .numeric) == .orderedDescending {
            return false
        }
        return true
    }
}

