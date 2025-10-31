//
//  CalorieCameraBridge.swift
//  HabitPet
//

import SwiftUI
import CalorieCameraKit

/// Bridge between CalorieCameraKit and your food logging flow.
/// Emits a normalized AICameraNutritionResult back to Home.
struct CalorieCameraBridge: View {
    let onComplete: (AICameraCompletion) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showCalorieCamera = false
    @State private var shouldDismiss = false

    var body: some View {
        VStack(spacing: 20) {
            Text("AI Food Camera")
                .font(.title).bold()

            Text("Take a photo of your food to get instant calorie estimates")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("📸 Open Calorie Camera") {
                showCalorieCamera = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $showCalorieCamera) {
            CalorieCameraView(
                config: .development, // flip to .production when your backend is locked
                onResult: { result in
                    // Map CalorieCameraKit → AICameraNutritionResult
                    let converted = convertCalorieResult(result)
                    DispatchQueue.main.async {
                        onComplete(.success(converted, sourceType: .camera))
                        showCalorieCamera = false
                        shouldDismiss = true
                    }
                },
                onCancel: {
                    DispatchQueue.main.async {
                        onComplete(.cancelled)
                        showCalorieCamera = false
                        shouldDismiss = true
                    }
                }
            )
        }
        .onChange(of: shouldDismiss) { oldValue, newValue in
            if newValue { dismiss() }
        }
    }

    /// Convert CalorieResult from CalorieCameraKit to AICameraNutritionResult
    private func convertCalorieResult(_ result: CalorieResult) -> AICameraNutritionResult {
        let primary = result.items.first
        var label = primary?.label ?? "Detected Food"
        if label.lowercased() == "geometry" { label = "Detected Food" }

        let cFused = max(0, result.total.mu)
        let sigmaCFused = max(0, result.total.sigma)

        // Portion-aware macros: prefer analyzer-provided macros per 100g and priors density
        let volumeML = primary?.volumeML ?? 0
        let density = primary?.densityGPerML ?? 1.0 // fallback 1 g/mL if unknown
        var grams = max(0, volumeML * density)
        
        // Safety cap: clamp grams to reasonable max (2kg = 2,000g) for typical food portions
        grams = min(grams, 2_000.0)

        let macrosPer100 = primary?.macrosPer100g
        NSLog("📊 Bridge: macrosPer100=\(macrosPer100 != nil ? "present" : "nil"), volumeML=\(volumeML), density=\(density), grams=\(grams)")
        
        var proteinG = macrosPer100.map { max(0, $0.proteinG * grams / 100.0) }
            ?? max(0, (cFused * 0.25) / 4.0)
        var carbsG   = macrosPer100.map { max(0, $0.carbsG   * grams / 100.0) }
            ?? max(0, (cFused * 0.45) / 4.0)
        var fatsG    = macrosPer100.map { max(0, $0.fatG    * grams / 100.0) }
            ?? max(0, (cFused * 0.30) / 9.0)
        
        // Reasonable nutrition thresholds for a single food item
        let maxProtein = 200.0  // 200g max protein per item
        let maxCarbs   = 300.0   // 300g max carbs per item
        let maxFats    = 200.0   // 200g max fats per item
        
        // Safety caps: prevent absurd macro values
        proteinG = min(proteinG, maxProtein)
        carbsG   = min(carbsG,   maxCarbs)
        fatsG    = min(fatsG,    maxFats)
        
        // Cap calories too (based on macros + reasonable max)
        let maxCalories = 2000.0  // 2000 kcal max per item
        let cappedCFused = min(cFused, maxCalories)
        
        NSLog("📊 Bridge: Final macros (capped): protein=\(proteinG), carbs=\(carbsG), fats=\(fatsG), calories=\(cappedCFused)")

        func r1(_ x: Double) -> Double { (x * 10).rounded() / 10 }

        return AICameraNutritionResult(
            label: label,
            confidence: 0.8,
            volumeML: primary?.volumeML ?? 0,
            sigmaV: primary?.sigma ?? 0,
            rho: primary?.densityGPerML ?? 1.0,
            sigmaRho: 0.1,
            e: 1.4,
            sigmaE: 0.1,
            cFused: cappedCFused,
            sigmaCFused: sigmaCFused,
            protein: r1(proteinG),
            carbs:   r1(carbsG),
            fats:    r1(fatsG)
        )
    }
}

#Preview {
    CalorieCameraBridge { result in
        print("Camera result: \(result)")
    }
}

