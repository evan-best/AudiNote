//
//  AppRootView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var session: SessionViewModel

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}


#Preview {
    AppRootView()
        .environmentObject(SessionViewModel())
}
