import SwiftUI

// MARK: - Color Extensions
extension Color {
    /// Hex文字列から色を初期化
    /// - Parameter hex: "#RRGGBB" または "RRGGBB" 形式の文字列
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
    
    /// 色をHex文字列に変換
    var hexString: String {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
    
    /// 色を暗くする
    func darker(by percentage: Double = 0.2) -> Color {
        return self.opacity(1.0 - percentage)
    }
    
    /// 色を明るくする
    func lighter(by percentage: Double = 0.2) -> Color {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = min(1.0, Double(components[0]) + percentage)
        let g = min(1.0, Double(components[1]) + percentage)
        let b = min(1.0, Double(components[2]) + percentage)
        let a = Double(components[3])
        
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Color Palette for Tags and Folders
extension Color {
    /// プリセットカラーパレット
    static let colorPalette: [Color] = [
        Color(hex: "#4A90A4"), // メインブルー
        Color(hex: "#F4A261"), // オレンジ
        Color(hex: "#67B3A3"), // ミントグリーン
        Color(hex: "#52C41A"), // グリーン
        Color(hex: "#F5222D"), // レッド
        Color(hex: "#FAAD14"), // イエロー
        Color(hex: "#722ED1"), // パープル
        Color(hex: "#13C2C2"), // シアン
        Color(hex: "#EB2F96"), // ピンク
        Color(hex: "#FA8C16"), // ディープオレンジ
        Color(hex: "#1890FF"), // ブルー
        Color(hex: "#389E0D"), // フォレストグリーン
    ]
    
    /// ランダムなプリセットカラーを取得
    static var randomPresetColor: Color {
        return colorPalette.randomElement() ?? Color(hex: "#4A90A4")
    }
    
    /// 色の名前を取得（日本語）
    var colorName: String {
        let hex = self.hexString.lowercased()
        
        switch hex {
        case "#4a90a4": return "ブルー"
        case "#f4a261": return "オレンジ"
        case "#67b3a3": return "ミント"
        case "#52c41a": return "グリーン"
        case "#f5222d": return "レッド"
        case "#faad14": return "イエロー"
        case "#722ed1": return "パープル"
        case "#13c2c2": return "シアン"
        case "#eb2f96": return "ピンク"
        case "#fa8c16": return "ディープオレンジ"
        case "#1890ff": return "スカイブルー"
        case "#389e0d": return "フォレスト"
        default: return "カスタム"
        }
    }
}

// MARK: - Accessibility Support
extension Color {
    /// 背景色に対してコントラストの高い文字色を返す
    var contrastingTextColor: Color {
        // 色の明度を計算
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = Double(components[0]) * 0.299
        let g = Double(components[1]) * 0.587
        let b = Double(components[2]) * 0.114
        let luminance = r + g + b
        
        // 明度が0.5以上なら黒、未満なら白
        return luminance > 0.5 ? .black : .white
    }
    
    /// アクセシビリティに配慮したカラーグレーディング
    func accessibleContrast(against background: Color) -> Color {
        // TODO: より詳細なコントラスト比計算を実装
        return self
    }
}