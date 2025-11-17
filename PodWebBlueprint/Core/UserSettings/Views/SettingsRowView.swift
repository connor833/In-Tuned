//
//  SettingsRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/6/23.
//

import SwiftUI

struct SettingsRowView: View {
    let option: SettingOption
    
    init(option: SettingOption) {
        self.option = option
    }
    
    var body: some View {
        VStack {
            HStack {
                Text(NSLocalizedString(option.title, comment: ""))
                
                Image(systemName: option.imageName)
                
                
            }
            .foregroundColor(Color("accentColor"))
            .frame(height: 12)
            
            Divider()
                .padding()
                .foregroundColor(.black)
            
        }
    }
}

struct SettingsRowView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsRowView(option: SettingOption(title: "Edit", imageName: "paintbrush", destination: "EditScreen"))
    }
}
