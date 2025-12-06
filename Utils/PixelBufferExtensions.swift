import CoreVideo

extension CVPixelBuffer {
    // 高速処理用にバッファを1次元配列(グレースケール)に変換
    func toGrayscaleData(width: Int, height: Int) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(self, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(self, .readOnly) }
        
        guard let base = CVPixelBufferGetBaseAddress(self) else { return nil }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        let srcW = CVPixelBufferGetWidth(self)
        let srcH = CVPixelBufferGetHeight(self)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        
        var result = [UInt8](repeating: 0, count: width * height)
        let scaleX = Float(srcW) / Float(width)
        let scaleY = Float(srcH) / Float(height)
        
        // 簡易ダウンサンプリング
        for y in 0..<height {
            for x in 0..<width {
                let sx = Int(Float(x) * scaleX)
                let sy = Int(Float(y) * scaleY)
                let offset = sy * bytesPerRow + sx * 4 // BGRA想定
                
                let b = Int(ptr[offset])
                let g = Int(ptr[offset+1])
                let r = Int(ptr[offset+2])
                result[y*width + x] = UInt8((r+g+b)/3)
            }
        }
        return result
    }
}
