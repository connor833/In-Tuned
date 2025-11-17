//
//  RepostInputView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import FirebaseFirestore

struct RepostInputView: View {
    @State private var caption = ""
    @State private var isUserDataLoading = true
    @State private var userData: User?
    @Environment(\.presentationMode) var mode
    @ObservedObject var repostViewModel: RepostViewModel
    
    let pod: Pod
    
    init(pod: Pod, repostViewModel: RepostViewModel) {
        self.pod = pod
        self.repostViewModel = repostViewModel
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Enhanced pod preview with glass morphism
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color("accentColor"))
                        
                        Text("Reposting")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    
                    HStack(spacing: 16) {
                        // Enhanced thumbnail with shadow
                        AsyncImage(url: URL(string: pod.thumbnailUrl)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(pod.title)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .lineLimit(2)
                                .foregroundColor(.primary)
                            
                            if isUserDataLoading {
                                // Enhanced loading state
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                                        )
                                    
                                    Text("Loading...")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack(spacing: 6) {
                                    Text("by")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                    
                                    Text(userData?.username ?? pod.user?.username ?? "Unknown")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
                                    
                                    if userData?.isVerified == true || pod.user?.isVerified == true {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.2), Color.clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
                )
                .padding(.horizontal, 20)
                
                // Enhanced caption input
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("accentColor"))
                        
                        Text("Add a caption")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("(optional)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.2), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .frame(minHeight: 100)
                        
                        TextField("What's on your mind?", text: $caption, axis: .vertical)
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundColor(.primary)
                            .padding(16)
                            .lineLimit(4...8)
                            .onChange(of: caption) { newValue in
                                // Sanitize caption input
                                let sanitized = InputSanitizer.clean(newValue, type: .podDescription)
                                if sanitized != newValue {
                                    caption = sanitized
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Enhanced repost button with glass morphism
                Button {
                    repostViewModel.createRepost(
                        podId: pod.id ?? "",
                        originalUserId: pod.userId,
                        caption: caption.isEmpty ? nil : caption
                    ) {
                        mode.wrappedValue.dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Repost")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color("accentColor"), Color("accentColor").opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color("accentColor").opacity(0.3), radius: 12, x: 0, y: 6)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .disabled(pod.id == nil)
                .scaleEffect(pod.id == nil ? 0.95 : 1.0)
                .opacity(pod.id == nil ? 0.6 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pod.id == nil)
            }
            .padding(.top, 20)
            .navigationTitle("Repost")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        mode.wrappedValue.dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                            Text("Cancel")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if pod.user == nil && userData == nil {
                fetchUserForPod()
            } else {
                isUserDataLoading = false
            }
        }
    }
    
    private func fetchUserForPod() {
        let db = Firestore.firestore()
        let userId = pod.userId
        db.collection("users").document(userId).getDocument { document, error in
            if let document = document, document.exists {
                do {
                    let user = try document.data(as: User.self)
                    DispatchQueue.main.async {
                        self.userData = user
                        self.isUserDataLoading = false
                    }
                } catch {
                    print("Error decoding user: \(error)")
                    DispatchQueue.main.async {
                        self.isUserDataLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isUserDataLoading = false
                }
            }
        }
    }
}

struct RepostInputView_Previews: PreviewProvider {
    static var previews: some View {
        RepostInputView(pod: PreviewClass().previewPod, repostViewModel: RepostViewModel())
    }
} 
