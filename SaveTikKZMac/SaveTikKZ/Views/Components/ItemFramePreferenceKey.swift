//
//  ItemFramePreferenceKey.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 8/25/26.
//

import SwiftUI
import Combine

struct ItemFramePreferenceKey: PreferenceKey {
    typealias Value = [UUID: CGRect]
    
    static var defaultValue: [UUID: CGRect] = [:]
    
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

struct ResultsContainerFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}
