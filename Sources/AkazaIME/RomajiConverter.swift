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

    init() {
        loadMapping()
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
