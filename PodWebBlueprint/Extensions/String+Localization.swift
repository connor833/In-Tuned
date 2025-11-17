//
//  String+Localization.swift
//  PodWebBlueprint
//
//  Created for localization support
//

import Foundation

extension String {
    /// Returns the localized string for the given key
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Returns a localized string with arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
    
    /// Returns a localized string with a specific comment
    func localized(comment: String) -> String {
        return NSLocalizedString(self, comment: comment)
    }
} 