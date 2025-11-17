//
//  SettingOptions.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/8/23.
//

import Foundation

class SettingOptions: ObservableObject {
    public var options: [SettingOption] = [SettingOption(title: "Edit", imageName: "paintbrush", destination: "EditScreen"), SettingOption(title: "Log Out", imageName: "person.fill.xmark", destination: "Logout")]
}
