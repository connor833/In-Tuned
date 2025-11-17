//
//  Block.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/1/25.
//

import Foundation
import FirebaseFirestore
import Firebase

struct Block: Identifiable, Codable {
    @DocumentID var id: String?
    let blockerId: String
    let blockedUserId: String
    let timestamp: Date
    let reason: String?
    let blockType: BlockType
    let version: Int?
    
    // Default initializer with version
    init(blockerId: String, blockedUserId: String, timestamp: Date, reason: String?, blockType: BlockType, version: Int? = 1) {
        self.id = nil
        self.blockerId = blockerId
        self.blockedUserId = blockedUserId
        self.timestamp = timestamp
        self.reason = reason
        self.blockType = blockType
        self.version = version
    }
    
    enum BlockType: String, Codable, CaseIterable {
        case user = "user"
        case content = "content"
        
        var displayName: String {
            switch self {
            case .user:
                return NSLocalizedString("Block User", comment: "")
            case .content:
                return NSLocalizedString("Block Content", comment: "")
            }
        }
    }
}

struct BlockMetadata: Identifiable, Codable {
    @DocumentID var id: String?
    let blockedUserId: String
    let timestamp: Date
    let blockType: Block.BlockType
    let reason: String?
    let version: Int?
    
    // Default initializer with version
    init(blockedUserId: String, timestamp: Date, blockType: Block.BlockType, reason: String?, version: Int? = 1) {
        self.id = nil
        self.blockedUserId = blockedUserId
        self.timestamp = timestamp
        self.blockType = blockType
        self.reason = reason
        self.version = version
    }
}
