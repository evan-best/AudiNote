//
//  View+Ext.swift
//  AudiNote
//
//  Created by Evan Best on 2025-12-20.
//

import Foundation
import SwiftUI

extension View {
	func toast(manager: ToastManager = .shared) -> some View {
		self.modifier(ToastModifier(toastManager: manager))
	}
}
