//
//  PrivacyPolicyView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Privacy Policy")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom)
                    
                    Group {
                        Text("Information We Collect")
                            .font(.headline)
                        
                        Text("We collect information you provide directly to us, such as when you create an account, upload content, or communicate with us.")
                            .font(.body)
                        
                        Text("How We Use Your Information")
                            .font(.headline)
                        
                        Text("We use the information we collect to provide, maintain, and improve our services, process transactions, and communicate with you.")
                            .font(.body)
                        
                        Text("Information Sharing")
                            .font(.headline)
                        
                        Text("We do not sell, trade, or otherwise transfer your personal information to third parties without your consent, except as described in this policy.")
                            .font(.body)
                        
                        Text("Data Security")
                            .font(.headline)
                        
                        Text("We implement appropriate security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.")
                            .font(.body)
                        
                        Text("Your Rights")
                            .font(.headline)
                        
                        Text("You have the right to access, update, or delete your personal information. You can also opt out of certain communications from us.")
                            .font(.body)
                        
                        Text("Contact Us")
                            .font(.headline)
                        
                        Text("If you have any questions about this Privacy Policy, please contact us at privacy@yourapp.com")
                            .font(.body)
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
