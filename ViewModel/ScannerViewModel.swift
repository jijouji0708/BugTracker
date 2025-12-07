import AVFoundation
import SwiftUI
import Observation

@Observable
final class ScannerViewModel: NSObject {
    var isRunning = false
    var sensitivity: Double = 50.0
    var trackedObjects: [TrackedObject] = []
    
    var isMotionSuppressed = false
    
    // UI用のカウント
    var objectCount: Int { trackedObjects.count }
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let motionLogic = MotionLogic()
    private let cameraQueue = DispatchQueue(label: "com.bugtracker.camera", qos: .userInteractive)
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        session.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) { session.addInput(input) }
        
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
    }
    
    func toggleScan() {
        if isRunning { stop() } else { start() }
    }
    
    private func start() {
        Task.detached { await self.session.startRunning() }
        isRunning = true
    }
    
    private func stop() {
        Task.detached { await self.session.stopRunning() }
        isRunning = false
        Task { @MainActor in 
            self.trackedObjects = []
            self.isMotionSuppressed = false
        }
        Task { await self.motionLogic.reset() }
    }
}

extension ScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let grayData = BufferUtils.extractGrayscaleData(from: pixelBuffer) else { return }
        
        Task {
            // 【重要】スライダーの値をロジック用のパラメータに変換
            let currentSensitivity = await MainActor.run { self.sensitivity }
            
            // 感度をそのままアルゴリズムに渡す（アルゴリズム側で変換）
            // 感度100 = 非常に敏感、感度1 = 鈍感
            let threshold = currentSensitivity
            
            // 最小サイズ（使用しないが互換性のため）
            let minSize = 20
            
            let result = await motionLogic.process(
                currentFrame: grayData,
                width: Constants.processWidth,
                height: Constants.processHeight,
                motionThreshold: threshold,
                minSize: minSize
            )
            
            await MainActor.run {
                guard self.isRunning else { return }
                self.trackedObjects = result.tracks
                self.isMotionSuppressed = result.isSuppressed
            }
        }
    }
}
