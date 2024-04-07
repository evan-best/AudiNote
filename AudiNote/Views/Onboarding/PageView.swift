//
//  PageView.swift
//  AudiNote
//
//  Created by Evan Best on 2024-04-07.
//

import SwiftUI

struct PageView: View {
    var page: Page
    var body: some View {
        VStack(spacing:20) {
            Image("\(page.imageUrl)")
                .resizable()
                .scaledToFit()
                .padding()
                .cornerRadius(30)
                .padding()
            
            Text(page.name)
                .font(.title)
            
            Text(page.description)
                .font(.subheadline)
                .frame(width: 300)
            
        }
    }
}

#Preview {
    PageView(page: Page.sample)
}
