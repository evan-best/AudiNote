//
//  Array+Ext.swift
//  AudiNote
//
//  Created by Evan Best on 2025-12-20.
//

import Foundation

extension Array {
	subscript(safe index: Int) -> Element? {
		return (startIndex <= index && index < endIndex) ? self[index] : nil
	}
}
