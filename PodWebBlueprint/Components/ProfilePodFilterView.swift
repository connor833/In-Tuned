//
//  ProfilePodFilterView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/10/23.
//


import Foundation

enum ProfilePodFilterViewModel: Int, CaseIterable {
    case pods
    case playlists
    
    var title: String {
        switch self {
        case.pods:
            return "Pods"
        case .playlists:
            return "Playlists"
        }
    }
}
