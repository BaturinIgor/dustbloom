import Foundation

/// In-game translations. Russian text in the code is the key; each language is a
/// flat JSON file bloom_i18n_<lang>.json {"русский текст": "translation"}.
/// %@ marks a value, filled in order. Unknown languages fall back to English.
enum Loc {
    static let supported = ["en", "de", "fr", "es", "it", "pt", "nl", "pl", "tr", "uk",
                            "ja", "ko", "zh-Hans", "zh-Hant", "ar", "th", "vi", "id", "sv"]

    static let lang: String = {
        if let forced = UserDefaults.standard.string(forKey: "bloomLang") { return forced }
        for pref in Locale.preferredLanguages {
            let l = Locale(identifier: pref).language
            let code = l.languageCode?.identifier ?? "en"
            if code == "ru" { return "ru" }
            if code == "zh" {
                let s = l.script?.identifier
                let r = l.region?.identifier
                return (s == "Hant" || r == "TW" || r == "HK" || r == "MO") ? "zh-Hant" : "zh-Hans"
            }
            if supported.contains(code) { return code }
        }
        return "en"
    }()

    static let table: [String: String] = {
        guard lang != "ru",
              let url = Bundle.main.url(forResource: "bloom_i18n_\(lang)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let t = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return t
    }()

    static var isRTL: Bool { lang == "ar" }
}

/// Translate a Russian source string; %@ placeholders take `args` in order.
func tr(_ key: String, _ args: Any...) -> String {
    var s = Loc.table[key] ?? key
    for a in args {
        guard let r = s.range(of: "%@") else { break }
        s.replaceSubrange(r, with: "\(a)")
    }
    return s
}
