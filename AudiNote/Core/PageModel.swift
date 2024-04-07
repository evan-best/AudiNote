//
//  PageModel.swift
//  AudiNote
//
//  Created by Evan Best on 2024-04-07.
//

import Foundation

struct Page: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var description: String
    var imageUrl: String
    var tag: Int
    
    static var sample = Page(name: "Title Example", description: "This is a sample description for previews.", imageUrl: "secure", tag: 0)
    
    static var samplePages: [Page] = [
        Page(name: "Welcome to AudiNote!", description: "The perfect solution for recording meetings, lectures, and conversations.", imageUrl: "generic", tag: 0),
        Page(name: "Safely Secure.", description: "We don't collect any of your personal data. Your recordings will be safely stored on your device.", imageUrl: "secure", tag: 1),
        Page(name: "Forever Free.", description: "No paywalls, no trials. Get started today!", imageUrl: "record", tag: 2)]
}
