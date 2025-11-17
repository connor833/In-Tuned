//
//  ProfileView.swift
//  PodWebBlueprint
//
//  Created by Connor Adams on 2/2/23.
//

import SwiftUI
import Kingfisher

struct UserEditView: View {
    private var selectedFilter:UserFilterViewModel = .pods
    @State private var fullname = ""
    @State private var username = ""
    @State private var bio = ""
    @State private var link = ""
    @ObservedObject var userViewModel: UserViewModel
    @State private var showErrorBanner = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @Namespace var animation
    @Environment(\.presentationMode) var mode
    
    let user: User
    var userTabView: UserTabView
    
    init(user: User, userTabview: UserTabView) {
        self.userViewModel = UserViewModel(user: user, authViewModel: AuthViewModel.shared)
        self.user = user
        _fullname = State(initialValue: user.fullname ?? "")
        _username = State(initialValue: user.username)
        _bio = State(initialValue: user.bio ?? "")
        _link = State(initialValue: user.link ?? "")
        self.userTabView = userTabview
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Modern header with navigation
                headerSection
                
                // Error banner with modern styling
                if showErrorBanner {
                    errorBanner
                }
                
                // Profile photo section
                profilePhotoSection
                
                // Form fields with modern styling
                formSection
                
                Spacer(minLength: 100) // Bottom padding for tab bar
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack {
            Button {
                mode.wrappedValue.dismiss()
            } label: {
                Text("Cancel")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Text("Edit Profile")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                saveProfile()
            } label: {
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if showSuccess {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("Save")
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
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Error Banner
    
    private var errorBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.red)
            
            Text(errorMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showErrorBanner = false
                }
            }
        }
    }
    
    // MARK: - Profile Photo Section
    
    private var profilePhotoSection: some View {
        VStack(spacing: 16) {
            NavigationLink(destination: ProfilePhotoSelectorView(userTabview: userTabView)) {
                ZStack {
                    if user.profileImageUrl != "" {
                        KFImage(URL(string: user.profileImageUrl))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    } else {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    
                    // Edit overlay
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .opacity(0.8)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Tap to change photo")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("accentColor"))
        }
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: 20) {
            // Name field
            formField(
                title: "Name",
                text: $fullname,
                placeholder: "Enter your name",
                inputType: .fullName
            )
            
            // Username field
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                TextField("Enter username", text: $username)
                    .font(.system(size: 16, weight: .regular))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                    )
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: username) { newValue in
                        // Force lowercase and sanitize
                        let sanitized = InputSanitizer.clean(newValue, type: .tag)
                        let lowercased = sanitized.lowercased()
                        if lowercased != newValue {
                            username = lowercased
                        }
                    }
            }
            
            // Bio field
            bioField
            
            // Link field
            formField(
                title: "Link",
                text: $link,
                placeholder: "Add a link to your website",
                inputType: .link
            )
        }
    }
    
    // MARK: - Form Field Helper
    
    private func formField(title: String, text: Binding<String>, placeholder: String, inputType: InputSanitizer.InputType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .regular))
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                )
                .onChange(of: text.wrappedValue) { newValue in
                    let sanitized = InputSanitizer.clean(newValue, type: inputType)
                    if sanitized != newValue {
                        text.wrappedValue = sanitized
                    }
                }
        }
    }
    
    // MARK: - Bio Field
    
    private var bioField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bio")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            ExpandableBioField(text: $bio, placeholder: bio.isEmpty ? "Tell us about yourself..." : bio)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                )
        }
    }
    
    // MARK: - Save Profile Function
    
    private func saveProfile() {
        if username.contains(" ") {
            withAnimation {
                errorMessage = "Username cannot contain spaces."
                showErrorBanner = true
            }
            return
        }
        
        // Validate fullname for profanity
        let fullnameResult = InputSanitizer.sanitize(fullname, type: .fullName)
        if !fullnameResult.isValid {
            withAnimation {
                errorMessage = fullnameResult.errorMessage ?? "Invalid full name."
                showErrorBanner = true
            }
            return
        }
        
        // Validate bio for profanity
        let bioResult = InputSanitizer.sanitize(bio, type: .userBio)
        if !bioResult.isValid {
            withAnimation {
                errorMessage = bioResult.errorMessage ?? "Invalid bio."
                showErrorBanner = true
            }
            return
        }
        
        isLoading = true
        showErrorBanner = false
        
        userViewModel.changeUsernameAndProfile(
            newUsername: username.lowercased(),
            fullname: fullnameResult.sanitizedText,
            bio: bioResult.sanitizedText,
            link: InputSanitizer.clean(link, type: .link)
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isLoading = false
                        self.showSuccess = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.updateValues()
                        self.mode.wrappedValue.dismiss()
                    }
                } else {
                    self.isLoading = false
                    
                    if let error = error as NSError?,
                       error.domain == "FunctionsErrorDomain",
                       error.code == 6 {
                        withAnimation {
                            self.errorMessage = "Username already in use."
                            self.showErrorBanner = true
                        }
                    } else {
                        withAnimation {
                            self.errorMessage = error?.localizedDescription ?? "Failed to update profile."
                            self.showErrorBanner = true
                        }
                    }
                }
            }
        }
    }
    
    func updateValues() {
        userTabView.user.username = username
        userTabView.user.fullname = fullname
        userTabView.user.bio = bio
        userTabView.user.link = link
    }
    
}

struct ExpandableBioField: View {
    @Binding var text: String
    let placeholder: String
    @State private var textHeight: CGFloat = 20
    
    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(1...5)
            .frame(height: textHeight)
            .onChange(of: text) { newValue in
                // Sanitize bio input in real-time
                let sanitized = InputSanitizer.clean(newValue, type: .userBio)
                if sanitized != newValue {
                    text = sanitized
                }
                updateHeight()
            }
            .onAppear {
                updateHeight()
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

struct Previews_UserEditView_Previews: PreviewProvider {
    static var previews: some View {
        UserEditView(user: PreviewClass().previewUser, userTabview: UserTabView(user: PreviewClass().previewUser))
    }
}
