import SwiftUI
import PhotosUI

struct PhotoPickerButton: View {
    let label: String
    let systemImage: String
    @Binding var imageData: Data?

    @State private var pickerItem: PhotosPickerItem?
    @State private var showOptions = false
    @State private var showCamera = false

    var body: some View {
        Group {
            if let data = imageData, let ui = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    Button {
                        imageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
                    .padding(Spacing.xs)
                }
            } else {
                Button { showOptions = true } label: {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: systemImage)
                            .font(.system(size: 28))
                            .foregroundStyle(Color.muckGreen)
                        Text(label)
                            .font(.muckBody)
                            .foregroundStyle(Color.muckNearBlack.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color.muckSurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .strokeBorder(Color.muckGreen.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Add Photo", isPresented: $showOptions) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo")
            }
            Button("Take Photo") { showCamera = true }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: pickerItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) {
                    // Compress to max 1MB JPEG
                    if let ui = UIImage(data: data) {
                        imageData = ui.jpegData(compressionQuality: 0.7)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(imageData: $imageData)
                .ignoresSafeArea()
        }
    }
}

// Minimal UIImagePickerController wrapper for camera
struct CameraView: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.imageData = img.jpegData(compressionQuality: 0.7)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
