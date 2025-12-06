import SwiftUI

struct TrackedObject: Identifiable, Sendable {
    let id: Int
    var life: Int
    var age: Int
    var size: Double
    var position: SIMD2<Double>
    var velocity: SIMD2<Double>
    var colorHue: Double
    var path: [SIMD3<Double>] // x, y, size
    
    var uiColor: Color {
        Color(hue: colorHue, saturation: 1.0, brightness: 1.0)
    }
}
