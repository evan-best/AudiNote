//
//  CGFloat+Ext.swift
//  AudiNote
//
//  Created by Evan Best on 2025-12-20.
//

import Foundation

extension CGFloat {
	func clamped(to r: ClosedRange<CGFloat>) -> CGFloat {
		Swift.min(Swift.max(self, r.lowerBound), r.upperBound)
	}
}
