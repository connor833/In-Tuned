import SwiftUI
import Kingfisher

struct ProfileImageModalView: View {
    let profileImageUrl: String
    let username: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Shadowed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            
            // Profile image
            VStack {
                if profileImageUrl != "" {
                    KFImage(URL(string: profileImageUrl))
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.6, maxHeight: UIScreen.main.bounds.height * 0.6)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.6, maxHeight: UIScreen.main.bounds.height * 0.6)
                        .foregroundColor(.gray)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                
                Text("@\(username)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.top, 20)
            }
            .onTapGesture {
                // Prevent dismissal when tapping the image itself
            }
        }
    }
}

struct ProfileImageModalView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileImageModalView(profileImageUrl: "https://example.com/profile.jpg", username: "username")
    }
}
