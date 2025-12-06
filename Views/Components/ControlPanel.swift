import SwiftUI

struct ControlPanel: View {
    let count: Int
    @Binding var sensitivity: Double
    let isRunning: Bool
    let onToggle: () -> Void
    
    // ピクセルサイズ換算 (UI表示用)
    var minPxSize: Int {
        Int(50 - (sensitivity / 100.0) * 48)
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            
            // 1. 検知数カウンター (日本語)
            HStack(alignment: .bottom, spacing: 4) {
                Text(String(format: "%03d", count))
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberpunkStyle.primaryColor)
                    .contentTransition(.numericText(value: Double(count)))
                    .shadow(color: CyberpunkStyle.primaryColor.opacity(0.6), radius: 4)
                
                Text("検知")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(CyberpunkStyle.dimColor)
                    .offset(y: -4)
            }
            .frame(minWidth: 60, alignment: .leading)
            
            // 2. 感度スライダー (日本語ラベル付き)
            VStack(alignment: .leading, spacing: 0) {
                Text("最小サイズ: \(minPxSize) px")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(CyberpunkStyle.primaryColor.opacity(0.8))
                
                Slider(value: $sensitivity, in: 1...100)
                    .tint(CyberpunkStyle.primaryColor)
            }
            .frame(maxWidth: .infinity)
            
            // 3. 電源ボタン (アイコンのみ)
            Button(action: onToggle) {
                Image(systemName: "power")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isRunning ? .black : CyberpunkStyle.primaryColor)
                    .frame(width: 44, height: 44)
                    .background(isRunning ? CyberpunkStyle.primaryColor : Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(CyberpunkStyle.primaryColor, lineWidth: 1)
                    )
                    .shadow(color: isRunning ? CyberpunkStyle.primaryColor : .clear, radius: 8)
            }
        }
        .padding(12)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule()) // 角丸を強くしてカプセル型に
        .overlay(
            Capsule()
                .stroke(CyberpunkStyle.dimColor, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
