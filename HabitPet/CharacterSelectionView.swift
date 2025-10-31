//
//  CharacterSelectionView.swift
//  HabitPet
//
//  Created by Janice C on 9/23/25.
//

import SwiftUI

struct CharacterSelectionView: View {
    @Binding var currentScreen: Int
    @Binding var userData: UserData
    @State private var selectedCharacter: CharacterType = .squirtle
    @State private var showPreview: Bool = false
    
    private let characters: [CharacterType] = CharacterType.allCases
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 16) {
                        Text("Choose Your Character!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("Select a companion for your health journey")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Character Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                        ForEach(characters) { character in
                            CharacterCard(
                                character: character,
                                isSelected: selectedCharacter == character
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedCharacter = character
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Character Preview
                    VStack(spacing: 16) {
                        Text("Preview")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        CharacterPreviewView(character: selectedCharacter)
                            .frame(height: 200)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(20)
                            .padding(.horizontal)
                    }
                    
                    // Character Description
                    VStack(spacing: 12) {
                        Text(selectedCharacter.displayName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(selectedCharacter.description)
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Continue Button
                    VStack(spacing: 16) {
                        Button {
                            userData.selectedCharacter = selectedCharacter
                            withAnimation(.easeInOut) {
                                currentScreen += 1
                            }
                        } label: {
                            Text("Continue with \(selectedCharacter.displayName)")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .foregroundColor(.white)
                                .background(buttonGradient)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .padding(.horizontal)
                        
                        Text("Your character will evolve based on your health progress!")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#0f172a"),
                Color(hex: "#1e293b"),
                Color(hex: "#0f4c75"),
                Color(hex: "#3730a3"),
                Color(hex: "#1e40af"),
                Color(hex: "#0891b2"),
                Color(hex: "#0d9488"),
                Color(hex: "#059669")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var buttonGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(hex: "#0891b2"), Color(hex: "#0d9488")]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Character Card
struct CharacterCard: View {
    let character: CharacterType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Character Image (PNG)
                Image(character.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Character Name
                Text(character.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Character Preview View
struct CharacterPreviewView: View {
    let character: CharacterType
    
    var body: some View {
        ZStack {
            // Character Image Preview
            Image(character.imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 180)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
            
            // Character info overlay
            VStack {
                Spacer()
                HStack {
                    Text(character.emoji)
                        .font(.system(size: 20))
                    Text(character.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Button Style
struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.18), value: configuration.isPressed)
    }
}

#Preview {
    CharacterSelectionView(
        currentScreen: .constant(0),
        userData: .constant(UserData())
    )
}
