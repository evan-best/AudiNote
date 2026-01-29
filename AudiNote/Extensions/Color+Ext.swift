import SwiftUI

extension Color {
    /// Create a Color from a hex string (e.g. #3498db or 3498db)
    init?(hex: String) {
        var hexColor = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexColor.hasPrefix("#") { hexColor.removeFirst() }
        guard hexColor.count == 6 || hexColor.count == 8 else { return nil }
        var hexNumber: UInt64 = 0
        guard Scanner(string: hexColor).scanHexInt64(&hexNumber) else { return nil }
        let r, g, b, a: Double
        if hexColor.count == 8 {
            r = Double((hexNumber & 0xFF000000) >> 24) / 255
            g = Double((hexNumber & 0x00FF0000) >> 16) / 255
            b = Double((hexNumber & 0x0000FF00) >> 8) / 255
            a = Double(hexNumber & 0x000000FF) / 255
        } else {
            r = Double((hexNumber & 0xFF0000) >> 16) / 255
            g = Double((hexNumber & 0x00FF00) >> 8) / 255
            b = Double((hexNumber & 0x0000FF) >> 0) / 255
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    /// Returns a color with the same hue but modified brightness/saturation for contrast and matching.
    /// Designed for use with semi-transparent backgrounds (15-25% opacity)
    func tagContrastPair() -> (background: Color, foreground: Color) {
        #if canImport(UIKit)
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        let uiColor = UIColor(self)
        if uiColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha) {
            // Since backgrounds are rendered with low opacity (15-25%), they appear very light
            // We need a dark, saturated foreground for good contrast
            // Use the same hue but increase saturation and reduce brightness for readability
            let fgBri: CGFloat = max(bri * 0.5, 0.3)
            let fgSat: CGFloat = min(sat + 0.3, 0.95)
            let fg = Color(hue: Double(hue), saturation: Double(fgSat), brightness: Double(fgBri), opacity: 1.0)
            return (self, fg)
        }
        #endif
        return (self, .primary)
    }
    /// Converts the Color to a hex string representation (if possible).
    func toHexString() -> String? {
        #if canImport(UIKit)
        guard let components = UIColor(self).cgColor.components else { return nil }
        // Handles both gray and RGB color spaces
        let r = Int(((components.count >= 3 ? components[0] : components[0]) * 255).rounded())
        let g = Int(((components.count >= 3 ? components[1] : components[0]) * 255).rounded())
        let b = Int(((components.count >= 3 ? components[2] : components[0]) * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
        #elseif canImport(AppKit)
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else { return nil }
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return nil
        #endif
    }
}
