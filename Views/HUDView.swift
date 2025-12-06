import SwiftUI
import AVFoundation

struct HUDView: View {
    @State private var viewModel = ScannerViewModel()
    
    var body: some View {
        ZStack {
            // 背景
            CyberpunkStyle.backgroundColor.ignoresSafeArea()
            
            // 1. カメラレイヤー
            CameraPreview(session: viewModel.session)
                .opacity(0.7)
                .ignoresSafeArea()
            
            // 2. スキャンライン & グリッドエフェクト
            GridOverlay()
            
            // 3. 検出オブジェクト描画レイヤー
            ObjectOverlay(objects: viewModel.trackedObjects)
                .ignoresSafeArea()
                .animation(.linear(duration: 0.1), value: viewModel.trackedObjects.count)
            
            // 4. UIコントロール
            VStack {
                Spacer()
                // ControlPanelは別ファイル(Components/ControlPanel.swift)から読み込まれます
                ControlPanel(
                    count: viewModel.objectCount,
                    sensitivity: $viewModel.sensitivity,
                    isRunning: viewModel.isRunning,
                    onToggle: viewModel.toggleScan
                )
                .padding(.bottom, 20)
            }
        }
        .statusBarHidden(true)
    }
}

// グリッド装飾
struct GridOverlay: View {
    var body: some View {
        ZStack {
            // スキャンライン
            LinearGradient(
                colors: [.clear, .black.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .background(Color.green.opacity(0.02))
            
            // 画面端の装飾
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(Color.green.opacity(0.1), lineWidth: 20)
                .blur(radius: 10)
        }
        .allowsHitTesting(false)
    }
}

// カメラプレビュー
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        
        if let connection = layer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        view.layer.addSublayer(layer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}
