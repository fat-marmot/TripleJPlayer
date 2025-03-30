import Foundation
import AVFoundation

class AudioPlayerService: ObservableObject {
    @Published var isPlaying = false
    
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
        statusObservation = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] (playerItem, _) in
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
    }
    
    func pause() {
        print("Pausing stream")
        player?.pause()
        isPlaying = false
    }
    
    deinit {
        statusObservation?.invalidate()
    }
}
