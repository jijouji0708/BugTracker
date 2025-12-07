import Foundation

actor MotionLogic {
    private var prevFrame: [UInt8]?
    private var prevPrevFrame: [UInt8]?  // 2フレーム前
    private var tracks: [TrackedObject] = []
    private var nextId: Int = 1
    
    // パラメータ
    private let minBlobPixels: Int = 20     // 最小ブロブサイズ（変化ピクセル数）
    private let maxBlobPixels: Int = 3000   // 最大ブロブサイズ
    private let maxTracksCount: Int = 20    // 最大トラック数
    
    func process(currentFrame: [UInt8], width: Int, height: Int, motionThreshold: Double, minSize: Int) -> (tracks: [TrackedObject], count: Int, isSuppressed: Bool) {
        guard let prev = prevFrame else {
            prevFrame = currentFrame
            return ([], 0, false)
        }
        
        // 閾値は直接使用（ピクセル差分の閾値として15-50）
        let pixelThreshold = Int(15 + (100 - motionThreshold) * 0.35)
        
        // 1. フレーム差分マスクを計算（ノイズ除去付き）
        let diffMask = computeDifferenceMaskWithDenoising(
            prev: prev,
            curr: currentFrame,
            width: width,
            height: height,
            threshold: pixelThreshold
        )
        
        // 2. 全体の変化量をチェック（カメラ移動検知）
        let changedCount = diffMask.reduce(0) { $0 + ($1 ? 1 : 0) }
        let totalPixels = width * height
        let changeRatio = Double(changedCount) / Double(totalPixels)
        
        // 20%以上変化 = カメラ移動
        if changeRatio > 0.20 {
            prevPrevFrame = prevFrame
            prevFrame = currentFrame
            // カメラ移動中はトラックをリセットしない（位置予測で対応）
            return (tracks.filter { $0.confidence > 0.7 }, tracks.filter { $0.confidence > 0.7 }.count, true)
        }
        
        // 3. ブロブ検出（Connected Component Analysis 簡易版）
        let blobs = detectBlobsSimple(
            mask: diffMask,
            width: width,
            height: height,
            minPixels: minBlobPixels,
            maxPixels: maxBlobPixels
        )
        
        // 4. トラッキング更新
        updateTracks(detectedBlobs: blobs)
        
        prevPrevFrame = prevFrame
        prevFrame = currentFrame
        
        // 5. 表示用にフィルタリング（2フレーム以上継続 & 信頼度0.4以上）
        let visibleTracks = tracks.filter { $0.age >= 2 && $0.confidence >= 0.4 }
        return (visibleTracks, visibleTracks.count, false)
    }
    
    func reset() {
        prevFrame = nil
        prevPrevFrame = nil
        tracks = []
        nextId = 1
    }
    
    // MARK: - Frame Differencing with Denoising
    
    private func computeDifferenceMaskWithDenoising(
        prev: [UInt8],
        curr: [UInt8],
        width: Int,
        height: Int,
        threshold: Int
    ) -> [Bool] {
        var mask = [Bool](repeating: false, count: prev.count)
        
        // ピクセルごとの差分
        for i in 0..<prev.count {
            let diff = abs(Int(curr[i]) - Int(prev[i]))
            mask[i] = diff > threshold
        }
        
        // 簡易ノイズ除去：孤立ピクセルを除外（3x3近傍で2個以上の変化がなければ除外）
        var cleanedMask = [Bool](repeating: false, count: prev.count)
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                if mask[idx] {
                    var neighborCount = 0
                    for dy in -1...1 {
                        for dx in -1...1 {
                            if dy == 0 && dx == 0 { continue }
                            if mask[(y + dy) * width + (x + dx)] {
                                neighborCount += 1
                            }
                        }
                    }
                    cleanedMask[idx] = neighborCount >= 2
                }
            }
        }
        
        return cleanedMask
    }
    
    // MARK: - Blob Detection (Simplified Connected Components)
    
    private struct Blob {
        var centerX: Double
        var centerY: Double
        var pixelCount: Int
        var boundingBox: (minX: Int, minY: Int, maxX: Int, maxY: Int)
    }
    
    private func detectBlobsSimple(
        mask: [Bool],
        width: Int,
        height: Int,
        minPixels: Int,
        maxPixels: Int
    ) -> [Blob] {
        // ダウンサンプリングしてグリッドベースで検出（高速化）
        let gridSize = 4
        let gridW = width / gridSize
        let gridH = height / gridSize
        
        // グリッドごとのカウント
        var gridCounts = [Int](repeating: 0, count: gridW * gridH)
        var gridSumX = [Double](repeating: 0, count: gridW * gridH)
        var gridSumY = [Double](repeating: 0, count: gridW * gridH)
        
        for y in 0..<height {
            for x in 0..<width {
                if mask[y * width + x] {
                    let gx = min(x / gridSize, gridW - 1)
                    let gy = min(y / gridSize, gridH - 1)
                    let gi = gy * gridW + gx
                    gridCounts[gi] += 1
                    gridSumX[gi] += Double(x)
                    gridSumY[gi] += Double(y)
                }
            }
        }
        
        // アクティブなグリッドをクラスタリング（Union-Find的アプローチ）
        var visited = [Bool](repeating: false, count: gridW * gridH)
        var blobs: [Blob] = []
        
        // セルあたり最低4ピクセルの変化が必要
        let cellThreshold = 4
        
        for gy in 0..<gridH {
            for gx in 0..<gridW {
                let gi = gy * gridW + gx
                if visited[gi] || gridCounts[gi] < cellThreshold { continue }
                
                // BFSでクラスタを探索
                var clusterPixels = 0
                var clusterSumX = 0.0
                var clusterSumY = 0.0
                var minGX = gx, maxGX = gx, minGY = gy, maxGY = gy
                
                var queue = [(gx, gy)]
                visited[gi] = true
                
                while !queue.isEmpty {
                    let (cx, cy) = queue.removeFirst()
                    let ci = cy * gridW + cx
                    
                    clusterPixels += gridCounts[ci]
                    clusterSumX += gridSumX[ci]
                    clusterSumY += gridSumY[ci]
                    
                    minGX = min(minGX, cx)
                    maxGX = max(maxGX, cx)
                    minGY = min(minGY, cy)
                    maxGY = max(maxGY, cy)
                    
                    // 4近傍
                    let neighbors = [(cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)]
                    for (nx, ny) in neighbors {
                        if nx >= 0 && nx < gridW && ny >= 0 && ny < gridH {
                            let ni = ny * gridW + nx
                            if !visited[ni] && gridCounts[ni] >= cellThreshold {
                                visited[ni] = true
                                queue.append((nx, ny))
                            }
                        }
                    }
                }
                
                // サイズフィルタリング
                if clusterPixels >= minPixels && clusterPixels <= maxPixels {
                    // アスペクト比チェック（極端に細長いものは除外）
                    let blobW = (maxGX - minGX + 1) * gridSize
                    let blobH = (maxGY - minGY + 1) * gridSize
                    let aspectRatio = Double(max(blobW, blobH)) / Double(max(1, min(blobW, blobH)))
                    
                    if aspectRatio < 5.0 {
                        blobs.append(Blob(
                            centerX: clusterSumX / Double(clusterPixels),
                            centerY: clusterSumY / Double(clusterPixels),
                            pixelCount: clusterPixels,
                            boundingBox: (
                                minX: minGX * gridSize,
                                minY: minGY * gridSize,
                                maxX: (maxGX + 1) * gridSize,
                                maxY: (maxGY + 1) * gridSize
                            )
                        ))
                    }
                }
            }
        }
        
        // 大きい順にソートして上位のみ返す
        blobs.sort { $0.pixelCount > $1.pixelCount }
        return Array(blobs.prefix(maxTracksCount))
    }
    
    // MARK: - Tracking
    
    private func updateTracks(detectedBlobs: [Blob]) {
        // 1. 既存トラックを減衰
        for i in 0..<tracks.count {
            tracks[i].life -= 1
            tracks[i].confidence = max(0.0, tracks[i].confidence - 0.1)
        }
        
        // 2. ハンガリアンマッチング（簡易版：Greedy）
        var matched = Set<Int>()
        var usedBlobs = Set<Int>()
        
        // 距離行列を計算してソート
        var pairs: [(trackIdx: Int, blobIdx: Int, dist: Double)] = []
        for i in 0..<tracks.count {
            guard let head = tracks[i].path.last else { continue }
            let predX = head.x + tracks[i].velocity.x
            let predY = head.y + tracks[i].velocity.y
            
            for j in 0..<detectedBlobs.count {
                let blob = detectedBlobs[j]
                let dist = hypot(blob.centerX - predX, blob.centerY - predY)
                if dist < 60 {  // マッチング最大距離
                    pairs.append((i, j, dist))
                }
            }
        }
        
        pairs.sort { $0.dist < $1.dist }
        
        // Greedyマッチング
        for pair in pairs {
            if matched.contains(pair.trackIdx) || usedBlobs.contains(pair.blobIdx) { continue }
            
            matched.insert(pair.trackIdx)
            usedBlobs.insert(pair.blobIdx)
            
            let blob = detectedBlobs[pair.blobIdx]
            let head = tracks[pair.trackIdx].path.last!
            
            tracks[pair.trackIdx].life = 10
            tracks[pair.trackIdx].age += 1
            tracks[pair.trackIdx].confidence = min(1.0, tracks[pair.trackIdx].confidence + 0.3)
            
            // 速度更新（平滑化）
            let newVx = blob.centerX - head.x
            let newVy = blob.centerY - head.y
            tracks[pair.trackIdx].velocity = SIMD2(
                x: newVx * 0.5 + tracks[pair.trackIdx].velocity.x * 0.5,
                y: newVy * 0.5 + tracks[pair.trackIdx].velocity.y * 0.5
            )
            
            // 位置更新（平滑化）
            let smoothX = head.x * 0.3 + blob.centerX * 0.7
            let smoothY = head.y * 0.3 + blob.centerY * 0.7
            let size = min(30, max(10, Double(blob.pixelCount) / 20.0 + 8))
            
            tracks[pair.trackIdx].path.append(SIMD3(smoothX, smoothY, size))
            if tracks[pair.trackIdx].path.count > 50 {
                tracks[pair.trackIdx].path.removeFirst()
            }
            tracks[pair.trackIdx].position = SIMD2(smoothX, smoothY)
            tracks[pair.trackIdx].size = size
        }
        
        // 3. 新規トラック作成（未マッチのブロブ）
        for j in 0..<detectedBlobs.count {
            if usedBlobs.contains(j) { continue }
            
            let blob = detectedBlobs[j]
            let hue = (Double(nextId) * 137.508).truncatingRemainder(dividingBy: 360.0) / 360.0
            let size = min(30, max(10, Double(blob.pixelCount) / 20.0 + 8))
            
            let newTrack = TrackedObject(
                id: nextId,
                life: 6,
                age: 1,
                size: size,
                position: SIMD2(blob.centerX, blob.centerY),
                velocity: SIMD2(0, 0),
                colorHue: hue,
                path: [SIMD3(blob.centerX, blob.centerY, size)],
                confidence: 0.4
            )
            tracks.append(newTrack)
            nextId += 1
        }
        
        // 4. 死んだトラックを削除
        tracks = tracks.filter { $0.life > 0 }
        
        // 5. トラック数制限
        if tracks.count > maxTracksCount {
            tracks.sort { $0.confidence > $1.confidence }
            tracks = Array(tracks.prefix(maxTracksCount))
        }
    }
}
