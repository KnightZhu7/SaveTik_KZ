//
//  HeaderView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI

struct HeaderView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var selectedAppearance: AppAppearance
    @Binding var showFilterPopover: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                Menu {
                    Picker("外观模式", selection: $selectedAppearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                            }.tag(mode)
                        }
                    }.pickerStyle(.inline)
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 24))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.primary.opacity(0.6), .regularMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .help("切换外观模式")
                
                if viewModel.hasResults {
                    Button(action: { showFilterPopover.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.system(size: 24))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.primary.opacity(0.6), .regularMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showFilterPopover, arrowEdge: .top) {
                        FilterPopoverView(viewModel: viewModel)
                    }
                    .padding(.leading, 8)
                    .transition(.opacity.combined(with: .scale))
                }
                Spacer()
            }
            .frame(height: 24)
            .padding(.leading, 20)
            .padding(.top, 10)
            .zIndex(1)
            
            Text("SaveTik_KZ")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.top, 40)
                .padding(.bottom, 20)
        }
    }
}
