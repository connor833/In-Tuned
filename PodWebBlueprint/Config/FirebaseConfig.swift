//
//  FirebaseConfig.swift
//  PodWebBlueprint
//
//  Firebase configuration setup through code instead of plist files
//

import Foundation
import Firebase

struct FirebaseConfig {
    
    // MARK: - Production Firebase Configuration
    private static let productionConfig = FirebaseConfiguration(
        googleAppId: "1:259551358773:ios:a9c1212e1f830c48d3a67c",
        gcmSenderId: "259551358773",
        projectId: "attuned-da066",
        bundleId: "Connor.Attuned",
        clientId: "259551358773-YOUR_PRODUCTION_CLIENT_ID.googleusercontent.com",
        apiKey: "AIzaSyB4eMivz7jA1HpVQr7dktj_Et5kf_h-vR8",
        databaseURL: "https://attuned-da066-default-rtdb.firebaseio.com",
        storageBucket: "attuned-da066.firebasestorage.app"
    )
    
    // MARK: - Development Firebase Configuration (your current setup)
    private static let developmentConfig = FirebaseConfiguration(
        googleAppId: "1:320621812224:ios:cf20c04cd1225a316d96e5", 
        gcmSenderId: "320621812224",
        projectId: "podwebtest-eb470",
        bundleId: "Connor.PodWebBlueprint",
        clientId: "320621812224-qpc6subfvot8b1ir1093ehepb5i1oam7.apps.googleusercontent.com",
        apiKey: "AIzaSyCMGt1HU0ujGOWEnxM16m6qzTbZDHyKkJg",
        databaseURL: "https://podwebtest-eb470-default-rtdb.firebaseio.com",
        storageBucket: "podwebtest-eb470.appspot.com"
    )
    
    // MARK: - Configuration Setup
    
    /// Configure Firebase with the appropriate environment settings
    static func configure() {
        let config = EnvironmentConfig.isProduction ? productionConfig : developmentConfig
        
        print("🔥 Configuring Firebase for: \(EnvironmentConfig.isProduction ? "PRODUCTION" : "DEVELOPMENT")")
        print("🔥 Project ID: \(config.projectId)")
        
        // Configure Firebase with our custom configuration
        FirebaseApp.configure(options: config.options)
    }
}

// MARK: - Firebase Configuration Extension

private extension FirebaseConfiguration {
    var options: FirebaseOptions {
        let options = FirebaseOptions(googleAppID: googleAppId, gcmSenderID: gcmSenderId)
        options.projectID = projectId
        options.bundleID = bundleId
        options.clientID = clientId
        options.apiKey = apiKey
        options.databaseURL = databaseURL
        options.storageBucket = storageBucket
        return options
    }
}

// MARK: - Configuration Model

private struct FirebaseConfiguration {
    let googleAppId: String
    let gcmSenderId: String
    let projectId: String
    let bundleId: String
    let clientId: String
    let apiKey: String
    let databaseURL: String
    let storageBucket: String
}
