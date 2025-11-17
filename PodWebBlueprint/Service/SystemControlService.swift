//
//  SystemControlService.swift
//  Attuned
//
//  Service for managing app-wide system controls
//

import Foundation
import FirebaseFirestore

class SystemControlService {
    static let shared = SystemControlService()
    private let db = Firestore.firestore()
    private let settingsDocId = "app_settings"
    
    private init() {}
    
    // MARK: - App Status
    
    func isAppEnabled() async throws -> Bool {
        let doc = try await db.collection("system_settings").document(settingsDocId).getDocument()
        
        if let data = doc.data(), let isEnabled = data["appEnabled"] as? Bool {
            return isEnabled
        }
        
        // Default to true if not set
        return true
    }
    
    // MARK: - Real-time Listener
    
    func observeAppStatus(completion: @escaping (Bool) -> Void) -> ListenerRegistration {
        return db.collection("system_settings").document(settingsDocId)
            .addSnapshotListener { snapshot, error in
                if let data = snapshot?.data(), let isEnabled = data["appEnabled"] as? Bool {
                    completion(isEnabled)
                } else {
                    completion(true) // Default to enabled
                }
            }
    }
}

