//
//  Color+Hex.swift
//  HabitPet
//
//  Created by Janice C on 9/16/25.
//

// MARK: - Hex Color Helper
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 8: // AARRGGBB
            a = (int & 0xFF000000) >> 24
            r = (int & 0x00FF0000) >> 16
            g = (int & 0x0000FF00) >> 8
            b = (int & 0x000000FF)
        default: // RRGGBB
            a = 255
            r = (int & 0xFF0000) >> 16
            g = (int & 0x00FF00) >> 8
            b = (int & 0x0000FF)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
