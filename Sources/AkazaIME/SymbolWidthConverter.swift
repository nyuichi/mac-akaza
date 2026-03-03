import Foundation

enum SymbolWidthConverter {
    private static let fullWidthOffset: UInt32 = 0xFEE0

    static func normalize(_ text: String, style: SymbolStyle) -> String {
        var normalized = String.UnicodeScalarView()
        normalized.reserveCapacity(text.unicodeScalars.count)

        for scalar in text.unicodeScalars {
            switch style {
            case .fullWidth:
                normalized.append(convertToFullWidthIfNeeded(scalar))
            case .halfWidth:
                normalized.append(convertToHalfWidthIfNeeded(scalar))
            }
        }

        return String(normalized)
    }

    private static func convertToFullWidthIfNeeded(_ scalar: UnicodeScalar) -> UnicodeScalar {
        let value = scalar.value
        guard isASCIISymbol(value) else { return scalar }
        return UnicodeScalar(value + fullWidthOffset) ?? scalar
    }

    private static func convertToHalfWidthIfNeeded(_ scalar: UnicodeScalar) -> UnicodeScalar {
        let value = scalar.value
        guard (0xFF01...0xFF5E).contains(value) else { return scalar }

        let asciiValue = value - fullWidthOffset
        guard isASCIISymbol(asciiValue) else { return scalar }
        return UnicodeScalar(asciiValue) ?? scalar
    }

    private static func isASCIISymbol(_ value: UInt32) -> Bool {
        guard (0x21...0x7E).contains(value) else { return false }
        if (0x30...0x39).contains(value) { return false } // 0-9
        if (0x41...0x5A).contains(value) { return false } // A-Z
        if (0x61...0x7A).contains(value) { return false } // a-z
        return true
    }
}
