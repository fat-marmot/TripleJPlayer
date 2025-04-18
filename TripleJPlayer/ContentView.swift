import SwiftUI
import AVKit
import AppKit

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayerService()
    @StateObject private var tripleJAPI = TripleJAPI()
    @State private var showDebug = false
    @State private var selectedTrackId: UUID? = nil
    @State private var showTrackDetails = false
    @State private var volume: Float = 1.0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top control bar
                HStack(spacing: 12) {
                    // Play/Pause Button
                    Button(action: {
                        audioPlayer.togglePlayPause()
                    }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    // Volume Slider
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.1.fill")
                            .foregroundColor(.white.opacity(0.7))
                        
                        VolumeSlider(volume: $volume) { newVolume in
                            audioPlayer.setVolume(newVolume)
                        }
                        .frame(height: 20)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    // AirPlay Button
                    AirPlayButton()
                        .frame(width: 40, height: 30)
                    
                    Spacer()
                    
                    // Loading indicator
                    if tripleJAPI.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.trailing, 8)
                    }
                    
                    // Debug Button (icon only)
                    Button(action: {
                        showDebug.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Show/Hide Debug Information")
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Main Content Area - Now Playing + Condensed Program Info
                VStack(spacing: 8) {
                    // Album artwork with presenter overlay when needed
                    AsyncImage(url: tripleJAPI.currentTrack.artwork) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 200, height: 200)
                                .background(Color.gray.opacity(0.3))
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .overlay(
                                    Group {
                                        if tripleJAPI.currentTrack.isPresenterSegment {
                                            ZStack {
                                                Color.black.opacity(0.6)
                                                VStack {
                                                    Image(systemName: "mic.fill")
                                                        .font(.system(size: 50))
                                                        .foregroundColor(.red)
                                                    
                                                    Text("ON AIR")
                                                        .font(.title)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                        .padding(.top, 8)
                                                }
                                            }
                                        }
                                    }
                                )
                        case .failure:
                            Image(systemName: "music.note")
                                .font(.system(size: 70))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 200)
                                .background(Color.gray.opacity(0.3))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 200, height: 200)
                    .cornerRadius(4)
                    
                    // Track info - adjusted for presenter segments
                    Text(tripleJAPI.currentTrack.title)
                        .font(.title)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    
                    // Show different text based on whether it's a presenter segment
                    if tripleJAPI.currentTrack.isPresenterSegment {
                        Text("Live Broadcast")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(.top, 2)
                    } else {
                        Text(tripleJAPI.currentTrack.artist)
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(.top, 2)
                        
                        Text(tripleJAPI.currentTrack.album)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 4)
                    }
                    
                    // Condensed Program Info Section
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "radio.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            
                            Text(tripleJAPI.currentProgram.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            if !tripleJAPI.currentProgram.presenter.isEmpty {
                                Text("with \(tripleJAPI.currentProgram.presenter)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            if !tripleJAPI.currentProgram.startTime.isEmpty && !tripleJAPI.currentProgram.endTime.isEmpty {
                                Text("\(tripleJAPI.currentProgram.startTime) - \(tripleJAPI.currentProgram.endTime)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                    }
                    .background(Color.blue.opacity(0.4))
                    .cornerRadius(8)
                    .padding(.horizontal, 4)
                }
                .padding()
                .background(tripleJAPI.currentTrack.isPresenterSegment ? Color.red.opacity(0.4) : Color.brown.opacity(0.6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Show error message if there is one
                if let errorMessage = tripleJAPI.lastErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 4)
                }
                
                // Recently Played section
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Recently Played")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(tripleJAPI.recentTracks.count) tracks")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 20)
                    .padding(.horizontal)
                    
                    if tripleJAPI.recentTracks.isEmpty {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            
                            Text("Loading recent tracks...")
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, minHeight: 100)
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(tripleJAPI.recentTracks) { track in
                                    RecentTrackRow(track: track)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(selectedTrackId == track.id ?
                                                      Color.white.opacity(0.15) :
                                                      Color.white.opacity(0.05))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                        )
                                        .onTapGesture {
                                            selectedTrackId = track.id
                                            showTrackDetails = true
                                        }
                                    
                                    if track.id != tripleJAPI.recentTracks.last?.id {
                                        Divider()
                                            .background(Color.white.opacity(0.1))
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
                
                Spacer()
                
                // Debug section
                if showDebug {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Information")
                            .font(.headline)
                            .foregroundColor(.yellow)
                            .padding(.top, 8)
                        
                        Text("Current Track:")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                        
                        Text("Title: \(tripleJAPI.currentTrack.title)")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Text("Artist: \(tripleJAPI.currentTrack.artist)")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Text("Recent tracks count: \(tripleJAPI.recentTracks.count)")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Text("Current Program: \(tripleJAPI.currentProgram.title)")
                            .font(.caption)
                            .foregroundColor(.white)
                        
                        Text("Player State: \(audioPlayer.isPlaying ? "Playing" : "Paused")")
                            .font(.caption)
                            .foregroundColor(.white)
                            
                        Text("Volume: \(Int(volume * 100))%")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .frame(width: 400, height: 720)
            .background(Color.black)
            .onAppear {
                print("ContentView appeared")
                // Initialize volume binding to match audio player
                volume = audioPlayer.currentVolume
                // Force an immediate refresh when view appears
                tripleJAPI.fetchNowPlaying()
                tripleJAPI.fetchRecentTracks()
                tripleJAPI.fetchProgramInfo()
            }
            
            // Track detail popup
            if showTrackDetails,
               let selectedId = selectedTrackId,
               let selectedTrack = tripleJAPI.recentTracks.first(where: { $0.id == selectedId }) {
                
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showTrackDetails = false
                    }
                
                TrackDetailView(track: selectedTrack)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showTrackDetails)
    }
}

// MARK: - Recent Track Row
struct RecentTrackRow: View {
    let track: Track
    
    var body: some View {
        HStack(spacing: 12) {
            // Track artwork with improved loading and error states
            AsyncImage(url: track.artwork) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        Color.gray.opacity(0.3)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    ZStack {
                        Color.gray.opacity(0.3)
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.7))
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 45, height: 45)
            .cornerRadius(6)
            .shadow(radius: 2)
            
            // Track info with improved layout
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if !track.album.isEmpty {
                        Text(track.album)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Played time with background
            Text(track.playedAt)
                .font(.system(size: 11))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle()) // Make entire row tappable
    }
}

// MARK: - Track Detail View
struct TrackDetailView: View {
    let track: Track
    
    var body: some View {
        VStack(spacing: 16) {
            // Large artwork
            AsyncImage(url: track.artwork) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 180, height: 180)
                        .background(Color.gray.opacity(0.3))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "music.note")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .frame(width: 180, height: 180)
                        .background(Color.gray.opacity(0.3))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 180, height: 180)
            .cornerRadius(8)
            .shadow(radius: 4)
            
            // Track info
            VStack(spacing: 8) {
                Text(track.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(track.artist)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                if !track.album.isEmpty {
                    Text("Album: \(track.album)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Text("Played \(track.playedAt)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 4)
            }
            .padding()
            
            // Buttons
            HStack(spacing: 20) {
                Button(action: {
                    // Add action to copy track info
                    let trackInfo = "\(track.title) by \(track.artist)"
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(trackInfo, forType: .string)
                    #endif
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    // Search on Apple Music
                    let query = "\(track.title) \(track.artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "https://music.apple.com/search?term=\(query)") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #endif
                    }
                }) {
                    Label("Apple Music", systemImage: "music.note")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 300)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
