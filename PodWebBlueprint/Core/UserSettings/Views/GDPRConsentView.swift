//
//  GDPRConsentView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import SwiftUI

struct GDPRConsentView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var gdprService = GDPRComplianceService()
    @State private var selectedConsentType: GDPRConsentType = .explicit
    @State private var dataPreferences = GDPRDataProcessingPreferences()
    @State private var showDetailedPreferences = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .foregroundColor(Color("accentColor"))
                }
                .padding()
                
                Spacer()
                
                Text("GDPR Consent")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // GDPR Information
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Data Protection & Your Rights")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Under the General Data Protection Regulation (GDPR), you have specific rights regarding your personal data. We need your consent to process certain types of data.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Consent Type Selection
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Consent Type")
                            .font(.headline)
                        
                        Picker("Consent Type", selection: $selectedConsentType) {
                            ForEach(GDPRConsentType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Data Processing Preferences
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Data Processing Preferences")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("Detailed Settings") {
                                showDetailedPreferences.toggle()
                            }
                            .font(.caption)
                            .foregroundColor(Color("accentColor"))
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Essential Processing (Always Required)
                            HStack {
                                Toggle("Essential Processing", isOn: .constant(true))
                                    .disabled(true)
                                Spacer()
                                Text("Required")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("Necessary for basic app functionality (account management, content hosting)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Analytics Processing
                            Toggle("Analytics & Usage Data", isOn: $dataPreferences.analyticsProcessing)
                            Text("Help us improve our service by analyzing how you use the app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Personalization Processing
                            Toggle("Content Personalization", isOn: $dataPreferences.personalizationProcessing)
                            Text("Personalize content recommendations based on your preferences")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Marketing Processing
                            Toggle("Marketing Communications", isOn: $dataPreferences.marketingProcessing)
                            Text("Send you promotional content and updates about new features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(10)
                    
                    // Your Rights Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Your Data Rights")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Access: View and download your personal data")
                            Text("• Rectification: Correct inaccurate information")
                            Text("• Erasure: Delete your personal data")
                            Text("• Portability: Receive your data in a portable format")
                            Text("• Restriction: Limit how we process your data")
                            Text("• Objection: Object to certain processing activities")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Legal Basis Information
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Legal Basis for Processing")
                            .font(.headline)
                        
                        Text("We process your data based on:")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("• Contract: To provide our podcast platform services")
                            Text("• Consent: For analytics, personalization, and marketing")
                            Text("• Legitimate Interest: For security and platform improvement")
                            Text("• Legal Obligation: To comply with applicable laws")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        Button(action: {
                            giveConsent()
                        }) {
                            Text("Give Consent")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("accentColor"))
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            withdrawConsent()
                        }) {
                            Text("Withdraw Consent")
                                .font(.headline)
                                .foregroundColor(Color("accentColor"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color("accentColor"), lineWidth: 2)
                                )
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDetailedPreferences) {
            DetailedGDPRPreferencesView(preferences: $dataPreferences)
        }
        .alert("GDPR Consent", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadCurrentPreferences()
        }
    }
    
    private func loadCurrentPreferences() {
        dataPreferences = gdprService.getDataProcessingPreferences()
    }
    
    private func giveConsent() {
        gdprService.recordGDPRConsent(consentGiven: true, consentType: selectedConsentType)
        gdprService.updateDataProcessingPreferences(dataPreferences)
        
        alertMessage = "Consent recorded successfully. Your data processing preferences have been updated."
        showAlert = true
    }
    
    private func withdrawConsent() {
        gdprService.recordGDPRConsent(consentGiven: false, consentType: selectedConsentType)
        
        // Reset preferences to minimal processing
        var minimalPreferences = GDPRDataProcessingPreferences()
        minimalPreferences.essentialProcessing = true // Always required
        gdprService.updateDataProcessingPreferences(minimalPreferences)
        
        alertMessage = "Consent withdrawn. Only essential data processing will continue."
        showAlert = true
    }
}

struct DetailedGDPRPreferencesView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var preferences: GDPRDataProcessingPreferences
    @State private var showDataRights = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Detailed Data Processing Preferences")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Essential Processing
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Essential Processing")
                                .font(.headline)
                            
                            Toggle("Account Management", isOn: .constant(true))
                                .disabled(true)
                            
                            Toggle("Content Hosting", isOn: .constant(true))
                                .disabled(true)
                            
                            Toggle("Authentication", isOn: .constant(true))
                                .disabled(true)
                            
                            Text("These are required for basic app functionality and cannot be disabled.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Analytics Processing
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Analytics & Usage Data")
                                .font(.headline)
                            
                            Toggle("Usage Analytics", isOn: $preferences.analyticsProcessing)
                            
                            Toggle("Performance Monitoring", isOn: $preferences.analyticsProcessing)
                            
                            Toggle("Error Reporting", isOn: $preferences.analyticsProcessing)
                            
                            Text("Help us understand how the app is used to improve performance and fix issues.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Personalization Processing
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Content Personalization")
                                .font(.headline)
                            
                            Toggle("Recommendation Engine", isOn: $preferences.personalizationProcessing)
                            
                            Toggle("Content Categorization", isOn: $preferences.personalizationProcessing)
                            
                            Toggle("User Preference Learning", isOn: $preferences.personalizationProcessing)
                            
                            Text("Personalize your experience by learning your content preferences and interests.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Marketing Processing
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Marketing Communications")
                                .font(.headline)
                            
                            Toggle("Promotional Notifications", isOn: $preferences.marketingProcessing)
                            
                            Toggle("Feature Announcements", isOn: $preferences.marketingProcessing)
                            
                            Toggle("Newsletter Subscriptions", isOn: $preferences.marketingProcessing)
                            
                            Text("Receive updates about new features, promotions, and platform news.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Data Rights Information
                        Button(action: {
                            showDataRights = true
                        }) {
                            HStack {
                                Text("Learn About Your Data Rights")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .sheet(isPresented: $showDataRights) {
            DataRightsView()
        }
    }
}

struct DataRightsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var gdprService = GDPRComplianceService()
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your Data Rights Under GDPR")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 15) {
                        // Right to Access
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Right to Access (Article 15)")
                                .font(.headline)
                            
                            Text("You have the right to obtain confirmation as to whether or not personal data concerning you are being processed, and, where that is the case, access to the personal data.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button("Request Data Export") {
                                requestDataExport()
                            }
                            .foregroundColor(Color("accentColor"))
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Right to Rectification
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Right to Rectification (Article 16)")
                                .font(.headline)
                            
                            Text("You have the right to obtain the rectification of inaccurate personal data concerning you.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button("Request Data Correction") {
                                // This would open a form to correct data
                                alertMessage = "Please contact us at privacy@attuned.app to request data correction."
                                showAlert = true
                            }
                            .foregroundColor(Color("accentColor"))
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Right to Erasure
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Right to Erasure (Article 17)")
                                .font(.headline)
                            
                            Text("You have the right to obtain the erasure of personal data concerning you without undue delay.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button("Request Data Deletion") {
                                requestDataDeletion()
                            }
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Right to Portability
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Right to Data Portability (Article 20)")
                                .font(.headline)
                            
                            Text("You have the right to receive the personal data concerning you in a structured, commonly used and machine-readable format.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button("Download My Data") {
                                requestDataExport()
                            }
                            .foregroundColor(Color("accentColor"))
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Right to Restriction
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Right to Restriction of Processing (Article 18)")
                                .font(.headline)
                            
                            Text("You have the right to obtain restriction of processing where certain conditions apply.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button("Request Processing Restriction") {
                                requestProcessingRestriction()
                            }
                            .foregroundColor(Color("accentColor"))
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
        .alert("Data Rights Request", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func requestDataExport() {
        gdprService.requestDataExport { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    // Save data to file or share
                    alertMessage = "Data export completed. Your data has been prepared for download."
                case .failure(let error):
                    alertMessage = "Failed to export data: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
    
    private func requestDataDeletion() {
        gdprService.requestDataDeletion { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    alertMessage = "Data deletion request submitted. Your account will be anonymized within 30 days."
                case .failure(let error):
                    alertMessage = "Failed to process deletion request: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
    
    private func requestProcessingRestriction() {
        gdprService.requestProcessingRestriction { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    alertMessage = "Processing restriction request submitted. We will limit data processing as requested."
                case .failure(let error):
                    alertMessage = "Failed to process restriction request: \(error.localizedDescription)"
                }
                showAlert = true
            }
        }
    }
}

extension GDPRConsentType {
    var displayName: String {
        switch self {
        case .explicit:
            return "Explicit Consent"
        case .implied:
            return "Implied Consent"
        case .optIn:
            return "Opt-In"
        case .optOut:
            return "Opt-Out"
        }
    }
}

#Preview {
    GDPRConsentView()
}
