import SwiftUI

struct DetectedLogView: View {
    let baseItem: FoodItem
    let sigmaKcal: Int
    let onSave: (LoggedFood) -> Void
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var portion: Double = 1.0   // 1.0 = 100%

    // Computed per-portion values
    private var kcal: Int      { Int(Double(baseItem.calories) * portion) }
    private var sigma: Int     { Int(Double(sigmaKcal) * portion) }
    private var protein: Double{ baseItem.protein * portion }
    private var carbs: Double  { baseItem.carbs   * portion }
    private var fats: Double   { baseItem.fats    * portion }

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {

                // --- Summary header (name + pill on same line) ---
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text("🥢 \(baseItem.name)")
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Text("Detected")
                            .font(.caption).bold()
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(999)
                    }

                    Text("≈ \(kcal) kcal ± \(sigma) kcal")
                        .font(.title3).bold()
                        .padding(.top, 4)

                    Text("\(String(format: "%.0f", protein)) g protein | \(String(format: "%.0f", fats)) g fat | \(String(format: "%.0f", carbs)) g carbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // --- Portion control (keeps the summary in sync) ---
                VStack(spacing: 8) {
                    HStack {
                        Text("Portion Size")
                            .font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Text("\(Int(portion * 100))%")
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)

                    Slider(value: $portion, in: 0.5...2.5, step: 0.1)
                        .padding(.horizontal)
                }

                Spacer()

                // --- Log button -> returns LoggedFood just like your logger ---
                Button {
                    let logged = LoggedFood(
                        food: FoodItem(
                            id: baseItem.id,
                            name: baseItem.name,
                            calories: kcal,
                            protein: protein,
                            carbs: carbs,
                            fats: fats,
                            category: baseItem.category,
                            usdaFood: baseItem.usdaFood
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
            .padding(.top, 12)
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { onClose(); dismiss() }
                }
            }
        }
    }
}

#if DEBUG
struct DetectedLogView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItem = FoodItem(
            id: 1,
            name: "Grilled Chicken Bowl",
            calories: 550,
            protein: 42,
            carbs: 48,
            fats: 18,
            category: "Meal"
        )

        return DetectedLogView(
            baseItem: sampleItem,
            sigmaKcal: 60,
            onSave: { _ in },
            onClose: {}
        )
        .previewDisplayName("DetectedLogView Preview")
    }
}
#endif
