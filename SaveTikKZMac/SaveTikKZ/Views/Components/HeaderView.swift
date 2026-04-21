//
//  HeaderView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

struct HeaderView: View {
    var body: some View {
        Text("SaveTik_KZ")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .padding(.top, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
    }
}
