//
//  AICameraView.swift
//  HabitPet
//
//  Created by Janice C on 10/14/25.
//

import SwiftUI
import UIKit
import Vision
import Foundation

// MARK: - Output Models
struct AICameraNutritionResult {
    var label: String
    var confidence: Double
    var volumeML: Double
    var sigmaV: Double
    var rho: Double
    var sigmaRho: Double
    var e: Double
    var sigmaE: Double
    var cFused: Double
    var sigmaCFused: Double
    let protein: Double?         // OPTIONAL grams (nil if unknown)
    let carbs: Double?           // OPTIONAL grams (nil if unknown)
    let fats: Double?            // OPTIONAL grams (nil if unknown)
}

enum AICameraCompletion {
    case success(AICameraNutritionResult, sourceType: UIImagePickerController.SourceType)
    case cancelled
    case failed(Error)
}

// MARK: - SwiftUI Bridge
struct AICameraView: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: (AICameraCompletion) -> Void

    var body: some View {
        AICameraControllerRepresentable(onComplete: onComplete)
            .ignoresSafeArea()
    }
}

// MARK: - UIViewControllerRepresentable
struct AICameraControllerRepresentable: UIViewControllerRepresentable {
    var onComplete: (AICameraCompletion) -> Void

    func makeUIViewController(context: Context) -> AICameraController {
        let vc = AICameraController()
        vc.onComplete = onComplete
        return vc
    }

    func updateUIViewController(_ uiViewController: AICameraController, context: Context) {}
}

// MARK: - Main Camera Controller
final class AICameraController: UIViewController {
    var onComplete: ((AICameraCompletion) -> Void)?
    private var imagePickerController: UIImagePickerController?
    private var selectedImage: UIImage?
    private var currentSourceType: UIImagePickerController.SourceType = .camera

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        presentImagePicker()
    }

    private func setupUI() {
        view.backgroundColor = .black
        
        // Add a cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        cancelButton.layer.cornerRadius = 10
        cancelButton.frame = CGRect(x: 20, y: 60, width: 80, height: 40)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
    }

    private func presentImagePicker() {
        // Create a custom overlay view with toggle options
        let overlayView = UIView(frame: view.bounds)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        view.addSubview(overlayView)
        
        // Create toggle container
        let toggleContainer = UIView()
        toggleContainer.backgroundColor = UIColor.white
        toggleContainer.layer.cornerRadius = 15
        toggleContainer.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(toggleContainer)
        
        // Camera button
        let cameraButton = createToggleButton(title: "Camera", icon: "camera.fill", action: {
            overlayView.removeFromSuperview()
            self.currentSourceType = .camera
            self.presentImagePicker(sourceType: .camera)
        })
        
        // Library button
        let libraryButton = createToggleButton(title: "Upload from Library", icon: "photo.fill", action: {
            print("🔍 Library button tapped")
            overlayView.removeFromSuperview()
            self.currentSourceType = .photoLibrary
            print("🔍 Set currentSourceType to: \(self.currentSourceType)")
            self.presentImagePicker(sourceType: .photoLibrary)
        })
        
        // Cancel button
        let cancelButton = createToggleButton(title: "Cancel", icon: "xmark", action: {
            overlayView.removeFromSuperview()
            self.onComplete?(.cancelled)
        })
        
        let stackView = UIStackView(arrangedSubviews: [cameraButton, libraryButton, cancelButton])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        toggleContainer.addSubview(stackView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            toggleContainer.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            toggleContainer.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor),
            toggleContainer.widthAnchor.constraint(equalToConstant: 280),
            
            stackView.topAnchor.constraint(equalTo: toggleContainer.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: toggleContainer.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: toggleContainer.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: toggleContainer.bottomAnchor, constant: -20)
        ])
        
        // Add tap gesture to dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissOverlay))
        overlayView.addGestureRecognizer(tapGesture)
    }
    
    private func createToggleButton(title: String, icon: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        
        // Use modern UIButton configuration
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.baseForegroundColor = .systemBlue
        config.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 15, bottom: 12, trailing: 15)
        config.imagePadding = 10
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            return outgoing
        }
        
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add action
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        
        // Set height
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        return button
    }
    
    @objc private func dismissOverlay() {
        // Find and remove overlay view
        for subview in view.subviews {
            if subview.backgroundColor == UIColor.black.withAlphaComponent(0.8) {
                subview.removeFromSuperview()
                onComplete?(.cancelled)
                break
            }
        }
    }

    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        picker.allowsEditing = true
        imagePickerController = picker
        present(picker, animated: true)
    }

    @objc private func cancelTapped() {
        onComplete?(.cancelled)
    }

    // MARK: - Food Detection
    private func detectFoodInImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            onComplete?(.failed(NSError(domain: "AICamera", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not process image"])))
            return
        }

        // Create Vision request for food detection
        let request = VNClassifyImageRequest { [weak self] request, error in
            if let error = error {
                self?.onComplete?(.failed(error))
                return
            }
            
            self?.processClassificationResults(request.results, image: image)
        }

        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            onComplete?(.failed(error))
        }
    }

    private func processClassificationResults(_ results: [Any]?, image: UIImage) {
        guard let observations = results as? [VNClassificationObservation] else {
            onComplete?(.failed(NSError(domain: "AICamera", code: 2, userInfo: [NSLocalizedDescriptionKey: "No classification results"])))
            return
        }

        // Look for food-related classifications
        let foodKeywords = ["food", "meal", "dish", "plate", "bowl", "salad", "sandwich", "pizza", "pasta", "rice", "chicken", "beef", "fish", "vegetable", "fruit", "bread", "cake", "dessert"]
        
        var bestFoodMatch: VNClassificationObservation?
        var bestConfidence: Float = 0
        
        for observation in observations {
            let identifier = observation.identifier.lowercased()
            let confidence = observation.confidence
            
            // Check if this classification is food-related
            for keyword in foodKeywords {
                if identifier.contains(keyword) && confidence > bestConfidence {
                    bestFoodMatch = observation
                    bestConfidence = confidence
                    break
                }
            }
        }

        // If we found a food match, use it; otherwise use the top result
        let finalObservation = bestFoodMatch ?? observations.first
        
        guard let observation = finalObservation else {
            onComplete?(.failed(NSError(domain: "AICamera", code: 3, userInfo: [NSLocalizedDescriptionKey: "No valid classification found"])))
            return
        }

        // Estimate nutrition based on detected food
        let nutritionData = estimateNutritionForFood(observation.identifier, confidence: observation.confidence, imageSize: image.size)
        
        print("🔍 Calling onComplete with success - sourceType: \(currentSourceType)")
        onComplete?(.success(nutritionData, sourceType: currentSourceType))
    }

    private func estimateNutritionForFood(_ foodName: String, confidence: Float, imageSize: CGSize) -> AICameraNutritionResult {
        // Enhanced food database with realistic nutrition estimates
        let foodDatabase: [String: (calories: Double, protein: Double, carbs: Double, fats: Double, volumeML: Double)] = [
            "chicken": (165, 31, 0, 3.6, 200),
            "salad": (25, 2, 5, 0.2, 150),
            "rice": (130, 2.7, 28, 0.3, 180),
            "pasta": (131, 5, 25, 1.1, 200),
            "pizza": (266, 11, 33, 10, 250),
            "sandwich": (250, 15, 30, 8, 200),
            "fish": (206, 22, 0, 12, 180),
            "beef": (250, 26, 0, 15, 200),
            "vegetable": (25, 2, 5, 0.2, 120),
            "fruit": (60, 1, 15, 0.2, 150),
            "bread": (265, 9, 49, 3.2, 100),
            "cake": (350, 4, 50, 15, 150),
            "dessert": (300, 3, 45, 12, 120),
            "yogurt": (100, 10, 8, 0.4, 150),
            "soup": (80, 4, 12, 2, 250),
            "burger": (354, 16, 33, 18, 200),
            "fries": (365, 4, 63, 11, 150),
            "sushi": (200, 8, 30, 4, 180),
            "taco": (226, 8, 20, 12, 150),
            "burrito": (300, 12, 35, 10, 250)
        ]

        // Find the best match in our database
        let lowercasedFood = foodName.lowercased()
        var bestMatch: (calories: Double, protein: Double, carbs: Double, fats: Double, volumeML: Double)?
        
        for (key, nutrition) in foodDatabase {
            if lowercasedFood.contains(key) {
                bestMatch = nutrition
                break
            }
        }

        // Use database values or fallback to generic estimates
        let (calories, protein, carbs, fats, volumeML) = bestMatch ?? (200, 10, 25, 8, 200)

        // Add some variation based on confidence and image size
        let sizeMultiplier = min(max(imageSize.width * imageSize.height / (300 * 300), 0.5), 2.0)
        let confidenceMultiplier = Double(confidence)
        
        let adjustedCalories = calories * sizeMultiplier * confidenceMultiplier
        let adjustedVolume = volumeML * sizeMultiplier

        return AICameraNutritionResult(
            label: foodName.capitalized,
            confidence: Double(confidence),
            volumeML: adjustedVolume,
            sigmaV: adjustedVolume * 0.2,
            rho: 1.0,
            sigmaRho: 0.1,
            e: 1.4,
            sigmaE: 0.1,
            cFused: adjustedCalories,
            sigmaCFused: adjustedCalories * 0.2,
            protein: protein * sizeMultiplier,
            carbs: carbs * sizeMultiplier,
            fats: fats * sizeMultiplier
        )
    }
}

// MARK: - UIImagePickerControllerDelegate
extension AICameraController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        print("🔍 Image picker finished picking media")
        print("🔍 Current source type: \(currentSourceType)")
        picker.dismiss(animated: true) { [weak self] in
            if let editedImage = info[.editedImage] as? UIImage {
                print("🔍 Using edited image")
                self?.selectedImage = editedImage
                self?.detectFoodInImage(editedImage)
            } else if let originalImage = info[.originalImage] as? UIImage {
                print("🔍 Using original image")
                self?.selectedImage = originalImage
                self?.detectFoodInImage(originalImage)
            } else {
                print("🔍 No image found in info")
                self?.onComplete?(.failed(NSError(domain: "AICamera", code: 4, userInfo: [NSLocalizedDescriptionKey: "No image selected"])))
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.onComplete?(.cancelled)
        }
    }
}

