//
//  SessionViewModel.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import Foundation
import Combine
import AuthenticationServices

final class SessionViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let authKey = "isAuthenticated"
    
    init() {
        loadSession()
    }
    
    private func loadSession() {
        isAuthenticated = userDefaults.bool(forKey: authKey)
    }
    
    private func saveSession() {
        userDefaults.set(isAuthenticated, forKey: authKey)
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
}
