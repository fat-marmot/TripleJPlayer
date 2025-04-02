//
//  PlayedTrack+CoreDataProperties.swift
//  TripleJPlayer
//
//  Created by Colin Burns on 2/4/2025.
//
//

import Foundation
import CoreData


extension PlayedTrack {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayedTrack> {
        return NSFetchRequest<PlayedTrack>(entityName: "PlayedTrack")
    }

    @NSManaged public var album: String?
    @NSManaged public var artist: String?
    @NSManaged public var artworkUrl: String?
    @NSManaged public var id: String?
    @NSManaged public var playedAt: Date?
    @NSManaged public var title: String?

}

extension PlayedTrack : Identifiable {

}
