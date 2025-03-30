//
//  Models.swift
//  TripleJPlayer
//
//  Created by Colin Burns on 28/3/2025.
//

import Foundation

struct Track: Identifiable {
    let id = UUID()
    let title: String
    let artist: String
    let album: String
    let artwork: URL
    let playedAt: String
    
    static let placeholder = Track(
        title: "Loading...",
        artist: "triple j",
        album: "",
        artwork: URL(string: "https://www.abc.net.au/cm/rimage/11948498-1x1-large.png?v=2")!,
        playedAt: "Now"
    )
}
