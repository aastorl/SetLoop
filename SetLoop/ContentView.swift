//
//  ContentView.swift
//  SetLoop
//
//  Created by Astor Ludueña  on 08/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            switch authViewModel.sessionState {
            case .loading:
                ProgressView("Cargando sesion")
            case .signedOut:
                AuthView(viewModel: authViewModel)
            case .signedIn(let profile):
                if profile.isProfileComplete {
                    MainTabView(
                        profile: profile,
                        onPersistProfile: { updatedProfile in
                            try await authViewModel.persistProfile(updatedProfile)
                        },
                        onSignOut: {
                            Task {
                                await authViewModel.signOut()
                            }
                        }
                    )
                } else {
                    ProfileCompletionView(
                        profile: profile,
                        onPersistProfile: { updatedProfile in
                            try await authViewModel.updateProfile(updatedProfile)
                        },
                        onSignOut: {
                            Task {
                                await authViewModel.signOut()
                            }
                        }
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
