//
//  ReportProblemView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 12/20/24.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct ReportProblemView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedIssueType: IssueType = .technicalIssue
    @State private var comments: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSubmitting = false
    
    var body: some View {
        VStack {
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
                
                Text("Report a Problem")
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
            
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("Report a Problem", comment: ""))
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text(NSLocalizedString("Issue Type", comment: ""))
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Menu {
                        ForEach(IssueType.allCases, id: \.self) { issueType in
                            Button(action: {
                                selectedIssueType = issueType
                            }) {
                                HStack {
                                    Text(issueType.displayName)
                                    if selectedIssueType == issueType {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedIssueType.displayName)
                                .foregroundColor(Color("textColor"))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(Color("accentColor"))
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(NSLocalizedString("Additional Comments (Optional)", comment: ""))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text(NSLocalizedString("Please provide any additional details about the issue you're experiencing.", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                        
                        TextEditor(text: $comments)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .frame(minHeight: 100)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        submitReport()
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            
                            Text(isSubmitting ? NSLocalizedString("Submitting...", comment: "") : NSLocalizedString("Send Report", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color("accentColor"))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    .disabled(isSubmitting)
                    
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Report Status"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        // Save to Firestore for tracking
        saveToFirestore { success in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                if success {
                    self.alertMessage = NSLocalizedString("Report submitted successfully! We'll review it and get back to you if needed.", comment: "")
                    self.showAlert = true
                    // Clear the form after successful submission
                    self.comments = ""
                } else {
                    self.alertMessage = NSLocalizedString("Failed to submit report. Please try again.", comment: "")
                    self.showAlert = true
                }
            }
        }
    }
    
    private func saveToFirestore(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? "anonymous"
        
        let reportData: [String: Any] = [
            "issueType": selectedIssueType.displayName,
            "issueDescription": selectedIssueType.description,
            "comments": comments,
            "userId": userId,
            "timestamp": Timestamp(),
            "status": "pending",
            "deviceInfo": [
                "iOSVersion": UIDevice.current.systemVersion,
                "deviceModel": UIDevice.current.model,
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            ]
        ]
        
        db.collection("problemReports").addDocument(data: reportData) { error in
            if let error = error {
                print("Error saving problem report: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Problem report saved successfully")
                completion(true)
            }
        }
    }
}

enum IssueType: CaseIterable {
    case technicalIssue
    case accountProblem
    case contentIssue
    case playbackProblem
    case uploadIssue
    case privacyConcern
    case featureRequest
    case other
    
    var displayName: String {
        switch self {
        case .technicalIssue:
            return NSLocalizedString("Technical Issue", comment: "")
        case .accountProblem:
            return NSLocalizedString("Account Problem", comment: "")
        case .contentIssue:
            return NSLocalizedString("Content Issue", comment: "")
        case .playbackProblem:
            return NSLocalizedString("Playback Problem", comment: "")
        case .uploadIssue:
            return NSLocalizedString("Upload Issue", comment: "")
        case .privacyConcern:
            return NSLocalizedString("Privacy Concern", comment: "")
        case .featureRequest:
            return NSLocalizedString("Feature Request", comment: "")
        case .other:
            return NSLocalizedString("Other", comment: "")
        }
    }
    
    var description: String {
        switch self {
        case .technicalIssue:
            return "App crashes, bugs, or unexpected behavior"
        case .accountProblem:
            return "Issues with login, registration, or account settings"
        case .contentIssue:
            return "Inappropriate content or content-related problems"
        case .playbackProblem:
            return "Audio/video not playing correctly"
        case .uploadIssue:
            return "Problems uploading pods or media"
        case .privacyConcern:
            return "Privacy or security related concerns"
        case .featureRequest:
            return "Suggestions for new features or improvements"
        case .other:
            return "Other issues not covered above"
        }
    }
}


#Preview {
    ReportProblemView()
} 
