//
//  EnvironmentConfig.swift
//  PodWebBlueprint
//
//  Environment configuration for production vs development/staging
//

import Foundation

struct EnvironmentConfig {
    
    // MARK: - Current Environment Detection
    
    static var isProduction: Bool {
        // FORCE PRODUCTION MODE
        print("🔍 FORCED PRODUCTION MODE")
        return true
        
        // Original logic:
        // #if PRODUCTION
        // return true
        // #else
        // return false
        // #endif
    }
    
    static var currentEnvironment: Environment {
        return isProduction ? .production : .development
    }
    
    // MARK: - Environment Types
    
    enum Environment: String, CaseIterable {
        case development = "development"
        case production = "production"
        
        var displayName: String {
            switch self {
            case .development:
                return "Development"
            case .production:
                return "Production"
            }
        }
    }
    
    // MARK: - Firebase Configuration
    
    static var firebaseProjectId: String {
        switch currentEnvironment {
        case .production:
            return "attuned-d683e"  // Your production Firebase project
        case .development:
            return "podweb-dev"         // Your development Firebase project
        }
    }
    
    static var firebaseConfigFileName: String {
        switch currentEnvironment {
        case .production:
            return "GoogleService-Info-Production"
        case .development:
            return "GoogleService-Info-Development"
        }
    }
    
    // MARK: - App Configuration
    
    static var appDisplayName: String {
        switch currentEnvironment {
        case .production:
            return "In-Tuned"
        case .development:
            return "In-Tuned Dev"
        }
    }
    
    static var bundleIdentifier: String {
        switch currentEnvironment {
        case .production:
            return "Connor.Attuned"
        case .development:
            return "com.yourcompany.podweb.dev"
        }
    }
    
    // MARK: - API Endpoints
    
    static var apiBaseURL: String {
        switch currentEnvironment {
        case .production:
            return "https://api.attunedapp.net"
        case .development:
            return "https://dev-api.attunedapp.net"
        }
    }
    
    // MARK: - Cloudflare Worker URLs
    
    static var r2UploadWorkerURL: String {
        switch currentEnvironment {
        case .production:
            return "https://uploader.attunedappdev.workers.dev"
        case .development:
            return "https://jolly-sun-3cc2.podwebdev.workers.dev"
        }
    }
    
    // MARK: - Debug Configuration
    
    static var enableDebugLogging: Bool {
        return !isProduction
    }
    
    static var enableCrashlytics: Bool {
        return isProduction
    }
    
    static var enableAnalytics: Bool {
        return isProduction
    }
}