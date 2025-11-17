//
//  CreatePlaylistView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 9/18/23.
//

import SwiftUI
import Kingfisher

struct CreatePlaylistView: View {
    @State var selectedPods = [String]()
    @State var title = ""
    @StateObject private var podSearchViewModel = PlaylistPodSearchViewModel()
    @Environment(\.presentationMode) var mode
    @State var showImagePicker = false
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var selectedImage: UIImage?
    @State private var thumbnail: Image?
    
    @State var thumbnailUrl = ""
    
    @State var uploader = StorageUploader()
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    
    @State private var podViewModels: [String: PodViewModel] = [:]
    
    // Error handling
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    let user: User
    
    init(user: User) {
        self.user = user
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Modern header with cool back button
            HStack {
                Button {
                    mode.wrappedValue.dismiss()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.red, lineWidth: 2)
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
                
                Text("New Playlist")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    // Validate playlist title for profanity
                    let titleResult = InputSanitizer.sanitize(title, type: .playlistTitle)
                    if !titleResult.isValid {
                        errorMessage = titleResult.errorMessage ?? "Invalid playlist title"
                        showErrorAlert = true
                        return
                    }
                    
                    isUploading = true
                    
                    if let selectedImage = selectedImage {
                        uploader.uploadImage(image: selectedImage, progressHandler: { progress in
                            DispatchQueue.main.async {
                                self.uploadProgress = progress
                            }
                        }, completion: { imageUrl in
                            self.thumbnailUrl = imageUrl
                            
                            // Create playlist using UserService directly with sanitized title
                            let userService = UserService()
                            userService.createPlaylist(title: titleResult.sanitizedText, podIds: selectedPods, thumbnailUrl: thumbnailUrl) { success, error in
                                if success {
                                    print("✅ Playlist created successfully with \(selectedPods.count) pods")
                                } else {
                                    print("❌ Error creating playlist: \(error?.localizedDescription ?? "Unknown error")")
                                }
                            }
                            print("selected pods \(selectedPods)")
                            mode.wrappedValue.dismiss()
                        })
                    }
                } label: {
                    if isUploading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Creating...")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray)
                        )
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Create")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(
                                    color: Color("accentColor").opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                        .opacity((selectedImage == nil || selectedPods.isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.5 : 1.0)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isUploading || selectedImage == nil || selectedPods.isEmpty || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            Divider()
                .background(Color(.systemGray4))
                .padding(.horizontal)
            
            
            // Modern form section
            VStack(spacing: 20) {
                // Playlist name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Playlist Name")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextField("Enter playlist name", text: $title)
                        .font(.system(size: 16, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                .padding(.horizontal, 20)
                
                // Thumbnail section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Thumbnail")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Button {
                        showImagePicker.toggle()
                    } label: {
                        if selectedImage != nil {
                            Image(uiImage: selectedImage!)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 80)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(width: 120, height: 80)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("Add Thumbnail")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .sheet(isPresented: $showImagePicker, onDismiss: loadImage) {
                        ImagePickerRectangle(selectedImage: $selectedImage)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
            
            // Progress bar for upload
            if isUploading {
                VStack(spacing: 8) {
                    ProgressView(value: uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                        .padding(.horizontal)
                    
                    Text("\(Int(uploadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.bottom)
            }
            
            HStack {
                SearchBar(text: $podSearchViewModel.searchText)
                    .onChange(of: podSearchViewModel.searchText) { _ in
                        podSearchViewModel.performSearch()
                    }
                
                // Show loading indicator while search is pending
                if podSearchViewModel.isLoading && podSearchViewModel.filteredPods.isEmpty {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
            }
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(podSearchViewModel.displayPods) { pod in
                        Button {
                            togglePodSelection(pod)
                        } label: {
                            PodRowViewThinForSelection(pod: pod, isSelected: selectedPods.contains(pod.id ?? ""))
                        }
                        .onAppear {
                            // Load more when reaching the last few items
                            if pod.id == podSearchViewModel.displayPods.last?.id && 
                               podSearchViewModel.hasMorePods && 
                               !podSearchViewModel.isFetchingMore {
                                podSearchViewModel.fetchNextPage()
                            }
                        }
                    }
                    
                    // Loading indicator at bottom
                    if podSearchViewModel.isFetchingMore {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .onAppear {
                // For creating a new playlist, no pods are already added
                podSearchViewModel.playlistPodIds = []
                podSearchViewModel.fetchFirstPage()
            }
        }
        .padding()
        .alert("Invalid Playlist Title", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    private func togglePodSelection(_ pod: Pod) {
        if selectedPods.contains(pod.id ?? "") {
            selectedPods.removeAll { $0 == pod.id }
        } else {
            selectedPods.append(pod.id ?? "")
        }
    }
    
    func loadImage() {
        guard let selectedImage = selectedImage else {
            return
        }
        
        // Validate the selected image
        let validationResult = FileValidator.validate(image: selectedImage, for: .thumbnail)
        
        if validationResult.isValid {
            thumbnail = Image(uiImage: selectedImage)
        } else {
            // Reset selection if validation fails
            self.selectedImage = nil
            print("Playlist thumbnail validation failed: \(validationResult.errorMessage ?? "Unknown error")")
            // You can add a user-facing error alert here
        }
    }
    
    private func getPodViewModel(for pod: Pod) -> PodViewModel {
        let podId = pod.id ?? ""
        if let cached = podViewModels[podId] {
            return cached
        } else {
            let newVM = PodViewModel(pod: pod)
            DispatchQueue.main.async {
                podViewModels[podId] = newVM
            }
            return newVM
        }
    }
}

// MARK: - PodRowViewThinForSelection
struct PodRowViewThinForSelection: View {
    @StateObject private var viewModel: PodViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    let lineLimit = 2
    let pod: Pod
    let isSelected: Bool
    
    init(pod: Pod, isSelected: Bool) {
        self.pod = pod
        self.isSelected = isSelected
        self._viewModel = StateObject(wrappedValue: PodViewModel(pod: pod))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // User info section
            HStack(spacing: 12) {
                if !viewModel.hasLoadedUser {
                    // Loading state
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            ProgressView()
                                .scaleEffect(0.7)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color("accentColor")))
                        )
                    
                    Text("Loading...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    // Profile image
                    KFImage(URL(string: viewModel.pod.user?.profileImageUrl ?? ""))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.pod.user?.fullname ?? "Unknown User")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("@\(viewModel.pod.user?.username ?? "unknown")")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            // Main content
            HStack(spacing: 16) {
                // Thumbnail with modern styling
                KFImage(URL(string: pod.thumbnailUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(pod.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Description
                    Text(pod.description)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(lineLimit)
                        .truncationMode(.tail)
                    
                    // Likes with modern styling
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red)
                        
                        Text("\(viewModel.pod.likes) \(viewModel.pod.likes == 1 ? "like" : "likes")")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.green.opacity(0.1) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
                )
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 12,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct CreatePlaylistView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePlaylistView(user: PreviewClass().previewUser)
    }
}
