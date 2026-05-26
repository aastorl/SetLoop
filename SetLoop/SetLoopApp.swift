//
//  SetLoopApp.swift
//  SetLoop
//
//  Created by Astor Ludueña  on 08/05/2026.
//

import SwiftUI

@main
struct SetLoopApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("UITEST_RESET_MOCK_DATA") {
            let userDefaults = UserDefaults.standard
            [
                "setloop.mock.accounts",
                "setloop.mock.current_user_id",
                "setloop.mock.applications",
                "setloop.mock.notifications"
            ].forEach { userDefaults.removeObject(forKey: $0) }
            try? KeychainSessionStore().clear()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
