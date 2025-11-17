//
//  CustomInputField.swift
//  TwitterSwiftUI
//
//  Created by Connor Adams on 6/10/22.
//

import SwiftUI

struct CustomInputField: View {
    let imageName: String
    let placeholderText: String
    var isSecureField: Bool? = false
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: imageName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color("accentColor"))
                .frame(width: 24, height: 24)
            
            if isSecureField ?? false {
                SecureField(placeholderText, text: $text)
                    .font(.body)
                    .foregroundColor(Color("textColor"))
            } else {
                TextField(placeholderText, text: $text)
                    .font(.body)
                    .foregroundColor(Color("textColor"))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

struct CustomInputField_Previews: PreviewProvider {
    static var previews: some View {
        CustomInputField(imageName: "envelope", placeholderText: "Email",
            isSecureField: false,
            text: .constant(""))
        
    }
}
