import SwiftUI

struct TermsAndPoliciesView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedSection: PolicySection = .terms
    
    enum PolicySection {
        case terms
        case privacy
    }
    
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
                
                Text("Terms & Policies")
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
            
            // Section Picker
            Picker("Section", selection: $selectedSection) {
                Text("Terms of Service").tag(PolicySection.terms)
                Text("Privacy Policy").tag(PolicySection.privacy)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedSection {
                    case .terms:
                        termsOfServiceContent
                    case .privacy:
                        privacyPolicyContent
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
    }
    
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Terms of Service")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last Updated: October 21, 2025")
                    .foregroundColor(.gray)
                
                Text("1. Acceptance of Terms")
                    .font(.headline)
                Text("By accessing and using In-Tuned, you agree to be bound by these Terms of Service and all applicable laws and regulations. If you do not agree to these terms, you may not use our service.")
                
                Text("2. Description of Service")
                    .font(.headline)
                Text("In-Tuned is a social podcast platform that allows users to upload, share, discover, and engage with audio content. Our service includes: podcast uploading (manual and RSS feed import), AI-powered content recommendations, social features (following, direct messaging, comments, replies), playlists, reposts, content discovery (trending, categories, moods), notifications, and community interaction tools.")
                
                Text("3. User Accounts")
                    .font(.headline)
                Text("3.1 Account Creation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• You must provide accurate and complete information when creating an account\n• You must be at least 13 years old to use our service\n• You are responsible for maintaining the confidentiality of your account credentials\n• You are responsible for all activities that occur under your account")
                
                Text("3.2 Account Security")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Notify us immediately of any unauthorized use of your account\n• Use strong passwords and enable two-factor authentication when available\n• Do not share your account credentials with others")
                
                Text("4. Content Ownership and Licensing")
                    .font(.headline)
                Text("4.1 Your Content")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• You retain ownership of all original content you create and upload\n• You are solely responsible for your content and its legality\n• You must have all necessary rights to any content you upload")
                
                Text("4.2 License to Us")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• By uploading content, you grant us a worldwide, non-exclusive, royalty-free license to host, display, distribute, and promote your content\n• This license allows us to operate and improve our platform\n• You may revoke this license by deleting your content")
                
                Text("4.3 Content Moderation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• We reserve the right to review, moderate, and remove content that violates these terms\n• We may use automated systems (including profanity filters) and human moderators to review content\n• We are not obligated to monitor all content but may do so at our discretion\n• Content filtering may apply to usernames, profile information, podcast titles/descriptions, tags, comments, and messages")
                
                Text("5. Prohibited Content and Activities")
                    .font(.headline)
                Text("You may not use our service to:")
                
                Text("5.1 Illegal Content")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Post content that violates any applicable laws or regulations\n• Share content that infringes on intellectual property rights\n• Upload content that contains malware or harmful code")
                
                Text("5.2 Harmful Content")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Content that is threatening, abusive, harassing, or defamatory\n• Content that promotes violence, hate speech, or discrimination\n• Content that is sexually explicit or inappropriate for general audiences")
                
                Text("5.3 Spam and Commercial Use")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Send unsolicited messages or spam\n• Use the service for unauthorized commercial purposes\n• Attempt to gain unauthorized access to our systems")
                
                Text("6. Community Guidelines")
                    .font(.headline)
                Text("6.1 Respectful Behavior")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Treat all users with respect and kindness\n• Engage in constructive discussions and feedback\n• Report inappropriate behavior through our reporting system")
                
                Text("6.2 Content Standards")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Create original, high-quality content\n• Give proper attribution when using others' work\n• Respect copyright and intellectual property rights")
                
                Text("7. Intellectual Property Rights")
                    .font(.headline)
                Text("7.1 Our Rights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• In-Tuned and its technology are protected by intellectual property laws\n• You may not copy, modify, or distribute our platform without permission\n• Our trademarks and logos are our exclusive property")
                
                Text("7.2 Third-Party Rights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Respect the intellectual property rights of others\n• Do not upload content that infringes on third-party rights\n• We will respond to valid DMCA takedown notices")
                
                Text("8. Privacy and Data Protection")
                    .font(.headline)
                Text("• Your privacy is important to us. Please review our Privacy Policy for details on how we collect, use, and protect your information\n• We comply with applicable data protection laws including GDPR and CCPA\n• You have rights regarding your personal data as outlined in our Privacy Policy")
                
                Text("9. Disclaimers and Limitations of Liability")
                    .font(.headline)
                Text("9.1 Service Availability")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• We provide our service 'as is' without warranties of any kind\n• We do not guarantee uninterrupted or error-free service\n• We may modify or discontinue features at any time")
                
                Text("9.2 Limitation of Liability")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• We are not liable for any indirect, incidental, or consequential damages\n• Our total liability is limited to the amount you paid for our service\n• We are not responsible for user-generated content or third-party actions")
                
                Text("10. Indemnification")
                    .font(.headline)
                Text("You agree to indemnify and hold us harmless from any claims, damages, or expenses arising from your use of our service, violation of these terms, or infringement of any rights of another party.")
                
                Text("11. Account Termination")
                    .font(.headline)
                Text("11.1 Termination by You")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• You may delete your account at any time through account settings\n• Upon termination, your content may be deleted according to our data retention policy\n• Some data may be retained for legal or operational purposes")
                
                Text("11.2 Termination by Us")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• We may suspend or terminate your account for violations of these terms\n• We may terminate accounts that are inactive for extended periods\n• We will provide notice when possible before termination")
                
                Text("12. Dispute Resolution")
                    .font(.headline)
                Text("12.1 Governing Law")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• These terms are governed by the laws of [Your Jurisdiction]\n• Any disputes will be resolved in the courts of [Your Jurisdiction]")
                
                Text("12.2 Arbitration")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• For disputes under $10,000, either party may elect binding arbitration\n• Arbitration will be conducted by a neutral arbitrator\n• You waive the right to participate in class action lawsuits")
                
                Text("13. Changes to Terms")
                    .font(.headline)
                Text("We may update these Terms of Service from time to time. We will notify you of material changes by posting the updated terms on our platform. Your continued use of our service after such changes constitutes acceptance of the updated terms.")
                
                Text("14. Severability")
                    .font(.headline)
                Text("If any provision of these terms is found to be unenforceable, the remaining provisions will remain in full force and effect.")
                
                Text("15. Contact Information")
                    .font(.headline)
                Text("If you have questions about these Terms of Service, please contact us at:\n\nEmail: dev@attunedapp.net")
            }
        }
    }
    
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last Updated: October 21, 2025")
                    .foregroundColor(.gray)
                
                Text("1. Information We Collect")
                    .font(.headline)
                Text("We collect several types of information to provide and improve our podcast platform services:")
                
                Text("1.1 Personal Information")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Account Information: Username, email address, full name, profile image, bio, and links\n• Authentication Data: Firebase authentication tokens and session information")
                
                Text("1.2 Content and Communications")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• User-Generated Content: Podcasts (audio files via manual upload or RSS import), podcast metadata (titles, descriptions, tags/keywords), comments, replies, reposts, playlists, and profile content (bio, links)\n• Private Communications: Direct messages, conversation data, and message history\n• Social Data: Followers, following lists, blocked users, follow requests, and user interaction data (likes, saves, plays)")
                
                Text("1.3 Usage and Behavioral Data")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Preferences: Category weights, keyword interactions, mood preferences, and personalized content recommendations\n• Activity Data: Last interaction timestamps, listening history, engagement metrics (likes, comments, plays), search queries, and content discovery patterns\n• Notification Settings: Push notification preferences, quiet hours, and notification delivery tokens (FCM)\n• RSS Subscriptions: RSS feed URLs, imported episodes, and subscription management data")
                
                Text("1.4 Technical Data")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Device Information: FCM tokens, device identifiers, and operating system\n• Usage Analytics: App interactions, feature usage, and performance data\n• Network Data: IP addresses and connection information")
                
                Text("2. How We Use Your Information")
                    .font(.headline)
                Text("We use your information for the following purposes:")
                
                Text("2.1 Service Provision")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Provide and maintain our podcast platform services\n• Enable user authentication and account management\n• Facilitate content creation, sharing, and discovery\n• Support social features like following and messaging")
                
                Text("2.2 Personalization and Improvement")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Personalize content recommendations using AI and machine learning algorithms based on your listening history, preferences, and interactions\n• Curate explore sections (Trending, New & Noteworthy, Top Charts, Featured)\n• Suggest content by category, mood, and keywords\n• Improve our services based on usage patterns and user feedback\n• Develop new features and functionality\n• Conduct research and analytics to enhance user experience")
                
                Text("2.3 Communication and Notifications")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Send push notifications about activity and updates\n• Provide customer support and respond to inquiries\n• Send important service announcements\n• Deliver personalized content recommendations")
                
                Text("2.4 Safety and Security")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Moderate content and enforce community guidelines using automated filters (including profanity detection) and human review\n• Filter inappropriate language in usernames, profiles, podcast content, tags, comments, and messages\n• Detect and prevent fraud, abuse, spam, and security threats\n• Process user reports and handle content violations\n• Ensure platform safety and user protection\n• Comply with legal obligations, law enforcement requests, and regulatory requirements (GDPR, CCPA, COPPA)")
                
                Text("3. Information Sharing and Disclosure")
                    .font(.headline)
                Text("We do not sell your personal information. We may share information in the following circumstances:")
                
                Text("3.1 Service Providers")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Firebase/Google: For authentication, Firestore database, Cloud Storage (audio files, images), push notifications (FCM), and analytics\n• Cloud Infrastructure: For hosting, content delivery (CDN), and media processing\n• AI/ML Services: For content recommendations and personalization algorithms\n• Third-party vendors: For specific technical services, email delivery, and platform operations")
                
                Text("3.2 Legal Requirements")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Law enforcement: When required by legal process or court order\n• Legal compliance: To comply with applicable laws and regulations\n• Safety protection: To protect user safety and platform integrity")
                
                Text("3.3 Business Transfers")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Mergers and acquisitions: In connection with business transfers\n• Asset sales: When transferring platform assets to third parties")
                
                Text("4. Data Security and Protection")
                    .font(.headline)
                Text("We implement comprehensive security measures to protect your information:")
                
                Text("4.1 Technical Safeguards")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Encryption: Data encrypted in transit and at rest\n• Access Controls: Role-based access and authentication\n• Monitoring: Continuous security monitoring and threat detection\n• Regular Updates: Security patches and system updates")
                
                Text("4.2 Administrative Safeguards")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Staff Training: Regular security awareness training\n• Data Minimization: Collect only necessary information\n• Regular Audits: Security assessments and compliance reviews")
                
                Text("5. Data Retention and Deletion")
                    .font(.headline)
                Text("We retain your information for different periods based on purpose:")
                
                Text("5.1 Retention Periods")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Account Data: Until account deletion or 3 years of inactivity\n• Uploaded Content: Podcasts, playlists, and reposts remain until you delete them or account is closed\n• RSS Feed Data: Subscription information and imported episodes until subscription is removed\n• Comments and Replies: Until deleted by you or when associated content is removed\n• Direct Messages: Until conversation is deleted or 1 year of inactivity\n• Analytics and Usage Data: Up to 2 years in aggregated, anonymized form\n• Preference Data: Stored for personalization until account deletion or reset")
                
                Text("5.2 Deletion Rights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Account Deletion: Complete removal of personal data\n• Content Deletion: Removal of specific content upon request\n• Data Export: Right to receive your data in portable format")
                
                Text("6. Your Rights and Choices")
                    .font(.headline)
                Text("You have the following rights regarding your personal information:")
                
                Text("6.1 Access and Control")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Access: View and download your personal data\n• Correction: Update or correct inaccurate information\n• Deletion: Request deletion of your personal data\n• Portability: Receive your data in a structured format")
                
                Text("6.2 Communication Preferences")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Notification Settings: Control push notification preferences\n• Privacy Settings: Manage account privacy and visibility\n• Data Sharing: Opt out of certain data processing activities")
                
                Text("6.3 Exercising Your Rights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("• Contact Us: Email us at dev@attunedapp.net\n• Account Settings: Use in-app privacy and account controls\n• Response Time: We will respond within 30 days of receiving your request")
                
                Text("7. International Data Transfers")
                    .font(.headline)
                Text("Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place for international transfers, including standard contractual clauses and adequacy decisions.")
                
                Text("8. Children's Privacy")
                    .font(.headline)
                Text("Our service is not intended for children under 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected such information, we will take steps to delete it promptly.")
                
                Text("9. Changes to This Policy")
                    .font(.headline)
                Text("We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy on our platform and updating the 'Last Updated' date. Your continued use of our service after such changes constitutes acceptance of the updated policy.")
                
                Text("10. Contact Information")
                    .font(.headline)
                Text("If you have questions about this Privacy Policy or our data practices, please contact us at:\n\nEmail: dev@attunedapp.net")
            }
        }
    }
}

#Preview {
    TermsAndPoliciesView()
} 