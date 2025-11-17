import SwiftUI
import Firebase
import FirebaseAuth

struct ReportUserView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedReason = ""
    @State private var additionalDetails = ""
    @State private var showingConfirmation = false
    @State private var isSubmitting = false
    
    let user: User
    
    let reportReasons = [
        "Inappropriate Content",
        "Harassment",
        "Spam",
        "Impersonation",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Why are you reporting this user?")) {
                    Picker("Select a reason", selection: $selectedReason) {
                        Text("Select a reason").tag("")
                        ForEach(reportReasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }
                }
                
                Section(header: Text("Additional Details")) {
                    TextEditor(text: $additionalDetails)
                        .frame(height: 100)
                }
                
                Section {
                    Button(action: {
                        submitReport()
                    }) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.red)
                            } else {
                                Text("Submit Report")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .disabled(selectedReason.isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Report Submitted", isPresented: $showingConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your report. We will review it and take appropriate action.")
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        let db = Firestore.firestore()
        let reporterId = Auth.auth().currentUser?.uid ?? "anonymous"
        
        let reportData: [String: Any] = [
            "reportedUserId": user.uid,
            "reportedUserUsername": user.username,
            "reporterId": reporterId,
            "reason": selectedReason,
            "additionalDetails": additionalDetails,
            "timestamp": Timestamp(),
            "status": "pending",
            "deviceInfo": [
                "iOSVersion": UIDevice.current.systemVersion,
                "deviceModel": UIDevice.current.model,
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            ]
        ]
        
        db.collection("userReports").addDocument(data: reportData) { error in
            DispatchQueue.main.async {
                self.isSubmitting = false
                
                if let error = error {
                    print("Error submitting user report: \(error.localizedDescription)")
                    // You could show an error alert here
                } else {
                    self.showingConfirmation = true
                    // Clear the form after successful submission
                    self.selectedReason = ""
                    self.additionalDetails = ""
                }
            }
        }
    }
}

struct ReportUserView_Previews: PreviewProvider {
    static var previews: some View {
        ReportUserView(user: PreviewClass().previewUser)
    }
} 