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
            NSLog("AkazaIME: romkan/default.yml not found")
            return
        }
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            NSLog("AkazaIME: Failed to read romkan/default.yml")
            return
        }
        parseYAML(content)
        buildPrefixes()
    }

    private func findMappingFile() -> String? {
        // App bundle の Resources から探す
        if let bundle = Bundle.main.resourcePath {
            let path = (bundle as NSString).appendingPathComponent("romkan/default.yml")
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func parseYAML(_ content: String) {
        var inMapping = false
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "mapping:" {
                inMapping = true
                continue
            }
            guard inMapping else { continue }
            // "key": "value" 形式をパース
            guard let match = parseKeyValue(trimmed) else { continue }
            mapping[match.key] = match.value
        }
        NSLog("AkazaIME: Loaded \(mapping.count) romaji mappings")
    }

    private func parseKeyValue(_ line: String) -> (key: String, value: String)? {
        // "key": "value" 形式
        let scanner = Scanner(string: line)
        guard scanner.scanString("\"") != nil else { return nil }
        guard let key = scanner.scanUpToString("\"") else { return nil }
        guard scanner.scanString("\"") != nil else { return nil }
        guard scanner.scanString(":") != nil else { return nil }
        _ = scanner.scanString(" ")
        guard scanner.scanString("\"") != nil else { return nil }
        guard let value = scanner.scanUpToString("\"") else { return nil }
        return (key: key, value: value)
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
}
