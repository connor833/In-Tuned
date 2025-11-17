//
//  COPPAComplianceService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

class COPPAComplianceService: ObservableObject {
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - Age Verification
    
    /// Check if user is under 13
    func isUserUnder13() -> Bool {
        return userDefaults.bool(forKey: "is_user_under_13")
    }
    
    /// Set user age status
    func setUserAgeStatus(isUnder13: Bool) {
        userDefaults.set(isUnder13, forKey: "is_user_under_13")
        
        if let userId = Auth.auth().currentUser?.uid {
            let ageData: [String: Any] = [
                "isUnder13": isUnder13,
                "timestamp": Timestamp(date: Date()),
                "verificationMethod": "self_declaration"
            ]
            
            db.collection("users").document(userId)
                .collection("coppa_status")
                .document("age_verification")
                .setData(ageData) { error in
                    if let error = error {
                        print("Error recording COPPA status: \(error)")
                    }
                }
        }
    }
    
    /// Verify parental consent
    func hasParentalConsent() -> Bool {
        return userDefaults.bool(forKey: "parental_consent_given")
    }
    
    /// Record parental consent
    func recordParentalConsent(
        parentEmail: String,
        parentName: String,
        consentGiven: Bool,
        verificationMethod: COPPAConsentVerificationMethod
    ) {
        userDefaults.set(consentGiven, forKey: "parental_consent_given")
        userDefaults.set(parentEmail, forKey: "parent_email")
        userDefaults.set(parentName, forKey: "parent_name")
        
        if let userId = Auth.auth().currentUser?.uid {
            let consentData: [String: Any] = [
                "parentEmail": parentEmail,
                "parentName": parentName,
                "consentGiven": consentGiven,
                "verificationMethod": verificationMethod.rawValue,
                "timestamp": Timestamp(date: Date()),
                "childUserId": userId
            ]
            
            db.collection("coppa_parental_consent")
                .addDocument(data: consentData) { error in
                    if let error = error {
                        print("Error recording parental consent: \(error)")
                    }
                }
        }
    }
    
    // MARK: - Data Collection Restrictions
    
    /// Get data collection limits for children under 13
    func getDataCollectionLimits() -> COPPADataCollectionLimits {
        return COPPADataCollectionLimits(
            canCollectPersonalInfo: false,
            canCollectLocationData: false,
            canCollectBehavioralData: false,
            canCollectAudioData: false,
            canCollectPhotos: false,
            canCollectContactInfo: false,
            canCollectDeviceInfo: false,
            canCollectUsageData: false,
            canCollectPreferences: false,
            canCollectSocialData: false
        )
    }
    
    /// Check if specific data collection is allowed
    func isDataCollectionAllowed(dataType: COPPADataType) -> Bool {
        let limits = getDataCollectionLimits()
        
        switch dataType {
        case .personalInfo:
            return limits.canCollectPersonalInfo
        case .locationData:
            return limits.canCollectLocationData
        case .behavioralData:
            return limits.canCollectBehavioralData
        case .audioData:
            return limits.canCollectAudioData
        case .photos:
            return limits.canCollectPhotos
        case .contactInfo:
            return limits.canCollectContactInfo
        case .deviceInfo:
            return limits.canCollectDeviceInfo
        case .usageData:
            return limits.canCollectUsageData
        case .preferences:
            return limits.canCollectPreferences
        case .socialData:
            return limits.canCollectSocialData
        }
    }
    
    // MARK: - Parental Controls
    
    /// Get parental control options
    func getParentalControlOptions() -> [COPPAParentalControl] {
        return [
            COPPAParentalControl(
                name: "Account Monitoring",
                description: "Monitor child's account activity and content",
                isEnabled: false
            ),
            COPPAParentalControl(
                name: "Content Restrictions",
                description: "Restrict access to certain types of content",
                isEnabled: false
            ),
            COPPAParentalControl(
                name: "Time Limits",
                description: "Set daily usage time limits",
                isEnabled: false
            ),
            COPPAParentalControl(
                name: "Friend Requests",
                description: "Approve or deny friend requests",
                isEnabled: false
            ),
            COPPAParentalControl(
                name: "Message Monitoring",
                description: "Monitor private messages",
                isEnabled: false
            )
        ]
    }
    
    /// Update parental control settings
    func updateParentalControl(_ control: COPPAParentalControl) {
        if let userId = Auth.auth().currentUser?.uid {
            let controlData: [String: Any] = [
                "controlName": control.name,
                "isEnabled": control.isEnabled,
                "timestamp": Timestamp(date: Date())
            ]
            
            db.collection("users").document(userId)
                .collection("parental_controls")
                .document(control.name.lowercased().replacingOccurrences(of: " ", with: "_"))
                .setData(controlData) { error in
                    if let error = error {
                        print("Error updating parental control: \(error)")
                    }
                }
        }
    }
    
    // MARK: - Data Deletion for Children
    
    /// Request immediate data deletion for child under 13
    func requestChildDataDeletion(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(COPPAError.userNotAuthenticated))
            return
        }
        
        // Immediate deletion for COPPA compliance
        let functions = Functions.functions()
        let deleteChildAccount = functions.httpsCallable("deleteChildAccount")
        
        let data: [String: Any] = [
            "userId": userId,
            "reason": "COPPA compliance - child under 13"
        ]
        
        deleteChildAccount.call(data) { result, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(true))
            }
        }
    }
    
    // MARK: - Parental Notification
    
    /// Send notification to parent about child's activity
    func sendParentalNotification(
        notificationType: COPPAParentalNotificationType,
        message: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        guard let userId = Auth.auth().currentUser?.uid,
              let parentEmail = userDefaults.string(forKey: "parent_email") else {
            completion(.failure(COPPAError.parentEmailNotAvailable))
            return
        }
        
        let notificationData: [String: Any] = [
            "childUserId": userId,
            "parentEmail": parentEmail,
            "notificationType": notificationType.rawValue,
            "message": message,
            "timestamp": Timestamp(date: Date())
        ]
        
        db.collection("coppa_parental_notifications")
            .addDocument(data: notificationData) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(true))
                }
            }
    }
    
    // MARK: - COPPA Compliance Check
    
    /// Check if current data collection practices are COPPA compliant
    func isCOPPACompliant() -> Bool {
        // Check if user is under 13
        if isUserUnder13() {
            // If under 13, must have parental consent
            return hasParentalConsent()
        } else {
            // If 13 or older, no special restrictions
            return true
        }
    }
    
    /// Get COPPA compliance status
    func getCOPPAComplianceStatus() -> COPPAComplianceStatus {
        if isUserUnder13() {
            if hasParentalConsent() {
                return .compliantWithParentalConsent
            } else {
                return .nonCompliantMissingConsent
            }
        } else {
            return .compliantAdultUser
        }
    }
}

// MARK: - Supporting Types

struct COPPADataCollectionLimits {
    let canCollectPersonalInfo: Bool
    let canCollectLocationData: Bool
    let canCollectBehavioralData: Bool
    let canCollectAudioData: Bool
    let canCollectPhotos: Bool
    let canCollectContactInfo: Bool
    let canCollectDeviceInfo: Bool
    let canCollectUsageData: Bool
    let canCollectPreferences: Bool
    let canCollectSocialData: Bool
}

enum COPPADataType: String, CaseIterable {
    case personalInfo = "personal_info"
    case locationData = "location_data"
    case behavioralData = "behavioral_data"
    case audioData = "audio_data"
    case photos = "photos"
    case contactInfo = "contact_info"
    case deviceInfo = "device_info"
    case usageData = "usage_data"
    case preferences = "preferences"
    case socialData = "social_data"
}

struct COPPAParentalControl: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    var isEnabled: Bool
}

enum COPPAConsentVerificationMethod: String, CaseIterable {
    case emailVerification = "email_verification"
    case phoneVerification = "phone_verification"
    case postalMail = "postal_mail"
    case videoCall = "video_call"
    case inPerson = "in_person"
}

enum COPPAParentalNotificationType: String, CaseIterable {
    case accountCreation = "account_creation"
    case contentUpload = "content_upload"
    case friendRequest = "friend_request"
    case messageReceived = "message_received"
    case dataCollection = "data_collection"
    case accountDeletion = "account_deletion"
}

enum COPPAComplianceStatus {
    case compliantAdultUser
    case compliantWithParentalConsent
    case nonCompliantMissingConsent
    case nonCompliantUnder13WithoutConsent
}

enum COPPAError: Error, LocalizedError {
    case userNotAuthenticated
    case parentEmailNotAvailable
    case parentalConsentRequired
    case dataCollectionNotAllowed
    case accountDeletionFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to perform this action"
        case .parentEmailNotAvailable:
            return "Parent email address is required for this action"
        case .parentalConsentRequired:
            return "Parental consent is required for users under 13"
        case .dataCollectionNotAllowed:
            return "Data collection is not allowed for users under 13 without parental consent"
        case .accountDeletionFailed:
            return "Failed to delete child account"
        }
    }
}
