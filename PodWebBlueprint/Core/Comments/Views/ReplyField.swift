//
//  ConversationView.swift
//  CryptChat
//
//  Created by Connor Adams on 8/10/22.
//

import SwiftUI
import Firebase

struct ReplyField: View {
    @State private var message = ""
    @State private var showProfanityAlert = false
    @State private var alertMessage = ""
    @ObservedObject var commentRowViewModel: CommentRowViewModel
    
    let pod: Pod
    let comment: Comment
    
    init(pod: Pod, comment: Comment, commentRowViewModel: CommentRowViewModel) {
        self.commentRowViewModel = commentRowViewModel
        self.pod = pod
        self.comment = comment
    }
    
    
    var body: some View {
        HStack(spacing: 12) {
            CustomTextField(placeholder: Text("New Reply..."), text: $message)
            
            Button {
                // Sanitize reply before sending
                let result = InputSanitizer.sanitize(message, type: .comment)
                
                if result.isValid {
                    // Reply is clean, proceed with upload
                    commentRowViewModel.replyToComment(pod: pod, caption: result.sanitizedText)
                    message = ""
                } else {
                    // Show error alert
                    alertMessage = result.errorMessage ?? "Invalid input"
                    showProfanityAlert = true
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(
                                message.isEmpty ? 
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) : 
                                LinearGradient(
                                    gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: message.isEmpty ? Color.clear : Color("accentColor").opacity(0.3),
                                radius: message.isEmpty ? 0 : 6,
                                x: 0,
                                y: 3
                            )
                    )
            }
            .disabled(message.isEmpty)
            .scaleEffect(message.isEmpty ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: message.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
        .alert("Cannot Post Reply", isPresented: $showProfanityAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct ReplyField_Previews: PreviewProvider {
    static var previews: some View {
        ReplyField(
            pod: PreviewClass().previewPod, 
            comment: PreviewClass().previewComment,
            commentRowViewModel: CommentRowViewModel(comment: PreviewClass().previewComment, pod: PreviewClass().previewPod)
        )
    }
}
