//
//  RSSStreamEditView.swift
//  Attuned
//
//  Created by AI Assistant
//

import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseStorage

struct RSSStreamEditView: View {
    let stream: RSSStream
    let userId: String
    var onSave: (RSSStream) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedThumbnailUrl: String
    @State private var customImage: UIImage?
    @State private var showImagePicker = false
    @State private var isUploadingImage = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let rssStreamService = RSSStreamService()
    
    init(stream: RSSStream, userId: String, onSave: @escaping (RSSStream) -> Void) {
        self.stream = stream
        self.userId = userId
        self.onSave = onSave
        
        // Initialize state with current values
        _editedTitle = State(initialValue: stream.title)
        _editedDescription = State(initialValue: stream.description ?? "")
        _editedThumbnailUrl = State(initialValue: stream.thumbnailUrl)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Thumbnail section
                    VStack(spacing: 12) {
                        Text("Podcast Artwork")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Image preview
                        Group {
                            if let customImage = customImage {
                                Image(uiImage: customImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                AsyncImage(url: URL(string: editedThumbnailUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .overlay(
                                            Image(systemName: "waveform.circle.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                        )
                                }
                            }
                        }
                        .frame(width: 150, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo")
                                Text("Change Artwork")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color("accentColor"))
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color("accentColor").opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color("accentColor"), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(isUploadingImage || isSaving)
                        
                        if isUploadingImage {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Uploading artwork...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Divider()
                    
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Podcast Name")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter podcast name", text: $editedTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.words)
                            .disabled(isSaving)
                        
                        HStack {
                            Text("\(editedTitle.count)/200")
                                .font(.caption)
                                .foregroundColor(editedTitle.count > 200 ? .red : .secondary)
                            
                            Spacer()
                            
                            if editedTitle.count > 150 {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text(editedTitle.count > 200 ? "Title too long" : "Title getting long")
                                        .font(.caption)
                                }
                                .foregroundColor(editedTitle.count > 200 ? .red : .orange)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Description section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextEditor(text: $editedDescription)
                            .frame(height: 120)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .disabled(isSaving)
                        
                        HStack {
                            Text("\(editedDescription.count)/1000")
                                .font(.caption)
                                .foregroundColor(editedDescription.count > 1000 ? .red : .secondary)
                            
                            Spacer()
                            
                            if editedDescription.count > 800 {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                    Text(editedDescription.count > 1000 ? "Description too long" : "Description getting long")
                                        .font(.caption)
                                }
                                .foregroundColor(editedDescription.count > 1000 ? .red : .orange)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Info box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(Color("accentColor"))
                            Text("About Editing")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        
                        Text("• Editing this information updates the podcast stream\n• Changes won't affect the original RSS feed\n• Keep titles under 200 characters\n• Descriptions should be under 1000 characters")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("accentColor").opacity(0.1))
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Edit Podcast Stream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(isSaving)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveChanges) {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !isValid)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $customImage)
            }
            .onChange(of: customImage) { newImage in
                if let image = newImage {
                    uploadCustomImage(image)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        return !editedTitle.isEmpty &&
               editedTitle.count <= 200 &&
               editedDescription.count <= 1000 &&
               !editedThumbnailUrl.isEmpty
    }
    
    private func uploadCustomImage(_ image: UIImage) {
        isUploadingImage = true
        
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                    throw NSError(domain: "RSSStreamEdit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"])
                }
                
                let filename = "\(userId)_rss_stream_\(UUID().uuidString).jpg"
                let storageRef = Storage.storage().reference().child("podcast_artwork/\(filename)")
                
                let metadata = StorageMetadata()
                metadata.contentType = "image/jpeg"
                
                _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
                let downloadURL = try await storageRef.downloadURL()
                
                await MainActor.run {
                    editedThumbnailUrl = downloadURL.absoluteString
                    isUploadingImage = false
                }
                
            } catch {
                await MainActor.run {
                    isUploadingImage = false
                    errorMessage = "Failed to upload image: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func saveChanges() {
        guard isValid else { return }
        guard let streamId = stream.id else { return }
        
        isSaving = true
        
        Task {
            do {
                // Update stream in Firestore
                try await rssStreamService.updateStreamDetails(
                    streamId,
                    title: editedTitle,
                    description: editedDescription.isEmpty ? nil : editedDescription,
                    thumbnailUrl: editedThumbnailUrl
                )
                
                // Create updated stream object
                var updatedStream = stream
                updatedStream.title = editedTitle
                updatedStream.description = editedDescription.isEmpty ? nil : editedDescription
                updatedStream.thumbnailUrl = editedThumbnailUrl
                updatedStream.updatedAt = Timestamp()
                
                await MainActor.run {
                    isSaving = false
                    onSave(updatedStream)
                    presentationMode.wrappedValue.dismiss()
                }
                
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save changes: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}
