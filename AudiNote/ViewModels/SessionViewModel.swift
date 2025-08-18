//
//  SessionViewModel.swift
//  AudiNote
//
//  Created by Evan Best on 2025-08-11.
//

import Foundation
import Combine
import AuthenticationServices

final class SessionViewModel: NSObject, ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var appleUserID: String? = nil
    
    private let userDefaults = UserDefaults.standard
    private let appleUserIDKey = "AppleUserID"
    
    override init() {
        super.init()
        loadPersistedSession()
    }
    
    private func loadPersistedSession() {
        if let savedUserID = userDefaults.string(forKey: appleUserIDKey) {
            appleUserID = savedUserID
            checkCredentialState(userID: savedUserID)
        }
    }
    
    private func saveSession() {
        if let userID = appleUserID {
            userDefaults.set(userID, forKey: appleUserIDKey)
        } else {
            userDefaults.removeObject(forKey: appleUserIDKey)
        }
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                appleUserID = credential.user
                isAuthenticated = true
                saveSession()
            }
        case .failure:
            isAuthenticated = false
        }
    }

    func checkCredentialState(userID: String) {
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                switch state {
                case .authorized:
                    self?.isAuthenticated = true
                case .revoked, .notFound:
                    self?.signOut()
                case .transferred:
                    // Handle transferred state if needed
                    self?.isAuthenticated = false
                @unknown default:
                    self?.isAuthenticated = false
                }
            }
        }
    }

    func signOut() {
        appleUserID = nil
        isAuthenticated = false
        saveSession()
    }
}
