//
//  PlayedTrack+Extensions.swift
//  TripleJPlayer
//
//  Created by Colin Burns on 30/3/2025.
//

import Foundation
import CoreData

extension PlayedTrack {
    // Convenience method to create a new track
    static func create(from track: Track, in context: NSManagedObjectContext) -> PlayedTrack {
        let newTrack = PlayedTrack(context: context)
        newTrack.id = track.id.uuidString
        newTrack.title = track.title
        newTrack.artist = track.artist
        newTrack.album = track.album
        newTrack.artworkUrl = track.artwork.absoluteString
        
        // Set the played time to now
        newTrack.playedAt = Date()
        
        do {
            try context.save()
            print("Successfully saved track: \(track.title)")
        } catch {
            print("Failed to save track: \(error.localizedDescription)")
        }
        
        return newTrack
    }
    
    // Convert to your Track model
    func toTrack() -> Track {
        return Track(
            title: self.title ?? "Unknown",
            artist: self.artist ?? "Unknown Artist",
            album: self.album ?? "",
            artwork: URL(string: self.artworkUrl ?? "") ?? URL(string: "https://www.abc.net.au/cm/rimage/11948498-1x1-large.png?v=2")!,
            playedAt: formatRelativeTime(from: self.playedAt ?? Date())
        )
    }
    
    // Format date to relative time string
    private func formatRelativeTime(from date: Date) -> String {
        let now = Date()
        let timeDiff = Int(now.timeIntervalSince(date))
        
        if timeDiff < 60 {
            return "Just now"
        } else if timeDiff < 3600 {
            let minutes = timeDiff / 60
            return "\(minutes)m ago"
        } else if timeDiff < 86400 {
            let hours = timeDiff / 3600
            return "\(hours)h ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }
}
