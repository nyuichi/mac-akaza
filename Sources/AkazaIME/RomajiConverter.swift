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

    init(tableName: String = "default") {
        loadMapping(tableName: tableName)
    }

    init(mapping: [String: String]) {
        self.mapping = mapping
        buildPrefixes()
    }

    func reload(tableName: String) {
        mapping = [:]
        prefixes = []
        buffer = ""
        loadMapping(tableName: tableName)
    }

    private func loadMapping(tableName: String) {
        guard let resolved = resolveMapping(tableName: tableName) else {
            NSLog("AkazaIME: Failed to load romkan table: \(tableName)")
            return
        }
        mapping = resolved
        buildPrefixes()
        NSLog("AkazaIME: Loaded \(mapping.count) romaji mappings from \(tableName)")
    }

    // 継承チェーンを再帰的に解決して最終的なマッピングを返す
    private func resolveMapping(tableName: String) -> [String: String]? {
        guard let data = loadFile(tableName: tableName) else { return nil }

        // 新形式 JSON: {"name": "...", "mapping": {...}, "extends": "..."}
        if let config = try? JSONDecoder().decode(RomKanConfig.self, from: data) {
            var base: [String: String] = [:]
            if let parentName = config.extends {
                base = resolveMapping(tableName: parentName) ?? [:]
            }
            if let mappingOverrides = config.mapping {
                for (key, value) in mappingOverrides {
                    if let value = value {
                        base[key] = value
                    } else {
                        base.removeValue(forKey: key)
                    }
                }
            }
            return base
        }

        // 旧形式 JSON: {"key": "value", ...}
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            return dict
        }

        NSLog("AkazaIME: romkan/\(tableName).json is not a valid mapping")
        return nil
    }

    private func loadFile(tableName: String) -> Data? {
        if let resourcePath = Bundle.main.resourcePath {
            let path = (resourcePath as NSString).appendingPathComponent("romkan/\(tableName).json")
            if FileManager.default.fileExists(atPath: path) {
                return FileManager.default.contents(atPath: path)
            }
        }
        return nil
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

// MARK: - JSON形式

private struct RomKanConfig: Decodable {
    let name: String?
    let description: String?
    let extends: String?
    let mapping: [String: String?]?
}
