//
//  ImageUploader.swift
//  PonderBlueprint
//
//  Created by Connor Adams on 6/28/22.
//

import FirebaseStorage
import UIKit
import Firebase

struct StorageUploader {
    
    // Function to upload an image to Firebase Storage
    func uploadImage(image: UIImage, progressHandler: @escaping(Double) -> Void, completion: @escaping(String) -> Void) {
        
        // Convert the UIImage to JPEG data with compression quality 0.5
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        
        // Generate a unique filename using NSUUID
        let filename = NSUUID().uuidString
        
        // Create a reference to the Firebase Storage path for the image
        let ref = Storage.storage().reference(withPath: "/profile_image/\(filename)")
        
        // Upload image data to Firebase Storage with progress tracking
        let uploadTask = ref.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                return
            }
            
            // Once upload is successful, retrieve the download URL
            ref.downloadURL { imageUrl, _ in
                guard let imageUrl = imageUrl?.absoluteString else { return }
                completion(imageUrl)
            }
        }
        
        // Monitor upload progress
        uploadTask.observe(.progress) { snapshot in
            let progress = Double(snapshot.progress!.completedUnitCount) / Double(snapshot.progress!.totalUnitCount)
            progressHandler(progress)
        }
    }
}
