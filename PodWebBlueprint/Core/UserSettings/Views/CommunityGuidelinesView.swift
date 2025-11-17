//
//  CommunityGuidelinesView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/21/25.
//

import SwiftUI

struct CommunityGuidelinesView: View {
    @Environment(\.presentationMode) var mode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Community Guidelines")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Help us maintain a positive and respectful community")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 10)
                    
                    // Guidelines
                    VStack(alignment: .leading, spacing: 16) {
                        
                        GuidelineSection(
                            title: "Content Standards",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            guidelines: [
                                "Keep content appropriate for all audiences",
                                "No explicit, violent, or harmful content",
                                "Respect copyright and intellectual property",
                                "No spam, scams, or misleading information"
                            ]
                        )
                        
                        GuidelineSection(
                            title: "Respectful Interaction",
                            icon: "heart.circle.fill",
                            color: .red,
                            guidelines: [
                                "Be respectful in comments and interactions",
                                "No harassment, bullying, or hate speech",
                                "Respect different opinions and viewpoints",
                                "Keep discussions constructive and positive"
                            ]
                        )
                        
                        GuidelineSection(
                            title: "Privacy & Safety",
                            icon: "lock.circle.fill",
                            color: .blue,
                            guidelines: [
                                "Don't share personal information",
                                "Respect others' privacy",
                                "Report suspicious or inappropriate behavior",
                                "No impersonation or fake accounts"
                            ]
                        )
                        
                        GuidelineSection(
                            title: "Platform Usage",
                            icon: "gear.circle.fill",
                            color: .orange,
                            guidelines: [
                                "Use the platform as intended",
                                "No automation or bot usage",
                                "Follow all applicable laws and regulations",
                                "Help us improve by providing feedback"
                            ]
                        )
                    }
                    
                    // Reporting Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "flag.circle.fill")
                                .foregroundColor(.purple)
                                .font(.title2)
                            Text("Reporting")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("If you see content or behavior that violates these guidelines, please report it immediately. We take all reports seriously and will take appropriate action.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button {
                            // Navigate to report view
                            // This would need to be implemented based on your existing report flow
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                Text("Report Content")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Footer
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Consequences")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Violations of these guidelines may result in content removal, account warnings, or account suspension. We reserve the right to take appropriate action to maintain a safe community environment.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        mode.wrappedValue.dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                            Text("Back")
                        }
                        .foregroundColor(Color("accentColor"))
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct GuidelineSection: View {
    let title: String
    let icon: String
    let color: Color
    let guidelines: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(guidelines, id: \.self) { guideline in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .foregroundColor(color)
                            .font(.system(size: 6))
                            .padding(.top, 8)
                        
                        Text(guideline)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    CommunityGuidelinesView()
}
