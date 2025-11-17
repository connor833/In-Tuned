//
//  TweetFilterViewModel.swift
//  TwitterSwiftUI
//
//  Created by Connor Adams on 6/7/22.
//

import Foundation

enum FeedFilterViewModel: Int, CaseIterable {
    case following
    case foryou
    
    var title: String {
        switch self {
        case.following:
            return NSLocalizedString("Following", comment: "")
        case .foryou:
            return NSLocalizedString("For You", comment: "")
        }
    }
}
