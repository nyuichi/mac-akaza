import Foundation

struct DownloadableDictConfig {
    let id: String
    let displayName: String
    let downloadURL: URL
    let fileName: String
    let encoding: String  // "eucjp" or "utf8"
}

let predefinedDownloadableDicts: [DownloadableDictConfig] = [
    DownloadableDictConfig(
        id: "skk-jisyo-l",
        displayName: "SKK-JISYO.L",
        downloadURL: URL(string: "https://raw.githubusercontent.com/skk-dev/dict/master/SKK-JISYO.L")!,
        fileName: "SKK-JISYO.L",
        encoding: "eucjp"
    ),
    DownloadableDictConfig(
        id: "neologd",
        displayName: "SKK-JISYO.neologd",
        downloadURL: URL(
            string: "https://github.com/tokuhirom/skk-jisyo-neologd/releases/download/20200910-a/SKK-JISYO.neologd"
        )!,
        fileName: "SKK-JISYO.neologd",
        encoding: "eucjp"
    )
]
