//
//  User.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/20/22.
//

import Firebase
import FirebaseFirestore
import FirebaseAuth

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let uid: String
    var username: String
    var fullname: String?
    var profileImageUrl: String
    let email: String
    let isVerified: Bool
    var followers: Int = 0
    var following: Int = 0
    var podCount: Int = 0
       
    var bio: String?
    var link: String?
    var isPrivate: Bool?
    var createdAt: Timestamp?
    var isCurrentUser: Bool { return Auth.auth().currentUser?.uid == id}
    var didFollow: Bool? = false
    var followRequestSent: Bool? = false
    
    // Blocking properties
    var blockedUsers: [String]? = []
    var blockedBy: [String]? = []
    
    // Essential fields for production (optional for backward compatibility)
    var isActive: Bool? = true
    var termsAcceptedAt: Timestamp?
    var lastUpdated: Timestamp?
    var version: Int? = 1
    
    // Account status fields
    var isDeleted: Bool? = false   // Set to true when account is deleted/anonymized
    
    // User profile fields
    var birthDate: Timestamp?      // User's birthdate from signup wheel
}

