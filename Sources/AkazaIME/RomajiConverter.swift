import Foundation

enum ConversionResult {
    case pending(String)
    case converted(String)
    case passthrough(Character)
}

class RomajiConverter {
    private var mapping: [String: String] = [:]
    private var prefixes: Set<String> = []
    private var buffer: String = ""
    private var bufferShiftStates: [Bool] = []

    var pendingRomaji: String { buffer }
    var pendingShiftStates: [Bool] { bufferShiftStates }

    init(mapping: [String: String]? = nil) {
        if let mapping {
            self.mapping = mapping
            buildPrefixes()
        } else {
            loadMapping()
        }
    }

    private func loadMapping() {
        guard let path = findMappingFile() else {
            NSLog("AkazaIME: romkan/default.json not found")
            return
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            NSLog("AkazaIME: Failed to read romkan/default.json")
            return
        }
        parseJSON(data)
        buildPrefixes()
    }

    private func findMappingFile() -> String? {
        if let bundle = Bundle.main.resourcePath {
            let path = (bundle as NSString).appendingPathComponent("romkan/default.json")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func parseJSON(_ data: Data) {
        do {
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                NSLog("AkazaIME: romkan/default.json is not a valid mapping")
                return
            }
            mapping = dict
        } catch {
            NSLog("AkazaIME: Failed to parse romkan/default.json: \(error)")
        }
        NSLog("AkazaIME: Loaded \(mapping.count) romaji mappings")
    }

    private func buildPrefixes() {
        prefixes.removeAll()
        for key in mapping.keys {
            for length in 1..<key.count {
                let prefix = String(key.prefix(length))
                prefixes.insert(prefix)
            }
        }
    }

    private func hasExactMatch(_ key: String) -> Bool {
        mapping[key] != nil
    }

    private func isPrefix(_ key: String) -> Bool {
        prefixes.contains(key)
    }

    func feed(_ character: Character, isShiftPressed: Bool, shiftKatakanaEnabled: Bool) -> [ConversionResult] {
        var results: [ConversionResult] = []
        buffer.append(character)
        bufferShiftStates.append(isShiftPressed)

        while !buffer.isEmpty {
            let lookupBuffer = lowercasedASCII(buffer)
            let exact = hasExactMatch(lookupBuffer)
            let prefix = isPrefix(lookupBuffer)

            if exact && !prefix {
                // 完全一致かつプレフィックスでない → 変換確定
                let converted = mapping[lookupBuffer]!
                results.append(.converted(
                    applyShiftKatakanaIfNeeded(
                        to: converted,
                        consumedCount: lookupBuffer.count,
                        shiftKatakanaEnabled: shiftKatakanaEnabled
                    )
                ))
                clear()
                return results
            }

            if prefix {
                // より長いキーのプレフィクスである → 待機
                results.append(.pending(buffer))
                return results
            }

            if exact && prefix {
                // 完全一致かつプレフィックスでもある → 待機（次の文字で判断）
                results.append(.pending(buffer))
                return results
            }

            // 完全一致でもプレフィックスでもない → バックトラック
            if !backtrack(&results, shiftKatakanaEnabled: shiftKatakanaEnabled) {
                // バックトラックでもマッチしない → 先頭文字を passthrough
                let first = buffer.removeFirst()
                bufferShiftStates.removeFirst()
                results.append(.passthrough(first))
            }
        }

        return results
    }

    private func backtrack(_ results: inout [ConversionResult], shiftKatakanaEnabled: Bool) -> Bool {
        // 先頭から最長一致を探す
        for length in stride(from: buffer.count - 1, through: 1, by: -1) {
            let candidate = lowercasedASCII(String(buffer.prefix(length)))
            if let converted = mapping[candidate] {
                results.append(.converted(
                    applyShiftKatakanaIfNeeded(
                        to: converted,
                        consumedCount: length,
                        shiftKatakanaEnabled: shiftKatakanaEnabled
                    )
                ))
                buffer = String(buffer.dropFirst(length))
                bufferShiftStates.removeFirst(length)
                return true
            }
        }
        return false
    }

    private func applyShiftKatakanaIfNeeded(to text: String, consumedCount: Int, shiftKatakanaEnabled: Bool) -> String {
        guard shiftKatakanaEnabled else { return text }
        guard consumedCount > 0 else { return text }
        guard bufferShiftStates.prefix(consumedCount).allSatisfy({ $0 }) else { return text }
        return text.applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
    }

    private func lowercasedASCII(_ text: String) -> String {
        String(text.map(lowercasedASCII))
    }

    private func lowercasedASCII(_ character: Character) -> Character {
        guard let ascii = character.asciiValue, (65...90).contains(ascii) else {
            return character
        }
        return Character(UnicodeScalar(ascii + 32))
    }

    func backspace() -> Bool {
        guard !buffer.isEmpty else { return false }
        buffer.removeLast()
        bufferShiftStates.removeLast()
        return true
    }

    func flush(shiftKatakanaEnabled: Bool) -> String? {
        guard !buffer.isEmpty else { return nil }
        let lookupBuffer = lowercasedASCII(buffer)

        // "n" → "ん"
        if lookupBuffer == "n" {
            let converted = applyShiftKatakanaIfNeeded(
                to: "ん",
                consumedCount: 1,
                shiftKatakanaEnabled: shiftKatakanaEnabled
            )
            clear()
            return converted
        }
        // それ以外はそのまま返す
        let remaining = buffer
        clear()
        return remaining
    }

    func clear() {
        buffer = ""
        bufferShiftStates = []
    }

    func setState(buffer newBuffer: String, shiftStates: [Bool]) {
        buffer = newBuffer
        if newBuffer.count == shiftStates.count {
            bufferShiftStates = shiftStates
        } else {
            bufferShiftStates = Array(repeating: false, count: newBuffer.count)
        }
    }

    func setBuffer(_ newBuffer: String) {
        setState(buffer: newBuffer, shiftStates: Array(repeating: false, count: newBuffer.count))
    }
}
