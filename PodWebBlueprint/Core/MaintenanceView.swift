//
//  MaintenanceView.swift
//  Attuned
//
//  View shown when app is in maintenance mode
//

import SwiftUI

struct MaintenanceView: View {
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Icon
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.orange)
                
                // Title
                Text("Under Maintenance")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Message
                Text("We're making some improvements.\nPlease check back soon!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                // Footer
                Text("Thank you for your patience")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    MaintenanceView()
}

