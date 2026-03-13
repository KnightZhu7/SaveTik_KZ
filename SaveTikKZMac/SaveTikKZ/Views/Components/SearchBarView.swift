//
//  SearchBarView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI
import AppKit

// MARK: - 基础 AppKit 拦截器（仅处理焦点，不干扰行为）
class NativeBehaviorTextField: NSTextField {
    private var hasAutoFocusedOnLaunch = false
    
    // 仅保留启动自动聚焦，解决打开 App 没光标的问题
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if !hasAutoFocusedOnLaunch, self.window != nil {
            hasAutoFocusedOnLaunch = true
            DispatchQueue.main.async { self.window?.makeFirstResponder(self) }
        }
    }
    override func selectText(_ sender: Any?) {
        // 拦截全选请求，什么都不做
    }
    
    // 🔥 这里不再重写 selectText 或 becomeFirstResponder
    // 所有的全选、光标定位逻辑将完全遵循 macOS 系统默认行为
}

// MARK: - 稳压包装器
struct FixedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    @Binding var requestFocus: Bool
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NativeBehaviorTextField()
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 13)
        textField.delegate = context.coordinator
        textField.focusRingType = .none
        
        if let cell = textField.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.wraps = false
            cell.isScrollable = true
        }
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        // 🔥 核心修复：通过强行 makeFirstResponder 解决清除后光标丢失的 Bug
        if requestFocus {
            DispatchQueue.main.async {
                if nsView.window?.firstResponder != nsView.currentEditor() {
                    nsView.window?.makeFirstResponder(nsView)
                }
                self.requestFocus = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FixedTextField
        init(_ parent: FixedTextField) { self.parent = parent }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

// MARK: - 主搜索视图
struct SearchBarView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var viewModel: ContentViewModel
    
    @State private var requestFocus: Bool = false
    @State private var textFieldID = UUID()
    
    var body: some View {
        HStack(spacing: 12) {
            FixedTextField(
                text: $viewModel.urlInput,
                placeholder: " 粘贴抖音视频分享链接... ",
                onSubmit: submitAction,
                requestFocus: $requestFocus
            )
            .id(textFieldID)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(AppTheme.cardColor(for: colorScheme))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.borderColor(for: colorScheme), lineWidth: 1)
            )

            Button(action: submitAction) {
                HStack {
                    if viewModel.isFetching {
                        ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: viewModel.shouldShowClearButton ? "xmark.circle.fill" : "link.circle.fill")
                    }
                    Text(viewModel.isFetching ? "解析中" : (viewModel.shouldShowClearButton ? "清除" : "获取"))
                }
                .font(.system(size: 13, weight: .bold))
                .frame(width: 90, height: 42)
                .background((viewModel.shouldShowClearButton || viewModel.isFetching) ? Color.gray.opacity(0.2) : AppTheme.accentBlue)
                .foregroundColor((viewModel.shouldShowClearButton || viewModel.isFetching) ? .primary : .white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isFetching)
        }
        .padding(.horizontal, 60)
    }
    
    private func submitAction() {
        viewModel.handleFetchAction(resetFocus: {
            // 通过重建 ID 和底层聚焦请求，确保“清除”后光标百分百准时出现
            textFieldID = UUID()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                requestFocus = true
            }
        })
    }
}
