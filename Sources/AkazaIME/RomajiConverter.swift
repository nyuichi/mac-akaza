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

    var pendingRomaji: String { buffer }

    init(tableName: String = "default") {
        loadMapping(tableName: tableName)
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

    func feed(_ character: Character) -> [ConversionResult] {
        var results: [ConversionResult] = []
        buffer.append(character)

        while !buffer.isEmpty {
            let exact = hasExactMatch(buffer)
            let prefix = isPrefix(buffer)

            if exact && !prefix {
                // 完全一致かつプレフィックスでない → 変換確定
                results.append(.converted(mapping[buffer]!))
                buffer = ""
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
            if !backtrack(&results) {
                // バックトラックでもマッチしない → 先頭文字を passthrough
                let first = buffer.removeFirst()
                results.append(.passthrough(first))
            }
        }

        return results
    }

    private func backtrack(_ results: inout [ConversionResult]) -> Bool {
        // 先頭から最長一致を探す
        for length in stride(from: buffer.count - 1, through: 1, by: -1) {
            let candidate = String(buffer.prefix(length))
            if let converted = mapping[candidate] {
                results.append(.converted(converted))
                buffer = String(buffer.dropFirst(length))
                return true
            }
        }
        return false
    }

    func backspace() -> Bool {
        guard !buffer.isEmpty else { return false }
        buffer.removeLast()
        return true
    }

    func flush() -> String? {
        guard !buffer.isEmpty else { return nil }
        // "n" → "ん"
        if buffer == "n" {
            buffer = ""
            return "ん"
        }
        // それ以外はそのまま返す
        let remaining = buffer
        buffer = ""
        return remaining
    }

    func clear() {
        buffer = ""
    }

    func setBuffer(_ newBuffer: String) {
        buffer = newBuffer
    }
}

// MARK: - JSON形式

private struct RomKanConfig: Decodable {
    let name: String?
    let description: String?
    let extends: String?
    let mapping: [String: String?]?
}
