import Foundation
import Combine

class TripleJAPI: ObservableObject {
    @Published var currentTrack: Track = Track.placeholder
    @Published var recentTracks: [Track] = []
    @Published var isLoading: Bool = false
    @Published var lastErrorMessage: String? = nil
    
    private var timer: Timer?
    private var recentTracksFromAPI: [Track] = []
    private var cancellables = Set<AnyCancellable>()
    
    // API endpoint
    private let apiURL = URL(string: "https://music.abcradio.net.au/api/v1/plays/triplej/now.json?tz=Australia%2FSydney")!
    
    init() {
        print("TripleJAPI initialized")
        fetchNowPlaying()
        
        // Add this debug line to check if we can retrieve tracks from CoreData
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            let savedTracks = TrackStore.shared.fetchRecentTracks()
            print("TEST: Found \(savedTracks.count) tracks in CoreData")
        }
    }
    
    func fetchNowPlaying() {
        print("Fetching now playing data...")
        guard let url = apiURL else {
            print("Invalid URL")
            scheduleNextUpdate(afterSeconds: 30)
            return
        }
        
        isLoading = true
        lastErrorMessage = nil
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
            
            if let error = error {
                print("Error fetching data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "Connection error: \(error.localizedDescription)"
                }
                self?.scheduleNextUpdate(afterSeconds: 30)
                return
            }
            
            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "No data received from API"
                }
                self?.scheduleNextUpdate(afterSeconds: 30)
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON response (first 200 chars): \(String(jsonString.prefix(200)))...")
                }
                
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                // Schedule next update based on next_updated timestamp
                if let nextUpdateString = json?["next_updated"] as? String {
                    self?.scheduleUpdateBasedOnTimestamp(nextUpdateString)
                } else {
                    // Fallback to fixed interval if next_updated is missing
                    self?.scheduleNextUpdate(afterSeconds: 30)
                }
                
                // Process "now" track
                if let now = json?["now"] as? [String: Any], !now.isEmpty {
                    print("Found 'now' data")
                    if let currentTrack = self?.processTrackData(now, isNowPlaying: true) {
                        DispatchQueue.main.async {
                            self?.currentTrack = currentTrack
                            print("Updated current track: \(currentTrack.title) by \(currentTrack.artist)")
                        }
                    }
                } else {
                    // Empty "now" object means a presenter is speaking
                    print("No current track - presenter segment")
                    DispatchQueue.main.async {
                        self?.currentTrack = Track.presenterSegment
                    }
                }

                // Process "prev" track - Save ONLY here
                if let prev = json?["prev"] as? [String: Any], !prev.isEmpty {
                    print("Found 'prev' data")
                    if let previousTrack = self?.processTrackData(prev, isNowPlaying: false) {
                        DispatchQueue.main.async {
                            // Create a single-item array with the previous track
                            self?.recentTracksFromAPI = [previousTrack]
                            
                            // Save to CoreData only when track appears in "prev"
                            TrackStore.shared.saveTrack(previousTrack)
                            
                            // Load combined tracks
                            self?.loadRecentTracks()
                            print("Updated recent tracks with previous track: \(previousTrack.title) by \(previousTrack.artist)")
                        }
                    }
                } else {
                    print("No 'prev' data found in JSON or it's in an unexpected format")
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "Error parsing data from API"
                }
                self?.scheduleNextUpdate(afterSeconds: 30)
            }
        }.resume()
    }
    
    private func scheduleUpdateBasedOnTimestamp(_ timestampString: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let nextUpdateDate = dateFormatter.date(from: timestampString) else {
            print("Could not parse next_updated timestamp, using default interval")
            scheduleNextUpdate(afterSeconds: 30)
            return
        }
        
        let timeUntilNextUpdate = nextUpdateDate.timeIntervalSinceNow
        
        // Add a small buffer (2 seconds) to ensure we update just after the API does
        // If the timestamp is in the past, update now plus 2 seconds
        let updateDelay = max(2, timeUntilNextUpdate + 2)
        
        print("Scheduling next update in \(updateDelay) seconds based on next_updated timestamp")
        scheduleNextUpdate(afterSeconds: updateDelay)
    }
    
    private func scheduleNextUpdate(afterSeconds seconds: TimeInterval) {
        // Cancel any existing timer
        timer?.invalidate()
        
        // Create new timer
        timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            print("Timer fired - fetching latest tracks")
            self?.fetchNowPlaying()
        }
    }
    
    private func processTrackData(_ track: [String: Any], isNowPlaying: Bool) -> Track? {
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
        var playedAt = isNowPlaying ? "Now" : "Just now"
        if !isNowPlaying, let playedTime = track["played_time"] as? String {
            playedAt = formatTimestamp(playedTime)
        }
        
        return Track(
            title: title,
            artist: artistName,
            album: albumName,
            artwork: artworkURL,
            playedAt: playedAt,
            isPresenterSegment: false
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
    
    func loadRecentTracks() {
        // Get tracks from CoreData to supplement API tracks
        let savedTracks = TrackStore.shared.fetchRecentTracks(limit: 10)
        print("DEBUG: Fetched \(savedTracks.count) tracks from CoreData")
        
        // Combine both sources and remove duplicates (by title and artist)
        var combinedTracks = recentTracksFromAPI
        print("DEBUG: Starting with \(combinedTracks.count) tracks from API")
        
        for track in savedTracks {
            // Check if track already exists in our list
            let exists = combinedTracks.contains { existingTrack in
                existingTrack.title == track.title && existingTrack.artist == track.artist
            }
            
            if !exists {
                combinedTracks.append(track)
                print("DEBUG: Added track from CoreData: \(track.title) by \(track.artist)")
            } else {
                print("DEBUG: Skipped duplicate track: \(track.title) by \(track.artist)")
            }
        }
        
        print("DEBUG: Combined track count before sorting: \(combinedTracks.count)")
        
        // Sort by time (most recent first)
        combinedTracks.sort { track1, track2 in
            // Create a helper function to convert string time to value for sorting
            let timeValue1 = self.timeValueForSorting(track1.playedAt)
            let timeValue2 = self.timeValueForSorting(track2.playedAt)
            return timeValue1 > timeValue2  // Change < to > to reverse the order
        }
        
        // Take only the first 5 tracks
        let limitedTracks = Array(combinedTracks.prefix(5))
        print("DEBUG: Final limited track count: \(limitedTracks.count)")
        
        self.recentTracks = limitedTracks
        print("Updated recent tracks with combined data: \(limitedTracks.count) items")
    }

    // Helper function for sorting
    private func timeValueForSorting(_ timeString: String) -> Int {
        if timeString.contains("Just now") || timeString == "Now" {
            return 0
        } else if timeString.contains("m ago") {
            if let minutes = Int(timeString.replacingOccurrences(of: "m ago", with: "")) {
                return minutes
            }
        } else if timeString.contains("h ago") {
            if let hours = Int(timeString.replacingOccurrences(of: "h ago", with: "")) {
                return hours * 60  // Convert hours to minutes for comparison
            }
        }
        return 999999 // Put at the end if we can't parse
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
        print("TripleJAPI deinitializing")
    }
}
