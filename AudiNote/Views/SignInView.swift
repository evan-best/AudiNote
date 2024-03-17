//
//  SignInView.swift
//  AudiNote
//
//  Created by Evan Best on 2024-03-17.
//

import SwiftUI

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        NavigationView {
            VStack {
                // Image
                Image("study-pic")
                
                // Form fields
                VStack(spacing: 24) {
                    InputView(text: $email,
                              title: "Email Address",
                              placeholder: "name@example.com")
                    .textInputAutocapitalization(.none)
                    
                    InputView(text: $password,
                              title: "Password",
                              placeholder: "Enter your password",
                              isSecureField: true)
                }
                .padding(.horizontal)
                
                // Sign in button
                Button {
                    
                } label: {
                    HStack {
                        Text("SIGN IN")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(Color.white)
                    .frame(width: UIScreen.main.bounds.width - 32, height: 48)
                }
                .background(Color(.systemMint))
                .cornerRadius(10)
                .padding(.top, 24)
                .padding(.bottom, 24)
                
                // Divider and OR Text
                HStack {
                    VStack { Divider () }
                    
                    Text("OR")
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                    VStack { Divider() }
                }
                .padding(.top, 8)
            }
        }
    }
}

#Preview {
    SignInView()
}
