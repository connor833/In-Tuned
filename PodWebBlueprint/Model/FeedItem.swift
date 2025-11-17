//
//  FeedItem.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 3/14/23.
//

import Foundation
import FirebaseFirestore

// Unified feed item that can represent either a pod or a repost
enum FeedItem: Identifiable, Hashable {
    case pod(Pod)
    case repost(RepostWithPod)
    
    var id: String? {
        switch self {
        case .pod(let pod):
            return pod.id
        case .repost(let repostWithPod):
            return repostWithPod.id
        }
    }
    
    var timestamp: Date {
        switch self {
        case .pod(let pod):
            return pod.timestamp.dateValue()
        case .repost(let repostWithPod):
            return repostWithPod.repost.timestamp
        }
    }
    
    var userId: String {
        switch self {
        case .pod(let pod):
            return pod.userId
        case .repost(let repostWithPod):
            return repostWithPod.repost.repostUserId
        }
    }
    
    // Get the actual pod (either original pod or reposted pod)
    var pod: Pod {
        switch self {
        case .pod(let pod):
            return pod
        case .repost(let repostWithPod):
            return repostWithPod.pod
        }
    }
    
    // Check if this is a repost
    var isRepost: Bool {
        switch self {
        case .pod:
            return false
        case .repost:
            return true
        }
    }
    
    // Get repost data if this is a repost
    var repostData: Repost? {
        switch self {
        case .pod:
            return nil
        case .repost(let repostWithPod):
            return repostWithPod.repost
        }
    }
}

// Extension for sorting
extension FeedItem: Comparable {
    static func < (lhs: FeedItem, rhs: FeedItem) -> Bool {
        return lhs.timestamp > rhs.timestamp // Newest first
    }
    
    static func == (lhs: FeedItem, rhs: FeedItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 