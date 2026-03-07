import Foundation

enum PunctuationStyle: Int {
    case kutouten = 0    // 、。
    case commaPeriod = 1 // ，．
}

class Settings {
    static let shared = Settings()

    private let defaults: UserDefaults

    private enum DefaultsName {
        static let showPredictiveCandidates = "showPredictiveCandidates"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [DefaultsName.showPredictiveCandidates: true])
    }

    var punctuationStyle: PunctuationStyle {
        get { PunctuationStyle(rawValue: defaults.integer(forKey: "punctuationStyle")) ?? .kutouten }
        set { defaults.set(newValue.rawValue, forKey: "punctuationStyle") }
    }

    var additionalDictPaths: [String] {
        get { defaults.stringArray(forKey: "additionalDictPaths") ?? [] }
        set { defaults.set(newValue, forKey: "additionalDictPaths") }
    }

    var showPredictiveCandidates: Bool {
        get { defaults.bool(forKey: DefaultsName.showPredictiveCandidates) }
        set { defaults.set(newValue, forKey: DefaultsName.showPredictiveCandidates) }
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
