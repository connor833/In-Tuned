import SwiftUI
import Firebase

struct ReportPodView: View {
    @Environment(\.presentationMode) var mode
    @State private var selectedReason = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @FocusState private var isTextFieldFocused: Bool
    
    let pod: Pod
    let user: User
    
    private let reportReasons = [
        "Inappropriate Content",
        "Spam or Misleading",
        "Harassment or Bullying",
        "Violence or Harmful Content",
        "Copyright Infringement",
        "Other"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Report Pod")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Help us understand what's happening")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top)
                
                // Pod Info
                VStack(spacing: 12) {
                    HStack {
                        Text("Pod being reported:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pod.title)
                                .font(.headline)
                                .lineLimit(2)
                            
                            Text("by @\(pod.user?.username ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.gray)
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
                    
                    ForEach(reportReasons, id: \.self) { reason in
                        Button(action: {
                            selectedReason = reason
                        }) {
                            HStack {
                                Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedReason == reason ? Color("accentColor") : .gray)
                                
                                Text(reason)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // Description Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Additional details (optional)")
                        .font(.headline)
                    
                    TextField("Please provide any additional context...", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .submitLabel(.return)
                        .focused($isTextFieldFocused)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    isTextFieldFocused = false
                                }
                                .foregroundColor(Color("accentColor"))
                                .fontWeight(.semibold)
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
                    .background(selectedReason.isEmpty ? Color.gray : Color("accentColor"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(selectedReason.isEmpty || isSubmitting)
                .padding(.horizontal)
            }
            .padding()
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        mode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .alert("Report Submitted", isPresented: $showSuccessAlert) {
                Button("OK") {
                    mode.wrappedValue.dismiss()
                }
            } message: {
                Text("Thank you for your report. We'll review it and take appropriate action.")
            }
        }
    }
    
    
    private func submitReport() {
        guard !selectedReason.isEmpty else { return }
        
        isSubmitting = true
        
        let db = Firestore.firestore()
        let reportData: [String: Any] = [
            "podId": pod.id ?? "",
            "podTitle": pod.title,
            "podUserId": pod.userId,
            "reporterId": user.uid,
            "reporterUsername": user.username,
            "reason": selectedReason,
            "description": description,
            "timestamp": Timestamp(),
            "status": "pending"
        ]
        
        db.collection("podReports").addDocument(data: reportData) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                
                if let error = error {
                    print("Error submitting report: \(error.localizedDescription)")
                    // You could show an error alert here
                } else {
                    showSuccessAlert = true
                    // Clear the form after successful submission
                    selectedReason = ""
                    description = ""
                }
            }
        }
    }
}

struct ReportPodView_Previews: PreviewProvider {
    static var previews: some View {
        ReportPodView(
            pod: PreviewClass().previewPod,
            user: PreviewClass().previewUser
        )
    }
} 