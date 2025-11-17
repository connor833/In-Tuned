//
//  UserPodFilterViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import Foundation

enum UserFilterViewModel: Int, CaseIterable {
    case pods
    case reposts
    
    var title: String {
        switch self {
        case.pods:
            return "Pods"
        case .reposts:
            return "Reposts"
        }
    }
    
    // Show pods and reposts for current user
    static func allCasesForCurrentUser() -> [UserFilterViewModel] {
        return [.pods, .reposts]
    }
    
    // Show pods and reposts for other users
    static func allCasesForOtherUsers() -> [UserFilterViewModel] {
        return [.pods, .reposts]
    }
}
