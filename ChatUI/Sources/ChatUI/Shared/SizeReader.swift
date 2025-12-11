import SwiftUI

/// Preference key for text height measurement
public struct TextHeightKey: PreferenceKey {
    public static var defaultValue: CGFloat = 38
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// View that measures text height using GeometryReader (only allowed in SizeReader.swift)
public struct MeasuredText: View {
    public let text: String
    public let width: CGFloat?
    public let font: Font
    public let padding: EdgeInsets

    public init(
        text: String,
        width: CGFloat? = nil,
        font: Font,
        padding: EdgeInsets
    ) {
        self.text = text
        self.width = width
        self.font = font
        self.padding = padding
    }

    public var body: some View {
        Text(text)
            .font(font)
            .padding(padding)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: TextHeightKey.self, value: proxy.size.height)
                }
            )
    }
}
