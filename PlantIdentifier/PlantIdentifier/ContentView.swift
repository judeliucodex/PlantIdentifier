import SwiftUI
import Vision
import CoreML
import PhotosUI

struct ContentView: View {
    @State private var inputImage: UIImage?
    @State private var classificationLabel: String = "Tap the camera to start"
    @State private var showImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Plant Identifier")
                .font(.largeTitle.bold())
                .padding(.top)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 300)
                
                if let inputImage = inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                } else {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                }
            }
            .padding()

            Text(classificationLabel)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()

            HStack(spacing: 40) {
                // Camera Button
                Button(action: {
                    self.sourceType = .camera
                    self.showImagePicker = true
                }) {
                    Image(systemName: "camera.fill")
                        .font(.title)
                }

                // Gallery Button
                Button(action: {
                    self.sourceType = .photoLibrary
                    self.showImagePicker = true
                }) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            Spacer()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $inputImage, sourceType: sourceType) { selectedImage in
                processImage(selectedImage)
            }
        }
    }

    // MARK: - CoreML Logic
    func processImage(_ image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        
        // 1. Load the model
        // Note: Ensure MyImageClassifier is added to your project
        guard let model = try? VNCoreMLModel(for: MyImageClassifier1(configuration: MLModelConfiguration()).model) else {
            classificationLabel = "Failed to load model"
            return
        }
        
        // 2. Create Request
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation],
                  let topResult = results.first else {
                classificationLabel = "Unknown species"
                return
            }
            
            let speciesName = topResult.identifier
            classificationLabel = "Identified: \(speciesName)"
            
            // 3. Trigger Safari Search
            searchOnGoogle(speciesName)
        }
        
        // 3. Run Request
        let handler = VNImageRequestHandler(ciImage: ciImage)
        DispatchQueue.global(qos: .userInteractive).async {
            try? handler.perform([request])
        }
    }

    func searchOnGoogle(_ query: String) {
        let formattedQuery = query.replacingOccurrences(of: " ", with: "+")
        if let url = URL(string: "https://www.google.com/search?q=\(formattedQuery)+plant+care") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Image Picker Wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var completion: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.completion(uiImage)
            }
            picker.dismiss(animated: true)
        }
    }
}
