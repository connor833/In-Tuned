//
//  COPPAComplianceView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/19/24.
//

import SwiftUI

struct COPPAComplianceView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var coppaService = COPPAComplianceService()
    @State private var isUnder13 = false
    @State private var hasParentalConsent = false
    @State private var parentEmail = ""
    @State private var parentName = ""
    @State private var showParentalConsentForm = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var parentalControls = [COPPAParentalControl]()
    
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
                
                Text("COPPA Compliance")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Age Verification
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Children's Online Privacy Protection Act (COPPA)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("COPPA protects the privacy of children under 13. We have special requirements for users under 13.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Toggle("I am under 13 years old", isOn: $isUnder13)
                            .onChange(of: isUnder13) { newValue in
                                coppaService.setUserAgeStatus(isUnder13: newValue)
                                if newValue {
                                    showParentalConsentForm = true
                                }
                            }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    if isUnder13 {
                        // Parental Consent Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Parental Consent Required")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            if hasParentalConsent {
                                Text("✅ Parental consent has been verified")
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            } else {
                                Text("❌ Parental consent is required to use this app")
                                    .foregroundColor(.red)
                                    .fontWeight(.semibold)
                                
                                Button("Request Parental Consent") {
                                    showParentalConsentForm = true
                                }
                                .foregroundColor(Color("accentColor"))
                            }
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Data Collection Restrictions
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Data Collection Restrictions")
                                .font(.headline)
                            
                            Text("For users under 13, we have strict limits on data collection:")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• No personal information collection without parental consent")
                                Text("• No location data collection")
                                Text("• No behavioral tracking")
                                Text("• No audio data collection")
                                Text("• No photo collection")
                                Text("• No contact information collection")
                                Text("• Limited device information collection")
                                Text("• No usage analytics")
                                Text("• No preference tracking")
                                Text("• No social data collection")
                            }
                            .font(.body)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Parental Controls
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Parental Controls")
                                .font(.headline)
                            
                            Text("Parents can control their child's account through these options:")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            ForEach(parentalControls) { control in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(control.name)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text(control.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { control.isEnabled },
                                        set: { newValue in
                                            var updatedControl = control
                                            updatedControl.isEnabled = newValue
                                            coppaService.updateParentalControl(updatedControl)
                                        }
                                    ))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Account Deletion
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Account Deletion")
                                .font(.headline)
                            
                            Text("Parents can request immediate deletion of their child's account and all associated data.")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button("Delete Child Account") {
                                requestChildAccountDeletion()
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.red, lineWidth: 2)
                            )
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                    } else {
                        // Adult User Information
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Adult User")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("As an adult user (13 or older), you have full access to all app features and data collection practices as outlined in our Privacy Policy.")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // COPPA Information
                    VStack(alignment: .leading, spacing: 15) {
                        Text("About COPPA")
                            .font(.headline)
                        
                        Text("The Children's Online Privacy Protection Act (COPPA) requires websites and online services to obtain parental consent before collecting personal information from children under 13.")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Protects children's privacy online")
                            Text("• Requires parental consent for data collection")
                            Text("• Limits data collection from children")
                            Text("• Gives parents control over their child's data")
                            Text("• Requires immediate data deletion upon request")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showParentalConsentForm) {
            ParentalConsentFormView(
                parentEmail: $parentEmail,
                parentName: $parentName,
                onConsentGiven: { email, name in
                    recordParentalConsent(email: email, name: name)
                }
            )
        }
        .alert("COPPA Compliance", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            loadCurrentStatus()
        }
    }
    
    private func loadCurrentStatus() {
        isUnder13 = coppaService.isUserUnder13()
        hasParentalConsent = coppaService.hasParentalConsent()
        parentalControls = coppaService.getParentalControlOptions()
    }
    
    private func recordParentalConsent(email: String, name: String) {
        coppaService.recordParentalConsent(
            parentEmail: email,
            parentName: name,
            consentGiven: true,
            verificationMethod: .emailVerification
        )
        
        hasParentalConsent = true
        alertMessage = "Parental consent has been recorded. Your child can now use the app with appropriate restrictions."
        showAlert = true
    }
    
    private func requestChildAccountDeletion() {
        coppaService.requestChildDataDeletion { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.alertMessage = "Child account deletion request submitted. The account will be deleted immediately for COPPA compliance."
                case .failure(let error):
                    self.alertMessage = "Failed to process deletion request: \(error.localizedDescription)"
                }
                self.showAlert = true
            }
        }
    }
}

struct ParentalConsentFormView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var parentEmail: String
    @Binding var parentName: String
    let onConsentGiven: (String, String) -> Void
    
    @State private var consentGiven = false
    @State private var verificationMethod: COPPAConsentVerificationMethod = .emailVerification
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Parental Consent Form")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Information Section
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Parental Consent Required")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            Text("Under COPPA, we need parental consent to collect personal information from children under 13. Please provide the following information:")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Form Fields
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Parent Information")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Parent Name")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                TextField("Enter parent's full name", text: $parentName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Parent Email")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                TextField("Enter parent's email address", text: $parentEmail)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Verification Method")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Picker("Verification Method", selection: $verificationMethod) {
                                    ForEach(COPPAConsentVerificationMethod.allCases, id: \.self) { method in
                                        Text(method.displayName).tag(method)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Consent Checkbox
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Consent Declaration")
                                .font(.headline)
                            
                            Toggle("I am the parent/legal guardian and give consent for my child to use this app", isOn: $consentGiven)
                            
                            Text("By checking this box, you confirm that you are the parent or legal guardian of the child and consent to the collection and use of personal information as described in our Privacy Policy.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Data Collection Information
                        VStack(alignment: .leading, spacing: 15) {
                            Text("What Information We Collect")
                                .font(.headline)
                            
                            Text("With parental consent, we may collect:")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("• Basic account information (username, email)")
                                Text("• Content created by the child (pods, comments)")
                                Text("• Usage data to improve the service")
                                Text("• Communication data (messages, notifications)")
                            }
                            .font(.body)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                        
                        // Action Buttons
                        VStack(spacing: 15) {
                            Button(action: {
                                if consentGiven && !parentName.isEmpty && !parentEmail.isEmpty {
                                    onConsentGiven(parentEmail, parentName)
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }) {
                                Text("Submit Parental Consent")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(consentGiven && !parentName.isEmpty && !parentEmail.isEmpty ? Color("accentColor") : Color.gray)
                                    .cornerRadius(10)
                            }
                            .disabled(!consentGiven || parentName.isEmpty || parentEmail.isEmpty)
                            
                            Button("Cancel") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .foregroundColor(Color("accentColor"))
                        }
                        .padding(.top)
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

extension COPPAConsentVerificationMethod {
    var displayName: String {
        switch self {
        case .emailVerification:
            return "Email Verification"
        case .phoneVerification:
            return "Phone Verification"
        case .postalMail:
            return "Postal Mail"
        case .videoCall:
            return "Video Call"
        case .inPerson:
            return "In Person"
        }
    }
}

#Preview {
    COPPAComplianceView()
}
