//
//  CoreMLFoodClassifier.swift
//  CalorieCameraKit
//
//  Created by Janice C on 10/30/25.
//

import Foundation
import CoreML
import Vision
#if canImport(UIKit)
import UIKit
#endif

// Match the protocol from the kit:
public struct ClassResult {
    public let label: String       // canonicalized name you’ll use for priors
    public let confidence: Double  // 0.0 ... 1.0
    public let rawTopK: [(String, Double)]
}

public final class CoreMLFoodClassifier: Classifier {
    private let vnModel: VNCoreMLModel
    private let topK: Int

    public init(model: MLModel, topK: Int = 3) throws {
        self.vnModel = try VNCoreMLModel(for: model)
        self.topK = topK
    }

    /// Classify a single food instance. If you don't have a mask yet, we classify the whole image.
    public func classify(instance: FoodInstanceMask) async throws -> ClassResult {
        // Prefer CGImage → Vision handles resizing/cropping internally.
        if let cgImage = cgImage(from: instance) {
            return try classify(cgImage: cgImage)
        }

        // Fallback: if CGImage failed but we can make a pixel buffer, use that.
        if let pb = try? pixelBuffer(from: instance) {
            return try classify(pixelBuffer: pb)
        }

        // Final fallback
        return ClassResult(label: "unknown", confidence: 0.0, rawTopK: [])
    }

    // MARK: - Core classification paths

    private func classify(cgImage: CGImage) throws -> ClassResult {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        return makeResult(from: request)
    }

    private func classify(pixelBuffer: CVPixelBuffer) throws -> ClassResult {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try handler.perform([request])

        return makeResult(from: request)
    }

    private func makeResult(from request: VNRequest) -> ClassResult {
        guard let results = request.results as? [VNClassificationObservation],
              let best = results.first else {
            return ClassResult(label: "unknown", confidence: 0.0, rawTopK: [])
        }

        let top = Array(results.prefix(topK)).map { ($0.identifier, Double($0.confidence)) }
        let canonical = Self.canonicalize(best.identifier)
        return ClassResult(label: canonical, confidence: Double(best.confidence), rawTopK: top)
    }

    // MARK: - Helpers

    /// Convert "Korean Braised Tofu" -> "korean_braised_tofu"
    private static func canonicalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    /// Try to get a CGImage from the instance.
    /// Expectation: your FoodInstanceMask should (at least) let us reach the RGB image bytes.
    private func cgImage(from instance: FoodInstanceMask) -> CGImage? {
        #if canImport(UIKit)
        if let data = instance.rgbImageData,
           let ui = UIImage(data: data),
           let cg = ui.cgImage ?? ui.precomposedCGImage() {
            return cg
        }
        #endif
        return nil
    }

    /// As a fallback, make a pixel buffer from the full image.
    private func pixelBuffer(from instance: FoodInstanceMask) throws -> CVPixelBuffer {
        #if canImport(UIKit)
        guard
            let data = instance.rgbImageData,
            let ui = UIImage(data: data),
            let cg = ui.cgImage ?? ui.precomposedCGImage()
        else {
            throw NSError(domain: "CoreMLFoodClassifier", code: -10, userInfo: [NSLocalizedDescriptionKey: "Bad image data"])
        }

        let width = cg.width
        let height = cg.height

        var pb: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pb)
        guard let pixelBuffer = pb else {
            throw NSError(domain: "CoreMLFoodClassifier", code: -11, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate pixel buffer"])
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            throw NSError(domain: "CoreMLFoodClassifier", code: -12, userInfo: [NSLocalizedDescriptionKey: "Context creation failed"])
        }

        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
        #else
        throw NSError(domain: "CoreMLFoodClassifier", code: -13, userInfo: [NSLocalizedDescriptionKey: "UIKit not available"])
        #endif
    }
}

#if canImport(UIKit)
private extension UIImage {
    func precomposedCGImage() -> CGImage? {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let img = renderer.image { _ in self.draw(in: CGRect(origin: .zero, size: size)) }
        return img.cgImage
    }
}
#endif
