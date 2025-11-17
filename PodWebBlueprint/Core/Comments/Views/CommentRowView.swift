//  CommentRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/22/23.
//

import SwiftUI
import Kingfisher
import FirebaseAuth

struct CommentRowView: View {
    @State var isLoading = false
    @State private var expanded: Bool = false
    @State private var truncated: Bool = false
    @ObservedObject var commentRowViewModel: CommentRowViewModel
    let lineLimit = 2
    @State private var isCooldownActive = false
    @State private var showingActionSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingReportSheet = false
    @State private var deleteSuccess = false

    
    @State var isPresented = false
    @State var showingProfile = false
    
    let comment: Comment
    let pod: Pod
    let onDelete: ((Comment) -> Void)?
    let onPodSelected: ((Pod) -> Void)?
    let onReply: ((Comment) -> Void)? // Add reply callback
    
    init(comment: Comment, pod: Pod, onDelete: ((Comment) -> Void)? = nil, onPodSelected: ((Pod) -> Void)? = nil, onReply: ((Comment) -> Void)? = nil) {
        self.commentRowViewModel = CommentRowViewModel(comment: comment, pod: pod)
        self.comment = comment
        self.pod = pod
        self.onDelete = onDelete
        self.onPodSelected = onPodSelected
        self.onReply = onReply
    }
    
    private var moreLessText: String {
            if !truncated {
                return ""
            } else {
                return self.expanded ? "read less" : " read more"
            }
        }
    
    var body: some View {
        if let user = commentRowViewModel.comment.user {
            VStack(spacing: 0) {
                // Modern Comment Card
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        // Profile Image
                        Button {
                            showingProfile = true
                        } label: {
                            if let profileImageUrl = commentRowViewModel.comment.user?.profileImageUrl, !profileImageUrl.isEmpty {
                                KFImage(URL(string: profileImageUrl))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .sheet(isPresented: $showingProfile) {
                            if #available(iOS 16.0, *) {
                                ProfileView(user: commentRowViewModel.comment.user ?? PreviewClass().previewUser) { selectedPod in
                                    // Dismiss the profile sheet
                                    showingProfile = false
                                    
                                    // Notify parent view about pod selection
                                    onPodSelected?(selectedPod)
                                }
                                .presentationDetents([.large])
                                .presentationDragIndicator(.visible)
                            } else {
                                ProfileView(user: commentRowViewModel.comment.user ?? PreviewClass().previewUser) { selectedPod in
                                    // Dismiss the profile sheet
                                    showingProfile = false
                                    
                                    // Notify parent view about pod selection
                                    onPodSelected?(selectedPod)
                                }
                            }
                        }
                        
                        // Comment Content
                        VStack(alignment: .leading, spacing: 8) {
                            // Username and timestamp
                            HStack(spacing: 6) {
                                Button {
                                    showingProfile = true
                                } label: {
                                    Text("@\(user.username)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                if user.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(comment.timestamp.dateValue().timeAgoDisplay())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                            
                            // Comment text
                            VStack(alignment: .leading, spacing: 6) {
                                Text(comment.caption)
                                    .font(.body)
                                    .foregroundColor(Color("textColor"))
                                    .lineLimit(expanded ? nil : lineLimit)
                                    .background(
                                        Text(comment.caption).lineLimit(lineLimit)
                                            .background(GeometryReader { visibleTextGeometry in
                                                ZStack {
                                                    Text(self.comment.caption)
                                                        .background(GeometryReader { fullTextGeometry in
                                                            Color.clear.onAppear {
                                                                self.truncated = fullTextGeometry.size.height > visibleTextGeometry.size.height
                                                            }
                                                        })
                                                }
                                                .frame(height: .greatestFiniteMagnitude)
                                            })
                                            .hidden()
                                    )
                                
                                if truncated {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            expanded.toggle()
                                        }
                                    }, label: {
                                        Text(moreLessText)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(Color("accentColor"))
                                    })
                                }
                            }
                            
                            // Action buttons
                            HStack(spacing: 20) {
                                Button {
                                    if !isCooldownActive {
                                        commentRowViewModel.toggleLike(comment: comment, pod: pod)
                                        
                                        isCooldownActive = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            isCooldownActive = false
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: commentRowViewModel.isLiked ? "heart.fill" : "heart")
                                            .font(.caption)
                                            .foregroundColor(commentRowViewModel.isLiked ? .red : Color("textColor"))
                                        
                                        Text("\(commentRowViewModel.comment.likes) \(commentRowViewModel.comment.likes == 1 ? "like" : "likes")")
                                            .font(.caption)
                                            .foregroundColor(commentRowViewModel.isLiked ? .red : Color("textColor"))
                                    }
                                }
                                .disabled(isCooldownActive)
                                
                                Button(action: {
                                    onReply?(comment)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "text.bubble")
                                            .font(.caption)
                                            .foregroundColor(Color("textColor"))
                                        
                                        Text("Reply")
                                            .font(.caption)
                                            .foregroundColor(Color("textColor"))
                                    }
                                }
                                
                                if comment.replyCount > 0 {
                                    Button(action: {
                                        onReply?(comment)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bubble.left.and.bubble.right")
                                                .font(.caption)
                                                .foregroundColor(Color("accentColor"))
                                            
                                            Text("\(comment.replyCount) \(comment.replyCount == 1 ? "reply" : "replies")")
                                                .font(.caption)
                                                .foregroundColor(Color("accentColor"))
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .redacted(reason: isLoading ? .placeholder : [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
                .contextMenu {
                    Button {
                        if !isCooldownActive {
                            commentRowViewModel.toggleLike(comment: comment, pod: pod)
                            
                            isCooldownActive = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isCooldownActive = false
                            }
                        }
                    } label: {
                        Label(commentRowViewModel.isLiked ? "Unlike" : "Like", systemImage: commentRowViewModel.isLiked ? "heart.fill" : "heart")
                    }
                    
                    Button {
                        onReply?(comment)
                    } label: {
                        Label("Reply to Comment", systemImage: "arrowshape.turn.up.left")
                    }
                    
                    Button {
                        UIPasteboard.general.string = comment.caption
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    
                    Button(role: .destructive) {
                        showingReportSheet = true
                    } label: {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }
                    
                    if comment.uid == Auth.auth().currentUser?.uid {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onChange(of: comment.caption) { _ in
                    // Reset truncated state when text changes
                    truncated = false
                    expanded = false
                }

                .sheet(isPresented: $showingReportSheet) {
                    ReportCommentView(comment: comment, pod: pod)
                }
                .alert("Delete Comment", isPresented: $showingDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        commentRowViewModel.deleteComment { success in
                            deleteSuccess = success
                            if success {
                                // Notify parent view about the deletion
                                onDelete?(comment)
                            }
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this comment? This action cannot be undone.")
                }
                .opacity(deleteSuccess ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: deleteSuccess)
            }
        }
            
    
    private func isCommentLongerThanTwoLines() -> Bool {
        let font = UIFont.systemFont(ofSize: 14)
        let size = CGSize(width: UIScreen.main.bounds.width - 32, height: .infinity)
        let height = comment.caption.height(withConstrainedWidth: size.width, font: font)
        return height > font.lineHeight * 2
    }
    

}


extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}

struct CommentRowView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack{
                ForEach(0..<25) { _ in
                    ForEach(ColorScheme.allCases, id: \.self, content: CommentRowView(comment: PreviewClass().previewComment, pod: PreviewClass().previewPod).preferredColorScheme)
                    
                }
            }
        }
    }
}
