import AVFoundation
import SwiftUI
import Observation

@Observable
final class VisionSystem: NSObject {
    // UI State
    var isRunning = false
    var sensitivity: Double = 50.0
    var trackedEntities: [TrackedEntity] = []
    var detectionCount: Int = 0
    
    // Camera Session
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.bugtracker.vision", qos: .userInteractive)
    
    // Internal Processing State (Thread-Confined to processingQueue)
    private var prevBuffer: [UInt8]?
    private var internalTracks: [TrackedEntity] = []
    private var nextId: Int = 1
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        session.sessionPreset = .vga640x480
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) { session.addInput(input) }
        
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        
        if session.canAddOutput(output) { session.addOutput(output) }
    }
    
    func toggleSystem() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    private func start() {
        Task.detached {
            await self.session.startRunning()
        }
        isRunning = true
    }
    
    private func stop() {
        Task.detached {
            await self.session.stopRunning()
        }
        isRunning = false
        // リセット処理
        processingQueue.async { [weak self] in
            self?.prevBuffer = nil
            self?.internalTracks = []
            self?.nextId = 1
            Task { @MainActor in
                self?.trackedEntities = []
                self?.detectionCount = 0
            }
        }
    }
}

// Delegate
extension VisionSystem: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // メインスレッドのプロパティに直接アクセスしないように注意 (Swift 6 strictness)
        // ここはprocessingQueue上で呼ばれる
        
        // 1. データ抽出
        guard let grayData = pixelBuffer.toGrayscaleData(width: Config.processWidth, height: Config.processHeight) else { return }
        
        // 2. MainActorのステートをキャプチャ（非同期でアクセスするため）
        // 注意: @Observableのプロパティはスレッドセーフではないため、処理に必要な値はキュー内で管理するか、
        // 単純な値ならTaskで取得する。ここでは内部ステート(internalTracks)を使うため安全。
        
        Task { @MainActor in
            // 感度のみUIから取得
            let sens = self.sensitivity
            
            // 計算キューへ戻す
            self.processingQueue.async { [weak self] in
                guard let self = self else { return }
                
                // 計算実行
                let result = MotionProcessor.compute(
                    buffer: grayData,
                    prevBuffer: self.prevBuffer,
                    currentTracks: self.internalTracks,
                    nextId: self.nextId,
                    sensitivity: sens
                )
                
                // 内部状態更新
                self.prevBuffer = grayData
                self.internalTracks = result.tracks
                self.nextId = result.nextId
                
                // UI更新 (MainActor)
                Task { @MainActor in
                    self.trackedEntities = result.tracks
                    self.detectionCount = result.validCount
                }
            }
        }
    }
}
