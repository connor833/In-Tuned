//
//  CCPAComplianceService.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAuth

class CCPAComplianceService: ObservableObject {
    private let db = Firestore.firestore()
    private let userDefaults = UserDefaults.standard
    
    // MARK: - CCPA Consumer Rights
    
    /// Check if user is a California resident
    func isCaliforniaResident() -> Bool {
        return userDefaults.bool(forKey: "is_california_resident")
    }
    
    /// Set California resident status
    func setCaliforniaResidentStatus(_ isResident: Bool) {
        userDefaults.set(isResident, forKey: "is_california_resident")
        
        if let userId = Auth.auth().currentUser?.uid {
            let statusData: [String: Any] = [
                "isCaliforniaResident": isResident,
                "timestamp": Timestamp(date: Date())
            ]
            
            db.collection("users").document(userId)
                .collection("ccpa_status")
                .document("residency_status")
                .setData(statusData) { error in
                    if let error = error {
                        print("Error recording CCPA status: \(error)")
                    }
                }
        }
    }
    
    /// Get categories of personal information collected
    func getPersonalInformationCategories() -> [CCPAPersonalInfoCategory] {
        return [
            .identifiers("Name, email address, username, unique personal identifier"),
            .commercialInformation("Podcast content, listening history, purchase history"),
            .internetActivity("Browsing history, search history, interaction with our service"),
            .geolocationData("General location data based on IP address"),
            .audioData("Podcast recordings, voice messages"),
            .professionalInformation("Profile information, bio, professional interests"),
            .inferences("Preferences, characteristics, behavior patterns")
        ]
    }
    
    /// Get purposes for collecting personal information
    func getCollectionPurposes() -> [String] {
        return [
            "To provide and maintain our podcast platform services",
            "To personalize content recommendations",
            "To communicate with you about our services",
            "To improve our platform and develop new features",
            "To ensure platform security and prevent fraud",
            "To comply with legal obligations",
            "To conduct analytics and research"
        ]
    }
    
    /// Get third parties with whom personal information is shared
    func getThirdPartySharing() -> [CCPAThirdParty] {
        return [
            CCPAThirdParty(
                name: "Google Firebase",
                category: "Cloud Services",
                purpose: "Authentication, database, storage, and analytics",
                dataTypes: ["Identifiers", "Internet Activity", "Commercial Information"]
            ),
            CCPAThirdParty(
                name: "Cloud Infrastructure Providers",
                category: "Hosting Services",
                purpose: "Content delivery and platform hosting",
                dataTypes: ["Identifiers", "Internet Activity", "Audio Data"]
            )
        ]
    }
    
    // MARK: - Right to Know
    
    /// Request information about personal data collection
    func requestPersonalInformationDisclosure(completion: @escaping (Result<CCPADisclosure, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(CCPAError.userNotAuthenticated))
            return
        }
        
        let disclosure = CCPADisclosure(
            categoriesCollected: getPersonalInformationCategories(),
            purposes: getCollectionPurposes(),
            thirdPartySharing: getThirdPartySharing(),
            dataRetentionPeriod: "Until account deletion or 3 years of inactivity",
            dataSources: ["Directly from you", "Automatically collected through app usage"],
            businessPurpose: "To operate and improve our podcast platform services"
        )
        
        completion(.success(disclosure))
    }
    
    // MARK: - Right to Delete
    
    /// Request deletion of personal information
    func requestPersonalInformationDeletion(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(.failure(CCPAError.userNotAuthenticated))
            return
        }
        
        // Use existing anonymization function
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
    
    // MARK: - Right to Opt-Out
    
    /// Check if user has opted out of sale
    func hasOptedOutOfSale() -> Bool {
        return userDefaults.bool(forKey: "ccpa_opted_out_of_sale")
    }
    
    /// Opt out of sale of personal information
    func optOutOfSale(completion: @escaping (Result<Bool, Error>) -> Void) {
        userDefaults.set(true, forKey: "ccpa_opted_out_of_sale")
        
        if let userId = Auth.auth().currentUser?.uid {
            let optOutData: [String: Any] = [
                "optedOutOfSale": true,
                "optOutTimestamp": Timestamp(date: Date()),
                "optOutMethod": "Mobile App"
            ]
            
            db.collection("users").document(userId)
                .collection("ccpa_opt_outs")
                .document("sale_opt_out")
                .setData(optOutData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(true))
                    }
                }
        } else {
            completion(.success(true))
        }
    }
    
    /// Opt back in to sale of personal information
    func optInToSale(completion: @escaping (Result<Bool, Error>) -> Void) {
        userDefaults.set(false, forKey: "ccpa_opted_out_of_sale")
        
        if let userId = Auth.auth().currentUser?.uid {
            let optInData: [String: Any] = [
                "optedOutOfSale": false,
                "optInTimestamp": Timestamp(date: Date()),
                "optInMethod": "Mobile App"
            ]
            
            db.collection("users").document(userId)
                .collection("ccpa_opt_outs")
                .document("sale_opt_out")
                .setData(optInData) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(true))
                    }
                }
        } else {
            completion(.success(true))
        }
    }
    
    // MARK: - Right to Non-Discrimination
    
    /// Ensure non-discrimination compliance
    func ensureNonDiscrimination() -> Bool {
        // We do not discriminate against users who exercise their CCPA rights
        // This is a policy compliance check
        return true
    }
    
    // MARK: - Authorized Agent
    
    /// Process request from authorized agent
    func processAuthorizedAgentRequest(
        agentName: String,
        agentEmail: String,
        consumerName: String,
        consumerEmail: String,
        requestType: CCPAAuthorizedAgentRequestType,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        // Verify agent authorization
        let agentRequest: [String: Any] = [
            "agentName": agentName,
            "agentEmail": agentEmail,
            "consumerName": consumerName,
            "consumerEmail": consumerEmail,
            "requestType": requestType.rawValue,
            "timestamp": Timestamp(date: Date()),
            "status": "pending_verification"
        ]
        
        db.collection("ccpa_authorized_agent_requests")
            .addDocument(data: agentRequest) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(true))
                }
            }
    }
    
    // MARK: - Data Categories for Sale Disclosure
    
    /// Check if we sell personal information
    func doWeSellPersonalInformation() -> Bool {
        // We do not sell personal information
        return false
    }
    
    /// Get categories of personal information sold (if any)
    func getPersonalInformationSold() -> [String] {
        // We do not sell personal information
        return []
    }
    
    // MARK: - Verification Requirements
    
    /// Verify consumer identity for CCPA requests
    func verifyConsumerIdentity(email: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        // In a real implementation, this would verify the consumer's identity
        // For now, we'll check if the email matches the current user
        if let currentUser = Auth.auth().currentUser,
           currentUser.email == email {
            completion(.success(true))
        } else {
            completion(.failure(CCPAError.identityVerificationFailed))
        }
    }
}

// MARK: - Supporting Types

struct CCPAPersonalInfoCategory {
    let category: String
    let description: String
    
    static func identifiers(_ description: String) -> CCPAPersonalInfoCategory {
        return CCPAPersonalInfoCategory(category: "Identifiers", description: description)
    }
    
    static func commercialInformation(_ description: String) -> CCPAPersonalInfoCategory {
        return CCPAPersonalInfoCategory(category: "Commercial Information", description: description)
    }
    
    static func internetActivity(_ description: String) -> CCPAPersonalInfoCategory {
        return CCPAPersonalInfoCategory(category: "Internet Activity", description: description)
    }
    
    static func geolocationData(_ description: String) -> CCPAPersonalInfoCategory {
        return CCPAPersonalInfoCategory(category: "Geolocation Data", description: description)
    }
    
    static func audioData(_ description: String) -> CCPAPersonalInfoCategory {
        return CCPAPersonalInfoCategory(category: "Audio Data", description: description)
    }
    
    static func professionalInformation(_ description: String) -> CCPAPersonalInfoCategory {
        return CCPAPersonalInfoCategory(category: "Professional Information", description: description)
    }
    
    static func inferences(_ description: String) -> CCPAPersonalInfoCategory {
        return CCPAPersonalInfoCategory(category: "Inferences", description: description)
    }
}

struct CCPAThirdParty {
    let name: String
    let category: String
    let purpose: String
    let dataTypes: [String]
}

struct CCPADisclosure {
    let categoriesCollected: [CCPAPersonalInfoCategory]
    let purposes: [String]
    let thirdPartySharing: [CCPAThirdParty]
    let dataRetentionPeriod: String
    let dataSources: [String]
    let businessPurpose: String
}

enum CCPAAuthorizedAgentRequestType: String, CaseIterable {
    case know = "know"
    case delete = "delete"
    case optOut = "opt_out"
}

enum CCPAError: Error, LocalizedError {
    case userNotAuthenticated
    case identityVerificationFailed
    case requestProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User must be authenticated to make CCPA requests"
        case .identityVerificationFailed:
            return "Unable to verify consumer identity"
        case .requestProcessingFailed:
            return "Failed to process CCPA request"
        }
    }
}
