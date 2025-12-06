import SwiftUI

// デザイン定義
struct CyberpunkStyle {
    static let primaryColor = Color.green
    static let dimColor = Color.green.opacity(0.3)
    static let backgroundColor = Color.black
    
    static let fontDesign: Font.Design = .monospaced
}

// 共通モディファイア
extension View {
    func cyberBorder() -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CyberpunkStyle.dimColor, lineWidth: 1)
        )
    }
}
