import Foundation

enum PunctuationStyle: Int {
    case kutouten = 0    // 、。
    case commaPeriod = 1 // ，．
}

class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var punctuationStyle: PunctuationStyle {
        get { PunctuationStyle(rawValue: defaults.integer(forKey: "punctuationStyle")) ?? .kutouten }
        set { defaults.set(newValue.rawValue, forKey: "punctuationStyle") }
    }

    var additionalDictPaths: [String] {
        get { defaults.stringArray(forKey: "additionalDictPaths") ?? [] }
        set { defaults.set(newValue, forKey: "additionalDictPaths") }
    }
}
