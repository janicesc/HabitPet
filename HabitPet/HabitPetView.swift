//
//  HabitPetView.swift
//  HabitPet
//
//  Created by Janice C on 9/23/25.
//

import SwiftUI

struct HabitPetView: View {
    var size: CGFloat = 220
    var characterType: CharacterType = .squirtle
    private let heightScaleProvider: () -> CGFloat
    private let widthScaleProvider: () -> CGFloat

    // 👇 Binding to trigger animations externally
    var triggerAnimation: Binding<Bool>?
    
    // Animation state
    @State private var isAnimating = false

    // MARK: - Initializers

    /// Use raw CGFloat values with character type
    init(size: CGFloat = 220,
         characterType: CharacterType = .squirtle,
         heightScale: CGFloat,
         widthScale: CGFloat,
         triggerAnimation: Binding<Bool>? = nil) {
        self.size = size
        self.characterType = characterType
        self.heightScaleProvider = { heightScale }
        self.widthScaleProvider  = { widthScale }
        self.triggerAnimation = triggerAnimation
    }

    /// Use bindings to CGFloat with character type
    init(size: CGFloat = 220,
         characterType: CharacterType = .squirtle,
         heightScale: Binding<CGFloat>,
         widthScale: Binding<CGFloat>,
         triggerAnimation: Binding<Bool>? = nil) {
        self.size = size
        self.characterType = characterType
        self.heightScaleProvider = { heightScale.wrappedValue }
        self.widthScaleProvider  = { widthScale.wrappedValue }
        self.triggerAnimation = triggerAnimation
    }

    /// Use bindings to Strings (cm / kg) with character type
    init(size: CGFloat = 220,
         characterType: CharacterType = .squirtle,
         heightCm: Binding<String>,
         weightKg: Binding<String>,
         triggerAnimation: Binding<Bool>? = nil) {
        self.size = size
        self.characterType = characterType
        self.heightScaleProvider = {
            let cm = CGFloat(Int(heightCm.wrappedValue) ?? 170)
            return Self.normalizeScale(cm / 170.0)
        }
        self.widthScaleProvider = {
            let kg = CGFloat(Int(weightKg.wrappedValue) ?? 70)
            return Self.normalizeScale(kg / 70.0)
        }
        self.triggerAnimation = triggerAnimation
    }
    
    /// Use UserData for automatic scaling
    init(size: CGFloat = 220,
         userData: UserData,
         triggerAnimation: Binding<Bool>? = nil) {
        self.size = size
        self.characterType = userData.selectedCharacter
        self.heightScaleProvider = {
            let cm = CGFloat(Int(userData.height) ?? 170)
            return Self.normalizeScale(cm / 170.0)
        }
        self.widthScaleProvider = {
            let kg = CGFloat(Int(userData.weight) ?? 70)
            return Self.normalizeScale(kg / 70.0)
        }
        self.triggerAnimation = triggerAnimation
    }

    // MARK: - Body

    var body: some View {
        Image("habitpet")
            .resizable()
            .scaledToFit()
            .frame(width: scaledSize.width, height: scaledSize.height)
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .rotationEffect(.degrees(isAnimating ? 5 : 0))
            .animation(.easeInOut(duration: 0.3).repeatCount(isAnimating ? 2 : 0, autoreverses: true), value: isAnimating)
            .onChange(of: triggerAnimation?.wrappedValue) { _, newValue in
                if newValue == true {
                    performIntroAnimations()
                    triggerAnimation?.wrappedValue = false
                }
            }
    }
    
    // MARK: - Computed Properties
    
    private var scaledSize: CGSize {
        let h = heightScaleProvider()
        let w = widthScaleProvider()
        return CGSize(width: size * w, height: size * h)
    }

    // MARK: - Animation Methods
    
    private func performIntroAnimations() {
        withAnimation {
            isAnimating = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                isAnimating = false
            }
        }
    }

    // MARK: - Helpers
    private static func normalizeScale(_ raw: CGFloat) -> CGFloat {
        // More realistic scaling ranges
        // Height: 0.8x to 1.2x (short to tall)
        // Weight: 0.7x to 1.3x (skinny to heavy)
        min(max(raw, 0.7), 1.3)
    }
}

#Preview {
    HabitPetView(size: 300, characterType: .squirtle, heightScale: 1.0, widthScale: 1.0)
        .frame(width: 300, height: 300)
        .background(Color.black)
}

