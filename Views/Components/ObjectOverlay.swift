import SwiftUI

struct ObjectOverlay: View {
    let objects: [TrackedObject]
    
    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / Double(Constants.processWidth)
            let scaleY = size.height / Double(Constants.processHeight)
            
            for obj in objects {
                guard !obj.path.isEmpty else { continue }
                
                let color = obj.uiColor
                
                // 軌跡を描画
                if obj.path.count >= 2 {
                    var trail = Path()
                    let first = obj.path[0]
                    trail.move(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
                    
                    for i in 1..<obj.path.count {
                        let p = obj.path[i]
                        trail.addLine(to: CGPoint(x: p.x * scaleX, y: p.y * scaleY))
                    }
                    
                    // 軌跡の太さと透明度
                    let trailOpacity = min(0.8, 0.3 + obj.confidence * 0.5)
                    context.stroke(trail, with: .color(color.opacity(trailOpacity)), lineWidth: 2)
                }
                
                // 現在位置マーカー
                if let head = obj.path.last {
                    let hx = head.x * scaleX
                    let hy = head.y * scaleY
                    let markerSize = max(16, min(40, head.z * 1.5))
                    
                    // 外円
                    let outerRect = CGRect(
                        x: hx - markerSize / 2,
                        y: hy - markerSize / 2,
                        width: markerSize,
                        height: markerSize
                    )
                    context.stroke(
                        Path(ellipseIn: outerRect),
                        with: .color(color),
                        lineWidth: 2
                    )
                    
                    // 中心点
                    let dotSize: CGFloat = 6
                    let dotRect = CGRect(
                        x: hx - dotSize / 2,
                        y: hy - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    context.fill(Path(ellipseIn: dotRect), with: .color(color))
                }
            }
        }
    }
}
