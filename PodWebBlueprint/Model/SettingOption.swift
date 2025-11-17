//
//  SettingOption.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/8/23.
//

import Foundation
import Firebase
import FirebaseFirestore

struct SettingOption: Identifiable, Decodable {
    @DocumentID var id: String?
    let title: String
    let imageName: String
    var destination: String
    
    
}
