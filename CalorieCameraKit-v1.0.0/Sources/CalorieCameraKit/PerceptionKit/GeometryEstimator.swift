import Foundation

/// Lightweight depth-based geometry estimator with proper uncertainty propagation.
/// Uses delta method to propagate volume, density, and energy uncertainties.
public final class GeometryEstimator {
    public struct Parameters {
        /// Estimated density in g/mL (default ~ water)
        public let density: Double
        /// Estimated energy per gram (kcal/g)
        public let energyPerGram: Double
        /// Relative volume uncertainty (σ_V = volume * relativeVolumeSigma)
        public let relativeVolumeSigma: Double
        /// Minimum σ if the relative value is too small
        public let minimumSigma: Double
        /// Fallback calories if depth is unavailable
        public let fallbackCalories: Double
        /// Evidence tags to attach when geometry succeeds
        public let evidence: [String]
        /// Evidence tags when geometry falls back
        public let fallbackEvidence: [String]
        /// Approximate real-world area represented by a single depth pixel (m²)
        public let pixelAreaEstimate: Double

        public init(
            density: Double = 1.0,
            energyPerGram: Double = 1.35,
            relativeVolumeSigma: Double = 0.25, // 25% volume uncertainty
            minimumSigma: Double = 80,
            fallbackCalories: Double = 420,
            evidence: [String] = ["Geometry", "Depth"],
            fallbackEvidence: [String] = ["Geometry", "Fallback"],
            pixelAreaEstimate: Double = 1.5e-6
        ) {
            self.density = density
            self.energyPerGram = energyPerGram
            self.relativeVolumeSigma = relativeVolumeSigma
            self.minimumSigma = minimumSigma
            self.fallbackCalories = fallbackCalories
            self.evidence = evidence
            self.fallbackEvidence = fallbackEvidence
            self.pixelAreaEstimate = pixelAreaEstimate
        }
    }

    private let parameters: Parameters
    private let fusionEngine: FusionEngine

    public init(parameters: Parameters = Parameters()) {
        self.parameters = parameters
        self.fusionEngine = FusionEngine(config: .default)
    }

    /// Estimate calories with proper uncertainty propagation using delta method
    ///
    /// If VLM priors are provided, uses them with their uncertainties.
    /// Otherwise falls back to default priors.
    public func estimate(
        from frame: CapturedFrame?,
        priors: FoodPriors? = nil
    ) -> GeometryEstimate {
        guard
            let frame,
            let depthData = frame.depthData,
            !depthData.depthMap.isEmpty
        else {
            return fallbackEstimate()
        }

        // Calculate volume from depth map
        let depths = depthData.depthMap.map(Double.init).filter { $0 > 0 } // Only valid depths
        guard !depths.isEmpty else { return fallbackEstimate() }
        
        let sorted = depths.sorted()
        let count = sorted.count
        
        // Find foreground (closest 40% of pixels) - this should be the food
        let foregroundEndIndex = Int(Double(count) * 0.4)
        let foregroundDepthMax = sorted[min(foregroundEndIndex, count - 1)]
        
        // Food pixels are the closest 40% (assuming food is on a plate/table, closer than background)
        var foodDepths: [Double] = []
        for depth in depths {
            if depth <= foregroundDepthMax {
                foodDepths.append(depth)
            }
        }
        
        guard foodDepths.count > 100 else {
            return fallbackEstimate()
        }
        
        let foodPixelCount = foodDepths.count
        let foodDepthSum = foodDepths.reduce(0, +)
        
        // Average depth of food region (in meters)
        let avgFoodDepth = foodDepthSum / Double(foodPixelCount)
        
        // Calculate real-world pixel size at this depth
        // Formula: pixel_size = (sensor_pixel_size × depth) / focal_length
        // Typical iPhone: sensor width ~6mm, pixel size ~1.5μm, focal ~4mm
        let pixelSizeAtDepth: Double
        if let intrinsics = frame.cameraIntrinsics {
            // Focal length in pixels, convert to mm assuming typical sensor size
            let avgFocalPixels = Double((intrinsics.focalLength.x + intrinsics.focalLength.y) / 2)
            let imageWidth = Double(intrinsics.imageSize.x)
            // Approximate: sensor width 6mm, so pixel size ~6mm / image_width
            let sensorPixelSize = 6e-3 / imageWidth
            // Focal length in mm ≈ (focal_pixels × sensor_width) / image_width
            let focalLengthMM = (avgFocalPixels * 6e-3) / imageWidth
            pixelSizeAtDepth = (sensorPixelSize * avgFoodDepth) / (focalLengthMM / 1000.0)
        } else {
            // Fallback: typical iPhone camera
            pixelSizeAtDepth = (1.5e-6 * avgFoodDepth) / 4e-3
        }
        let pixelAreaMetersSquared = pixelSizeAtDepth * pixelSizeAtDepth
        
        // Food area = number of food pixels × area per pixel
        let foodAreaMetersSquared = Double(foodPixelCount) * pixelAreaMetersSquared
        
        // Height estimate: difference between closest and farthest food pixels
        let minFoodDepth = foodDepths.min() ?? avgFoodDepth
        let maxFoodDepth = foodDepths.max() ?? avgFoodDepth
        let heightMeters = max(0.01, maxFoodDepth - minFoodDepth) // At least 1cm
        
        // Volume = area × height
        let volumeMetersCubed = foodAreaMetersSquared * heightMeters
        
        // Convert m³ → mL (1 m³ = 1,000,000 mL), clamp to reasonable range
        // Much more conservative: cap at 2L (2000mL) for typical food portions
        let volumeML = min(max(10.0, volumeMetersCubed * 1_000_000.0), 2_000.0)
        
        NSLog("📐 Geometry: foodPixels=\(foodPixelCount), avgDepth=\(String(format: "%.3f", avgFoodDepth))m, area=\(String(format: "%.4f", foodAreaMetersSquared))m², height=\(String(format: "%.3f", heightMeters))m, volumeML=\(String(format: "%.1f", volumeML))")

        // Estimate volume uncertainty from depth measurement variability
        let volumeSigmaML = volumeML * parameters.relativeVolumeSigma

        // Create volume estimate
        let volumeEstimate = VolumeEstimate(muML: volumeML, sigmaML: volumeSigmaML)

        // Use VLM-provided priors if available, otherwise use defaults
        let foodPriors: FoodPriors
        if let vlmPriors = priors {
            foodPriors = vlmPriors
            NSLog("📐 Using VLM priors: ρ=\(vlmPriors.density.mu)±\(vlmPriors.density.sigma), e=\(vlmPriors.kcalPerG.mu)±\(vlmPriors.kcalPerG.sigma)")
        } else {
            // Use default priors with estimated uncertainties
            foodPriors = FoodPriors(
                density: PriorStats(mu: parameters.density, sigma: parameters.density * 0.20),
                kcalPerG: PriorStats(mu: parameters.energyPerGram, sigma: parameters.energyPerGram * 0.15)
            )
            NSLog("📐 Using default priors: ρ=\(parameters.density), e=\(parameters.energyPerGram)")
        }

        // Use delta method to propagate uncertainties: C = V × ρ × e
        let calorieEstimate = fusionEngine.caloriesFromGeometry(
            volume: volumeEstimate,
            priors: foodPriors
        )

        let finalSigma = max(parameters.minimumSigma, calorieEstimate.sigma)

        NSLog("📐 Volume: \(volumeML)±\(volumeSigmaML) mL → Calories: \(calorieEstimate.mu)±\(finalSigma)")

        let evidence = parameters.evidence

        return GeometryEstimate(
            label: "Geometry",
            volumeML: volumeML,
            calories: calorieEstimate.mu,
            sigma: finalSigma,
            evidence: evidence
        )
    }

    private func fallbackEstimate() -> GeometryEstimate {
        let evidence = parameters.fallbackEvidence
        let calories = parameters.fallbackCalories

        // Use reasonable uncertainty estimate for fallback
        let sigma = max(parameters.minimumSigma, calories * 0.50)  // 50% uncertainty for fallback

        return GeometryEstimate(
            label: "Geometry",
            volumeML: 350,
            calories: calories,
            sigma: sigma,
            evidence: evidence
        )
    }
}
