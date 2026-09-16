import Foundation
import AVFoundation

/// 相机扫码：AVCaptureMetadataOutput(qr)，扫到即回调并停止。
final class ScannerController: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastError: String?

    var onFound: ((String) -> Void)?

    let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private var configured = false
    private let queue = DispatchQueue(label: "zcode.scanner")

    func start() {
        lastError = nil
        guard AVCaptureDevice.default(for: .video) != nil else {
            lastError = "无可用相机"
            return
        }
        queue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async { self.isScanning = true }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async { self.isScanning = false }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { self.lastError = "相机初始化失败" }
            return
        }
        session.beginConfiguration()
        session.sessionPreset = .high
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: queue)
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()
        configured = true
    }
}

extension ScannerController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              obj.type == .qr,
              let value = obj.stringValue else { return }
        // 防抖：一帧里可能连续来多条，先停扫再回调
        stop()
        DispatchQueue.main.async { [weak self] in
            self?.onFound?(value)
        }
    }
}
