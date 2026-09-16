import SwiftUI
import AVFoundation

/// 扫码页：相机预览层 + 扫描框提示。识别成功回调一次。
struct ScannerView: View {
    @StateObject private var controller = ScannerController()
    @Environment(\.dismiss) private var dismiss
    let onFound: (String) -> Void

    var body: some View {
        ZStack {
            ScannerPreview(controller: controller)
                .ignoresSafeArea()
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 240, height: 240)
                    .opacity(0.9)
                Text("对准 PC 端 ZCode 给出的远程连接二维码")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.top, 12)
                Spacer()
                Button("取消") { dismiss() }
                    .foregroundStyle(.white)
                    .padding(.bottom, 24)
            }
            if let err = controller.lastError {
                VStack {
                    Text(err).foregroundStyle(.white).padding()
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
            }
        }
        .onAppear {
            controller.onFound = { raw in
                dismiss()
                onFound(raw)
            }
            controller.start()
        }
        .onDisappear { controller.stop() }
    }
}

/// 相机预览层封装。
private struct ScannerPreview: UIViewControllerRepresentable {
    @ObservedObject var controller: ScannerController

    func makeUIViewController(context: Context) -> PreviewVC {
        let vc = PreviewVC()
        vc.session = controller.session
        return vc
    }
    func updateUIViewController(_ vc: PreviewVC, context: Context) {}
}

private final class PreviewVC: UIViewController {
    var session: AVCaptureSession?
    private var layer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let l: AVCaptureVideoPreviewLayer
        if let layer {
            l = layer
        } else {
            guard let session else { return }
            l = AVCaptureVideoPreviewLayer(session: session)
            l.videoGravity = .resizeAspectFill
            l.frame = view.bounds
            view.layer.insertSublayer(l, at: 0)
            layer = l
        }
        l.frame = view.bounds
    }
}
