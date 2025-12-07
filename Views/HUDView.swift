import SwiftUI
import AVFoundation

struct HUDView: View {
    @State private var viewModel = ScannerViewModel()
    
    var body: some View {
        ZStack {
            // 背景
            // 背景
            Color.black.ignoresSafeArea()
            
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
                // 録画中インジケーター
                if viewModel.isRunning {
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .opacity(0.8)
                                Text("SCANNING")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                            
                            if viewModel.isMotionSuppressed {
                                Text("CAMERA MOVING TOO FAST")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow)
                                    .padding(4)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                    .transition(.opacity)
                }
                
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

// グリッド装飾 (Apple風: ミニマルなビューファインダー)
struct GridOverlay: View {
    var body: some View {
        ZStack {
            // 四隅のコーナーマーカー
            GeometryReader { geometry in
                let w = geometry.size.width
                let h = geometry.size.height
                let length: CGFloat = 40
                
                Path { path in
                    // 左上
                    path.move(to: CGPoint(x: 20, y: 20 + length))
                    path.addLine(to: CGPoint(x: 20, y: 20))
                    path.addLine(to: CGPoint(x: 20 + length, y: 20))
                    
                    // 右上
                    path.move(to: CGPoint(x: w - 20 - length, y: 20))
                    path.addLine(to: CGPoint(x: w - 20, y: 20))
                    path.addLine(to: CGPoint(x: w - 20, y: 20 + length))
                    
                    // 左下
                    path.move(to: CGPoint(x: 20, y: h - 20 - length))
                    path.addLine(to: CGPoint(x: 20, y: h - 20))
                    path.addLine(to: CGPoint(x: 20 + length, y: h - 20))
                    
                    // 右下
                    path.move(to: CGPoint(x: w - 20 - length, y: h - 20))
                    path.addLine(to: CGPoint(x: w - 20, y: h - 20))
                    path.addLine(to: CGPoint(x: w - 20, y: h - 20 - length))
                }
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            
            // 中央のクロスヘア (非常に薄く)
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.3))
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
