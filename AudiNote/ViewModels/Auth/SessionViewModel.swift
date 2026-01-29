//
//  SessionViewModel.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import Foundation
import Combine
import AuthenticationServices
import SwiftUI

final class SessionViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var appearanceMode: String = "System"
    @Published var hapticFeedbackEnabled: Bool = true
    
    private let userDefaults = UserDefaults.standard
    private let authKey = "isAuthenticated"
    private let appearanceKey = "appearanceMode"
    private let hapticKey = "hapticFeedbackEnabled"
    
    init() {
        loadSession()
    }
    
    private func loadSession() {
        isAuthenticated = userDefaults.bool(forKey: authKey)
        appearanceMode = userDefaults.string(forKey: appearanceKey) ?? "System"
        hapticFeedbackEnabled = userDefaults.object(forKey: hapticKey) == nil ? true : userDefaults.bool(forKey: hapticKey)
    }
    
    private func saveSession() {
        userDefaults.set(isAuthenticated, forKey: authKey)
        userDefaults.set(appearanceMode, forKey: appearanceKey)
        userDefaults.set(hapticFeedbackEnabled, forKey: hapticKey)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success:
            isAuthenticated = true
            saveSession()
        case .failure:
            isAuthenticated = false
        }
    }

    func signOut() {
        isAuthenticated = false
        saveSession()
    }
    
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil // System
        }
    }
    
    func setAppearance(_ mode: String) {
        appearanceMode = mode
        saveSession()
    }
    
    func setHapticFeedback(_ enabled: Bool) {
        hapticFeedbackEnabled = enabled
        saveSession()
    }
    
    func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticFeedbackEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
}
