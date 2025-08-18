//
//  MainTabView.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import SwiftUI

struct MainTabGateView: View {
    @StateObject private var session = SessionViewModel()

    var body: some View {
        if session.isAuthenticated {
            MainTabView().environmentObject(session)
        } else {
            OnboardingView().environmentObject(session)
        }
    }
}

enum Tabs {
    case recordings, favourites, capture
}

struct MainTabView: View {
    @State private var selection: Tabs = .recordings
    @State private var showSheet: Bool = false
    
    private let sampleAmplitudes: [CGFloat] = (0..<50).map { i in
        let value = CGFloat(abs(sin(Double(i) * 0.3))) * 0.9 + 0.1
        return value
    }
    
    var body: some View {
        ZStack(alignment: .bottom){
            RecordingsView()
            RecordButton()
        }
    }
}

#Preview {
    MainTabGateView()
}
