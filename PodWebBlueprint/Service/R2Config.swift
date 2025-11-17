//
//  R2Config.swift
//  PodWebBlueprint
//
//  Cloudflare R2 configuration for different environments
//

import Foundation

struct R2Config {
    // MARK: - Environment-Specific Configuration
    
    // Production Cloudflare R2 Configuration
    private static let productionEndpoint = "https://98ee3438200df3fa05fc0f36d43b503e.r2.cloudflarestorage.com"
    private static let productionBucketName = "attuned-production"
    private static let productionAccountId = "98ee3438200df3fa05fc0f36d43b503e"
    private static let productionAccessKeyId = "017588d23a9367a8f07ebfbc72d212f0"
    private static let productionSecretAccessKey = "4284770ac7b04c65b6ef2700526cdebd432f3ce90ddb4ac3e44d3f6fbbd6220f"
    private static let productionPublicDomain = "https://pub-3e20cabba81e450fae7b96084e2a468e.r2.dev"
    
    // Development Cloudflare R2 Configuration  
    private static let developmentEndpoint = "https://66c94044fd36e21988e02b74fcd4ccc0.r2.cloudflarestorage.com"
    private static let developmentBucketName = "cloudflare-testing"
    private static let developmentAccountId = "66c94044fd36e21988e02b74fcd4ccc0"
    private static let developmentAccessKeyId = "5f6835ab135a6e6b755b0e558425bec7"
    private static let developmentSecretAccessKey = "63eb65eb97f50d87fd07e835b757c326729d1daf23bf7b57aa79e35e0b9da7f0"
    private static let developmentPublicDomain = "https://pub-65e3d702de6e45c6810cabd0b0895357.r2.dev"
    
    // MARK: - Active Configuration (Like the old config but environment-aware)
    
    static var endpoint: String {
        return EnvironmentConfig.isProduction ? productionEndpoint : developmentEndpoint
    }
    
    static var bucketName: String {
        return EnvironmentConfig.isProduction ? productionBucketName : developmentBucketName
    }
    
    static var region: String {
        return "auto" // R2 uses 'auto' as the region
    }
    
    static var accountId: String {
        return EnvironmentConfig.isProduction ? productionAccountId : developmentAccountId
    }
    
    static var accessKeyId: String {
        return EnvironmentConfig.isProduction ? productionAccessKeyId : developmentAccessKeyId
    }
    
    static var secretAccessKey: String {
        return EnvironmentConfig.isProduction ? productionSecretAccessKey : developmentSecretAccessKey
    }
    
    static var publicDomain: String {
        return EnvironmentConfig.isProduction ? productionPublicDomain : developmentPublicDomain
    }
    
    // Optional: Custom domain if you have one configured
    static let customDomain = "YOUR_CUSTOM_DOMAIN" // e.g., "https://videos.yourdomain.com"
    
    // Upload settings
    static let maxFileSize = 10 * 1024 * 1024 * 1024 // 10GB limit (practical limit for 1 hour content)
    static let allowedVideoFormats = ["mp4", "mov", "avi", "mkv", "wmv", "flv", "webm"]
    
    // Generate a unique filename for uploads
    static func generateFileName(originalName: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let uuid = UUID().uuidString
        
        // Extract file extension from original name
        let fileExtension = originalName.components(separatedBy: ".").last?.lowercased() ?? "mp4"
        
        // Ensure we have a valid extension
        let validExtension = ["mp4", "mov", "avi", "mkv", "mp3", "wav", "m4a"].contains(fileExtension) ? fileExtension : "mp4"
        
        return "videos/\(timestamp)_\(uuid).\(validExtension)"
    }
    
    // Get the full URL for uploaded videos
    static func getVideoURL(fileName: String) -> String {
        // Use the correct public R2 URL format that actually works for video playback
        // The format should be: https://pub-{accountId}.r2.dev/{fileName}
        return "\(publicDomain)/\(fileName)"
    }
}