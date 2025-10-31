import SwiftUI
import CoreML
import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

public struct CalorieCameraView: View {
    @StateObject private var coordinator: CalorieCameraCoordinator

    private var pathColumns: [GridItem] { [GridItem(.adaptive(minimum: 80), spacing: 8)] }

    public init(
        config: CalorieConfig = .default,
        onResult: @escaping (CalorieResult) -> Void = { _ in },
        onCancel: (() -> Void)? = nil
    ) {
        _coordinator = StateObject(
            wrappedValue: CalorieCameraCoordinator(
                config: config,
                onResult: onResult,
                onCancel: onCancel
            )
        )
    }

    public var body: some View {
        VStack(spacing: 16) {
#if canImport(AVFoundation) && canImport(UIKit)
            CameraPreviewSurface(
                session: coordinator.previewSession,
                status: coordinator.statusMessage
            )
#else
            CameraPreviewPlaceholder(status: coordinator.statusMessage)
                .frame(height: 320)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
#endif

            Text("Calorie Camera")
                .font(.title2).bold()

            Text(coordinator.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if coordinator.isCapturing || coordinator.qualityProgress > 0 {
                ProgressView(value: coordinator.qualityProgress, total: 1.0) {
                    Text("Capture quality").font(.caption).foregroundStyle(.secondary)
                } currentValueLabel: {
                    Text("\(Int(coordinator.qualityProgress * 100))%").font(.caption2).monospacedDigit()
                }
                .progressViewStyle(.linear)
                .tint(.green)
                .accessibilityIdentifier("quality-progress")
            }

            if !coordinator.activePaths.isEmpty {
                LazyVGrid(columns: pathColumns, alignment: .leading, spacing: 8) {
                    ForEach(coordinator.activePaths) { path in
                        Text(path.displayName)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(path.badgeColor)
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                            .accessibilityLabel(path.accessibilityLabel)
                    }
                }
                .animation(.easeInOut, value: coordinator.activePaths)
            }

            if let question = coordinator.voiQuestion {
                VStack(spacing: 12) {
                    Text(question).font(.body).multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button("No")  { coordinator.respondToVoI(false) }.buttonStyle(.bordered)
                        Button("Yes") { coordinator.respondToVoI(true)  }.buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
            }

            if let result = coordinator.lastResult {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total: \(Int(result.total.mu)) kcal ± \(Int(2 * result.total.sigma))")
                        .font(.headline)
                    if let item = result.items.first {
                        Text("Evidence: \(item.evidence.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("evidence-tags")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer(minLength: 12)

            HStack(spacing: 12) {
                Button("Cancel") { coordinator.cancel() }
                    .buttonStyle(.bordered)
                    .disabled(!coordinator.canCancel)

                Button("Capture Sample") { coordinator.startCapture() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!coordinator.canStartCapture)
                    .accessibilityIdentifier("capture-button")
            }
        }
        .padding()
        .task { await coordinator.prepareSessionIfNeeded() }
        .onDisappear { coordinator.teardown() }
    }
}

// MARK: - Coordinator

@MainActor
private final class CalorieCameraCoordinator: ObservableObject {
    enum State: Equatable { case idle, ready, capturing, awaitingVoI, completed, failed(String) }
    private enum CaptureCoordinatorError: Error { case cameraUnavailable }

    @Published private(set) var state: State = .idle
    @Published private(set) var statusMessage: String = "Preparing capture…"
    @Published private(set) var activePaths: [AnalysisPath] = []
    @Published private(set) var voiQuestion: String?
    @Published private(set) var lastResult: CalorieResult?
    @Published private(set) var qualityProgress: Double = 0.0
    #if canImport(AVFoundation) && canImport(UIKit)
    @Published private(set) var previewSession: AVCaptureSession?
    #endif

    var canStartCapture: Bool { state == .ready || state == .completed }
    var canCancel: Bool { state == .capturing || state == .awaitingVoI }
    var isCapturing: Bool { state == .capturing || state == .awaitingVoI }

    private let config: CalorieConfig
    private let onResult: (CalorieResult) -> Void
    private let onCancel: (() -> Void)?
    private let qualityEstimator: CaptureQualityEstimator
    private let frameCaptureService: FrameCaptureService?
    private let analyzerClient: AnalyzerClient?
    private let routerEngine: AnalyzerRouter
    private let geometryEstimator: GeometryEstimator

    // MARK: - Local classification + priors (new hook)
    private let localClassifier: (any Classifier)? = {
        // NOTE: Add SeeFood.mlmodel to the APP target (HabitPet), not the package target.
        // Xcode compiles it to SeeFood.mlmodelc in the app bundle at build time.
        guard let url = Bundle.main.url(forResource: "SeeFood", withExtension: "mlmodelc") else {
            NSLog("⚠️ SeeFood.mlmodelc not found in app bundle — local classifier disabled")
            return nil
        }
        do {
            let model = try MLModel(contentsOf: url)
            return try CoreMLFoodClassifier(model: model, topK: 3)
        } catch {
            NSLog("⚠️ Failed to load SeeFood.mlmodelc: \(error)")
            return nil
        }
    }()

    private let nutritionDB: NutritionDB = {
        // Replace with your real data source when ready
        return MockNutritionDB()
    }()

    private var pendingResult: CalorieResult?
    private var askedQuestions = 0

    init(
        config: CalorieConfig,
        onResult: @escaping (CalorieResult) -> Void,
        onCancel: (() -> Void)?
    ) {
        self.config = config
        self.onResult = onResult
        self.onCancel = onCancel
        self.qualityEstimator = CaptureQualityEstimator(parameters: config.captureQuality)
        self.analyzerClient = CalorieCameraCoordinator.makeAnalyzerClient()
        self.routerEngine = AnalyzerRouter(config: config)
        self.geometryEstimator = GeometryEstimator()
        self.frameCaptureService = CalorieCameraCoordinator.makeCaptureService()

        if self.analyzerClient == nil {
            statusMessage = "⚠️ ANALYZER CLIENT IS NIL - NO API CALLS"
            NSLog("❌ Analyzer client nil — API calls disabled")
        } else {
            NSLog("✅ Analyzer client created")
        }
        updateActivePaths()
    }

    func prepareSessionIfNeeded() async {
        guard state == .idle else { return }
        statusMessage = "Calibrate camera and hold steady."
        qualityEstimator.reset()
        qualityProgress = 0

        do {
            if let capture = frameCaptureService {
                guard capture.isCameraAvailable() else { throw CaptureCoordinatorError.cameraUnavailable }
                try await capture.requestPermissions()
                try await capture.startSession()
                #if canImport(AVFoundation) && canImport(UIKit)
                if let p = capture as? CameraPreviewProviding { previewSession = p.previewSession }
                #endif
            }
        } catch {
            state = .failed("Camera unavailable. Allow camera access in Settings.")
            statusMessage = "Camera access required."
            return
        }

        try? await Task.sleep(for: .milliseconds(120))
        state = .ready
        statusMessage = "Ready to capture."
    }

    func startCapture() {
        guard canStartCapture else { return }
        Task { await capture() }
    }

    func respondToVoI(_ yes: Bool) {
        guard state == .awaitingVoI, var result = pendingResult else { return }
        askedQuestions += 1
        let tag = yes ? "VoI-Confirmed" : "VoI-Rejected"
        let factor = yes ? 0.7 : 0.95
        result = applyVoIAdjustment(to: result, factor: factor, evidenceTag: tag)
        pendingResult = nil
        voiQuestion = nil
        finish(with: result)
    }

    func cancel() {
        switch state {
        case .capturing, .awaitingVoI:
            state = .idle
            statusMessage = "Capture cancelled."
            qualityEstimator.reset()
            qualityProgress = 0
            pendingResult = nil
            voiQuestion = nil
            onCancel?()
        default: break
        }
    }

    func teardown() {
        frameCaptureService?.stopSession()
        qualityEstimator.reset()
        qualityProgress = 0
        pendingResult = nil
        voiQuestion = nil
        #if canImport(AVFoundation) && canImport(UIKit)
        previewSession = nil
        #endif
        state = .idle
    }

    private func capture() async {
        state = .capturing
        qualityEstimator.reset()
        qualityProgress = 0
        statusMessage = "Move around the plate to hit quality threshold."

        let qualityStatus = await performQualityGate()
        statusMessage = (qualityStatus?.shouldStop == true)
            ? "Analyzing capture…"
            : "Analyzing best-effort capture…"

        var capturedFrame: CapturedFrame?
        if let capture = frameCaptureService {
            do { capturedFrame = try await capture.captureFrame() }
            catch { print("[CalorieCamera] frame capture failed:", error) }
        }

        var analyzerObservation: AnalyzerObservation?
        var apiErrorMessage: String?

        if let analyzerClient {
            NSLog("🔄 Calling analyzer…")
            statusMessage = "Calling API..."
            do {
                if let data = capturedFrame?.rgbImage {
                    analyzerObservation = try await analyzerClient.analyze(imageData: data, mimeType: "image/jpeg")
                } else {
                    analyzerObservation = try await analyzerClient.analyze(imageData: placeholderImageData(), mimeType: "image/png")
                }
                NSLog("✅ API success; path: \(analyzerObservation?.path?.rawValue ?? "nil")")
                statusMessage = "API succeeded!"
            } catch {
                NSLog("❌ API failed: \(error)")
                apiErrorMessage = "\(error)"
                statusMessage = "API failed: \(error)"
                if let ae = error as? AnalyzerClientError { NSLog("❌ Error details: \(ae.localizedDescription)") }
            }
        } else {
            NSLog("⚠️ analyzerClient is nil")
            statusMessage = "No analyzer client"
        }

        // --------- Local classification hook + label/priors selection (added) ---------
        let localClass = await classifyLocallyAndGetPriors(from: capturedFrame)

        // Geometry estimate (prefer analyzer priors; else local classifier priors; else default)
        let geometry = geometryEstimator.estimate(
            from: capturedFrame,
            priors: analyzerObservation?.priors ?? localClass?.priors
        )

        // Choose the best label to display:
        // Priority: analyzer label → local classifier label → geometry fallback label
        let chosenLabel = analyzerObservation?.label
            ?? localClass?.label
            ?? geometry.label

        // Fuse geometry + analyzer (unchanged router behavior)
        let fusion = routerEngine.fuse(
            geometry: geometry,
            analyzerObservation: analyzerObservation
        )

        // Merge evidence tags (include local classifier tags if present)
        let finalEvidence = Array(Set(
            fusion.evidence +
            (analyzerObservation?.evidence ?? []) +
            (localClass?.evidence ?? [])
        )).sorted()

        let finalCalories = fusion.fusedCalories
        let finalSigma = fusion.fusedSigma

        let item = ItemEstimate(
            label: chosenLabel,
            volumeML: geometry.volumeML,
            calories: finalCalories,
            sigma: finalSigma,
            evidence: finalEvidence
        )

        let result = CalorieResult(items: [item], total: (mu: finalCalories, sigma: finalSigma))

        if analyzerObservation != nil {
            statusMessage = "✅ API worked! Path: \(analyzerObservation?.path?.rawValue ?? "?")"
        } else if apiErrorMessage != nil {
            statusMessage = "❌ API error"
        } else {
            statusMessage = "⚠️ API returned nil"
        }

        if shouldAskVoI(for: result) {
            pendingResult = result
            voiQuestion = nextVoIQuestion()
            state = .awaitingVoI
            statusMessage = "Need extra clarification."
        } else {
            finish(with: result)
        }
    }

    private func finish(with result: CalorieResult) {
        state = .completed
        statusMessage = "Capture complete."
        qualityProgress = 1.0
        lastResult = result
        onResult(result)
    }

    private func updateActivePaths() {
        var order: [AnalysisPath] = []
        if config.flags.routerEnabled { order.append(contentsOf: [.analyzer, .router, .label, .menu]) }
        order.append(.geometry)
        if config.flags.mixtureEnabled { order.append(.mixture) }
        activePaths = order.reduce(into: [AnalysisPath]()) { acc, p in if !acc.contains(p) { acc.append(p) } }
    }

    private func shouldAskVoI(for result: CalorieResult) -> Bool {
        guard config.flags.voiEnabled, askedQuestions == 0 else { return false }
        return result.totalRelativeUncertainty >= config.voiThreshold
    }

    private func nextVoIQuestion() -> String {
        if let candidate = config.askBinaryPool.first {
            return "Is the dish \(candidate)?"
        }
        return "Does this plate include sauce or dressing?"
    }

    private func applyVoIAdjustment(to result: CalorieResult, factor: Double, evidenceTag: String) -> CalorieResult {
        guard let item = result.items.first else { return result }
        let adjustedItem = ItemEstimate(
            id: item.id,
            label: item.label,
            volumeML: item.volumeML,
            calories: item.calories,
            sigma: max(item.sigma * factor, 1.0),
            evidence: Array(Set(item.evidence + [evidenceTag])).sorted()
        )
        let adjustedTotal = (mu: result.total.mu, sigma: max(result.total.sigma * factor, 1.0))
        return CalorieResult(items: [adjustedItem], total: adjustedTotal)
    }

    // MARK: - Local classifier helper (self-contained)
    private func classifyLocallyAndGetPriors(
        from capturedFrame: CapturedFrame?
    ) async -> (label: String, priors: FoodPriors, evidence: [String])? {
        guard let localClassifier else { return nil }
        guard let data = capturedFrame?.rgbImage else { return nil }

        // If you have a real segmented instance, pass that in.
        // This lightweight fallback classifies the whole image RGB.
        let instance = FoodInstanceMask(rgbImageData: data) // adjust initializer if your type differs

        do {
            let result = try await localClassifier.classify(instance: instance)
            let priors = try await nutritionDB.getPriors(for: result.label)
            let evidence = [
                "Local-Classifier:\(result.label)",
                "Conf:\(Int(result.confidence * 100))%"
            ]
            return (label: result.label, priors: priors, evidence: evidence)
        } catch {
            NSLog("⚠️ Local classification failed: \(error)")
            return nil
        }
    }

    // MARK: - Wiring for analyzer + camera (unchanged)
    private static func makeAnalyzerClient() -> AnalyzerClient? {
        let baseURL = "https://uisjdlxdqfovuwurmdop.supabase.co/functions/v1"
        let apiKey  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVpc2pkbHhkcWZvdnV3dXJtZG9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5MDkyODYsImV4cCI6MjA3NDQ4NTI4Nn0.WaACHNXUWh5ZXKu5aZf1EjolXvWdD7R5mbNqBebnIuI"
        guard let url = URL(string: baseURL) else { return nil }
        return HTTPAnalyzerClient(configuration: .init(baseURL: url, apiKey: apiKey))
    }

    private static let placeholderImage = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/w8AAwMB/6XGMZkAAAAASUVORK5CYII=") ?? Data()
    private func placeholderImageData() -> Data { Self.placeholderImage }

    private static func makeCaptureService() -> FrameCaptureService? {
        #if canImport(AVFoundation) && canImport(UIKit)
        return SystemPhotoCaptureService()
        #else
        return nil
        #endif
    }

    private func performQualityGate() async -> CaptureQualityStatus? {
        var latest: CaptureQualityStatus?
        for sample in generateMockQualitySamples() {
            guard state == .capturing else { break }
            let status = qualityEstimator.evaluate(sample: sample)
            latest = status
            updateQualityStatus(status)
            if status.shouldStop { break }
            try? await Task.sleep(for: .milliseconds(90))
        }
        return latest
    }

    private func updateQualityStatus(_ status: CaptureQualityStatus) {
        qualityProgress = status.progress
        if status.shouldStop {
            statusMessage = "Quality locked. Processing capture…"
            return
        }
        if !status.meetsTracking {
            statusMessage = "Hold steady to restore tracking…"
        } else if !status.meetsParallax {
            statusMessage = "Move around the plate for more viewpoints."
        } else if !status.meetsDepth {
            statusMessage = "Lower the device slightly to capture depth."
        } else {
            statusMessage = "Gathering more frames…"
        }
    }

    private func generateMockQualitySamples() -> [CaptureQualitySample] {
        let p = config.captureQuality
        let steps = max(p.minimumStableFrames + 3, 5)
        let parallaxStep = p.parallaxTarget / Double(steps - 1)
        let depthStep = p.depthCoverageTarget / Double(steps)
        var samples: [CaptureQualitySample] = []
        var parallax = 0.0
        var depth = p.depthCoverageTarget * 0.4
        for index in 0..<steps {
            parallax = min(p.parallaxTarget * 1.1, parallax + parallaxStep)
            depth = min(1.0, depth + depthStep)
            let tracking: TrackingState = index < 1 ? .limited : .normal
            samples.append(.init(timestamp: Date(), parallax: parallax, trackingState: tracking, depthCoverage: depth))
        }
        return samples
    }
}

#if canImport(AVFoundation) && canImport(UIKit)
private struct CameraPreviewSurface: View {
    let session: AVCaptureSession?
    let status: String
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let session {
                CameraPreviewContainer(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                CameraPreviewPlaceholder(status: status)
            }
            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
                .opacity(session == nil ? 0.7 : 1.0)
            Text(status)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.92))
                .padding(12)
        }
        .frame(height: 320)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        .animation(.easeInOut(duration: 0.25), value: session != nil)
    }
}

@available(iOS 13.0, *)
private struct CameraPreviewContainer: UIViewRepresentable {
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        configure(layer: view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== session { uiView.videoPreviewLayer.session = session }
        configure(layer: uiView.videoPreviewLayer)
    }

    private func configure(layer: AVCaptureVideoPreviewLayer) {
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        if layer.connection?.isVideoOrientationSupported == true {
            layer.connection?.videoOrientation = .portrait
        }
    }
}
#endif

private struct CameraPreviewPlaceholder: View {
    let status: String
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12) {
                Image(systemName: "camera.aperture").font(.system(size: 42)).foregroundStyle(.white.opacity(0.8))
                Text(status).font(.footnote).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center).padding(.horizontal, 16)
            }
        }
    }
}

private enum AnalysisPath: String, CaseIterable, Identifiable {
    case analyzer, router, label, menu, geometry, mixture
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .analyzer: return "Analyzer"
        case .router:   return "Router"
        case .label:    return "Label"
        case .menu:     return "Menu"
        case .geometry: return "Geometry"
        case .mixture:  return "Mixture"
        }
    }
    var accessibilityLabel: String {
        switch self {
        case .analyzer: return "Analyzer path active"
        case .router:   return "Router path active"
        case .label:    return "Label path active"
        case .menu:     return "Menu path active"
        case .geometry: return "Geometry path active"
        case .mixture:  return "Mixture fusion active"
        }
    }
    var badgeColor: Color {
        switch self {
        case .analyzer: return .teal
        case .router:   return .blue
        case .label:    return .purple
        case .menu:     return .orange
        case .geometry: return .green
        case .mixture:  return .pink
        }
    }
}
