//
//  InterruptedUploadsAlert.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 1/15/25.
//

import SwiftUI

struct InterruptedUploadsAlert: View {
    let uploads: [UploadItem]
    let onRetryAll: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            // Title
            Text("Uploads Interrupted")
                .font(.title2)
                .fontWeight(.bold)
            
            // Message
            Text("\(uploads.count) upload\(uploads.count == 1 ? "" : "s") were interrupted when the app was closed. Would you like to retry them?")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Upload List
            if uploads.count <= 3 {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(uploads) { upload in
                        HStack {
                            Image(systemName: "doc")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(upload.podTitle)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                
                                Text(upload.fileName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            Text(upload.formattedFileSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("\(uploads.count) uploads were interrupted")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Buttons
            VStack(spacing: 12) {
                Button("Retry All Uploads") {
                    onRetryAll()
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct InterruptedUploadsAlert_Previews: PreviewProvider {
    static var previews: some View {
        InterruptedUploadsAlert(
            uploads: [
                UploadItem(
                    fileName: "sample.mp4",
                    fileUrl: URL(fileURLWithPath: "/tmp/sample.mp4"),
                    fileSize: 50000000,
                    podTitle: "Sample Video",
                    podDescription: "A sample video",
                    tags: ["sample"],
                    thumbnailImage: nil,
                    source: .photosPicker,
                    user: User(
                        uid: "preview_user",
                        username: "preview_user",
                        fullname: "Preview User",
                        profileImageUrl: "",
                        email: "preview@example.com",
                        isVerified: false
                    )
                )
            ],
            onRetryAll: {},
            onDismiss: {}
        )
    }
}
