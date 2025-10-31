import SwiftUI

struct HalfSizedFoodLogView: View {
    let foodItem: FoodItem
    let onSave: (LoggedFood) -> Void
    let onClose: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var portion: Double = 1.0
    
    var body: some View {
        VStack(spacing: 16) {
            // Header with food name and cancel button (match Food Logger card)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(foodItem.name)
                        .font(.headline)
                    Text(foodItem.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") {
                    onClose()
                    dismiss()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.horizontal)

            // Portion Size section
            VStack(spacing: 8) {
                HStack {
                    Text("Portion Size")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(Int(portion * 100))%")
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)

                Slider(value: $portion, in: 0.1...3.0, step: 0.1)
                    .padding(.horizontal)
            }

            // Nutrition section
            VStack(spacing: 12) {
                Text("Nutrition (per portion)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 20) {
                    nutrientColumn(title: "Calories", value: "\(Int(Double(foodItem.calories) * portion))")
                    nutrientColumn(title: "Protein", value: "\(String(format: "%.1f", foodItem.protein * portion))g")
                    nutrientColumn(title: "Carbs", value: "\(String(format: "%.1f", foodItem.carbs * portion))g")
                    nutrientColumn(title: "Fats", value: "\(String(format: "%.1f", foodItem.fats * portion))g")
                }
            }
            .padding(.horizontal)

            // Log Food button
            Button {
                let logged = LoggedFood(
                    food: FoodItem(
                        id: foodItem.id,
                        name: foodItem.name,
                        calories: Int(Double(foodItem.calories) * portion),
                        protein: foodItem.protein * portion,
                        carbs: foodItem.carbs * portion,
                        fats: foodItem.fats * portion,
                        category: foodItem.category,
                        usdaFood: foodItem.usdaFood
                    ),
                    portion: portion,
                    timestamp: Date()
                )
                onSave(logged)
                onClose()
                dismiss()
            } label: {
                Text("Log Food")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.vertical)
    }
    
    private func nutrientColumn(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2)
                .bold()
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    HalfSizedFoodLogView(
        foodItem: FoodItem(
            id: 999_2190,
            name: "Korean Braised Tofu (Dubu Jorim)",
            calories: 220,
            protein: 16,
            carbs: 8,
            fats: 14,
            category: "Prepared entrée"
        ),
        onSave: { _ in },
        onClose: {}
    )
}

