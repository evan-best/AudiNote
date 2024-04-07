//
//  ContentView.swift
//  AudiNote
//
//  Created by Evan Best on 2024-03-17.
//

import SwiftUI

struct ContentView: View {
    @State private var pageIndex = 0
    private let pages: [Page] = Page.samplePages
    private let dotAppearance = UIPageControl.appearance()
    var body: some View {
        TabView(selection: $pageIndex) {
            ForEach(pages) { page in
                VStack {
                    Spacer()
                    PageView(page:page)
                    Spacer()
                    
                    if page == pages.last {
                        Button {
                            goToZero()
                        } label: {
                            Text("Get Started!")
                                .foregroundStyle(Color.white)
                                .fontWeight(.semibold)
                        }
                        .frame(width: 140, height: 50)
                        .background(Color(.systemBlue))
                        .opacity(0.9)
                        .cornerRadius(10)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    } else {
                        Button {
                            incrementPage()
                        } label: {
                            Image(systemName: "arrow.right")
                                .foregroundStyle(Color.white)
                        }
                        .frame(width: 100, height: 40)
                        .background(Color(.systemBlue))
                        .opacity(0.9)
                        .cornerRadius(10)
                        .padding(.top, 24)
                        .padding(.bottom, 24)
                    }
                    Spacer()
                }
                .tag(page.tag)
            }
        }
        .animation(.easeInOut, value: pageIndex)
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .onAppear {
            dotAppearance.currentPageIndicatorTintColor = .blue
            dotAppearance.pageIndicatorTintColor = .gray
        }
    }
    
    func incrementPage() {
        pageIndex += 1
    }
    
    func goToZero() {
        pageIndex = 0
    }
}

#Preview {
    ContentView()
}
