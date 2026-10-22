import SwiftUI

/// Inline text field that toggles between readable label and editable field on tap.
public struct InlineEditField: View {
    @Binding public var text: String
    public var placeholder: String
    public var onCommit: () -> Void

    @State private var isEditing: Bool = false
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Title",
        onCommit: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onCommit = onCommit
    }

    public var body: some View {
        Group {
            if isEditing {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        isEditing = false
                        onCommit()
                    }
                    .onChange(of: isFocused) { focused in
                        if !focused {
                            isEditing = false
                            onCommit()
                        }
                    }
            } else {
                Text(text.isEmpty ? placeholder : text)
                    .foregroundColor(text.isEmpty ? .secondary : .primary)
                    .lineLimit(2)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        isEditing = true
                        isFocused = true
                    }
            }
        }
    }
}
