import SwiftUI

struct ImageCropper: View {
    @Binding var image: UIImage?
    @Binding var croppedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    @State private var dragOffset: CGSize = .zero
    @State private var cropRect: CGRect = .zero
    @State private var showCropFrame: Bool = false

    var body: some View {
        VStack {
            if let image = image {
                GeometryReader { geometry in
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .overlay(Rectangle().stroke(Color.white, lineWidth: 2))
                            .clipped()

                        Rectangle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .offset(x: cropRect.origin.x, y: cropRect.origin.y)
                            .gesture(DragGesture()
                                .onChanged { value in
                                    dragOffset.width += value.translation.width
                                    dragOffset.height += value.translation.height
                                    cropRect = CGRect(x: dragOffset.width, y: dragOffset.height, width: cropRect.width, height: cropRect.height)
                                }
                                .onEnded { _ in
                                    // Update crop rect when dragging ends
                                    cropRect = CGRect(x: dragOffset.width, y: dragOffset.height, width: cropRect.width, height: cropRect.height)
                                }
                            )
                    }
                    .frame(width: geometry.size.width, height: geometry.size.width) // Keep aspect ratio square
                    .clipped()
                    .onAppear {
                        // Initialize crop rect to the center of the image
                        cropRect = CGRect(x: (geometry.size.width - 200) / 2, y: (geometry.size.width - 200) / 2, width: 200, height: 200)
                    }
                }
                .padding()
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)

                Button("Crop") {
                    // Crop the image based on the cropRect
                    croppedImage = cropImage(image: image, rect: cropRect)
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            } else {
                Text("No image selected")
            }
        }
    }

    // Function to crop the image based on a given rect
    private func cropImage(image: UIImage, rect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard let croppedCGImage = cgImage.cropping(to: rect) else { return nil }
        return UIImage(cgImage: croppedCGImage)
    }
}

struct ImageCropper_Previews: PreviewProvider {
    static var previews: some View {
        ImageCropper(image: .constant(UIImage(named: "example")), croppedImage: .constant(nil))
    }
}
