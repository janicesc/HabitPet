//
//  SignUpScreen.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI

struct SignUpScreen: View {
    @Binding var currentScreen: Int
    @Binding var userData: UserData   // custom model for name/email
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var showNameError: Bool = false
    @State private var showEmailError: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email
    }
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 24) {
                headerSection
                formSection
                footerSection
            }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)
        }
        .onAppear {
            name = userData.name
            email = userData.email
        }
    }
    
    // MARK: Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue, Color.purple, Color.indigo]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 64, height: 64)
                
                // Show selected avatar instead of generic person icon
                Image(userData.selectedCharacter.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            }
            .padding(.bottom, 12)
            
            Text("Hi there! Let's get started.")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("Tell us a bit about yourself")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))
            
            // Show character name
            Text("with \(userData.selectedCharacter.displayName)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
        }
        .multilineTextAlignment(.center)
    }
    
    // MARK: Form
    private var formSection: some View {
        VStack(spacing: 20) {
            // Name Input
            VStack(alignment: .leading, spacing: 6) {
                StyledTextField(
                    title: "Name",
                    placeholder: "Enter your name",
                    text: $name,
                    isError: showNameError,
                    focusedField: $focusedField,
                    fieldType: .name
                )
                
                if showNameError {
                    errorMessage("Please fill out this field.")
                }
            }
            
            // Email Input
            VStack(alignment: .leading, spacing: 6) {
                StyledTextField(
                    title: "Email",
                    placeholder: "your.email@example.com",
                    text: $email,
                    isError: showEmailError,
                    focusedField: $focusedField,
                    fieldType: .email
                )
                .keyboardType(.emailAddress)
                
                if showEmailError {
                    errorMessage("Please include a valid email with '@' and domain.")
                }
            }
            
            // Continue Button
            Button {
                validateForm()
            } label: {
                Text("Continue")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundColor(Color.blue.opacity(0.9))
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
            }
            .padding(.top, 24)
        }
    }
    
    // MARK: Footer
    private var footerSection: some View {
        Text("By continuing, you agree to our Terms & Privacy Policy")
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
    
    // MARK: Validation
    private func validateForm() {
        var isValid = true
        
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            showNameError = true
            isValid = false
        } else {
            showNameError = false
        }
        
        if !isValidEmail(email) {
            showEmailError = true
            isValid = false
        } else {
            showEmailError = false
        }
        
        if isValid {
            userData.name = name
            userData.email = email
            withAnimation(.easeInOut) { currentScreen = 2 }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    // MARK: Error UI
    private func errorMessage(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "#be185d")) // magenta/pink
                .font(.system(size: 14))
            Text(message)
                .font(.caption)
                .foregroundColor(Color(hex: "#1e3a8a")) // midnight navy
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }
}

// MARK: - StyledTextField
struct StyledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isError: Bool
    @FocusState.Binding var focusedField: SignUpScreen.Field?
    let fieldType: SignUpScreen.Field
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.white.opacity(0.6)) // placeholder
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                
                TextField("", text: $text)
                    .focused($focusedField, equals: fieldType)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .foregroundColor(.white) // input text
                    .font(.system(size: 16))
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isError ? Color.red :
                                    (focusedField == fieldType ? Color.white.opacity(0.8) : Color.white.opacity(0.2)),
                                lineWidth: 1
                            )
                    )
                    .accentColor(.white) // white cursor
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
        }
    }
}

#Preview {
    SignUpScreen(
        currentScreen: .constant(1),
        userData: .constant(UserData())
    )
}

