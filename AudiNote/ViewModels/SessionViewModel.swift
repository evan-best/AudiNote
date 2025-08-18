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

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                appleUserID = credential.user
                isAuthenticated = true
            }
        case .failure:
            isAuthenticated = false
        }
    }

    func checkCredentialState(userID: String) {
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { [weak self] state, _ in
            DispatchQueue.main.async {
                self?.isAuthenticated = (state == .authorized)
            }
        }
    }

    func signOut() {
        appleUserID = nil
        isAuthenticated = false
    }
}
