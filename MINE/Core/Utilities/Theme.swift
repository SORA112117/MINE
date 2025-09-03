import SwiftUI

struct Theme {
    // メインカラー
    static let primary = Color(hex: "4A90A4")     // 落ち着いた青緑
    static let secondary = Color(hex: "67B3A3")   // 優しいミント
    static let accent = Color(hex: "F4A261")      // 温かみのあるオレンジ
    static let background = Color(hex: "FAF9F7")  // オフホワイト
    static let text = Color(hex: "2C3E50")        // ダークグレー
    
    // 追加カラー
    static let success = Color(hex: "52C41A")
    static let warning = Color(hex: "FAAD14")
    static let error = Color(hex: "F5222D")
    static let info = Color(hex: "1890FF")
    
    // グレースケール
    static let gray1 = Color(hex: "F5F5F5")
    static let gray2 = Color(hex: "E8E8E8")
    static let gray3 = Color(hex: "D9D9D9")
    static let gray4 = Color(hex: "BFBFBF")
    static let gray5 = Color(hex: "8C8C8C")
    static let gray6 = Color(hex: "595959")
    
    // 影
    static let shadowColor = Color.black.opacity(0.1)
    static let shadowRadius: CGFloat = 8
    static let shadowOffset = CGSize(width: 0, height: 2)
}

// Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}