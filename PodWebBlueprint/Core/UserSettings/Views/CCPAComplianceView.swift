//
//  CCPAComplianceView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import SwiftUI

struct CCPAComplianceView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isCaliforniaResident = false
    @StateObject private var ccpaService = CCPAComplianceService()
    
    var body: some View {
        VStack {
            // Header with back button
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("accentColor"), lineWidth: 2)
                            )
                            .shadow(
                                color: Color.black.opacity(0.1),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Text("CCPA Rights")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // California Resident Status
                    VStack(alignment: .leading, spacing: 15) {
                        Text("California Consumer Privacy Act (CCPA)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("The CCPA provides California residents with specific rights regarding their personal information.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Toggle("I am a California resident", isOn: $isCaliforniaResident)
                            .onChange(of: isCaliforniaResident) { newValue in
                                // Save the selection to local storage and Firestore
                                ccpaService.setCaliforniaResidentStatus(newValue)
                                print("✅ California resident status saved: \(newValue)")
                            }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    if isCaliforniaResident {
                        // What We Collect
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Personal Information We Collect")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("1. Identifiers")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("• Name, email address, username, unique personal identifier")
                                
                                Text("2. Audio/Visual Data")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("• Podcast recordings, photos, videos you post")
                                
                                Text("3. Content Interaction Data")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("• What content you interact with in the app")
                                
                                Text("4. Geolocation Data")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("• General location based on IP address")
                            }
                            .font(.body)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Sale of Personal Information
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Sale of Personal Information")
                                .font(.headline)
                            
                            Text("We do not sell personal information")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                            
                            Text("Your personal information is not sold to third parties. We only use your data to provide and improve our podcast platform services.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Your Rights
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Your CCPA Rights")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("1. Right to Know")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("You have the right to know what personal information we collect, use, and share.")
                                
                                Text("2. Right to Access")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("You have the right to access and download your personal information.")
                                
                                Text("3. Right to Delete")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("You have the right to request deletion of your personal information.")
                                
                                Text("4. Right to Non-Discrimination")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("We will not discriminate against you for exercising your CCPA rights.")
                            }
                            .font(.body)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Action Buttons
                        VStack(spacing: 15) {
                            NavigationLink(destination: AccountSettingsView()
                                .navigationBarHidden(true)) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundColor(Color("accentColor"))
                                    Text("Download Your Data")
                                        .font(.headline)
                                        .foregroundColor(Color("accentColor"))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color("accentColor"), lineWidth: 2)
                                )
                            }
                            
                            NavigationLink(destination: AccountSettingsView()
                                .navigationBarHidden(true)) {
                                HStack {
                                    Image(systemName: "trash.circle")
                                        .foregroundColor(.red)
                                    Text("Delete Your Account")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.red, lineWidth: 2)
                                )
                            }
                        }
                        
                        // Contact Information
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Contact Us")
                                .font(.headline)
                            
                            Text("If you have questions about your CCPA rights or our data practices:")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("• Email: privacy@attuned.app")
                                Text("• Use the Account Settings for data actions")
                            }
                            .font(.body)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Load saved California resident status when view appears
            isCaliforniaResident = ccpaService.isCaliforniaResident()
            print("📱 Loaded California resident status: \(isCaliforniaResident)")
        }
    }
}

struct CCPADisclosureView: View {
    @Environment(\.presentationMode) var presentationMode
    let disclosure: CCPADisclosure
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Personal Information Disclosure")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                    
                    // Categories Collected
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Categories of Personal Information We Collect")
                            .font(.headline)
                        
                        ForEach(disclosure.categoriesCollected, id: \.category) { category in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(category.category)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(category.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Purposes
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Purposes for Collecting Personal Information")
                            .font(.headline)
                        
                        ForEach(disclosure.purposes, id: \.self) { purpose in
                            Text("• \(purpose)")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Third Party Sharing
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Third Parties We Share Information With")
                            .font(.headline)
                        
                        ForEach(disclosure.thirdPartySharing, id: \.name) { thirdParty in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(thirdParty.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Category: \(thirdParty.category)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Purpose: \(thirdParty.purpose)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Data Types: \(thirdParty.dataTypes.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Data Retention
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Retention")
                            .font(.headline)
                        
                        Text(disclosure.dataRetentionPeriod)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Data Sources
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Sources")
                            .font(.headline)
                        
                        ForEach(disclosure.dataSources, id: \.self) { source in
                            Text("• \(source)")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
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
    CCPAComplianceView()
}
