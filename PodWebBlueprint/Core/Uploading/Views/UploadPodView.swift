//
//  UploadPodView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/22/23.
//

import SwiftUI
import Firebase
import FirebaseCore
import FirebaseStorage
import Kingfisher
import PhotosUI
import AVKit
import AVFoundation

struct UploadPodView: View {
    @State private var podName = ""
    @State private var description = ""
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @FocusState private var isTagInputFocused: Bool
    @FocusState private var isPodNameFocused: Bool
    @State private var shouldDismissKeyboard = false
    
    @State var thumbnailUrl = ""
    @State var videoName = ""
    @State private var extractedMetadata: (duration: TimeInterval?, fileSize: Int64?, mimeType: String?) = (nil, nil, nil)
    @State private var isSquareThumbnail = false // Toggle for square vs rectangular thumbnails
    
    @State var openFile = false
    @State private var showImagePicker = false
    @State private var showVideoPicker = false
    @State private var showDocumentPicker: Bool = false
    @State private var showFileSelectionMenu = false
    @State private var isUploading = false
    @State private var showUploadError = false
    @State private var uploadErrorMessage = ""
    @State private var showUploadSuccess = false
    @State private var isVideoLoading = false
    @State private var isCompressing = false
    @State private var compressionProgress: Double = 0.0
    @State private var compressedFileUrl: URL?
    @State private var autoStartEnabled = false
    
    // Profanity validation alerts
    @State private var showProfanityAlert = false
    @State private var profanityAlertMessage = ""
    
    @State var fileUrl: URL? {
        didSet {
            print("🎬 UploadPodView: fileUrl didSet to: \(fileUrl?.absoluteString ?? "nil")")
            
            // Compress the video immediately when it's loaded
            if let url = fileUrl {
                autoStartEnabled = true
                print("🗜️ UploadPodView: Starting compression for: \(url.lastPathComponent)")
                compressVideoImmediately(url: url)
            }
        }
    }
    @State var podFileUrl = ""
    @State private var uploadResult: Result<URL, Error>?
    
    @State private var selectedImage: UIImage?
    @State private var thumbnail: Image?
    
    @State private var typeFlag = 0
    @State private var videoSource: R2UploadService.VideoSource = .unknown
    
    @State var uploader = StorageUploader()
    @StateObject var viewModel = UploadViewModel()
    @ObservedObject private var uploadQueue = UploadQueueManager.shared
    
    let user: User
    private let aiProcessor = AIProcessor()  // Add AIProcessor instance
    private let openAIProcessor = OpenAIProcessor(apiKey: AIConfig.openAIAPIKey)
    
    init(user: User) {
        self.user = user
    }
    
    @Namespace var animation
    @Environment(\.presentationMode) var mode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Modern header with navigation
                headerSection
                
                // Upload progress section with modern styling
                if viewModel.isUploading {
                    uploadProgressSection
                }
                
                // Main content sections
                contentSections
                
                Spacer(minLength: 100) // Bottom padding for tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        // Ensure compression triggers even if didSet timing misses
        .onChange(of: fileUrl) { newUrl in
            guard let url = newUrl else { return }
            print("🗜️ onChange(fileUrl): ensuring compression for \(url.lastPathComponent)")
            compressVideoImmediately(url: url)
        }
        .navigationBarBackButtonHidden()
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isPodNameFocused = false
                    isTagInputFocused = false
                    shouldDismissKeyboard.toggle()
                }
                .foregroundColor(Color("accentColor"))
                .fontWeight(.medium)
            }
        }
    }
        
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Title centered at the top
            Text("Upload Pod")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // Navigation buttons
            HStack {
                Button {
                    if viewModel.isUploading {
                        viewModel.cancelUpload()
                    } else {
                        mode.wrappedValue.dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isUploading ? "stop.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(viewModel.isUploading ? "Cancel Upload" : "Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        viewModel.isUploading ? Color.orange : Color.red,
                                        viewModel.isUploading ? Color.orange.opacity(0.8) : Color.red.opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: viewModel.isUploading ? Color.orange.opacity(0.3) : Color.red.opacity(0.3),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                
                Spacer()
                
                Button {
                    startUpload()
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isUploading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Uploading...")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text("Upload")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        (!viewModel.isUploading && !isCompressing && canUpload) ? Color("accentColor") : Color.gray,
                                        (!viewModel.isUploading && !isCompressing && canUpload) ? Color("accentColor").opacity(0.8) : Color.gray.opacity(0.8)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: (!viewModel.isUploading && !isCompressing && canUpload) ? Color("accentColor").opacity(0.3) : Color.clear,
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                    )
                }
                .disabled(viewModel.isUploading || !canUpload || isCompressing)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Upload Progress Section
    
    private var uploadProgressSection: some View {
        VStack(spacing: 16) {
            // Progress bar with modern styling
            VStack(spacing: 12) {
                HStack {
                    Text(viewModel.uploadStatus.isEmpty ? "Uploading..." : viewModel.uploadStatus)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.uploadProgress * 100))%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color("accentColor"))
                }
                
                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color("accentColor")))
                    .frame(height: 6)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.systemGray5))
                    )
            }
            
            // Upload stats
            if !viewModel.uploadSpeed.isEmpty || !viewModel.timeRemaining.isEmpty {
                HStack(spacing: 20) {
                    if !viewModel.uploadSpeed.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                            Text(viewModel.uploadSpeed)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if !viewModel.timeRemaining.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                            Text(viewModel.timeRemaining)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Content Sections
    
    private var contentSections: some View {
        VStack(spacing: 20) {
            // Thumbnail section
            thumbnailSection
            
            // Media file section
            mediaFileSection
            
            // Form fields
            formFieldsSection
        }
    }
    
    // MARK: - Start Upload Function
    
    private func startUpload() {
        // Ensure all requirements are met before upload
        guard canUpload, let fileUrl = fileUrl else {
            print("❌ Upload blocked: canUpload=\(canUpload), fileUrl=\(fileUrl?.absoluteString ?? "nil")")
            return
        }
        // Do not start while compression is in progress
        if isCompressing {
            print("⏳ Upload deferred: compression in progress")
            return
        }
        
        // Validate pod title for profanity
        let titleResult = InputSanitizer.sanitize(podName, type: .podTitle)
        if !titleResult.isValid {
            profanityAlertMessage = titleResult.errorMessage ?? "Invalid pod title"
            showProfanityAlert = true
            return
        }
        
        // Validate pod description for profanity
        let descResult = InputSanitizer.sanitize(description, type: .podDescription)
        if !descResult.isValid {
            profanityAlertMessage = descResult.errorMessage ?? "Invalid pod description"
            showProfanityAlert = true
            return
        }
        
        // Validate all tags for profanity
        for tag in tags {
            let tagResult = InputSanitizer.sanitize(tag, type: .tag)
            if !tagResult.isValid {
                profanityAlertMessage = tagResult.errorMessage ?? "Invalid tag"
                showProfanityAlert = true
                return
            }
        }
        
        // Always use compressed file when available (required)
        let uploadFileUrl = compressedFileUrl ?? fileUrl
        let uploadFileName = compressedFileUrl?.lastPathComponent ?? fileUrl.lastPathComponent
        
        print("🚀 Starting upload with: image=\(selectedImage != nil), file=\(uploadFileName), title='\(podName)'")
        print("🚀 Using file: \(uploadFileUrl == fileUrl ? "original" : "compressed")")
        
        // Extract metadata from local file before uploading
        Task {
            let metadata = await FileValidator.extractAudioMetadata(from: uploadFileUrl)
            print("🎵 Extracted metadata - Duration: \(metadata.duration?.description ?? "nil"), Size: \(metadata.fileSize?.description ?? "nil"), MIME: \(metadata.mimeType ?? "nil")")
            
            // Store metadata for later use
            await MainActor.run {
                self.extractedMetadata = metadata
            }
            
            // Get file size
            let fileSize = metadata.fileSize ?? 0
            
            // Convert R2UploadService.VideoSource to VideoSource
            let uploadSource: VideoSource
            switch videoSource {
            case .photosPicker:
                uploadSource = .photosPicker
            case .filesApp:
                uploadSource = .filesApp
            case .unknown:
                uploadSource = .unknown
            }
            
            // Add to upload queue
            let wasAdded = uploadQueue.addUpload(
                fileName: uploadFileName,
                fileUrl: uploadFileUrl,
                fileSize: fileSize,
                podTitle: podName,
                podDescription: description,
                tags: tags,
                thumbnailImage: selectedImage,
                source: uploadSource,
                user: user
            )
            
            guard wasAdded else {
                // Queue is full, show error and don't dismiss
                DispatchQueue.main.async {
                    self.showUploadError = true
                    self.uploadErrorMessage = "Upload queue is full. Please wait for current uploads to complete before adding more."
                }
                return
            }
            
            // Show success message and dismiss after a brief delay
            DispatchQueue.main.async {
                self.showUploadSuccess = true
                print("🚀 Upload started, dismissing view - upload will continue in background")
                
                // Dismiss after showing success message
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.mode.wrappedValue.dismiss()
                }
            }
        }
    }
        
    // MARK: - Video Compression
    
    private func compressVideoImmediately(url: URL) {
        print("🗜️ Starting immediate compression for: \(url.lastPathComponent)")
        print("🗜️ File URL: \(url)")
        print("🗜️ File exists: \(FileManager.default.fileExists(atPath: url.path))")
        
        // Show compression state
        DispatchQueue.main.async {
            self.isCompressing = true
            self.compressionProgress = 0.0
        }
        
        Task {
            do {
                // Get file size to determine compression settings
                let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                let sizeGB = Double(fileSize) / (1024 * 1024 * 1024)
                
                print("🗜️ Original file size: \(String(format: "%.2f", sizeGB))GB")
                print("🗜️ File size in bytes: \(fileSize)")
                
                // Determine if this is audio or video based on file extension
                let originalExtension = url.pathExtension.lowercased()
                let audioExtensions = ["mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus", "aiff", "caf"]
                let isAudioFile = audioExtensions.contains(originalExtension)
                
                print("🗜️ Original extension: \(originalExtension), isAudio: \(isAudioFile)")
                
                // Skip compression for audio files - they're already small and don't need it
                if isAudioFile {
                    print("🗜️ Audio file detected - skipping compression")
                    DispatchQueue.main.async {
                        self.compressedFileUrl = url // Use original file for audio
                        self.isCompressing = false
                        self.compressionProgress = 1.0
                    }
                    return
                }
                
                // Only compress video files
                print("🗜️ Video file detected - proceeding with compression")
                
                // Create temporary file for compressed output
                let tempDir = FileManager.default.temporaryDirectory
                let compressedFileName = "compressed_\(UUID().uuidString).mp4"
                let compressedFileUrl = tempDir.appendingPathComponent(compressedFileName)
                
                // Use AVAssetExportSession for compression
                print("🗜️ Creating AVAsset from URL: \(url)")
                let asset = AVAsset(url: url)
                print("🗜️ AVAsset created successfully")
                
                // Prefer ~720p output; fallback to medium/low quality
                let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
                let chosenPreset: String
                if compatiblePresets.contains(AVAssetExportPreset1280x720) {
                    chosenPreset = AVAssetExportPreset1280x720
                } else if compatiblePresets.contains(AVAssetExportPresetMediumQuality) {
                    chosenPreset = AVAssetExportPresetMediumQuality
                } else {
                    chosenPreset = AVAssetExportPresetLowQuality
                }
                print("🗜️ Creating export session with preset: \(chosenPreset)")
                guard let exportSession = AVAssetExportSession(asset: asset, presetName: chosenPreset) else {
                    print("❌ Failed to create export session")
                    throw NSError(domain: "CompressionError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
                }
                print("🗜️ Export session created successfully")
                
                exportSession.outputURL = compressedFileUrl
                exportSession.outputFileType = .mp4 // Only video files reach this point
                
                exportSession.shouldOptimizeForNetworkUse = true
                
                print("🗜️ Export file type set to: \(exportSession.outputFileType?.rawValue)")
                
                // Target ~8 Mbps via fileLengthLimit when available (best-effort)
                // Approximate duration-based target size to ~8 Mbps: sizeBytes ≈ bitrate(bps) * duration(s) / 8
                let durationSeconds = CMTimeGetSeconds(asset.duration)
                if durationSeconds.isFinite && durationSeconds > 0 {
                    let targetBitrateBps: Double = 8_000_000 // ~8 Mbps
                    let targetSizeBytes = Int64(targetBitrateBps * durationSeconds / 8.0)
                    if targetSizeBytes > 0 {
                        exportSession.fileLengthLimit = targetSizeBytes
                        print("🗜️ Applying fileLengthLimit ≈ \(targetSizeBytes) bytes (~8 Mbps)")
                    }
                }
                
                // Monitor compression progress
                let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    DispatchQueue.main.async {
                        self.compressionProgress = Double(exportSession.progress)
                    }
                }
                
                // Start compression
                print("🗜️ Starting export...")
                await exportSession.export()
                print("🗜️ Export completed with status: \(exportSession.status.rawValue)")
                
                // Stop progress timer
                progressTimer.invalidate()
                
                // Check if compression was successful
                if exportSession.status == .completed {
                    print("✅ Compression completed for: \(url.lastPathComponent)")
                    
                    // Get compressed file size
                    let compressedSize = try compressedFileUrl.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    let compressedSizeGB = Double(compressedSize) / (1024 * 1024 * 1024)
                    print("🗜️ Compressed file size: \(String(format: "%.2f", compressedSizeGB))GB")
                    
                    // Update state
                    DispatchQueue.main.async {
                        self.compressedFileUrl = compressedFileUrl
                        self.isCompressing = false
                        self.compressionProgress = 1.0
                        print("🗜️ Final compressed file: \(compressedFileUrl.lastPathComponent)")
                        // Auto-start disabled by request. User taps Upload after compression.
                    }
                } else if let error = exportSession.error {
                    print("❌ Compression failed: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isCompressing = false
                    }
                } else {
                    print("❌ Compression cancelled")
                    DispatchQueue.main.async {
                        self.isCompressing = false
                    }
                }
                
            } catch {
                print("❌ Compression error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isCompressing = false
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // MARK: - Validation
    
    /// Computed property that determines if all required fields are present for upload
    private var canUpload: Bool {
        return selectedImage != nil && fileUrl != nil && !podName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Thumbnail Section
    
    private var thumbnailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Thumbnail")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Show aspect ratio toggle only when no image is selected
                if selectedImage == nil {
                    // Thumbnail aspect ratio toggle
                    HStack(spacing: 8) {
                        Button(action: {
                            isSquareThumbnail = false
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "rectangle")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Rectangle")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSquareThumbnail ? Color.clear : Color("accentColor"))
                            )
                            .foregroundColor(isSquareThumbnail ? .primary : .white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color("accentColor"), lineWidth: 1)
                            )
                        }
                        
                        Button(action: {
                            isSquareThumbnail = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square")
                                    .font(.system(size: 12, weight: .medium))
                                Text("Square")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(isSquareThumbnail ? Color("accentColor") : Color.clear)
                            )
                            .foregroundColor(isSquareThumbnail ? .white : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color("accentColor"), lineWidth: 1)
                            )
                        }
                    }
                } else {
                    // Show remove button when image is selected
                    Button(action: {
                        selectedImage = nil
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                            Text("Remove")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red)
                        )
                        .foregroundColor(.white)
                    }
                }
            }
            
            Button {
                showImagePicker.toggle()
            } label: {
                if selectedImage != nil {
                    HStack {
                        Spacer()
                        Image(uiImage: selectedImage!)
                            .resizable()
                            .aspectRatio(contentMode: .fit) // Changed to fit to show actual aspect ratio
                            .frame(maxHeight: 100) // Use maxHeight to allow adaptive width
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        Spacer()
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(height: 100) // Use height only, width will be adaptive
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: isSquareThumbnail ? "square" : "rectangle")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                                
                                Text("Add \(isSquareThumbnail ? "Square" : "Rectangular") Thumbnail")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color("accentColor").opacity(0.3), lineWidth: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                        .foregroundColor(Color("accentColor").opacity(0.3))
                                )
                        )
                }
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showImagePicker, onDismiss: loadImage) {
                FlexibleImagePicker(selectedImage: $selectedImage, isSquare: isSquareThumbnail)
            }
        }
    }
    
    // MARK: - Media File Section
    
    private var mediaFileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Media File")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if isCompressing {
                // Compression progress
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Compressing...")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("\(Int(compressionProgress * 100))% complete")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    ProgressView(value: compressionProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .scaleEffect(y: 2.0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else if fileUrl != nil {
                // Media preview with delete option
                HStack(spacing: 12) {
                    // Interactive media player
                    InteractiveMediaPlayer(fileName: fileUrl?.lastPathComponent ?? "", fileUrl: fileUrl)
                    
                    // Delete button
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            fileUrl = nil
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else if isVideoLoading {
                // Loading state for video processing
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Color("accentColor"))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Processing Video...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("This may take a moment for large files")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else if isCompressing {
                // Compression progress
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Compressing...")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("\(Int(compressionProgress * 100))% complete")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    ProgressView(value: compressionProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                        .scaleEffect(y: 2.0)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else {
                // Upload placeholder
                Button {
                    showFileSelectionMenu = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color("accentColor"))
                        
                        Text("Add Media")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("accentColor"))
                    }
                    .frame(width: 140, height: 100)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color("accentColor").opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color("accentColor").opacity(0.3), lineWidth: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                            .foregroundColor(Color("accentColor").opacity(0.3))
                                    )
                            )
                    )
                }
                .scaleEffect(fileUrl == nil ? 1.0 : 0.95)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .actionSheet(isPresented: $showFileSelectionMenu) {
            ActionSheet(
                title: Text("Select Media"),
                buttons: [
                    .default(Text("From Camera Roll")) {
                        typeFlag = 2
                        videoSource = .photosPicker
                        print("🎬 UploadPodView: About to show VideoPicker")
                        showVideoPicker.toggle()
                        print("🎬 UploadPodView: showVideoPicker is now: \(showVideoPicker)")
                    },
                    .default(Text("From Files")) {
                        typeFlag = 1
                        videoSource = .filesApp
                        showDocumentPicker.toggle()
                    },
                    .cancel()
                ]
            )
        }
        .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.audio, .video, .mpeg4Movie]) { result in
            Task {
                do {
                    let fileUrl = try result.get()
                    
                    print("📁 File selected: \(fileUrl)")
                    print("📁 File scheme: \(fileUrl.scheme ?? "nil")")
                    
                    // Show loading state for iCloud files
                    if fileUrl.scheme?.contains("icloud") == true {
                        print("☁️ iCloud file detected, this may take a moment...")
                    }
                    
                    // Validate the selected file
                    let validationResult = await FileValidator.validate(fileURL: fileUrl, for: .podContent)
                    
                    if validationResult.isValid {
                        await MainActor.run {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                self.fileUrl = fileUrl
                                print("✅ File validation successful, file URL set")
                            }
                        }
                    } else {
                        // Show error for invalid file
                        let errorMessage = validationResult.errorMessage ?? "Unknown error"
                        print("❌ File validation failed: \(errorMessage)")
                        
                        // Special handling for iCloud files
                        if fileUrl.scheme?.contains("icloud") == true {
                            print("☁️ iCloud file validation failed - file may still be downloading")
                            // You could show a user-friendly message here about waiting for iCloud download
                        }
                        
                        // You can add a user-facing error alert here
                    }
                } catch {
                    print("❌ Error reading docs: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                }
            }
        }
        .sheet(isPresented: $showVideoPicker) {
            VideoPicker(selectedURL: $fileUrl, isLoading: $isVideoLoading)
                .onChange(of: fileUrl) { newUrl in
                    print("🎬 UploadPodView: fileUrl changed to: \(newUrl?.absoluteString ?? "nil")")
                    // fileName will be automatically set by fileUrl's didSet
                }
                .onAppear {
                    print("🎬 UploadPodView: VideoPicker sheet appeared")
                }
        }
        .alert("Upload Failed", isPresented: $showUploadError) {
            Button("Try Again") {
                // User can try uploading again
                showUploadError = false
            }
            Button("Cancel", role: .cancel) {
                showUploadError = false
            }
        } message: {
            Text("The upload failed. Please check your internet connection and try again.\n\nError: \(uploadErrorMessage)")
        }
        .alert("Upload Started", isPresented: $showUploadSuccess) {
            Button("OK") {
                showUploadSuccess = false
            }
        } message: {
            Text("Your upload has been added to the queue and will continue in the background. You can track its progress in the Uploads tab.")
        }
        .alert("Cannot Upload Pod", isPresented: $showProfanityAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(profanityAlertMessage)
        }
    }
    
    // MARK: - Form Fields Section
    
    private var formFieldsSection: some View {
        VStack(spacing: 20) {
            // Pod name field
            formField(
                title: "Pod Name",
                text: $podName,
                placeholder: "Enter pod name",
                isMultiline: false
            )
            
            // Description field
            formField(
                title: "Description",
                text: $description,
                placeholder: "Describe your pod...",
                isMultiline: true
            )
            
            // Tags section
            tagsSection
        }
    }
    // MARK: - Tags Section
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            // Tag input field
            HStack(spacing: 12) {
                TextField("Add tags...", text: $tagInput)
                    .focused($isTagInputFocused)
                    .onSubmit {
                        addTag()
                    }
                    .onChange(of: tagInput) { newValue in
                        if newValue.contains(" ") {
                            let trimmedTag = newValue.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "")
                            if !trimmedTag.isEmpty {
                                tagInput = trimmedTag
                                addTag()
                            } else {
                                tagInput = ""
                            }
                        }
                    }
                    .submitLabel(.return)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
                
                Button(action: addTag) {
                    Text("Add")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color("accentColor"))
                        )
                }
                .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Tags display
            if !tags.isEmpty {
                TagsFlowLayout(tags: tags, onDelete: deleteTag)
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Form Field Helper
    
    private func formField(title: String, text: Binding<String>, placeholder: String, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if isMultiline {
                ExpandableTextField(text: text, placeholder: placeholder, shouldDismiss: $shouldDismissKeyboard)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
                    .onChange(of: text.wrappedValue) { newValue in
                        let sanitized = InputSanitizer.clean(newValue, type: .podDescription)
                        if sanitized != newValue {
                            text.wrappedValue = sanitized
                        }
                    }
            } else {
                TextField(placeholder, text: text)
                    .focused($isPodNameFocused)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
                    .onChange(of: text.wrappedValue) { newValue in
                        let sanitized = InputSanitizer.clean(newValue, type: .podTitle)
                        if sanitized != newValue {
                            text.wrappedValue = sanitized
                        }
                    }
            }
        }
    }
        
        func loadImage() {
            guard let selectedImage = selectedImage else { return }
            
            // Validate the selected image
            let validationResult = FileValidator.validate(image: selectedImage, for: .thumbnail)
            
            if validationResult.isValid {
                thumbnail = Image(uiImage: selectedImage)
            } else {
                // Reset selection if validation fails
                self.selectedImage = nil
                print("Image validation failed: \(validationResult.errorMessage ?? "Unknown error")")
                // You can add a user-facing error alert here
            }
        }
        
        // MARK: - Tag Management
        
        func addTag() {
            let trimmedTag = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTag.isEmpty && !tags.contains(trimmedTag) {
                // Validate tag for profanity
                let tagResult = InputSanitizer.sanitize(trimmedTag, type: .tag)
                if !tagResult.isValid {
                    // Show profanity alert if tag contains inappropriate language
                    profanityAlertMessage = tagResult.errorMessage ?? "Invalid tag"
                    showProfanityAlert = true
                    return
                }
                
                // Add sanitized tag
                if !tagResult.sanitizedText.isEmpty {
                    tags.append(tagResult.sanitizedText)
                    tagInput = ""
                }
            }
        }
        
        func deleteTag(at index: Int) {
            if index < tags.count {
                tags.remove(at: index)
            }
        }
        
        // MARK: - AI Processing and Pod Data Upload
        
        func processAndUploadPodData(fileUrl: String) {
            print("🔄 processAndUploadPodData called with fileUrl: \(fileUrl)")
            
            // Sanitize all inputs before processing
            let sanitizedTitle = InputSanitizer.clean(podName, type: .podTitle)
            let sanitizedDescription = InputSanitizer.clean(description, type: .podDescription)
            let sanitizedTags = tags.map { InputSanitizer.clean($0, type: .tag) }.filter { !$0.isEmpty }
            
            print("📝 Sanitized inputs - Title: '\(sanitizedTitle)', Description: '\(sanitizedDescription)', Tags: \(sanitizedTags)")
            
            // Process the pod using OpenAI with fallback to local processor
            Task {
                let processedPod = await openAIProcessor.processPodWithFallback(
                    title: sanitizedTitle,
                    description: sanitizedDescription,
                    userTags: sanitizedTags.isEmpty ? nil : sanitizedTags,
                    originalProcessor: aiProcessor
                )
                
                print("🤖 AI processing complete - Category: \(processedPod.category), Keywords: \(processedPod.keywords)")
                
                // Upload the sanitized pod data to Firestore
                print("📤 Starting Firestore upload...")
                await MainActor.run {
                    uploadPodData(
                        fileUrl: fileUrl,
                        title: sanitizedTitle,
                        description: sanitizedDescription,
                        category: processedPod.category,
                        keywords: processedPod.keywords
                    )
                }
            }
        }
        
        func uploadPodData(fileUrl: String, title: String, description: String, category: String?, keywords: [String]) {
            let db = Firestore.firestore()
            let uniqueID = UUID().uuidString
            let podRef = db.collection("pods").document(uniqueID)
            
            // Use the pre-extracted metadata
            let currentTime = Timestamp()
            
            let podData: [String: Any] = [
                "title": title,
                "titleLowercased": title.lowercased(),
                "timestamp": currentTime,
                "description": description,
                "fileUrl": fileUrl,
                "thumbnailUrl": thumbnailUrl,
                "userId": user.uid,
                "likes": 0,
                
                // Engagement metrics (all start at 0)
                "views": 0,
                "shares": 0,
                "comments": 0,
                "saves": 0,
                
                // Content metadata (using pre-extracted values)
                "duration": extractedMetadata.duration as Any,
                "fileSize": extractedMetadata.fileSize as Any,
                "mimeType": extractedMetadata.mimeType as Any,
                
                // Optional properties
                "category": category ?? "Miscellaneous",
                "keywords": keywords,
                
                // Essential production fields
                "isActive": true,
                "createdAt": currentTime,
                "updatedAt": currentTime,
                "version": 1,
                
                // Content moderation (default approved)
                "isReported": false,
                "moderationStatus": "approved",
                "contentWarnings": []
            ]
            
            // Upload to main pods collection with retry logic
            podRef.setData(podData) { error in
                if let error = error {
                    print("❌ Error uploading pod data: \(error.localizedDescription)")
                    print("❌ Error details: \(error)")
                    
                    // Check if it's an App Check error and retry
                    if error.localizedDescription.contains("AppCheck") || error.localizedDescription.contains("App not registered") {
                        print("🔄 App Check error detected, retrying upload...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            // Retry the upload inline
                            podRef.setData(podData) { retryError in
                                if let retryError = retryError {
                                    print("❌ Retry failed: \(retryError.localizedDescription)")
                                    // If retry fails, still dismiss the view since the file was uploaded successfully
                                    DispatchQueue.main.async {
                                        print("⚠️ Pod data upload failed, but file was uploaded successfully")
                                        self.isUploading = false
                                        self.mode.wrappedValue.dismiss()
                                    }
                                } else {
                                    print("✅ Pod upload retry successful")
                                    DispatchQueue.main.async {
                                        self.isUploading = false
                                        self.mode.wrappedValue.dismiss()
                                    }
                                }
                            }
                        }
                    } else {
                        // Show user-friendly error
                        DispatchQueue.main.async {
                            print("❌ Upload failed: \(error.localizedDescription)")
                        }
                    }
                } else {
                    print("✅ Pod uploaded successfully with metadata")
                    DispatchQueue.main.async {
                        self.isUploading = false
                        self.mode.wrappedValue.dismiss()
                    }
                }
            }
            
            // Upload to user's personal pods collection
            db.collection("users").document(user.uid).collection("pods").document(uniqueID).setData(podData) { error in
                if let error = error {
                    print("Error uploading user pod data: \(error.localizedDescription)")
                } else {
                    print("✅ User pod data uploaded successfully")
                    
                    // Increment user's pod count
                    self.incrementUserPodCount(userId: user.uid)
                }
            }
        }
    
    // MARK: - User Pod Count Management
    
    /// Increments the user's pod count atomically
    private func incrementUserPodCount(userId: String) {
        let userRef = Firestore.firestore().collection("users").document(userId)
        
        userRef.updateData([
            "podCount": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("❌ Failed to increment user pod count: \(error)")
            } else {
                print("✅ User pod count incremented successfully for user: \(userId)")
            }
        }
    }
}

struct ExpandableTextField: View {
    @Binding var text: String
    let placeholder: String
    @Binding var shouldDismiss: Bool
    @State private var textHeight: CGFloat = 30
    @FocusState private var isFocused: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder text
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .padding(.top, 8)
                    .padding(.leading, 4)
            }
            
            TextEditor(text: $text)
                .frame(minHeight: textHeight, maxHeight: 100)
                .focused($isFocused)
                .onChange(of: text) { _ in
                    updateHeight()
                }
                .onAppear {
                    updateHeight()
                }
                .onChange(of: shouldDismiss) { _ in
                    isFocused = false
                }
        }
    }
    
    private func updateHeight() {
        // Estimate lines based on character count and typical line width
        let charactersPerLine: Int = 30 // Approximate characters per line
        let estimatedLines = max(1, (text.count / charactersPerLine) + 1)
        let lineHeight: CGFloat = 20
        textHeight = CGFloat(estimatedLines) * lineHeight
    }
}

// MARK: - TagsFlowLayout

struct TagsFlowLayout: View {
    let tags: [String]
    let onDelete: (Int) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 8) {
            ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                TagBubble(tag: tag) {
                    onDelete(index)
                }
            }
        }
    }
    
    // MARK: - Retry Logic (inline implementation)
}

struct TagBubble: View {
    let tag: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Text(tag)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("accentColor"))
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("accentColor"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color("accentColor").opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color("accentColor"), lineWidth: 1)
                )
        )
    }
}

// MARK: - InteractiveMediaPlayer

struct InteractiveMediaPlayer: View {
    let fileName: String
    let fileUrl: URL?
    
    @StateObject private var playerViewModel = MediaPlayerViewModel()
    @State private var showFullScreenPlayer = false
    
    private var fileExtension: String {
        return fileName.components(separatedBy: ".").last?.lowercased() ?? ""
    }
    
    private var isVideo: Bool {
        let videoExts = ["mp4", "mov", "avi", "mkv", "m4v", "mpeg", "mpg", "3gp", "webm"]
        return videoExts.contains(fileExtension)
    }
    
    private var isAudio: Bool {
        let audioExts = ["mp3", "wav", "m4a", "aac", "flac", "mp2", "wma", "ogg", "opus"]
        return audioExts.contains(fileExtension)
    }
    
    private var mediaColor: Color {
        if isVideo {
            return .purple
        } else if isAudio {
            return .orange
        } else {
            return Color("accentColor")
        }
    }
    
    var body: some View {
            VStack(spacing: 8) {
                if isVideo {
                    // Video player preview
                    ZStack {
                        if let url = fileUrl {
                            VideoThumbnailView(url: url)
                                .frame(maxWidth: 200, maxHeight: 120)
                                .cornerRadius(12)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .frame(width: 200, height: 120)
                                .cornerRadius(12)
                        }
                        
                        // Play button overlay
                        Button {
                            if isVideo {
                                showFullScreenPlayer = true
                            } else {
                                togglePlayback()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.6))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .scaleEffect(playerViewModel.isPlaying ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: playerViewModel.isPlaying)
                    }
                } else if isAudio {
                    // Audio player interface
                    VStack(spacing: 12) {
                        // Waveform visual
                        HStack(spacing: 3) {
                            ForEach(0..<8, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(mediaColor)
                                    .frame(width: 3, height: CGFloat.random(in: 8...24))
                                    .scaleEffect(y: playerViewModel.isPlaying ? CGFloat.random(in: 0.5...1.5) : 1.0)
                                    .animation(
                                        playerViewModel.isPlaying
                                        ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(index) * 0.1)
                                        : .default,
                                        value: playerViewModel.isPlaying
                                    )
                            }
                        }
                        .frame(height: 30)
                        
                        // Play button
                        Button {
                            togglePlayback()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(mediaColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Circle()
                                    .stroke(mediaColor, lineWidth: 2)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: playerViewModel.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(mediaColor)
                            }
                        }
                        .scaleEffect(playerViewModel.isPlaying ? 0.95 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: playerViewModel.isPlaying)
                    }
                    .frame(width: 200, height: 120)
                } else {
                    // Generic file preview
                    VStack(spacing: 8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(mediaColor)
                        
                        Text("Document")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(mediaColor)
                    }
                    .frame(width: 200, height: 120)
                }
                
                // Remove filename display
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(mediaColor.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(mediaColor.opacity(0.2), lineWidth: 1.5)
                    )
                    .shadow(color: mediaColor.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            .onAppear {
                if let url = fileUrl {
                    playerViewModel.setupPlayer(with: url)
                }
            }
            .sheet(isPresented: $showFullScreenPlayer) {
                if let url = fileUrl, isVideo {
                    FullScreenVideoPlayer(url: url)
                }
            }
        }
        
        private func togglePlayback() {
            if playerViewModel.isPlaying {
                playerViewModel.pause()
            } else {
                playerViewModel.play()
            }
        }
    }
    
    // MARK: - MediaPlayerViewModel
    
    class MediaPlayerViewModel: ObservableObject {
        @Published var isPlaying = false
        private var player: AVPlayer?
        
        func setupPlayer(with url: URL) {
            player = AVPlayer(url: url)
        }
        
        func play() {
            player?.play()
            isPlaying = true
        }
        
        func pause() {
            player?.pause()
            isPlaying = false
        }
    }
    
    // MARK: - VideoThumbnailView
    
    struct VideoThumbnailView: View {
        let url: URL
        @State private var thumbnailImage: UIImage?
        
        var body: some View {
            ZStack {
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        )
                }
            }
            .onAppear {
                generateThumbnail()
            }
            .onChange(of: url) { _ in
                generateThumbnail()
            }
        }
        
        private func generateThumbnail() {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Don't set maximumSize to let it use the natural video dimensions
            // This prevents weird aspect ratio issues
            
            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            
            DispatchQueue.global(qos: .background).async {
                do {
                    let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                    let image = UIImage(cgImage: cgImage)
                    
                    DispatchQueue.main.async {
                        self.thumbnailImage = image
                    }
                } catch {
                    print("Error generating thumbnail: \(error)")
                    // Fallback to a default image or keep loading state
                }
            }
        }
    }
    
    // MARK: - VideoPlayerView
    
    struct VideoPlayerView: UIViewRepresentable {
        let url: URL
        let showControls: Bool
        
        func makeUIView(context: Context) -> UIView {
            let playerLayer = AVPlayerLayer()
            let player = AVPlayer(url: url)
            playerLayer.player = player
            playerLayer.videoGravity = .resizeAspectFill
            
            let view = UIView()
            view.layer.addSublayer(playerLayer)
            
            // Auto-layout the player layer
            DispatchQueue.main.async {
                playerLayer.frame = view.bounds
            }
            
            return view
        }
        
        func updateUIView(_ uiView: UIView, context: Context) {
            if let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
                playerLayer.frame = uiView.bounds
            }
        }
    }
    
    // MARK: - FullScreenVideoPlayer
    
    struct FullScreenVideoPlayer: View {
        let url: URL
        @Environment(\.presentationMode) var presentationMode
        
        var body: some View {
            NavigationView {
                VideoPlayer(player: AVPlayer(url: url))
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .foregroundColor(Color("accentColor"))
                            .fontWeight(.medium)
                        }
                    }
            }
        }
    }
    
    struct UploadPodView_Previews: PreviewProvider {
        static var previews: some View {
            UploadPodView(user: PreviewClass().previewUser)
        }
    }
