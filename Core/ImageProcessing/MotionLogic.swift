import Foundation

actor MotionLogic {
    private var prevFrame: [UInt8]?
    private var tracks: [TrackedObject] = []
    private var nextId: Int = 1
    
    // 【修正1】ブロックサイズを小さく (8 -> 6)
    // 小さな虫の輪郭を捉えやすくします
    private let blockSize: Int = 6
    
    // 【修正2】スキャン間隔を密に (8 -> 4)
    // これにより「虫が隙間にいて検知されない」を防ぎます
    // 処理負荷は上がりますが、精度は劇的に向上します
    private let scanStep: Int = 4
    
    private let searchRadius: Int = 16
    private let maxBugSize: Int = 300 // 少し許容範囲を広げる
    
    func process(currentFrame: [UInt8], width: Int, height: Int, motionThreshold: Double, minSize: Int) -> (tracks: [TrackedObject], count: Int) {
        guard let prev = prevFrame else {
            prevFrame = currentFrame
            return ([], 0)
        }
        
        let vectors = calcVectors(prev: prev, curr: currentFrame, width: width, height: height)
        let globalMotion = calculateGlobalMotion(vectors: vectors)
        
        let bugs = extractBugs(
            vectors: vectors,
            globalMotion: globalMotion,
            threshold: motionThreshold,
            minSize: minSize
        )
        
        updateTracks(detectedObjects: bugs)
        
        prevFrame = currentFrame
        return (tracks, tracks.count)
    }
    
    func reset() {
        prevFrame = nil
        tracks = []
        nextId = 1
    }
    
    // MARK: - Algorithm
    
    private struct Vector { let x, y, dx, dy: Int }
    private struct Detection { var x, y, vx, vy, size: Double }
    
    private func calcVectors(prev: [UInt8], curr: [UInt8], width: Int, height: Int) -> [Vector] {
        var vectors: [Vector] = []
        let margin = searchRadius + blockSize
        
        // 【修正3】「のっぺり判定」を無効化 (threshold = 0)
        // iPadのようなツルッとした画面でも、強制的に全箇所をスキャンさせます
        // これで「背景が白すぎて無視される」問題が解決します
        let textureThreshold = 0
        
        // 高密度スキャン実行
        for y in stride(from: margin, to: height - margin, by: scanStep) {
            for x in stride(from: margin, to: width - margin, by: scanStep) {
                let idx = y * width + x
                
                // テクスチャ判定 (今回は0なので実質スルーせず全て計算)
                if textureThreshold > 0 {
                    let center = Int(prev[idx])
                    let diff = abs(Int(prev[idx-2]) - center) + abs(Int(prev[idx+2]) - center)
                    if diff < textureThreshold { continue }
                }
                
                var bestDx = 0, bestDy = 0, minSAD = Int.max
                
                // 探索
                for dy in stride(from: -searchRadius, through: searchRadius, by: 2) {
                    for dx in stride(from: -searchRadius, through: searchRadius, by: 2) {
                        var sad = 0
                        // 小さいブロック(6x6)で比較
                        for by in 0..<blockSize {
                            for bx in 0..<blockSize {
                                let p = Int(prev[(y+by)*width + (x+bx)])
                                let c = Int(curr[(y+dy+by)*width + (x+dx+bx)])
                                sad += abs(p - c)
                            }
                        }
                        if sad < minSAD {
                            minSAD = sad
                            bestDx = dx
                            bestDy = dy
                        }
                    }
                }
                
                // マッチング閾値 (少し緩める: 2000)
                // 画面撮影時のモアレ(縞模様)などを許容するため
                if minSAD < 2000 {
                    vectors.append(Vector(x: x, y: y, dx: bestDx, dy: bestDy))
                }
            }
        }
        return vectors
    }
    
    private func calculateGlobalMotion(vectors: [Vector]) -> (dx: Double, dy: Double) {
        // ベクトルが極端に少ない時は手ブレ補正をOFFにする
        if vectors.count < 20 { return (0, 0) }
        
        let sortedX = vectors.map { $0.dx }.sorted()
        let sortedY = vectors.map { $0.dy }.sorted()
        let mid = vectors.count / 2
        
        return (Double(sortedX[mid]), Double(sortedY[mid]))
    }
    
    private func extractBugs(vectors: [Vector], globalMotion: (dx: Double, dy: Double), threshold: Double, minSize: Int) -> [Detection] {
        var candidates: [Detection] = []
        
        for v in vectors {
            let relDx = Double(v.dx) - globalMotion.dx
            let relDy = Double(v.dy) - globalMotion.dy
            let speed = hypot(relDx, relDy)
            
            if speed > threshold {
                candidates.append(Detection(x: Double(v.x), y: Double(v.y), vx: relDx, vy: relDy, size: 1))
            }
        }
        
        var clusters: [Detection] = []
        let mergeDist = 20.0
        
        while !candidates.isEmpty {
            var c = candidates.removeLast()
            var count = 1
            
            var i = candidates.count - 1
            while i >= 0 {
                let p = candidates[i]
                if hypot(c.x - p.x, c.y - p.y) < mergeDist {
                    c.x += p.x; c.y += p.y
                    c.vx += p.vx; c.vy += p.vy
                    count += 1
                    candidates.remove(at: i)
                }
                i -= 1
            }
            
            // サイズ判定
            if count >= minSize && count <= maxBugSize {
                let f = 1.0 / Double(count)
                clusters.append(Detection(
                    x: c.x * f,
                    y: c.y * f,
                    vx: c.vx * f,
                    vy: c.vy * f,
                    size: Double(count)
                ))
            }
        }
        return clusters
    }
    
    private func updateTracks(detectedObjects: [Detection]) {
        for i in 0..<tracks.count { tracks[i].life -= 1 }
        
        var matchedIndices = Set<Int>()
        
        for i in 0..<tracks.count {
            if tracks[i].life < -5 { continue }
            guard let head = tracks[i].path.last else { continue }
            
            let predX = head.x + tracks[i].velocity.x
            let predY = head.y + tracks[i].velocity.y
            
            var bestDist = 40.0
            var bestIdx = -1
            
            for (j, obj) in detectedObjects.enumerated() {
                if matchedIndices.contains(j) { continue }
                let d = hypot(obj.x - predX, obj.y - predY)
                if d < bestDist {
                    bestDist = d
                    bestIdx = j
                }
            }
            
            if bestIdx != -1 {
                matchedIndices.insert(bestIdx)
                let obj = detectedObjects[bestIdx]
                
                tracks[i].life = 10
                tracks[i].age += 1
                tracks[i].velocity = SIMD2(
                    x: obj.vx * 0.5 + tracks[i].velocity.x * 0.5,
                    y: obj.vy * 0.5 + tracks[i].velocity.y * 0.5
                )
                // サイズ調整 (高密度スキャンに合わせて表示倍率調整)
                let displaySize = Double(obj.size) * 2.0 + 5.0
                let newPos = SIMD3(
                    x: head.x * 0.6 + obj.x * 0.4,
                    y: head.y * 0.6 + obj.y * 0.4,
                    z: displaySize
                )
                tracks[i].path.append(newPos)
                if tracks[i].path.count > 60 { tracks[i].path.removeFirst() }
            }
        }
        
        for (j, obj) in detectedObjects.enumerated() {
            if !matchedIndices.contains(j) {
                let hue = (Double(nextId) * 137.508).truncatingRemainder(dividingBy: 360.0) / 360.0
                let displaySize = Double(obj.size) * 2.0 + 5.0
                let newTrack = TrackedObject(
                    id: nextId,
                    life: 5,
                    age: 0,
                    size: displaySize,
                    position: SIMD2(obj.x, obj.y),
                    velocity: SIMD2(obj.vx, obj.vy),
                    colorHue: hue,
                    path: [SIMD3(obj.x, obj.y, displaySize)]
                )
                tracks.append(newTrack)
                nextId += 1
            }
        }
        tracks = tracks.filter { $0.life > 0 }
    }
}
