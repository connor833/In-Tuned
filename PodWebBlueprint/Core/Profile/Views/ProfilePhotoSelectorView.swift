import SwiftUI
import Kingfisher

struct ProfilePhotoSelectorView: View {
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var profileImage: Image?
    @State private var isLoading = false // Added loading state
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var mode
    var userTabView: UserTabView
    
    init(userTabview: UserTabView){
        self.userTabView = userTabview
    }

    var body: some View {
        VStack {
            HStack {
                Button {
                    mode.wrappedValue.dismiss()
                } label: {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                Spacer()
            }
            .padding(.horizontal)

            Button {
                showImagePicker.toggle()
            } label: {
                if let profileImage = profileImage {
                    profileImage
                        .resizable()
                        .modifier(ProfileImageModifier())
                } else if userTabView.user.profileImageUrl != "" {
                    KFImage(URL(string: userTabView.user.profileImageUrl))
                        .resizable()
                        .modifier(ProfileImageModifier())
                } else {
                    Text("+ Photo")
                        .foregroundColor(.white)
                        .foregroundColor(Color("accentColor"))
                        .background(Circle()
                            .scaledToFill()
                            
                            .frame(width: 180, height: 180)
                        )
                        .frame(width: 180, height: 180)
                        .padding(.top, 44)
                }
            }
            .sheet(isPresented: $showImagePicker, onDismiss: loadImage) {
                ImagePicker(selectedImage: $selectedImage)
            }
            .padding(.top, 44)

            if let selectedImage = selectedImage {
                Button {
                    isLoading = true // Start loading
                    viewModel.uploadProfileImage(selectedImage) { success,imageUrl  in
                        isLoading = false // Stop loading

                        if success {
                            userTabView.user.profileImageUrl = imageUrl ?? userTabView.user.profileImageUrl
                            // Dismiss the view upon successful upload
                            mode.wrappedValue.dismiss()
                        }
                    }
                } label: {
                    if isLoading {
                        ProgressView() // Display a loading spinner
                            .frame(width: 340, height: 50)
                            .background(Color("accentColor"))
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                            .padding()
                    } else {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 340, height: 50)
                            .background(Color("accentColor"))
                            .clipShape(Capsule())
                            .padding()
                            .shadow(color: .gray.opacity(0.5), radius: 10, x: 0, y: 0)
                    }
                }
            }

            Spacer()
        }
        .padding(.top, 20)
        .navigationBarBackButtonHidden(true)
    }

    func loadImage() {
        guard let selectedImage = selectedImage else {
            return
        }
        
        // Validate the selected image
        let validationResult = FileValidator.validate(image: selectedImage, for: .profileImage)
        
        if validationResult.isValid {
            profileImage = Image(uiImage: selectedImage)
        } else {
            // Reset selection if validation fails
            self.selectedImage = nil
            print("Profile image validation failed: \(validationResult.errorMessage ?? "Unknown error")")
            // You can add a user-facing error alert here
        }
    }
}

// Rest of the code remains the same


private struct ProfileImageModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color(.systemBlue))
            .scaledToFill()
            .frame(width: 180, height: 180)
            .clipShape(Circle())
    }
}

struct ProfilePhotoSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilePhotoSelectorView(userTabview: UserTabView(user: PreviewClass().previewUser))
    }
}
