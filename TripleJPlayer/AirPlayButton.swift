import SwiftUI
import AVKit
import AppKit

struct AirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        
        // Try to get the underlying button to customize it
        if let button = routePickerView.subviews.first(where: { $0 is NSButton }) as? NSButton {
            if let airplayImage = NSImage(systemSymbolName: "airplayaudio", accessibilityDescription: "AirPlay") {
                button.image = airplayImage
            }
            button.bezelStyle = .regularSquare
            button.isBordered = false
        }
        
        return routePickerView
    }
    
    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {
        // Nothing to update
    }
}

// A SwiftUI wrapper for volume control
struct VolumeSlider: NSViewRepresentable {
    @Binding var volume: Float
    var onChanged: ((Float) -> Void)?
    
    class Coordinator: NSObject {
        var parent: VolumeSlider
        
        init(_ parent: VolumeSlider) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: NSSlider) {
            let newVolume = Float(sender.doubleValue)
            parent.volume = newVolume
            parent.onChanged?(newVolume)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(
            value: Double(volume),
            minValue: 0,
            maxValue: 1,
            target: context.coordinator,
            action: #selector(Coordinator.valueChanged(_:))
        )
        slider.isEnabled = true
        
        return slider
    }
    
    func updateNSView(_ nsView: NSSlider, context: Context) {
        nsView.doubleValue = Double(volume)
    }
}
