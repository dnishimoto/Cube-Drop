//
//  Cube_DropApp.swift
//  Cube Drop
//
//  Created by David Nishimoto on 7/7/26.
//

import SwiftUI
import CoreData

@main
struct Cube_DropApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
