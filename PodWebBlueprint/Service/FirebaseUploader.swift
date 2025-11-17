import Firebase
import FirebaseStorage

class FirebaseUploader {
    // MARK: - Properties
    let storageRef: StorageReference
    
    // MARK: - Initialization
    init() {
        storageRef = Storage.storage().reference()
    }
    
    // MARK: - Methods

    /// Uploads a photo to Firebase Storage.
    /// - Parameters:
    ///   - fileData: The data of the file to be uploaded.
    ///   - fileName: The name to be given to the uploaded file.
    ///   - completion: A closure to be called upon completion with the URL of the uploaded file.
    func uploadPhoto(fileData: Data, fileName: String, completion: @escaping (URL?) -> Void) {
        let photoRef = storageRef.child("photos/\(fileName)")
        photoRef.putData(fileData, metadata: nil) { (metadata, error) in
            guard let _ = metadata else {
                completion(nil)
                return
            }
            photoRef.downloadURL { (url, error) in
                completion(url)
            }
        }
    }

    /// Uploads a file from a URL to Firebase Storage.
    /// - Parameters:
    ///   - fileURL: The URL of the file to be uploaded.
    ///   - destinationPath: The destination path for the file in Firebase Storage.
    ///   - completion: A closure to be called upon completion with the result of the operation.
    func uploadFileFromURLToFirebaseStorage(fileURL: URL, destinationPath: String, contentType: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let filename = NSUUID().uuidString
        let fileRef = Storage.storage().reference(withPath: "/audios/\(filename)")
        
        // Use URLSession to download the file data
        URLSession.shared.dataTask(with: fileURL) { (data, _, error) in
            if let error = error {
                print("Error downloading file data: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let fileData = data else {
                let noDataError = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(noDataError))
                return
            }
            
            // Upload the file data to Firebase Storage
            let metadata = StorageMetadata()
            metadata.contentType = contentType // Set content type explicitly
            fileRef.putData(fileData, metadata: metadata) { (metadata, error) in
                if let error = error {
                    print("Error uploading file data: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // File uploaded successfully, get the download URL
                fileRef.downloadURL { (url, error) in
                    if let error = error {
                        print("Error getting download URL: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    if let downloadURL = url {
                        print("Download URL: \(downloadURL)")
                        completion(.success(downloadURL))
                    }
                }
            }
        }.resume()
    }


    /// Uploads a video from a URL to Firebase Storage.
    /// - Parameters:
    ///   - videoURL: The URL of the video to be uploaded.
    ///   - destinationPath: The destination path for the video in Firebase Storage.
    ///   - completion: A closure to be called upon completion with the result of the operation.
    func uploadVideoFromURLToFirebaseStorage(videoURL: URL, destinationPath: String, completion: @escaping (Result<URL, Error>) -> Void) {
        print("Uploading video at destination path: \(destinationPath)")
        print("Video URL: \(videoURL)")
        let filename = NSUUID().uuidString
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = Storage.storage()
        let fileRef = Storage.storage().reference(withPath: "/videos/\(filename)")
        
        // Use URLSession to download the video data
        URLSession.shared.dataTask(with: videoURL) { (data, _, error) in
            if let error = error {
                print("Error downloading video data: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let videoData = data else {
                let noDataError = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(noDataError))
                return
            }
            
            // Upload the video data to Firebase Storage
            fileRef.putData(videoData, metadata: metadata) { (metadata, error) in
                if let error = error {
                    print("Error uploading video data: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                // Video uploaded successfully, get the download URL
                fileRef.downloadURL { (url, error) in
                    if let error = error {
                        print("Error getting download URL: \(error.localizedDescription)")
                        completion(.failure(error))
                        return
                    }
                    
                    if let downloadURL = url {
                        print("Download URL: \(downloadURL)")
                        completion(.success(downloadURL))
                    }
                }
            }
        }.resume()
    }
}
