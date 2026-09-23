//
//  VRC_OSC_ChatboxApp.swift
//  VRC-OSC-Chatbox
//
//  Created by WYH2004 on 2026/6/12.
//

import SwiftUI

@main
struct VRC_OSC_ChatboxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var permissions = StartupPermissionController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active {
                        Task {
                            await permissions.requestOnLaunch()
                        }
                    }
                }
        }
    }
}
