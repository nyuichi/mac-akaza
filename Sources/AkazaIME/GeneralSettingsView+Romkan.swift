import Cocoa

// MARK: - NSTableViewDataSource / NSTableViewDelegate

extension GeneralSettingsView: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        Settings.shared.additionalDictPaths.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        let path = Settings.shared.additionalDictPaths[row]
        if let colonRange = path.range(of: ":", options: .backwards) {
            let filePath = String(path[path.startIndex..<colonRange.lowerBound])
            let encoding = String(path[colonRange.upperBound...])
            let encodingLabel = encoding == "eucjp" ? "EUC-JP" : "UTF-8"
            return "\(filePath) (\(encodingLabel))"
        }
        return path
    }
}

// MARK: - ローマ字テーブル選択

let romkanTableOptions: [(id: String, displayName: String)] = [
    ("default", "ローマ字（標準）"),
    ("atok", "ATOK"),
    ("azik", "AZIK"),
    ("kana", "かな入力"),
    ("tut", "TUT-Code")
]

extension GeneralSettingsView {
    /// 入力方式ラベルと popup を設定し、ラベルを返す
    func setupRomkanControls() -> NSTextField {
        let label = NSTextField(labelWithString: "入力方式:")
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        romkanPopUp.translatesAutoresizingMaskIntoConstraints = false
        let currentTable = Settings.shared.romkanTable
        let selectedIndex = romkanTableOptions.firstIndex(where: { $0.id == currentTable }) ?? 0
        romkanPopUp.addItems(withTitles: romkanTableOptions.map { $0.displayName })
        romkanPopUp.selectItem(at: selectedIndex)
        romkanPopUp.target = self
        romkanPopUp.action = #selector(romkanTableChanged(_:))
        addSubview(romkanPopUp)

        return label
    }

    @objc func romkanTableChanged(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard index >= 0 && index < romkanTableOptions.count else { return }
        Settings.shared.romkanTable = romkanTableOptions[index].id
        NotificationCenter.default.post(name: .romkanTableDidChange, object: nil)
    }
}
