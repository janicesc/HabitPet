//
//  IntroScreen.swift
//  HabitPet
//
//  Created by Janice C on 9/23/25.
//

import SwiftUI
import AVKit

struct IntroScreen: View {
    @Binding var currentScreen: Int
    @Binding var userData: UserData

    // State
    @State private var showCTA: Bool = true
    @State private var showConfetti: Bool = false
    @State private var petBounce: Bool = false
    @State private var triggerAvatarAnimation = false

    var body: some View {
        ZStack {
            // Gradient background always visible
            backgroundGradient

            VStack(spacing: 32) {
                // Avatar Video (always visible)
                AvatarVideoView()
                    .frame(height: UIScreen.main.bounds.height * 0.45)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            petBounce = true
                        }
                    }

                // Text & tagline
                VStack(spacing: 16) {
                    Text("Meet Your HabitPet!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 2)

                    Text("Ready to glow from the inside out?\nGrow with your nutrition companion and hit your healthy-eating goals.")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                        .padding(.horizontal, 8)
                }

                // CTA (always visible)
                VStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut) { currentScreen = 1 }
                    } label: {
                        Text("Start My Healthy Journey 🚀")
                            .font(.system(size: 20, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(buttonGradient)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(PressScaleButtonStyle())
                    .padding(.horizontal, 8)

                    Text("Join thousands who've transformed their lives with joy")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }


    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: Self.bgColors),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private static let bgColors: [Color] = [
        Color(hex: "#0f172a"),
        Color(hex: "#1e293b"),
        Color(hex: "#0f4c75"),
        Color(hex: "#3730a3"),
        Color(hex: "#1e40af"),
        Color(hex: "#0891b2"),
        Color(hex: "#0d9488"),
        Color(hex: "#059669")
    ]

    private var buttonGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(hex: "#0891b2"), Color(hex: "#0d9488")]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}


// MARK: - Confetti
struct ConfettiView: View {
    @State private var particles: [UUID] = (0..<30).map { _ in UUID() }
    var body: some View {
        GeometryReader { geo in
            ForEach(particles, id: \.self) { _ in
                Circle()
                    .fill([Color.red, .yellow, .green, .blue, .pink, .purple].randomElement()!)
                    .frame(width: 8, height: 8)
                    .position(x: .random(in: 0..<geo.size.width),
                              y: .random(in: 0..<geo.size.height/2))
            }
        }
    }
}


// MARK: - Avatar Video View
struct AvatarVideoView: View {
    @State private var player: AVPlayer?
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                // Fallback image while video loads
                Image("habitpet")
                    .resizable()
                    .scaledToFit()
            }
        }
        .onAppear {
            setupVideo()
        }
    }
    
    private func setupVideo() {
        // Array of available video files
        let videoOptions = [
            "avatar-default-jump",
            "avatar-default-laugh", 
            "avatar-default-punch"
        ]
        
        // Randomly select one video
        let selectedVideo = videoOptions.randomElement() ?? "avatar-default-jump"
        
        guard let url = Bundle.main.url(forResource: selectedVideo, withExtension: "mp4") else {
            print("Could not find \(selectedVideo).mp4")
            return
        }
        
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        self.player = player
    }
}

#Preview {
    IntroScreen(currentScreen: .constant(0), userData: .constant(UserData()))
}
