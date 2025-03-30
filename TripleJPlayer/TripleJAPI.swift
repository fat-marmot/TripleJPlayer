//
//  TripleJAPI.swift
//  TripleJPlayer
//
//  Created by Colin Burns on 29/3/2025.
//

import Foundation
import Combine

class TripleJAPI: ObservableObject {
    @Published var currentTrack: Track = Track.placeholder
    @Published var recentTracks: [Track] = []
    
    private var timer: Timer?
    private let updateInterval: TimeInterval = 30 // Update every 30 seconds
    
    init() {
        print("TripleJAPI initialized")
        fetchNowPlaying()
        startPolling()
    }
    
    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            print("Timer fired - fetching latest tracks")
            self?.fetchNowPlaying()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    func fetchNowPlaying() {
        print("Fetching now playing data...")
        guard let url = URL(string: "https://music.abcradio.net.au/api/v1/plays/triplej/now.json?tz=Australia%2FSydney") else {
            print("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                return
            }
            
            print("Received data of size: \(data.count) bytes")
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON response (first 200 chars): \(String(jsonString.prefix(200)))...")
                }
                
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                if let topKeys = json?.keys {
                    print("Top level JSON keys: \(topKeys.joined(separator: ", "))")
                }
                
                if let now = json?["now"] as? [String: Any] {
                    print("Found 'now' data")
                    if let currentTrack = self?.processTrackData(now) {
                        DispatchQueue.main.async {
                            self?.currentTrack = currentTrack
                            print("Updated current track: \(currentTrack.title) by \(currentTrack.artist)")
                        }
                    }
                }
                
                if let prev = json?["prev"] as? [[String: Any]] {
                    print("Found \(prev.count) recent tracks")
                    
                    let tracks = prev.compactMap { self?.processTrackData($0) }
                    print("Processed \(tracks.count) recent tracks")
                    
                    // Print first few track titles for debugging
                    if !tracks.isEmpty {
                        print("First track: \(tracks[0].title) by \(tracks[0].artist)")
                        if tracks.count > 1 {
                            print("Second track: \(tracks[1].title) by \(tracks[1].artist)")
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self?.recentTracks = tracks
                        print("Updated recent tracks array with \(tracks.count) items")
                    }
                } else {
                    print("No 'prev' data found in JSON or it's not an array")
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func processTrackData(_ track: [String: Any]) -> Track? {
        // Extract recording data
        guard let recording = track["recording"] as? [String: Any] else {
            print("No recording data found in track")
            return nil
        }
        
        // Get title
        let title = recording["title"] as? String ?? "Unknown Track"
        
        // Get artist
        var artistName = "Unknown Artist"
        if let artists = recording["artists"] as? [[String: Any]] {
            for artist in artists {
                if let type = artist["type"] as? String, type == "primary",
                   let name = artist["name"] as? String {
                    artistName = name
                    break
                }
            }
        }
        
        // Get album and artwork
        var albumName = ""
        var artworkURL = URL(string: "https://www.abc.net.au/cm/rimage/11948498-1x1-large.png?v=2")!
        
        if let release = track["release"] as? [String: Any] {
            albumName = release["title"] as? String ?? ""
            
            if let artwork = release["artwork"] as? [[String: Any]], let firstArtwork = artwork.first,
               let sizes = firstArtwork["sizes"] as? [[String: Any]] {
                for size in sizes {
                    if let aspectRatio = size["aspect_ratio"] as? String, aspectRatio == "1x1",
                       let width = size["width"] as? Int, width >= 400,
                       let urlString = size["url"] as? String, let url = URL(string: urlString) {
                        artworkURL = url
                        break
                    }
                }
            }
        }
        
        // Format played time
        var playedAt = "Just now"
        if let playedTime = track["played_time"] as? String {
            playedAt = formatTimestamp(playedTime)
        }
        
        return Track(
            title: title,
            artist: artistName,
            album: albumName,
            artwork: artworkURL,
            playedAt: playedAt
        )
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let date = dateFormatter.date(from: timestamp) else {
            return "Just now"
        }
        
        let timeDiff = Int(Date().timeIntervalSince(date))
        
        if timeDiff < 60 {
            return "Just now"
        } else if timeDiff < 3600 {
            let minutes = timeDiff / 60
            return "\(minutes)m ago"
        } else if timeDiff < 86400 {
            let hours = timeDiff / 3600
            return "\(hours)h ago"
        } else {
            let hourFormatter = DateFormatter()
            hourFormatter.dateFormat = "HH:mm"
            return hourFormatter.string(from: date)
        }
    }
    
    deinit {
        stopPolling()
        print("TripleJAPI deinitializing")
    }
}
