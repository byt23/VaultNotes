//
//  VaultNotesApp.swift
//  VaultNotes
//
//  Created by BERKAY TURAN on 19.04.2026.
//

import SwiftUI
import SwiftData

@main
struct VaultNotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for : SifreliNot.self)
    }
}
