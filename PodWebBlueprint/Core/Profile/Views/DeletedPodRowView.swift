//
//  DeletedPodRowView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/22/23.
//

import SwiftUI
import FirebaseFirestore

struct DeletedPodRowView: View {
    let pod: Pod
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            // Placeholder thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.title2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(pod.title)
                    .font(.headline)
                    .foregroundColor(.gray)
                
                Text(pod.description)
                    .font(.subheadline)
                    .foregroundColor(.gray.opacity(0.8))
                    .lineLimit(2)
                
                HStack {
                    Text("Pod not available")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button(action: onRemove) {
                        Text("Remove")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct DeletedPodRowView_Previews: PreviewProvider {
    static var previews: some View {
        DeletedPodRowView(
            pod: Pod(
                title: "Pod not available",
                timestamp: Timestamp(date: Date()),
                description: "This pod has been deleted or is no longer accessible.",
                fileUrl: "",
                thumbnailUrl: "",
                userId: "preview-user-id",
                likes: 0
            ),
            onRemove: {}
        )
        .padding()
    }
}
