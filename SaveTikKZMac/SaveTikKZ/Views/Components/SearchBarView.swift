//
//  SearchBarView.swift
//  SaveTikKZ
//
//  Created by Knight Zhu on 3/12/26.
//

import SwiftUI
import AppKit
import Combine

// MARK: - 基础 AppKit 拦截器
class NativeBehaviorTextField: NSTextField {
    // 拦截全选请求，避免任何情况下输入框文字被自动全选
    override func selectText(_ sender: Any?) {
        // 什么都不做，禁用默认全选行为
    }
}

// MARK: - NSTextField 包装器
struct FixedTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void

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

            // 如果输入框当前有焦点且新文本非空，取消全选并把光标移到末尾
            // 避免 first responder 状态下外部设置 stringValue 触发默认全选
            if !text.isEmpty, let editor = nsView.currentEditor(),
               nsView.window?.firstResponder === editor {
                editor.selectedRange = NSRange(location: text.count, length: 0)
            }

            // 文本被外部清空且有焦点时，resign first responder 避免 placeholder 偏移
            if text.isEmpty, nsView.window?.firstResponder === nsView.currentEditor() {
                DispatchQueue.main.async {
                    nsView.window?.makeFirstResponder(nil)
                }
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

                // 用户手动删除至空时，resign first responder 避免 placeholder 偏移
                if textField.stringValue.isEmpty {
                    DispatchQueue.main.async {
                        textField.window?.makeFirstResponder(nil)
                    }
                }
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
    @Environment(\.colorScheme) var systemColorScheme
    var colorSchemeOverride: ColorScheme? = nil
    @ObservedObject var viewModel: ContentViewModel

    private var colorScheme: ColorScheme {
        colorSchemeOverride ?? systemColorScheme
    }

    @State private var textFieldID = UUID()

    var body: some View {
        HStack(spacing: 12) {
            FixedTextField(
                text: $viewModel.urlInput,
                placeholder: " 粘贴抖音分享链接... ",
                onSubmit: submitAction
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

            let isSecondaryStyle = viewModel.shouldShowClearButton || viewModel.isFetching
            let btnForeground: Color = isSecondaryStyle
                ? (colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.85))
                : Color.white
            let btnBackground: Color = isSecondaryStyle
                ? (colorScheme == .dark ? Color(red: 0.22, green: 0.22, blue: 0.22) : Color(red: 0.90, green: 0.90, blue: 0.92))
                : AppTheme.accentBlue

            Button(action: submitAction) {
                HStack(spacing: 6) {
                    if viewModel.isFetching {
                        ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                    } else {
                        btnForeground
                            .frame(width: 14, height: 14)
                            .mask(
                                Image(systemName: viewModel.shouldShowClearButton ? "xmark.circle.fill" : "link.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                            )
                    }
                    Text(viewModel.isFetching ? "解析中" : (viewModel.shouldShowClearButton ? "清除" : "获取"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(btnForeground)
                }
                .frame(width: 90, height: 42)
                .background(btnBackground)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isFetching)
        }
        .padding(.horizontal, 60)
        .animation(.easeInOut(duration: 0.15), value: colorScheme)
    }

    private func submitAction() {
        viewModel.handleFetchAction(resetFocus: {
            // 清除时重建 TextField，解决 placeholder 偏移问题
            // 不请求焦点，所以清除后光标不会自动回到输入框
            textFieldID = UUID()
        })
    }
}
