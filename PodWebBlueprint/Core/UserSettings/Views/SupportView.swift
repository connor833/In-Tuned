import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore

struct SupportView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedFAQ: FAQ? = nil
    @State private var showHelpRequest = false
    
    let faqs = [
        FAQ(question: "How do I upload a podcast episode?", answer: "Tap the '+' button in the Feed tab. You can either manually upload an audio file (select from your device or record) or import episodes from an RSS feed. For manual uploads, add a title, description, thumbnail, and optional tags. Your upload will process in the background."),
        FAQ(question: "What's the difference between manual upload and RSS import?", answer: "Manual upload: Upload individual episodes one at a time from your device. Perfect for original content.\n\nRSS import: Subscribe to an existing podcast RSS feed to automatically import episodes. Great for sharing your existing podcast from other platforms."),
        FAQ(question: "How do I import my podcast from an RSS feed?", answer: "Tap '+' button, then select 'Import from RSS'. Enter your RSS feed URL (from platforms like Anchor, Spotify, Apple Podcasts). The app will fetch all episodes and let you select which ones to import. You can also subscribe to automatically check for new episodes."),
        FAQ(question: "How does the AI recommendation system work?", answer: "In-Tuned learns from your interactions (what you play, like, save, and comment on) to personalize your feed. We track category preferences, keyword interactions, and listening patterns to suggest content you'll enjoy. You can see personalized content in your Feed and Explore sections."),
        FAQ(question: "What are the Explore sections?", answer: "Trending: Popular episodes from the past week (or latest if no recent content)\n\nNew & Noteworthy: Recently posted episodes from the past week\n\nTop Charts: Most-liked episodes of all time\n\nFeatured: High-quality episodes curated by our algorithm\n\nCategories & Moods: Browse by topic or vibe"),
        FAQ(question: "How do I create playlists?", answer: "Go to your profile, tap the '+' icon in the Playlists section. Add a title, thumbnail, and select episodes to include. Playlists are public and can be liked and saved by other users."),
        FAQ(question: "What are reposts and how do they work?", answer: "Reposts let you share someone else's podcast episode to your profile with optional commentary. Tap the repost icon on any episode, add your thoughts (optional), and it will appear on your profile. The original creator is always credited."),
        FAQ(question: "How do comments and replies work?", answer: "Tap on any podcast episode to see comments. You can add a comment, like comments, or reply to existing comments. All comments and replies are moderated for inappropriate language."),
        FAQ(question: "Can I send direct messages to other users?", answer: "Yes! Go to someone's profile and tap the message icon, or use the Messages tab to see all your conversations. You can send text messages or share podcast episodes directly. Messages are private between you and the recipient."),
        FAQ(question: "How do I block or unblock users?", answer: "Visit the user's profile, tap the three dots menu, and select 'Block User'. Blocked users cannot see your content, message you, or interact with your posts. You can unblock users anytime from their profile or in Account Settings > Blocked Users."),
        FAQ(question: "What happens when I follow someone?", answer: "Following someone adds their content to your personalized feed. You'll see their new uploads prioritized based on the AI recommendation system. If their account is private, they'll need to approve your follow request first."),
        FAQ(question: "How do notifications work?", answer: "You'll receive push notifications for: new followers, likes on your content, comments and replies, direct messages, follow requests (if private account), and system announcements. Manage notification preferences in Settings > Notifications."),
        FAQ(question: "What is quiet hours?", answer: "Quiet hours silences non-critical notifications during times you specify (e.g., 10 PM - 8 AM). You can enable this in Settings > Notifications > Quiet Hours. Important notifications may still come through."),
        FAQ(question: "Why was my content flagged or rejected?", answer: "In-Tuned uses automated profanity filters to maintain a safe community. Content may be rejected if it contains inappropriate language in: usernames, full names, bios, podcast titles/descriptions, tags, comments, or messages. Edit your content to remove inappropriate language and try again."),
        FAQ(question: "How do I delete my account?", answer: "Go to Settings > Account Settings > Delete Account. This will permanently delete your account, all your uploaded content, playlists, messages, and personal data. This action cannot be undone."),
        FAQ(question: "How do I download my data?", answer: "Go to Settings > Account Settings > Download Your Data. You'll receive an export of your account information, uploaded content metadata, and activity data. This may take a few minutes to prepare."),
        FAQ(question: "Why can't I upload my file?", answer: "Common issues:\n• File too large: Videos are automatically compressed. Very large files may take time.\n• Wrong format: We support MP3, M4A, WAV, MP4, MOV, and other common audio/video formats.\n• Network issue: Check your internet connection.\n• Queue full: Wait for current uploads to complete (max 3 concurrent uploads).")
    ]
    
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
                
                Text("Support")
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
                    // Welcome Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome to In-Tuned Support")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("We're here to help you get the most out of your podcasting experience.")
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    
                    // FAQs Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Frequently Asked Questions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(faqs) { faq in
                            FAQRow(faq: faq, isExpanded: selectedFAQ?.id == faq.id) {
                                withAnimation {
                                    if selectedFAQ?.id == faq.id {
                                        selectedFAQ = nil
                                    } else {
                                        selectedFAQ = faq
                                    }
                                }
                            }
                        }
                    }
                    
                    // Contact Support Button
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Need More Help?")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Button {
                            showHelpRequest = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(Color("accentColor"))
                                Text("Contact Support")
                                    .foregroundColor(Color("textColor"))
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color("accentColor").opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color("accentColor"), lineWidth: 2)
                                    )
                            )
                            .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Additional Resources
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Additional Resources")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        NavigationLink(destination: CommunityGuidelinesView()) {
                            HStack {
                                Text("Community Guidelines")
                                    .foregroundColor(Color("textColor"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showHelpRequest) {
            HelpRequestForm()
        }
    }
}

// MARK: - Supporting Views

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color("accentColor"))
                Text(title)
                    .foregroundColor(Color("textColor"))
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

struct FAQRow: View {
    let faq: FAQ
    let isExpanded: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: action) {
                HStack {
                    Text(faq.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("textColor"))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }
            
            if isExpanded {
                Text(faq.answer)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct ResourceLink: View {
    let title: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Text(title)
                    .foregroundColor(Color("textColor"))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

// MARK: - Help Request Form

struct HelpRequestForm: View {
    @Environment(\.dismiss) var dismiss
    @State private var subject = ""
    @State private var message = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header text
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How can we help you?")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Describe your issue or question and we'll get back to you at your registered email address.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Subject field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subject")
                            .font(.headline)
                        
                        TextField("Brief description of your issue", text: $subject)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal)
                    
                    // Message field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message")
                            .font(.headline)
                        
                        TextEditor(text: $message)
                            .frame(minHeight: 150)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            )
                        
                        Text("\(message.count)/1000 characters")
                            .font(.caption)
                            .foregroundColor(message.count > 900 ? .orange : .secondary)
                    }
                    .padding(.horizontal)
                    
                    // Info text
                    VStack(alignment: .leading, spacing: 5) {
                        Text("We'll respond to your registered email address:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let email = Auth.auth().currentUser?.email {
                            Text(email)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Color("accentColor"))
                        }
                    }
                    .padding(.horizontal)
                    
                    // Submit button
                    Button {
                        submitHelpRequest()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isSubmitting ? "Submitting..." : "Submit Request")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color("accentColor").opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(subject.isEmpty || message.isEmpty || isSubmitting)
                    .opacity((subject.isEmpty || message.isEmpty || isSubmitting) ? 0.5 : 1.0)
                    .padding(.horizontal)
                    .padding(.top, 10)
                }
                .padding(.vertical)
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Request Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for contacting us! We'll respond to your email within 1-2 business days.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitHelpRequest() {
        guard let currentUser = Auth.auth().currentUser else {
            errorMessage = "You must be logged in to submit a support request."
            showError = true
            return
        }
        
        guard !subject.isEmpty, !message.isEmpty else { return }
        
        // Limit message length
        let trimmedMessage = String(message.prefix(1000))
        
        isSubmitting = true
        
        let db = Firestore.firestore()
        let requestData: [String: Any] = [
            "userId": currentUser.uid,
            "userEmail": currentUser.email ?? "No email",
            "subject": subject,
            "message": trimmedMessage,
            "timestamp": Timestamp(),
            "status": "pending",
            "deviceInfo": [
                "iOSVersion": UIDevice.current.systemVersion,
                "deviceModel": UIDevice.current.model,
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            ]
        ]
        
        db.collection("support-requests").addDocument(data: requestData) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                
                if let error = error {
                    print("❌ Error submitting support request: \(error.localizedDescription)")
                    errorMessage = "Failed to submit request. Please try again or email us at dev@attunedapp.net"
                    showError = true
                } else {
                    print("✅ Support request submitted successfully")
                    showSuccess = true
                    // Clear form
                    subject = ""
                    message = ""
                }
            }
        }
    }
}

// MARK: - Models

struct FAQ: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

#Preview {
    SupportView()
} 