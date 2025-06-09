//
//  ShakeDetector.swift
//  Venja
//
//  Created by Anders Hovmöller on 2025-06-08.
//

import SwiftUI

#if os(iOS)
import UIKit

struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void
    
    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        ShakeDetectorViewController(onShake: onShake)
    }
    
    func updateUIViewController(_ uiViewController: ShakeDetectorViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

class ShakeDetectorViewController: UIViewController {
    var onShake: () -> Void
    
    init(onShake: @escaping () -> Void) {
        self.onShake = onShake
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake()
        }
    }
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}
#endif