//
//  SearchFilterViewModel.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import Foundation

enum SearchFilterViewModel: Int, CaseIterable {
    case pods
    case users
    
    var title: String {
        switch self {
        case.pods:
            return "Pods"
        case .users:
            return "Users"
        }
    }
}
