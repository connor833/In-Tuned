import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct OnboardingView: View {
    @State private var currentStep = -1
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var profileImage: Image?
    @State private var bio = ""
    @State private var isLoading = false
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Error handling
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    // Preferences selection state
    @State private var selectedCategories: Set<String> = []
    @StateObject var userPreferencesViewModel = UserPreferencesViewModel()
    
    // Animation states
    @State private var isAnimating = false
    @State private var showContent = false
    @State private var progressAnimation = 0.0
    @Namespace private var animation
    
    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color("mainColor").opacity(0.1),
                    Color("accentColor").opacity(0.05),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern progress indicator
            VStack(spacing: 0) {
                Spacer()
                        .frame(height: 60)
                    
                    modernProgressIndicator
                        .padding(.horizontal, 30)
                        .padding(.bottom, 40)
                }
                
                // Content area with smooth transitions
                ZStack {
                    ForEach(-1...2, id: \.self) { step in
                        if currentStep == step {
                            stepContent(for: step)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                    }
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0), value: currentStep)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert("Invalid Bio", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: selectedImage) { _ in
            loadImage()
        }
        .onAppear {
            startEntranceAnimation()
        }
    }
    
    // MARK: - Modern UI Components
    
    private var modernProgressIndicator: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? 
                          LinearGradient(
                            gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ) : 
                          LinearGradient(
                            gradient: Gradient(colors: [Color(.systemGray5), Color(.systemGray4)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                    )
                    .frame(width: 12, height: 12)
                    .scaleEffect(index == currentStep ? 1.2 : 1.0)
                    .shadow(
                        color: index <= currentStep ? Color("accentColor").opacity(0.3) : Color.clear,
                        radius: index == currentStep ? 8 : 0,
                        x: 0,
                        y: 2
                    )
                    .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0), value: currentStep)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    @ViewBuilder
    private func stepContent(for step: Int) -> some View {
        switch step {
        case -1:
            welcomeStep
        case 0:
            profilePhotoStep
        case 1:
            bioStep
        case 2:
            preferencesStep
        default:
            EmptyView()
        }
    }
    
    // MARK: - Step Views
    
    private var welcomeStep: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                // Animated welcome icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    
                            Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.0 : 0.5)
                        .opacity(isAnimating ? 1.0 : 0.0)
                }
                .animation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0).delay(0.2), value: isAnimating)
                
                VStack(spacing: 16) {
                            Text("Welcome to In-Tuned!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("textColor"), Color("textColor").opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                            
                            Text("Your account has been successfully created. Let's set up your profile to get started!")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                }
                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.4), value: showContent)
                        }
                        
                        Spacer()
                        
            // Modern button with gradient and shadow
                        Button {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                currentStep = 0
                            }
                        } label: {
                HStack(spacing: 12) {
                            Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                }
                                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(
                    color: Color("accentColor").opacity(0.4),
                    radius: 12,
                    x: 0,
                    y: 6
                )
                .scaleEffect(isAnimating ? 1.0 : 0.9)
                .opacity(isAnimating ? 1.0 : 0.0)
            }
            .padding(.horizontal, 30)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.6), value: isAnimating)
                        
                        Spacer()
                    }
                    .padding()
    }
    
    private var profilePhotoStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                        Text("Add a Profile Photo!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color("textColor"), Color("textColor").opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                        
                        Text("Let others know who you are")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.2), value: showContent)
            
            // Modern profile photo picker
                        Button {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                            showImagePicker.toggle()
                        } label: {
                ZStack {
                            if let profileImage = profileImage {
                                profileImage
                                    .resizable()
                                    .scaledToFill()
                            .frame(width: 160, height: 160)
                                    .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                            .shadow(
                                color: Color("accentColor").opacity(0.3),
                                radius: 12,
                                x: 0,
                                y: 6
                            )
                            } else {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(.systemGray6), Color(.systemGray5)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 160, height: 160)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color("accentColor").opacity(0.3), Color("accentColor").opacity(0.1)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                            
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                                
                                Text("Add Photo")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color("accentColor"))
                            }
                        }
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.4), value: showContent)
            
            VStack(spacing: 16) {
                        if selectedImage != nil {
                            Button {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                                isLoading = true
                                authViewModel.uploadProfileImage(selectedImage!) { success, _ in
                                    isLoading = false
                                    if success {
                                let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.prepare()
                                notificationFeedback.notificationOccurred(.success)
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                            currentStep = 1
                                        }
                                    }
                                }
                            } label: {
                        HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                } else {
                                    Text("Continue")
                                    .font(.system(size: 18, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .shadow(
                            color: Color("accentColor").opacity(0.4),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                    }
                    .padding(.horizontal, 30)
                        }
                        
                        Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                currentStep = 1
                            }
                        } label: {
                    Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.6), value: showContent)
            
            Spacer()
                    }
                    .padding()
    }
    
    private var bioStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                        Text("Tell us about yourself")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color("textColor"), Color("textColor").opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                        
                        Text("Add a bio to your profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.2), value: showContent)
            
            // Modern text editor with line limits
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bio")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(bio.count)/500")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(bio.count > 450 ? .orange : .secondary)
                }
                .padding(.horizontal, 4)
                
                TextField("Tell us about yourself...", text: $bio, axis: .vertical)
                    .lineLimit(1...5)
                    .font(.system(size: 16, weight: .regular))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color("accentColor").opacity(0.3), Color("accentColor").opacity(0.1)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                            .onChange(of: bio) { newValue in
                                let sanitized = InputSanitizer.clean(newValue, type: .userBio)
                                if sanitized != newValue {
                                    bio = sanitized
                                }
                            }
            }
            .padding(.horizontal, 30)
            .scaleEffect(showContent ? 1.0 : 0.9)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.4), value: showContent)
                        
            VStack(spacing: 16) {
                        Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                            
                            // Validate bio for profanity before saving
                            let bioResult = InputSanitizer.sanitize(bio, type: .userBio)
                            if !bioResult.isValid {
                                // Show error alert for profanity
                                errorMessage = bioResult.errorMessage ?? "Invalid bio"
                                showErrorAlert = true
                                return
                            }
                            
                            if let uid = Auth.auth().currentUser?.uid {
                                isLoading = true
                                Firestore.firestore().collection("users")
                                    .document(uid)
                                    .updateData(["bio": bioResult.sanitizedText]) { error in
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            isLoading = false
                                            if let error = error {
                                                print("Error updating bio: \(error.localizedDescription)")
                                            } else {
                                        let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.prepare()
                                notificationFeedback.notificationOccurred(.success)
                                                authViewModel.fetchUser()
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                                    currentStep = 2
                                                }
                                            }
                                        }
                                    }
                            }
                        } label: {
                    HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            } else {
                                Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(
                        color: Color("accentColor").opacity(0.4),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                }
                .padding(.horizontal, 30)
                        
                        Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                                currentStep = 2
                            }
                        } label: {
                            Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                        }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.6), value: showContent)
            
            Spacer()
                    }
                    .padding()
    }
    
    private var preferencesStep: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                        Text("What interests you?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color("textColor"), Color("textColor").opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                        
                        Text("Select your favorite topics to personalize your feed")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.2), value: showContent)
            
            // Modern category grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(availableCategories, id: \.self) { category in
                                Button {
                        let selectionFeedback = UISelectionFeedbackGenerator()
                        selectionFeedback.prepare()
                        selectionFeedback.selectionChanged()
                                    if selectedCategories.contains(category) {
                                        selectedCategories.remove(category)
                                    } else {
                                        selectedCategories.insert(category)
                                    }
                                } label: {
                        HStack(spacing: 8) {
                                        Image(systemName: iconForCategory(category))
                                .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(selectedCategories.contains(category) ? .white : Color("accentColor"))
                                        
                                        Text(category)
                                .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(selectedCategories.contains(category) ? .white : Color("accentColor"))
                                    }
                                    .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                                    .padding(.horizontal, 16)
                                    .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    selectedCategories.contains(category) ? 
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("accentColor"), Color("accentColor").opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(.systemGray6), Color(.systemGray5)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                    .overlay(
                                        Group {
                                            if selectedCategories.contains(category) {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(Color.clear, lineWidth: 1)
                                            } else {
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(
                                                        LinearGradient(
                                                            gradient: Gradient(colors: [Color("accentColor").opacity(0.3), Color("accentColor").opacity(0.1)]),
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 1
                                                    )
                                            }
                                        }
                                    )
                        )
                        .shadow(
                            color: selectedCategories.contains(category) ? Color("accentColor").opacity(0.3) : Color.black.opacity(0.05),
                            radius: selectedCategories.contains(category) ? 8 : 4,
                            x: 0,
                            y: selectedCategories.contains(category) ? 4 : 2
                        )
                        .scaleEffect(selectedCategories.contains(category) ? 1.05 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 30)
            .scaleEffect(showContent ? 1.0 : 0.9)
            .opacity(showContent ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.4), value: showContent)
            
            VStack(spacing: 16) {
                        Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                            updateSelectedPreferences()
                        } label: {
                    HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            } else {
                                Text("Continue")
                                .font(.system(size: 18, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: selectedCategories.isEmpty ? 
                                [Color(.systemGray4), Color(.systemGray3)] :
                                [Color("accentColor"), Color("accentColor").opacity(0.8)]
                            ),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(
                        color: selectedCategories.isEmpty ? Color.clear : Color("accentColor").opacity(0.4),
                        radius: selectedCategories.isEmpty ? 0 : 12,
                        x: 0,
                        y: selectedCategories.isEmpty ? 0 : 6
                    )
                        }
                        .disabled(selectedCategories.isEmpty || isLoading)
                .padding(.horizontal, 30)
                        
                        Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
                            authViewModel.completeOnboarding()
                        } label: {
                            Text("Skip for now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0).delay(0.6), value: showContent)
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Helper Properties and Methods
    
    private var availableCategories: [String] {
        return ["Sports", "News", "Entertainment", "Technology", "Health", "Music", "Business", "Science", "Education", "Comedy"]
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Sports": return "sportscourt"
        case "News": return "newspaper"
        case "Entertainment": return "tv"
        case "Technology": return "desktopcomputer"
        case "Health": return "heart"
        case "Music": return "music.note"
        case "Business": return "briefcase"
        case "Science": return "flask"
        case "Education": return "graduationcap"
        case "Comedy": return "theatermasks"
        default: return "star"
        }
    }
    
    private func startEntranceAnimation() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
                showContent = true
            }
        }
    }
    
    private func updateSelectedPreferences() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        // Update user preferences based on selected categories
        Task {
            for category in selectedCategories {
                // Give selected categories a higher initial weight (users already have all categories)
                await userPreferencesViewModel.updateCategoryWeight(for: category, userId: uid)
                await userPreferencesViewModel.updateCategoryWeight(for: category, userId: uid) // Call twice for higher weight
            }
            
            // Small delay to show loading state, then finish onboarding
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isLoading = false
                                        let notificationFeedback = UINotificationFeedbackGenerator()
                                notificationFeedback.prepare()
                                notificationFeedback.notificationOccurred(.success)
                print("✅ User preferences updated during onboarding")
                // Finish onboarding
                self.authViewModel.completeOnboarding()
            }
        }
    }
    
    func loadImage() {
        guard let selectedImage = selectedImage else { return }
        
        // Validate the selected image
        let validationResult = FileValidator.validate(image: selectedImage, for: .profileImage)
        
        if validationResult.isValid {
            profileImage = Image(uiImage: selectedImage)
        } else {
            // Reset selection if validation fails
            self.selectedImage = nil
            print("Onboarding profile image validation failed: \(validationResult.errorMessage ?? "Unknown error")")
            // You can add a user-facing error alert here
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
} 
