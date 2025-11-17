//
//  GDPRComplianceService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

class GDPRComplianceService: ObservableObject {
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - GDPR Consent Management
    
    /// Check if user has given GDPR consent
    func hasGDPRConsent() -> Bool {
        return userDefaults.bool(forKey: "gdpr_consent_given")
    }
    
    /// Record GDPR consent
    func recordGDPRConsent(consentGiven: Bool, consentType: GDPRConsentType, timestamp: Date = Date()) {
        userDefaults.set(consentGiven, forKey: "gdpr_consent_given")
        userDefaults.set(timestamp.timeIntervalSince1970, forKey: "gdpr_consent_timestamp")
        userDefaults.set(consentType.rawValue, forKey: "gdpr_consent_type")
        
        // Store in Firestore for audit trail
        if let userId = Auth.auth().currentUser?.uid {
            let consentData: [String: Any] = [
                "consentGiven": consentGiven,
                "consentType": consentType.rawValue,
                "timestamp": Timestamp(date: timestamp),
                "ipAddress": getCurrentIPAddress(),
                "userAgent": getUserAgent()
            ]
            
            db.collection("users").document(userId)
                .collection("gdpr_consent")
                .document("consent_record")
                .setData(consentData) { error in
                    if let error = error {
                        print("Error recording GDPR consent: \(error)")
                    }
                }
        }
    }
    
    /// Get user's data processing preferences
    func getDataProcessingPreferences() -> GDPRDataProcessingPreferences {
        var preferences = GDPRDataProcessingPreferences()
        
        preferences.essentialProcessing = userDefaults.bool(forKey: "gdpr_essential_processing")
        preferences.analyticsProcessing = userDefaults.bool(forKey: "gdpr_analytics_processing")
        preferences.marketingProcessing = userDefaults.bool(forKey: "gdpr_marketing_processing")
        preferences.personalizationProcessing = userDefaults.bool(forKey: "gdpr_personalization_processing")
        
        return preferences
    }
    
    /// Update data processing preferences
    func updateDataProcessingPreferences(_ preferences: GDPRDataProcessingPreferences) {
        userDefaults.set(preferences.essentialProcessing, forKey: "gdpr_essential_processing")
        userDefaults.set(preferences.analyticsProcessing, forKey: "gdpr_analytics_processing")
        userDefaults.set(preferences.marketingProcessing, forKey: "gdpr_marketing_processing")
        userDefaults.set(preferences.personalizationProcessing, forKey: "gdpr_personalization_processing")
        
        // Sync with Firestore
        if let userId = Auth.auth().currentUser?.uid {
            let preferencesData: [String: Any] = [
                "essentialProcessing": preferences.essentialProcessing,
                "analyticsProcessing": preferences.analyticsProcessing,
                "marketingProcessing": preferences.marketingProcessing,
                "personalizationProcessing": preferences.personalizationProcessing,
                "lastUpdated": Timestamp(date: Date())
            ]
            
            db.collection("users").document(userId)
                .collection("gdpr_preferences")
                .document("processing_preferences")
                .setData(preferencesData) { error in
                    if let error = error {
                        print("Error updating GDPR preferences: \(error)")
                    }
                }
        }
    }
    
    // MARK: - Data Subject Rights
    
    /// Request data export (GDPR Article 20 - Right to Data Portability)
    func requestDataExport(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(GDPRError.userNotAuthenticated))
            return
        }
        
        Task {
            do {
                let exportData = try await generateDataExport(userId: userId)
                completion(.success(exportData))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Request data deletion (GDPR Article 17 - Right to Erasure)
    func requestDataDeletion(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(GDPRError.userNotAuthenticated))
            return
        }
        
        // Call the existing anonymizeUserAccount function
        let functions = Functions.functions()
        let anonymizeAccount = functions.httpsCallable("anonymizeUserAccount")
        
        anonymizeAccount.call { result, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }
    
    /// Request data rectification (GDPR Article 16 - Right to Rectification)
    func requestDataRectification(field: String, newValue: Any, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(GDPRError.userNotAuthenticated))
            return
        }
        
        db.collection("users").document(userId)
            .updateData([field: newValue]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(true))
                }
            }
    }
    
    /// Request processing restriction (GDPR Article 18 - Right to Restriction of Processing)
    func requestProcessingRestriction(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(GDPRError.userNotAuthenticated))
            return
        }
        
        let restrictionData: [String: Any] = [
            "processingRestricted": true,
            "restrictionTimestamp": Timestamp(date: Date()),
            "restrictionReason": "User requested processing restriction"
        ]
        
        db.collection("users").document(userId)
            .collection("gdpr_restrictions")
            .document("processing_restriction")
            .setData(restrictionData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(true))
                }
            }
    }
    
    // MARK: - Data Processing Legal Basis
    
    /// Get legal basis for data processing
    func getLegalBasisForProcessing() -> [String: GDPRLegalBasis] {
        return [
            "account_management": .contract,
            "content_hosting": .contract,
            "personalization": .consent,
            "analytics": .legitimate_interest,
            "marketing": .consent,
            "security": .legitimate_interest,
            "legal_compliance": .legal_obligation
        ]
    }
    
    // MARK: - Data Protection Impact Assessment
    
    /// Check if DPIA is required for specific processing activities
    func requiresDPIA(processingActivity: String) -> Bool {
        let highRiskActivities = [
            "automated_decision_making",
            "profiling",
            "large_scale_processing",
            "sensitive_data_processing"
        ]
        
        return highRiskActivities.contains(processingActivity)
    }
    
    // MARK: - Helper Methods
    
    private func generateDataExport(userId: String) async throws -> Data {
        // Collect all user data from Firestore
        let userDoc = try await db.collection("users").document(userId).getDocument()
        let userData = userDoc.data() ?? [:]
        
        // Collect user preferences
        let preferencesDoc = try await db.collection("users").document(userId)
            .collection("user-preferences").document("preferences").getDocument()
        let preferencesData = preferencesDoc.data() ?? [:]
        
        // Collect user content
        let podsQuery = try await db.collection("pods").whereField("userId", isEqualTo: userId).getDocuments()
        let podsData = podsQuery.documents.map { $0.data() }
        
        // Create comprehensive export
        let exportData: [String: Any] = [
            "user_data": userData,
            "preferences": preferencesData,
            "content": [
                "pods": podsData
            ],
            "export_timestamp": Timestamp(date: Date()),
            "export_version": "1.0"
        ]
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    private func getCurrentIPAddress() -> String {
        // This would need to be implemented with a network request
        // For now, return a placeholder
        return "IP_ADDRESS_PLACEHOLDER"
    }
    
    private func getUserAgent() -> String {
        return "In-Tuned iOS App"
    }
}

// MARK: - Supporting Types

enum GDPRConsentType: String, CaseIterable {
    case explicit = "explicit"
    case implied = "implied"
    case optIn = "opt_in"
    case optOut = "opt_out"
}

struct GDPRDataProcessingPreferences {
    var essentialProcessing: Bool = true // Always required for service functionality
    var analyticsProcessing: Bool = false
    var marketingProcessing: Bool = false
    var personalizationProcessing: Bool = false
}

enum GDPRLegalBasis: String, CaseIterable {
    case consent = "consent"
    case contract = "contract"
    case legal_obligation = "legal_obligation"
    case vital_interests = "vital_interests"
    case public_task = "public_task"
    case legitimate_interest = "legitimate_interest"
}

enum GDPRError: Error, LocalizedError {
    case userNotAuthenticated
    case consentNotGiven
    case dataExportFailed
    case dataDeletionFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to perform this action"
        case .consentNotGiven:
            return "GDPR consent is required for this operation"
        case .dataExportFailed:
            return "Failed to export user data"
        case .dataDeletionFailed:
            return "Failed to delete user data"
        }
    }
}
