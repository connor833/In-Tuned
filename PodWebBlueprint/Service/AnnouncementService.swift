//
//  AnnouncementService.swift
//  PodWebBlueprint
//
//  Service for fetching and managing announcements
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class AnnouncementService: ObservableObject {
    static let shared = AnnouncementService()
    
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    
    // Key for storing seen announcement IDs
    private let seenAnnouncementsKey = "seenAnnouncementIDs"
    
    // MARK: - Fetch Announcements
    
    /// Fetches active announcements that the current user hasn't seen yet
    func fetchUnseenAnnouncements() async throws -> [Announcement] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AnnouncementService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let appVersion = getCurrentAppVersion()
        let seenIDs = getSeenAnnouncementIDs()
        
        print("📢 AnnouncementService: Fetching announcements for user \(userId)")
        print("📢 Already seen IDs: \(seenIDs)")
        
        // Fetch active announcements from Firestore
        // Simple query to avoid needing composite index
        let snapshot = try await db.collection("announcements")
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .getDocuments()
        
        var announcements: [Announcement] = []
        
        for document in snapshot.documents {
            do {
                print("📢 Processing announcement document: \(document.documentID)")
                print("📢 Document data: \(document.data())")
                
                var announcement = try document.data(as: Announcement.self)
                announcement.id = document.documentID
                
                print("📢 Decoded announcement: \(announcement.title)")
                print("📢 Is active: \(announcement.isActive)")
                print("📢 Already seen: \(seenIDs.contains(document.documentID))")
                print("📢 Applies to version: \(announcement.appliesTo(appVersion: appVersion))")
                
                // Filter based on criteria
                guard announcement.isActive else {
                    print("📢 Skipping - not active")
                    continue
                }
                guard !seenIDs.contains(document.documentID) else {
                    print("📢 Skipping - already seen")
                    continue
                }
                guard announcement.appliesTo(appVersion: appVersion) else {
                    print("📢 Skipping - doesn't apply to version \(appVersion)")
                    continue
                }
                
                // Check target audience
                if try await shouldShowToUser(announcement: announcement, userId: userId) {
                    print("📢 ✅ Adding announcement to list")
                    announcements.append(announcement)
                } else {
                    print("📢 Skipping - doesn't apply to user")
                }
            } catch {
                print("⚠️ AnnouncementService: Error decoding announcement \(document.documentID): \(error)")
                print("⚠️ Document data: \(document.data())")
            }
        }
        
        // Sort by priority (high to low) then by creation date
        announcements.sort { a1, a2 in
            if a1.priority != a2.priority {
                let priorityOrder: [Announcement.Priority] = [.critical, .high, .medium, .low]
                let index1 = priorityOrder.firstIndex(of: a1.priority) ?? 99
                let index2 = priorityOrder.firstIndex(of: a2.priority) ?? 99
                return index1 < index2
            }
            return a1.createdAt > a2.createdAt
        }
        
        print("📢 AnnouncementService: Found \(announcements.count) unseen announcements")
        return announcements
    }
    
    // MARK: - Mark as Seen
    
    /// Marks an announcement as seen by the current user
    func markAsSeen(announcementId: String) {
        var seenIDs = getSeenAnnouncementIDs()
        if !seenIDs.contains(announcementId) {
            seenIDs.append(announcementId)
            saveSeenAnnouncementIDs(seenIDs)
            print("✅ AnnouncementService: Marked announcement \(announcementId) as seen")
        }
    }
    
    /// Marks multiple announcements as seen
    func markMultipleAsSeen(announcementIds: [String]) {
        var seenIDs = getSeenAnnouncementIDs()
        for id in announcementIds where !seenIDs.contains(id) {
            seenIDs.append(id)
        }
        saveSeenAnnouncementIDs(seenIDs)
        print("✅ AnnouncementService: Marked \(announcementIds.count) announcements as seen")
    }
    
    // MARK: - UserDefaults Management
    
    private func getSeenAnnouncementIDs() -> [String] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        let key = "\(seenAnnouncementsKey)_\(userId)"
        return userDefaults.stringArray(forKey: key) ?? []
    }
    
    private func saveSeenAnnouncementIDs(_ ids: [String]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let key = "\(seenAnnouncementsKey)_\(userId)"
        userDefaults.set(ids, forKey: key)
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private func shouldShowToUser(announcement: Announcement, userId: String) async throws -> Bool {
        switch announcement.targetAudience {
        case .all:
            return true
            
        case .newUsers:
            return try await isNewUser(userId: userId)
            
        case .existingUsers:
            return try await !isNewUser(userId: userId)
            
        case .specific:
            // You could extend this to check a specific list of user IDs
            return true
        }
    }
    
    private func isNewUser(userId: String) async throws -> Bool {
        let userDoc = try await db.collection("users").document(userId).getDocument()
        
        guard let data = userDoc.data(),
              let timestamp = data["timestamp"] as? Timestamp else {
            return false
        }
        
        let accountAge = Date().timeIntervalSince(timestamp.dateValue())
        let thirtyDaysInSeconds: TimeInterval = 30 * 24 * 60 * 60
        
        return accountAge < thirtyDaysInSeconds
    }
    
    // MARK: - Clear Seen (for testing)
    
    /// Clears all seen announcements for current user (useful for testing)
    func clearSeenAnnouncements() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let key = "\(seenAnnouncementsKey)_\(userId)"
        userDefaults.removeObject(forKey: key)
        print("🗑️ AnnouncementService: Cleared all seen announcements")
    }
}

