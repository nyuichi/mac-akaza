import Foundation

enum PunctuationStyle: Int {
    case kutouten = 0    // 、。
    case commaPeriod = 1 // ，．
}

enum NumberSymbolStyle: Int {
    case fullWidth = 0
    case halfWidth = 1
}

class Settings {
    static let shared = Settings()

    private let defaults: UserDefaults

    private enum DefaultsName {
        static let numberSymbolStyle = "numberSymbolStyle"
        static let showPredictiveCandidates = "showPredictiveCandidates"
        static let shiftKatakanaInputEnabled = "shiftKatakanaInputEnabled"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [DefaultsName.showPredictiveCandidates: true])
    }

    var punctuationStyle: PunctuationStyle {
        get { PunctuationStyle(rawValue: defaults.integer(forKey: "punctuationStyle")) ?? .kutouten }
        set { defaults.set(newValue.rawValue, forKey: "punctuationStyle") }
    }

    var numberSymbolStyle: NumberSymbolStyle {
        get {
            NumberSymbolStyle(rawValue: defaults.integer(forKey: DefaultsName.numberSymbolStyle))
                ?? .fullWidth
        }
        set { defaults.set(newValue.rawValue, forKey: DefaultsName.numberSymbolStyle) }
    }

    var additionalDictPaths: [String] {
        get { defaults.stringArray(forKey: "additionalDictPaths") ?? [] }
        set { defaults.set(newValue, forKey: "additionalDictPaths") }
    }

    var showPredictiveCandidates: Bool {
        get { defaults.bool(forKey: DefaultsName.showPredictiveCandidates) }
        set { defaults.set(newValue, forKey: DefaultsName.showPredictiveCandidates) }
    }

    var shiftKatakanaInputEnabled: Bool {
        get { defaults.bool(forKey: DefaultsName.shiftKatakanaInputEnabled) }
        set { defaults.set(newValue, forKey: DefaultsName.shiftKatakanaInputEnabled) }
    }

    // サジェスト候補の最大パス数。k=9 は速度が遅いため k=5 をデフォルトとする (2026-02-26)
    // defaults write com.github.tokuhirom.inputmethod.Japanese.Akaza suggestMaxPaths -int 5
    var suggestMaxPaths: Int {
        get {
            let value = defaults.integer(forKey: "suggestMaxPaths")
            if value <= 0 { return 5 }
            return min(value, 20)
        }
        set { defaults.set(newValue, forKey: "suggestMaxPaths") }
    }
}
