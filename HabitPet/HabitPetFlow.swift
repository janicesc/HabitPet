//
//  HabitPetFlow.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI

struct HabitPetFlow: View {
    @State private var currentScreen: Int = 0
    @State private var userData: UserData = UserData()
    @State private var loggedFoods: [LoggedFood] = []
    
    var body: some View {
        ZStack {
            switch currentScreen {
            case 0:
                IntroScreen(currentScreen: $currentScreen, userData: $userData)
            case 1:
                SignUpScreen(currentScreen: $currentScreen, userData: $userData)
            case 2:
                BiometricsScreen(currentScreen: $currentScreen, userData: $userData)
            case 3:
                GoalSettingScreen(currentScreen: $currentScreen, userData: $userData)
            case 4:
                FoodPreferencesScreen(currentScreen: $currentScreen, userData: $userData)
            case 5:
                NotificationsScreen(currentScreen: $currentScreen, userData: $userData)
            case 6:
                HomeScreen(userData: userData, loggedFoods: loggedFoods) // 👈 Landing screen after onboarding
            case 7:
                RecipesView(
                    currentScreen: $currentScreen, 
                    loggedFoods: $loggedFoods,
                    onFoodLogged: { _ in },
                    userData: userData
                )
            default:
                HomeScreen(userData: userData, loggedFoods: loggedFoods) // 👈 Landing screen after onboarding
            }
        }
        .animation(.easeInOut, value: currentScreen)
        .transition(.slide)
        .onAppear {
            // If the user has previously completed onboarding/signed in, skip to Home
            if UserDefaults.standard.bool(forKey: "hp_isSignedIn") ||
               UserDefaults.standard.bool(forKey: "hp_hasOnboarded") {
                currentScreen = 6
            }
        }
    }
}

#Preview {
    HabitPetFlow()
}
