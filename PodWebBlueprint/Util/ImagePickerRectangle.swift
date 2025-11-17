import SwiftUI
import TOCropViewController // Import TOCropViewController

struct ImagePickerRectangle: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> some UIViewController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        context.coordinator.imagePicker = picker
        return picker
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerRectangle
        weak var imagePicker: UIImagePickerController?

        init(_ parent: ImagePickerRectangle) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let image = info[.originalImage] as? UIImage else { 
                parent.presentationMode.wrappedValue.dismiss()
                return 
            }

            // Present TOCropViewController to allow cropping
            let cropViewController = TOCropViewController(image: image)
            cropViewController.delegate = self
            
            // Set cropViewController properties to force rectangular crop but enable rotation
            cropViewController.aspectRatioLockEnabled = true
            cropViewController.toolbar.clampButtonHidden = true
            cropViewController.toolbar.resetButtonHidden = true
            cropViewController.rotateButtonsHidden = false      // Show rotation buttons
            cropViewController.rotateClockwiseButtonHidden = false // Show clockwise rotation button
            
            // Set a custom rectangular ratio (e.g., 16:9)
            cropViewController.aspectRatioPreset = .presetCustom
            cropViewController.customAspectRatio = CGSize(width: 16, height: 9) // Customize as needed
            
            picker.present(cropViewController, animated: true, completion: nil)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

extension ImagePickerRectangle.Coordinator: TOCropViewControllerDelegate {
    func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
        parent.selectedImage = image
        parent.presentationMode.wrappedValue.dismiss()
    }
    
    func cropViewControllerDidCancel(_ cropViewController: TOCropViewController) {
        // Dismiss the crop view back to the image picker
        cropViewController.dismiss(animated: true) {
            // Now dismiss the image picker properly
            DispatchQueue.main.async {
                self.imagePicker?.dismiss(animated: true) {
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}
