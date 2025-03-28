//
//  TripleJPlayerApp.swift
//  TripleJPlayer
//
//  Created by Colin Burns on 28/3/2025.
//

import SwiftUI

@main
struct TripleJPlayerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
