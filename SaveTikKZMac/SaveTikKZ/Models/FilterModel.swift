//
//  FilterModel.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import Foundation

// MARK: - 排序优先级枚举
enum SortPriority: String, CaseIterable, Identifiable {
    case resolution = "分辨率优先"
    case encoding = "编码优先"
    var id: String { self.rawValue }
}

// MARK: - 筛选器标签模型
struct FilterToken: Identifiable, Equatable {
    let id = UUID()
    let name: String
    var isOn: Bool
    
    // 用于内部排序的数值大小（例如 1080P -> 1080）
    var numericValue: Int {
        Int(name.filter { $0.isNumber }) ?? 0
    }
}
