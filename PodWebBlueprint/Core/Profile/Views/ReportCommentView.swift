//
//  ReportCommentView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 6/11/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

struct ReportCommentView: View {
    @Environment(\.presentationMode) var mode
    @State private var selectedReason: ReportReason?
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    
    let comment: Comment
    let pod: Pod
    
    enum ReportReason: String, CaseIterable {
        case spam = "Spam"
        case inappropriate = "Inappropriate Content"
        case harassment = "Harassment"
        case falseInformation = "False Information"
        case other = "Other"
        
        var description: String {
            switch self {
            case .spam:
                return "Unwanted commercial content or repetitive posts"
            case .inappropriate:
                return "Content that violates community guidelines"
            case .harassment:
                return "Bullying, threats, or abusive behavior"
            case .falseInformation:
                return "Misleading or factually incorrect information"
            case .other:
                return "Other reasons not listed above"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        mode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Header
                VStack(spacing: 8) {
                    Text("Report Comment")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Help us understand what's happening")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 4)
                
                // Comment Preview
                VStack(spacing: 12) {
                    HStack {
                        Text("Comment being reported:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            if let user = comment.user {
                                HStack {
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    if user.isVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 12))
                                    }
                                }
                            }
                            
                            Text(comment.caption)
                                .font(.body)
                                .lineLimit(3)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Report Reason Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reason for reporting")
                        .font(.headline)
                    
                    ForEach(ReportReason.allCases, id: \.self) { reason in
                        Button(action: {
                            selectedReason = reason
                        }) {
                            HStack {
                                Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedReason == reason ? Color("accentColor") : .gray)
                                
                                Text(reason.rawValue)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                Spacer()
                
                // Submit Button
                Button(action: submitReport) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isSubmitting ? "Submitting..." : "Submit Report")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedReason != nil ? Color("accentColor") : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(selectedReason == nil || isSubmitting)
                .padding(.horizontal)
        }
        .padding()
        .alert("Report Submitted", isPresented: $showSuccessAlert) {
            Button("OK") {
                mode.wrappedValue.dismiss()
            }
        } message: {
            Text("Thank you for your report. We'll review it and take appropriate action.")
        }
    }
    
    private func submitReport() {
        guard let reason = selectedReason else { return }
        guard let currentUser = Auth.auth().currentUser else { return }
        
        isSubmitting = true
        
        let db = Firestore.firestore()
        var reportData: [String: Any] = [
            "commentId": comment.id ?? "",
            "commentText": comment.caption,
            "commentUserId": comment.uid,
            "commentUsername": comment.user?.username ?? "Unknown",
            "podId": pod.id ?? "",
            "podTitle": pod.title,
            "reporterId": currentUser.uid,
            "reason": reason.rawValue,
            "timestamp": Timestamp(),
            "status": "pending"
        ]
        
        // Fetch reporter's username
        db.collection("users").document(currentUser.uid).getDocument { document, error in
            if let document = document, document.exists, let username = document.data()?["username"] as? String {
                reportData["reporterUsername"] = username
            }
            
            // Submit the report
            db.collection("commentReports").addDocument(data: reportData) { error in
                DispatchQueue.main.async {
                    isSubmitting = false
                    
                    if let error = error {
                        print("Error submitting report: \(error.localizedDescription)")
                        // You could show an error alert here
                    } else {
                        showSuccessAlert = true
                        // Clear the form after successful submission
                        selectedReason = nil
                    }
                }
            }
        }
    }
}

#Preview {
    ReportCommentView(
        comment: PreviewClass().previewComment,
        pod: PreviewClass().previewPod
    )
} 
