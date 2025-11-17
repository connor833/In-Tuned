//
//  AccountSettingsView.swift
//  PodWebBlueprint
//
//  Created by Assistant on Account Settings Implementation
//

import SwiftUI
import FirebaseFirestore

struct AccountSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showDownloadData = false
    @State private var isDownloadingData = false
    @State private var showDownloadSuccess = false
    @State private var showDownloadError = false
    @State private var downloadErrorMessage = ""
    @State private var latestDataDownload: DataDownload?
    @State private var hasRecentLocalDownload = false

    
    var body: some View {
        VStack {
            // Header with back button
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color("accentColor"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color("accentColor"), lineWidth: 2)
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
                
                Text("Account Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Button { } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.clear)
                }
                .disabled(true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Account Information Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Account Information")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("textColor"), Color("textColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 16) {
                            modernInfoRow(
                                icon: "envelope.fill",
                                title: "Email",
                                value: authViewModel.currentUser?.email ?? "Not available",
                                iconColor: .blue
                            )
                            
                            modernInfoRow(
                                icon: "at",
                                title: "Username",
                                value: authViewModel.currentUser?.username ?? "Not available",
                                iconColor: .purple
                            )
                            
                            modernInfoRow(
                                icon: "calendar.badge.plus",
                                title: "Member Since",
                                value: formatDate(authViewModel.currentUser?.createdAt),
                                iconColor: .green
                            )
                            
                            // Last Data Download Section
                            if let latestDownload = latestDataDownload {
                                let canDownload = !latestDownload.downloadUrl.isEmpty
                                
                                Button {
                                    if canDownload {
                                        downloadLastExport(url: latestDownload.downloadUrl, fileName: latestDownload.fileName)
                                    }
                                } label: {
                                    HStack(spacing: 16) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(canDownload ? .blue : .gray)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Last Data Download")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            HStack(spacing: 8) {
                                                Text(formatDate(latestDownload.exportDate))
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                
                                                Text("•")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                
                                                Text(canDownload ? "Available" : "Local File")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(canDownload ? .green : .blue)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if canDownload {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .disabled(!canDownload)
                                .opacity(canDownload ? 1.0 : 0.6)
                                .buttonStyle(PlainButtonStyle())
                            } else if hasRecentLocalDownload {
                                // Show recent local download info
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Recent Data Export")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        HStack(spacing: 8) {
                                            Text("Just now")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            
                                            Text("•")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.secondary)
                                            
                                            Text("Local File")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
                    )
                    
                    // Account Actions Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Account Actions")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("textColor"), Color("textColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 16) {
                            // Download Account Data Button
                            Button {
                                let userService = UserService()
                                userService.canDownloadData { canDownload, errorMessage in
                                    DispatchQueue.main.async {
                                        if canDownload {
                                            showDownloadData = true
                                        } else {
                                            downloadErrorMessage = errorMessage ?? "Monthly download limit reached"
                                            showDownloadError = true
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.1)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 44, height: 44)
                                        
                                        if isDownloadingData {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 20, weight: .medium))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Download Account Data")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Get a copy of all your data")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if !isDownloadingData {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.1)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .shadow(color: Color.blue.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isDownloadingData)
                            
                            // Delete Account Navigation Link
                            NavigationLink(destination: DeleteAccountView()) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundColor(.red)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Delete Account")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.red)
                                        
                                        Text("Permanently remove your account")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(
                                                    LinearGradient(
                                                        gradient: Gradient(colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)]),
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                )
                                .shadow(color: Color.red.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 6)
                    )
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            fetchLatestDownloadInfo()
        }
        .alert("Download Account Data", isPresented: $showDownloadData) {
            Button("Cancel", role: .cancel) { }
            Button("Download") {
                downloadAccountData()
            }
        } message: {
            Text("This will prepare a copy of all your account data including profile information, pods, comments, and preferences. The download will be available shortly.")
        }
        .alert("Download Completed", isPresented: $showDownloadSuccess) {
            Button("OK") { }
        } message: {
            Text("Your account data has been exported successfully! The JSON file has been created and the share sheet should appear shortly.")
        }
        .alert("Download Error", isPresented: $showDownloadError) {
            Button("OK") { }
        } message: {
            Text(downloadErrorMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetNavigationStack"))) { _ in
            // Immediately dismiss the account settings view when account is deleted
            DispatchQueue.main.async {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private func formatDate(_ timestamp: Timestamp?) -> String {
        guard let timestamp = timestamp else { return "Not available" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp.dateValue())
    }
    
    private func downloadAccountData() {
        isDownloadingData = true
        
        let userService = UserService()
        
        // Proceed with download (monthly limit already checked)
        userService.downloadAccountData { success, error, data in
            DispatchQueue.main.async {
                isDownloadingData = false
                
                if success {
                    showDownloadSuccess = true
                    hasRecentLocalDownload = true
                    // Refresh the latest download info
                    fetchLatestDownloadInfo()
                } else {
                    downloadErrorMessage = error?.localizedDescription ?? "Unknown error occurred"
                    showDownloadError = true
                }
            }
        }
    }
    
    private func fetchLatestDownloadInfo() {
        let userService = UserService()
        userService.fetchLatestDownloadInfo { downloadInfo in
            DispatchQueue.main.async {
                // Convert the download info to the format expected by the UI
                if let downloadInfo = downloadInfo {
                    // Create a simple structure for the UI with proper conversions
                    let dateFormatter = ISO8601DateFormatter()
                    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    
                    let exportDate = dateFormatter.date(from: downloadInfo["exportDate"] as? String ?? "") ?? Date()
                    let expiresDate = dateFormatter.date(from: downloadInfo["expiresAt"] as? String ?? "") ?? Date()
                    
                    // Create a default summary since we don't store it in the subcollection
                    let defaultSummary = DownloadSummary(
                        totalPods: 0,
                        totalComments: 0,
                        totalSavedPods: 0,
                        totalPlaylists: 0,
                        totalNotifications: 0,
                        totalConversations: 0,
                        totalMessages: 0,
                        totalFriends: 0,
                        totalFollowing: 0,
                        totalFollowers: 0
                    )
                    
                    self.latestDataDownload = DataDownload(
                        downloadUrl: downloadInfo["downloadUrl"] as? String ?? "",
                        fileName: downloadInfo["fileName"] as? String ?? "",
                        exportDate: Timestamp(date: exportDate),
                        expiresAt: Timestamp(date: expiresDate),
                        fileSize: downloadInfo["fileSize"] as? Int ?? 0,
                        summary: defaultSummary
                    )
                } else {
                    self.latestDataDownload = nil
                }
            }
        }
    }
    
    private func downloadLastExport(url: String, fileName: String) {
        guard let downloadURL = URL(string: url) else {
            downloadErrorMessage = "Invalid download URL"
            showDownloadError = true
            return
        }
        
        // Download the file and then share it
        URLSession.shared.dataTask(with: downloadURL) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.downloadErrorMessage = "Failed to download file: \(error.localizedDescription)"
                    self.showDownloadError = true
                    return
                }
                
                guard let data = data else {
                    self.downloadErrorMessage = "No data received from server"
                    self.showDownloadError = true
                    return
                }
                
                // Save the file to documents directory
                guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                    self.downloadErrorMessage = "Error accessing documents directory"
                    self.showDownloadError = true
                    return
                }
                
                let fileURL = documentsPath.appendingPathComponent(fileName)
                
                do {
                    try data.write(to: fileURL)
                    // Share the file using UIActivityViewController
                    self.shareDownloadedFile(fileURL: fileURL, fileName: fileName)
                } catch {
                    self.downloadErrorMessage = "Failed to save file: \(error.localizedDescription)"
                    self.showDownloadError = true
                }
            }
        }.resume()
    }
    
    private func shareDownloadedFile(fileURL: URL, fileName: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            downloadErrorMessage = "Error accessing root view controller"
            showDownloadError = true
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        // Set the subject for email sharing
        activityViewController.setValue("Account Data Export - \(fileName)", forKey: "subject")
        
        // Present the activity view controller
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootViewController.present(activityViewController, animated: true) {
            print("✅ Share sheet presented for downloaded file: \(fileName)")
        }
    }
    
    // MARK: - Modern UI Helper Functions
    
    @ViewBuilder
    private func modernInfoRow(icon: String, title: String, value: String, iconColor: Color) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [iconColor.opacity(0.2), iconColor.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }

}

struct AccountSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AccountSettingsView()
            .environmentObject(AuthViewModel())
    }
} 
