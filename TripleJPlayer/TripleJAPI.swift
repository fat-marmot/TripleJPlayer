import Foundation
import Combine

class TripleJAPI: ObservableObject {
    // Published properties
    @Published var currentTrack: Track = Track.placeholder
    @Published var recentTracks: [Track] = []
    @Published var currentProgram: Program = Program.placeholder
    @Published var isLoading: Bool = false
    @Published var lastErrorMessage: String? = nil
    
    // Timers and state
    private var nowPlayingTimer: Timer?
    private var programInfoTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // API endpoints
    private let nowPlayingURL = URL(string: "https://music.abcradio.net.au/api/v1/plays/triplej/now.json?tz=Australia%2FSydney")!
    private let recentTracksURL = URL(string: "https://music.abcradio.net.au/api/v1/plays/search.json?station=triplej&order=desc&tz=Australia%2FSydney&limit=20")!
    
    // For program info, we'll need to dynamically create the URL with current date
    private func createProgramInfoURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH'%3A'mm'%3A'ss"
        
        let now = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        
        let fromDate = dateFormatter.string(from: now)
        let toDate = dateFormatter.string(from: tomorrow)
        
        let urlString = "https://program.abcradio.net.au/api/v1/programitems/search.json?include=next%2Cwith_images%2Cresized_images&service=triplej&from=\(fromDate)&to=\(toDate)&order_by=ppe_date&order=asc&limit=10"
        
        return URL(string: urlString)!
    }
    
    init() {
        print("TripleJAPI initialized")
        
        // Initial data fetch
        fetchNowPlaying()
        fetchRecentTracks()
        fetchProgramInfo()
    }
    
    // MARK: - Now Playing Functions
    func fetchNowPlaying() {
        print("Fetching now playing data...")
        isLoading = true
        lastErrorMessage = nil
        
        URLSession.shared.dataTask(with: nowPlayingURL) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.isLoading = false
                }
            }
            
            if let error = error {
                print("Error fetching now playing data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "Connection error: \(error.localizedDescription)"
                }
                self?.scheduleNextNowPlayingUpdate(afterSeconds: 30)
                return
            }
            
            guard let data = data else {
                print("No data received from now playing API")
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "No data received from API"
                }
                self?.scheduleNextNowPlayingUpdate(afterSeconds: 30)
                return
            }
            
            do {
                // Log the JSON response for debugging if needed
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON first 200 chars: \(String(jsonString.prefix(200)))...")
                }
                
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                // Most important: Schedule next update based on next_updated timestamp
                if let nextUpdateString = json?["next_updated"] as? String {
                    print("Found next_updated timestamp: \(nextUpdateString)")
                    self?.scheduleNowPlayingUpdateBasedOnTimestamp(nextUpdateString)
                } else {
                    // Fallback to fixed interval if next_updated is missing
                    print("No next_updated timestamp found in response")
                    self?.scheduleNextNowPlayingUpdate(afterSeconds: 30)
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
                    // Empty "now" object typically means a presenter is speaking
                    print("No current track - presenter segment")
                    DispatchQueue.main.async {
                        self?.currentTrack = Track.presenterSegment
                    }
                }
            } catch {
                print("Error parsing now playing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "Error parsing data from API"
                }
                self?.scheduleNextNowPlayingUpdate(afterSeconds: 30)
            }
        }.resume()
    }
    
    // This function updates the scheduling based on the next_updated timestamp
    private func scheduleNowPlayingUpdateBasedOnTimestamp(_ timestampString: String) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try to parse with fractional seconds first
        var nextUpdateDate: Date?
        nextUpdateDate = dateFormatter.date(from: timestampString)
        
        // If that fails, try without fractional seconds
        if nextUpdateDate == nil {
            dateFormatter.formatOptions = [.withInternetDateTime]
            nextUpdateDate = dateFormatter.date(from: timestampString)
        }
        
        // If still nil, try a more forgiving approach
        if nextUpdateDate == nil {
            let fallbackFormatter = DateFormatter()
            fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            nextUpdateDate = fallbackFormatter.date(from: timestampString)
        }
        
        guard let updateDate = nextUpdateDate else {
            print("Could not parse next_updated timestamp: \(timestampString), using default interval")
            scheduleNextNowPlayingUpdate(afterSeconds: 30)
            return
        }
        
        // Calculate time until next update
        let timeUntilNextUpdate = updateDate.timeIntervalSinceNow
        
        // Add a small buffer (1 second) to ensure we update just after the API does
        // If the timestamp is in the past, update immediately with a 1 second delay
        let updateDelay = max(1, timeUntilNextUpdate + 1)
        
        print("Scheduling next update in \(updateDelay) seconds based on next_updated timestamp (\(timestampString))")
        
        // Log the calculated time for debugging
        let updateDateTime = Date(timeIntervalSinceNow: updateDelay)
        let logFormatter = DateFormatter()
        logFormatter.dateFormat = "HH:mm:ss"
        print("Next update will occur at approximately: \(logFormatter.string(from: updateDateTime))")
        
        scheduleNextNowPlayingUpdate(afterSeconds: updateDelay)
    }
    
    private func scheduleNextNowPlayingUpdate(afterSeconds seconds: TimeInterval) {
        // Cancel any existing timer
        nowPlayingTimer?.invalidate()
        
        // Create new timer
        nowPlayingTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            print("Timer fired at \(Date()) - fetching latest track")
            self?.fetchNowPlaying()
        }
        
        // Add to RunLoop to prevent timer from being invalidated when app is in background
        RunLoop.current.add(nowPlayingTimer!, forMode: .common)
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
    
    // MARK: - Recent Tracks Functions
    
    func fetchRecentTracks() {
        print("Fetching recent tracks...")
        
        URLSession.shared.dataTask(with: recentTracksURL) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching recent tracks: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received from recent tracks API")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                if let items = json?["items"] as? [[String: Any]] {
                    var tracks: [Track] = []
                    
                    for item in items {
                        if let track = self?.processTrackData(item, isNowPlaying: false) {
                            tracks.append(track)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self?.recentTracks = tracks
                        print("Updated recent tracks: \(tracks.count) items")
                    }
                }
            } catch {
                print("Error parsing recent tracks JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    // MARK: - Program Info Functions
    
    func fetchProgramInfo() {
        print("Fetching program info...")
        
        let programURL = createProgramInfoURL()
        
        URLSession.shared.dataTask(with: programURL) { [weak self] data, response, error in
            if let error = error {
                print("Error fetching program info: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received from program info API")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                if let items = json?["items"] as? [[String: Any]], let firstProgram = items.first {
                    if let program = self?.processProgramData(firstProgram) {
                        DispatchQueue.main.async {
                            self?.currentProgram = program
                            print("Updated current program: \(program.title)")
                        }
                    }
                    
                    // Schedule next program info update (hourly)
                    self?.scheduleNextProgramInfoUpdate(afterSeconds: 3600)
                }
            } catch {
                print("Error parsing program info JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func processProgramData(_ programData: [String: Any]) -> Program? {
        guard let title = programData["title"] as? String else {
            return nil
        }
        
        // Extract host/presenter information
        var presenter = ""
        if let hosts = programData["hosts"] as? [[String: Any]], let firstHost = hosts.first {
            presenter = firstHost["name"] as? String ?? ""
        }
        
        // Extract program image
        var imageURL = URL(string: "https://www.abc.net.au/cm/rimage/11948498-1x1-large.png?v=2")!
        if let images = programData["images"] as? [[String: Any]], let firstImage = images.first,
           let urlString = firstImage["url"] as? String, let url = URL(string: urlString) {
            imageURL = url
        }
        
        // Extract start and end times
        var startTime = ""
        var endTime = ""
        if let from = programData["from"] as? String {
            startTime = formatProgramTime(from)
        }
        if let to = programData["to"] as? String {
            endTime = formatProgramTime(to)
        }
        
        return Program(
            title: title,
            presenter: presenter,
            image: imageURL,
            startTime: startTime,
            endTime: endTime,
            description: programData["description"] as? String ?? ""
        )
    }
    
    private func scheduleNextProgramInfoUpdate(afterSeconds seconds: TimeInterval) {
        // Cancel any existing timer
        programInfoTimer?.invalidate()
        
        // Create new timer
        programInfoTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            print("Program info timer fired - fetching latest program info")
            self?.fetchProgramInfo()
        }
    }
    
    // MARK: - Helper Functions
    
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
    
    private func formatProgramTime(_ timestamp: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        guard let date = dateFormatter.date(from: timestamp) else {
            return ""
        }
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
    
    deinit {
        nowPlayingTimer?.invalidate()
        programInfoTimer?.invalidate()
        nowPlayingTimer = nil
        programInfoTimer = nil
        print("TripleJAPI deinitializing")
    }
}
