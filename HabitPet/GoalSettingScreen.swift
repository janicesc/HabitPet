//
//  GoalSettingScreen.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI

struct GoalSettingScreen: View {
    @Binding var currentScreen: Int
    @Binding var userData: UserData
    
    @State private var selectedGoal: String = ""
    @State private var goalDuration: Int = 3
    
    private let goals: [GoalOption] = [
        GoalOption(
            id: "slim",
            title: "Slim",
            subtitle: "Lose weight",
            avatar: "🏃‍♀️",
            description: "Focus on creating a caloric deficit"
        ),
        GoalOption(
            id: "content",
            title: "Content",
            subtitle: "Maintain weight",
            avatar: "🧘‍♀️",
            description: "Maintain current weight with balanced nutrition"
        ),
        GoalOption(
            id: "strong",
            title: "Strong",
            subtitle: "Gain weight",
            avatar: "💪",
            description: "Build muscle with increased protein intake"
        )
    ]
    
    var body: some View {
        ZStack {
            background
            content
        }
    }
    
    // MARK: Background
    private var background: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#6366f1"), // indigo-500
                Color(hex: "#a855f7"), // purple-500
                Color(hex: "#ec4899")  // pink-500
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: Content
    private var content: some View {
        VStack(spacing: 24) {
            header
            goalOptions
            if !selectedGoal.isEmpty {
                durationSelector
            }
            continueButton
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, 24)
    }
    
    // MARK: Sections
    private var header: some View {
        VStack(spacing: 8) {
            Text("What's your goal?")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Choose the body you want to achieve")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
    
    private var goalOptions: some View {
        VStack(spacing: 16) {
            ForEach(goals) { goal in
                Button {
                    selectedGoal = goal.id
                } label: {
                    GoalCard(goal: goal, isSelected: selectedGoal == goal.id)
                }
            }
        }
    }
    
    private var durationSelector: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("I want to reach this goal in:")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(goalDuration) months")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Slider(
                value: Binding(
                    get: { Double(goalDuration) },
                    set: { goalDuration = Int($0) }
                ),
                in: 1...12,
                step: 1
            )
            .tint(.white)
            
            HStack {
                Text("1 month")
                Spacer()
                Text("12 months")
            }
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var continueButton: some View {
        Button {
            if !selectedGoal.isEmpty {
                userData.goal = selectedGoal
                userData.goalDuration = goalDuration
                withAnimation(.easeInOut) { currentScreen += 1 }
            }
        } label: {
            Text("Continue")
                .font(.system(size: 20, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(Color.purple)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
        }
        .disabled(selectedGoal.isEmpty)
        .opacity(selectedGoal.isEmpty ? 0.5 : 1)
    }
}

// MARK: - GoalCard
struct GoalCard: View {
    let goal: GoalOption
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Text(goal.avatar)
                .font(.system(size: 28))
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text(goal.subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                Text(goal.description)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: 2)
        )
    }
}

// MARK: - Model
struct GoalOption: Identifiable {
    var id: String
    var title: String
    var subtitle: String
    var avatar: String
    var description: String
}

#Preview {
    GoalSettingScreen(
        currentScreen: .constant(3),
        userData: .constant(UserData())
    )
}
