import SwiftUI

// Swift 6: Sendable準拠でスレッド間転送を安全に
struct TrackedEntity: Identifiable, Sendable {
    let id: Int
    var life: Int
    var age: Int
    var size: Double
    var position: SIMD2<Double> // x, y
    var velocity: SIMD2<Double> // vx, vy
    var colorHue: Double
    var path: [SIMD3<Double>]   // x, y, size
    
    var color: Color {
        Color(hue: colorHue, saturation: 1.0, brightness: 1.0)
    }
}
