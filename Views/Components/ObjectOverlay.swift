import SwiftUI

struct ObjectOverlay: View {
    let objects: [TrackedObject]
    
    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / Double(Constants.processWidth)
            let scaleY = size.height / Double(Constants.processHeight)
            
            for obj in objects {
                if obj.path.count < 2 { continue }
                
                var path = Path()
                let p0 = obj.path[0]
                path.move(to: CGPoint(x: p0.x * scaleX, y: p0.y * scaleY))
                
                for p in obj.path.dropFirst() {
                    path.addLine(to: CGPoint(x: p.x * scaleX, y: p.y * scaleY))
                }
                
                context.stroke(path, with: .color(obj.uiColor.opacity(0.7)), lineWidth: 2)
                
                if let head = obj.path.last {
                    let hx = head.x * scaleX
                    let hy = head.y * scaleY
                    let rect = CGRect(x: hx - 5, y: hy - 5, width: 10, height: 10)
                    context.stroke(Path(ellipseIn: rect), with: .color(obj.uiColor), lineWidth: 2)
                }
            }
        }
    }
}
