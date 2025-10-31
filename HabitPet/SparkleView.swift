//
//  SparkleView.swift
//  HabitPet
//
//  Created by Janice C on 9/17/25.
//

import SwiftUI
import Lottie

struct SparkleView: UIViewRepresentable {
    var name: String = "Sparkle"     // JSON file name in your bundle
    var loopMode: LottieLoopMode = .playOnce
    var speed: CGFloat = 1.0
    var onCompletion: (() -> Void)? = nil

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)  // ✅ pass animation name here
        view.contentMode = .scaleAspectFill
        view.backgroundBehavior = .pauseAndRestore
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.loopMode = loopMode
        uiView.animationSpeed = speed

        uiView.currentProgress = 0
        uiView.play { _ in
            onCompletion?()
        }
    }
}
