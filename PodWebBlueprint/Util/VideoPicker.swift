//
//  VideoPicker.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/15/25.
//

import SwiftUI
import PhotosUI
import AVFoundation

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Binding var isLoading: Bool
    @Environment(\.presentationMode) var presentationMode
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        print("🎬 VideoPicker: makeUIViewController called")
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        print("🎬 VideoPicker: PHPickerViewController created")
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            print("🎬 VideoPicker: didFinishPicking called with \(results.count) results")
            picker.dismiss(animated: true)
            
            guard let result = results.first else {
                print("🎬 VideoPicker: No results found")
                return
            }
            
            print("🎬 VideoPicker: Processing result: \(result)")
            
            // Show loading state
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
            
            // Try to get the file URL directly first (faster)
            if let url = result.itemProvider.registeredTypeIdentifiers.first {
                print("🎬 VideoPicker: Trying direct URL access for type: \(url)")
            }
            
            // Get the original video file - we'll compress it during upload
            // This gives us the full quality original file for our own compression
            loadVideoFileRepresentation(result)
        }
        
        private func loadVideoFileRepresentation(_ result: PHPickerResult) {
            // Get the original video file (we'll compress it during upload)
            print("🎬 VideoPicker: Starting to load original video file...")
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                print("🎬 VideoPicker: loadFileRepresentation completed")
                if let error = error {
                    print("❌ Error loading video: \(error.localizedDescription)")
                    return
                }
                
                guard let url = url else {
                    print("❌ No video URL received")
                    return
                }
                
                print("🎬 VideoPicker: Got video URL: \(url)")
                
                // Copy to a permanent location to avoid issues with temporary files
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let destinationURL = documentsPath.appendingPathComponent("\(UUID().uuidString).mov")
                
                do {
                    // Copy the file to a permanent location
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    
                    DispatchQueue.main.async {
                        print("🎬 VideoPicker: Setting selectedURL to: \(destinationURL)")
                        self.parent.selectedURL = destinationURL
                        self.parent.isLoading = false // Hide loading state
                        print("🎬 VideoPicker: selectedURL is now: \(self.parent.selectedURL?.absoluteString ?? "nil")")
                    }
                    
                    print("✅ Video selected: \(destinationURL.lastPathComponent)")
                } catch {
                    print("❌ Error copying video: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.parent.isLoading = false // Hide loading state on error
                    }
                }
            }
        }
    }
}
