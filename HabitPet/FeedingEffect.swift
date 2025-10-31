//
//  FeedingEffect.swift
//  HabitPet
//
//  Created by Janice C on 9/17/25.
//  Updated: Adds Lottie-based sparkle option with particle fallback + iOS17-compatible onChange.
//

import SwiftUI
#if canImport(Lottie)
import Lottie
#endif

struct FeedingEffect: View {
    @Binding var isActive: Bool
    var duration: Double = 1.2

    var body: some View {
        ZStack {
            if isActive {                      // ✅ only render while active
                if lottieAvailable {
                    LottieSparkleWrapper(isActive: $isActive, duration: duration)
                        .transition(.opacity.combined(with: .scale))
                } else {
                    ParticleSparkle(isActive: $isActive, duration: duration)
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .allowsHitTesting(false)
        // If you were using .blendMode(.screen) and seeing a yellow tint, try removing it
        // or swapping to .plusLighter based on your background palette.
        //.compositingGroup().blendMode(.plusLighter)
    }

    private var lottieAvailable: Bool {
        #if canImport(Lottie)
        return Bundle.main.path(forResource: "Sparkle", ofType: "json") != nil
        #else
        return false
        #endif
    }
}

#if canImport(Lottie)
// MARK: - Lottie wrapper
private struct LottieSparkleWrapper: UIViewRepresentable {
    @Binding var isActive: Bool
    var duration: Double

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let animationView = LottieAnimationView(name: "Sparkle")
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .playOnce
        animationView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.animationView = animationView
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }
        if isActive {
            animationView.currentProgress = 0
            animationView.play { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    if isActive { isActive = false }
                }
            }
        } else {
            animationView.stop()
            animationView.currentProgress = 0
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var animationView: LottieAnimationView?
    }
}
#endif

// MARK: - Particle fallback
private struct ParticleSparkle: View {
    @Binding var isActive: Bool
    @State private var particles: [Particle] = []
    var duration: Double

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var opacity: Double
        var scale: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Circle()
                        .fill(Color.cyan.opacity(p.opacity))
                        .frame(width: 8 * p.scale, height: 8 * p.scale)
                        .position(x: p.x, y: p.y)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // iOS 17+ signature; add availability if you need iOS 16
            .onChange(of: isActive) { _, active in
                if active { triggerParticles(in: geo.size) }
            }
            .onAppear {
                if !isActive { particles.removeAll() }
            }
        }
    }

    private func triggerParticles(in size: CGSize) {
        particles.removeAll()
        let cx = size.width / 2, cy = size.height / 2
        for _ in 0..<16 {
            particles.append(
                Particle(
                    x: cx + CGFloat.random(in: -size.width*0.25 ... size.width*0.25),
                    y: cy + CGFloat.random(in: -size.height*0.25 ... size.height*0.25),
                    opacity: Double.random(in: 0.6...1.0),
                    scale: CGFloat.random(in: 0.8...1.4)
                )
            )
        }
        withAnimation(.easeOut(duration: duration)) {
            particles = particles.map { p in
                var cp = p; cp.opacity = 0; cp.scale = 2.0; return cp
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            particles.removeAll()
            isActive = false
        }
    }
}

// MARK: - Backward/forward compatible onChange
extension View {
    func compatibleOnChange<Value: Equatable>(
        of value: Value,
        perform action: @escaping (_ oldValue: Value, _ newValue: Value) -> Void
    ) -> some View {
        if #available(iOS 17.0, *) {
            return self.onChange(of: value, action)
        } else {
            return self.onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }
}

// MARK: - Preview
struct FeedingEffect_Previews: PreviewProvider {
    struct Wrapper: View {
        @State private var active = false
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                FeedingEffect(isActive: $active)
                    .frame(width: 200, height: 200)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    active = true
                }
            }
        }
    }

    static var previews: some View {
        Wrapper()
            .previewLayout(.sizeThatFits)
    }
}

