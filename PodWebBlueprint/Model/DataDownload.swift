//
//  DataDownload.swift
//  PodWebBlueprint
//
//  Created by Assistant on Data Download Model
//

import Foundation
import FirebaseFirestore
import Firebase

public struct DataDownload: Identifiable, Decodable {
    @DocumentID public var id: String?
    public let downloadUrl: String
    public let fileName: String
    public let exportDate: Timestamp
    public let expiresAt: Timestamp
    public let fileSize: Int
    public let summary: DownloadSummary
    
    public init(downloadUrl: String, fileName: String, exportDate: Timestamp, expiresAt: Timestamp, fileSize: Int, summary: DownloadSummary) {
        self.downloadUrl = downloadUrl
        self.fileName = fileName
        self.exportDate = exportDate
        self.expiresAt = expiresAt
        self.fileSize = fileSize
        self.summary = summary
    }
}

public struct DownloadSummary: Decodable {
    public let totalPods: Int
    public let totalComments: Int
    public let totalSavedPods: Int
    public let totalPlaylists: Int
    public let totalNotifications: Int
    public let totalConversations: Int
    public let totalMessages: Int
    public let totalFriends: Int
    public let totalFollowing: Int
    public let totalFollowers: Int
    
    public init(totalPods: Int, totalComments: Int, totalSavedPods: Int, totalPlaylists: Int, totalNotifications: Int, totalConversations: Int, totalMessages: Int, totalFriends: Int, totalFollowing: Int, totalFollowers: Int) {
        self.totalPods = totalPods
        self.totalComments = totalComments
        self.totalSavedPods = totalSavedPods
        self.totalPlaylists = totalPlaylists
        self.totalNotifications = totalNotifications
        self.totalConversations = totalConversations
        self.totalMessages = totalMessages
        self.totalFriends = totalFriends
        self.totalFollowing = totalFollowing
        self.totalFollowers = totalFollowers
    }
} 
