import CoreVideo

enum BufferUtils {
    static func extractGrayscaleData(from pixelBuffer: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        let targetW = Constants.processWidth
        let targetH = Constants.processHeight
        
        var grayData = [UInt8](repeating: 0, count: targetW * targetH)
        let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        let scaleX = Float(width) / Float(targetW)
        let scaleY = Float(height) / Float(targetH)
        
        grayData.withUnsafeMutableBufferPointer { destPtr in
            for y in 0..<targetH {
                let srcY = Int(Float(y) * scaleY)
                for x in 0..<targetW {
                    let srcX = Int(Float(x) * scaleX)
                    
                    let offset = srcY * bytesPerRow + srcX * 4
                    let b = Int(ptr[offset])
                    let g = Int(ptr[offset + 1])
                    let r = Int(ptr[offset + 2])
                    
                    // 単純平均でグレー化
                    destPtr[y * targetW + x] = UInt8((r + g + b) / 3)
                }
            }
        }
        return grayData
    }
}
