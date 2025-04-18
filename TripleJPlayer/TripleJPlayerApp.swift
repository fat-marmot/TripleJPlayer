//
//  TripleJPlayerApp.swift
//  TripleJPlayer
//
//  Created by Colin Burns on 28/3/2025.
//

import SwiftUI

@main
struct TripleJPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(width: 400, height: 720, alignment: .center)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
