import SwiftUI

struct ControlPanel: View {
    let count: Int
    @Binding var sensitivity: Double
    let isRunning: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            
            // 1. 検知数
            VStack(alignment: .leading, spacing: 2) {
                Text("検知数")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText(value: Double(count)))
            }
            .frame(width: 60, alignment: .leading)
            
            // 2. 感度設定
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("感度設定")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(sensitivity))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                Slider(value: $sensitivity, in: 1...100)
                    .tint(isRunning ? .green : .blue)
            }
            .frame(maxWidth: .infinity)
            
            // 3. 開始/停止ボタン (大きく明確に)
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.red : Color.green)
                        .frame(width: 56, height: 56)
                        .shadow(color: (isRunning ? Color.red : Color.green).opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    VStack(spacing: 2) {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                        Text(isRunning ? "停止" : "開始")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal, 16)
    }
}
