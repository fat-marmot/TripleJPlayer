//
//  TrackStore.swift
//  TripleJPlayer
//
//  Created by Colin Burns on 30/3/2025.
//

import Foundation
import CoreData

class TrackStore {
    
    static let shared = TrackStore()
    
    private let persistenceController = PersistenceController.shared
    
    func saveTrack(_ track: Track) {
        // Skip saving presenter segments to the database
        if track.isPresenterSegment {
            print("Skipping save for presenter segment")
            return
        }
        
        let context = persistenceController.container.viewContext
        
        // Check if track already exists to avoid duplicates
        let fetchRequest: NSFetchRequest<PlayedTrack> = PlayedTrack.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", track.id.uuidString)
        
        do {
            let results = try context.fetch(fetchRequest)
            
            // If track doesn't exist, save it
            if results.isEmpty {
                let playedTrack = PlayedTrack(context: context)
                playedTrack.id = track.id.uuidString
                playedTrack.title = track.title
                playedTrack.artist = track.artist
                playedTrack.album = track.album
                playedTrack.artworkUrl = track.artwork.absoluteString
                playedTrack.playedAt = Date()
                // We don't need to store isPresenterSegment since we skip presenter segments,
                // but it would be good to add this field if you ever need to save them
                
                try context.save()
                print("Track saved to CoreData: \(track.title)")
            }
        } catch {
            print("Error saving track: \(error.localizedDescription)")
        }
    }
    
    func fetchRecentTracks(limit: Int = 5) -> [Track] {
        let context = persistenceController.container.viewContext
        
        let fetchRequest: NSFetchRequest<PlayedTrack> = PlayedTrack.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "playedAt", ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            let results = try context.fetch(fetchRequest)
            
            return results.map { playedTrack in
                Track(
                    title: playedTrack.title ?? "Unknown",
                    artist: playedTrack.artist ?? "Unknown Artist",
                    album: playedTrack.album ?? "",
                    artwork: URL(string: playedTrack.artworkUrl ?? "") ?? URL(string: "https://www.abc.net.au/cm/rimage/11948498-1x1-large.png?v=2")!,
                    playedAt: formatTimeSince(date: playedTrack.playedAt ?? Date()),
                    isPresenterSegment: false // All tracks from database are music tracks, not presenter segments
                )
            }
        } catch {
            print("Error fetching tracks: \(error.localizedDescription)")
            return []
        }
    }

    // Helper function to format time
    private func formatTimeSince(date: Date) -> String {
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
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "HH:mm"
            return dayFormatter.string(from: date)
        }
    }
    
    // Optional: Add a method to clean up old tracks
    func cleanupOldTracks(olderThan days: Int = 7) {
        let context = persistenceController.container.viewContext
        
        // Calculate the cutoff date
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return
        }
        
        let fetchRequest: NSFetchRequest<PlayedTrack> = PlayedTrack.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "playedAt < %@", cutoffDate as NSDate)
        
        do {
            let oldTracks = try context.fetch(fetchRequest)
            print("Found \(oldTracks.count) tracks older than \(days) days to clean up")
            
            for track in oldTracks {
                context.delete(track)
            }
            
            try context.save()
        } catch {
            print("Error cleaning up old tracks: \(error.localizedDescription)")
        }
    }
}
