import Foundation
import AVFoundation
import AVKit
import AppKit

class AudioPlayerService: ObservableObject {
    @Published var isPlaying = false
    @Published var currentVolume: Float = 1.0
    
    // Triple J's streaming URL
    private let streamURL = URL(string: "https://live-radio01.mediahubaustralia.com/2TJW/mp3/")!
    
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    
    init() {
        setupPlayer()
        print("AudioPlayerService initialized with URL: \(streamURL)")
    }
    
    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: streamURL)
        player = AVPlayer(playerItem: playerItem)
        
        // Observe the player item's status to know when it's ready to play
        statusObservation = playerItem.observe(\.status, options: [.new, .initial]) { (playerItem, _) in
            switch playerItem.status {
            case .readyToPlay:
                print("Player item is ready to play")
            case .failed:
                print("Player item failed: \(String(describing: playerItem.error))")
            case .unknown:
                print("Player item status is unknown")
            @unknown default:
                print("Player item status is unknown (default)")
            }
        }
        
        // Set initial volume
        player?.volume = currentVolume
    }
    
    func togglePlayPause() {
        print("Toggle play/pause called")
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func play() {
        print("Attempting to play stream: \(streamURL)")
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        print("Pausing stream")
        player?.pause()
        isPlaying = false
    }
    
    func setVolume(_ volume: Float) {
        currentVolume = volume
        player?.volume = volume
    }
    
    // A simplified approach for showing AirPlay on macOS
    func showAirPlayMenu() {
        // On macOS, we let the AirPlayButton handle this directly
        // This method is kept for API compatibility
        print("AirPlay menu requested - handled by AirPlayButton in UI")
    }
    
    private func updateNowPlayingInfo() {
        // Set up Now Playing info if needed
        print("Updated now playing info")
    }
    
    deinit {
        statusObservation?.invalidate()
        print("AudioPlayerService deinitializing")
    }
}
