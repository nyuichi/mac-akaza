import Cocoa

class GeneralSettingsView: NSView {
    private let punctuationPopUp = NSPopUpButton()
    private let showPredictiveCandidatesCheckbox = NSButton(
        checkboxWithTitle: "推測候補表示",
        target: nil,
        action: nil
    )
    private let modelVersionLabel = NSTextField(labelWithString: "読み込み中...")
    private let modelBuildTimestampLabel = NSTextField(labelWithString: "")
    private let userDictTableView = NSTableView()
    private let addDictButton = NSButton(title: "+ 追加", target: nil, action: nil)
    private let removeDictButton = NSButton(title: "- 削除", target: nil, action: nil)

    // ダウンロード可能辞書の行ごとのステータス更新クロージャ
    private var dictRowUpdaters: [() -> Void] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadModelInfo()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        loadModelInfo()
    }

    private func setupUI() {
        let punctuationLabel = NSTextField(labelWithString: "句読点スタイル:")
        punctuationLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(punctuationLabel)

        punctuationPopUp.translatesAutoresizingMaskIntoConstraints = false
        punctuationPopUp.addItems(withTitles: [
            "「、。」（標準）",
            "「，．」（カンマ・ピリオド）"
        ])
        punctuationPopUp.selectItem(at: Settings.shared.punctuationStyle.rawValue)
        punctuationPopUp.target = self
        punctuationPopUp.action = #selector(punctuationStyleChanged(_:))
        addSubview(punctuationPopUp)

        showPredictiveCandidatesCheckbox.translatesAutoresizingMaskIntoConstraints = false
        showPredictiveCandidatesCheckbox.state = Settings.shared.showPredictiveCandidates ? .on : .off
        showPredictiveCandidatesCheckbox.target = self
        showPredictiveCandidatesCheckbox.action = #selector(showPredictiveCandidatesChanged(_:))
        addSubview(showPredictiveCandidatesCheckbox)

        NSLayoutConstraint.activate([
            punctuationLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            punctuationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            punctuationPopUp.centerYAnchor.constraint(equalTo: punctuationLabel.centerYAnchor),
            punctuationPopUp.leadingAnchor.constraint(equalTo: punctuationLabel.trailingAnchor, constant: 8),
            punctuationPopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),

            showPredictiveCandidatesCheckbox.topAnchor.constraint(
                equalTo: punctuationLabel.bottomAnchor, constant: 12),
            showPredictiveCandidatesCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            showPredictiveCandidatesCheckbox.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])

        let lastModelView = setupModelInfoViews(below: showPredictiveCandidatesCheckbox)
        setupDictViews(below: lastModelView)
    }

    @discardableResult
    private func setupModelInfoViews(below aboveView: NSView) -> NSView {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        let modelSectionLabel = NSTextField(labelWithString: "モデル情報")
        modelSectionLabel.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        modelSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modelSectionLabel)

        let modelVersionKeyLabel = NSTextField(labelWithString: "バージョン:")
        modelVersionKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modelVersionKeyLabel)

        modelVersionLabel.translatesAutoresizingMaskIntoConstraints = false
        modelVersionLabel.isSelectable = true
        addSubview(modelVersionLabel)

        let modelBuildKeyLabel = NSTextField(labelWithString: "ビルド日時:")
        modelBuildKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(modelBuildKeyLabel)

        modelBuildTimestampLabel.translatesAutoresizingMaskIntoConstraints = false
        modelBuildTimestampLabel.isSelectable = true
        addSubview(modelBuildTimestampLabel)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 16),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            modelSectionLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            modelSectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            modelVersionKeyLabel.topAnchor.constraint(equalTo: modelSectionLabel.bottomAnchor, constant: 8),
            modelVersionKeyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            modelVersionKeyLabel.widthAnchor.constraint(equalToConstant: 80),

            modelVersionLabel.centerYAnchor.constraint(equalTo: modelVersionKeyLabel.centerYAnchor),
            modelVersionLabel.leadingAnchor.constraint(equalTo: modelVersionKeyLabel.trailingAnchor, constant: 8),

            modelBuildKeyLabel.topAnchor.constraint(equalTo: modelVersionKeyLabel.bottomAnchor, constant: 6),
            modelBuildKeyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            modelBuildKeyLabel.widthAnchor.constraint(equalToConstant: 80),

            modelBuildTimestampLabel.centerYAnchor.constraint(equalTo: modelBuildKeyLabel.centerYAnchor),
            modelBuildTimestampLabel.leadingAnchor.constraint(
                equalTo: modelBuildKeyLabel.trailingAnchor, constant: 8)
        ])

        return modelBuildKeyLabel
    }

    private func setupDictViews(below aboveView: NSView) {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        let dictSectionLabel = NSTextField(labelWithString: "辞書")
        dictSectionLabel.font = NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        dictSectionLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dictSectionLabel)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 16),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            dictSectionLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 8),
            dictSectionLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
        ])

        let lastSystemView = setupSystemDictSection(below: dictSectionLabel)
        setupUserDictSection(below: lastSystemView)
    }

    private func setupSystemDictSection(below aboveView: NSView) -> NSView {
        let sysLabel = NSTextField(labelWithString: "システム辞書")
        sysLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        sysLabel.textColor = .secondaryLabelColor
        sysLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sysLabel)

        NSLayoutConstraint.activate([
            sysLabel.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 8),
            sysLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
        ])

        var lastView: NSView = sysLabel
        dictRowUpdaters = []

        for config in predefinedDownloadableDicts {
            let (rowView, update) = makeDownloadableDictRow(config: config)
            dictRowUpdaters.append(update)

            NSLayoutConstraint.activate([
                rowView.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 6),
                rowView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
                rowView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
            ])
            lastView = rowView
        }

        return lastView
    }

    private func makeDownloadableDictRow(
        config: DownloadableDictConfig
    ) -> (view: NSView, update: () -> Void) {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        let nameLabel = NSTextField(labelWithString: config.displayName)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)

        let statusLabel = NSTextField(labelWithString: "確認中...")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(statusLabel)

        let actionButton = NSButton(title: "", target: nil, action: nil)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(actionButton)

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            nameLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            nameLabel.widthAnchor.constraint(equalToConstant: 160),

            statusLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 12),
            statusLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            actionButton.leadingAnchor.constraint(equalTo: statusLabel.trailingAnchor, constant: 8),
            actionButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            actionButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            container.heightAnchor.constraint(equalToConstant: 24)
        ])

        let updateStatus = { [weak statusLabel, weak actionButton] in
            guard let statusLabel = statusLabel, let actionButton = actionButton else { return }
            let downloaded = akazaServerProcess.isDictDownloaded(config)
            if downloaded {
                statusLabel.stringValue = "読み込み済み"
                statusLabel.textColor = .systemGreen
                actionButton.title = "削除"
                actionButton.action = #selector(GeneralSettingsView.deleteDictButtonClicked(_:))
            } else {
                statusLabel.stringValue = "未ダウンロード"
                statusLabel.textColor = .systemOrange
                actionButton.title = "ダウンロード"
                actionButton.action = #selector(GeneralSettingsView.downloadDictButtonClicked(_:))
            }
        }

        actionButton.target = self
        actionButton.tag = predefinedDownloadableDicts.firstIndex(where: { $0.id == config.id }) ?? 0
        updateStatus()

        return (container, updateStatus)
    }

    private func setupUserDictSection(below aboveView: NSView) {
        let userLabel = NSTextField(labelWithString: "ユーザー辞書")
        userLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        userLabel.textColor = .secondaryLabelColor
        userLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(userLabel)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DictPath"))
        column.title = "辞書パス"
        column.resizingMask = .autoresizingMask
        userDictTableView.addTableColumn(column)
        userDictTableView.headerView = nil
        userDictTableView.dataSource = self
        userDictTableView.delegate = self

        let scrollView = NSScrollView()
        scrollView.documentView = userDictTableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        addDictButton.target = self
        addDictButton.action = #selector(addDictButtonClicked(_:))
        addDictButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addDictButton)

        removeDictButton.target = self
        removeDictButton.action = #selector(removeDictButtonClicked(_:))
        removeDictButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(removeDictButton)

        NSLayoutConstraint.activate([
            userLabel.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 12),
            userLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: userLabel.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 100),

            addDictButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            addDictButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            removeDictButton.centerYAnchor.constraint(equalTo: addDictButton.centerYAnchor),
            removeDictButton.leadingAnchor.constraint(equalTo: addDictButton.trailingAnchor, constant: 8)
        ])
    }

}

// MARK: - Actions

extension GeneralSettingsView {
    @objc func downloadDictButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < predefinedDownloadableDicts.count else { return }
        let config = predefinedDownloadableDicts[index]

        sender.isEnabled = false
        akazaServerProcess.downloadDict(config) { _ in
            DispatchQueue.main.async { [weak self] in
                sender.isEnabled = true
                self?.dictRowUpdaters[index]()
                akazaServerProcess.restart()
            }
        }
    }

    @objc func deleteDictButtonClicked(_ sender: NSButton) {
        let index = sender.tag
        guard index < predefinedDownloadableDicts.count else { return }
        let config = predefinedDownloadableDicts[index]

        do {
            try akazaServerProcess.deleteDict(config)
        } catch {
            NSLog("AkazaIME: failed to delete \(config.fileName): \(error)")
        }
        dictRowUpdaters[index]()
        akazaServerProcess.restart()
    }

    @objc func addDictButtonClicked(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            DispatchQueue.main.async {
                self?.selectEncoding(for: url)
            }
        }
    }

    func selectEncoding(for url: URL) {
        let alert = NSAlert()
        alert.messageText = "エンコーディングを選択"
        alert.informativeText = url.lastPathComponent
        alert.addButton(withTitle: "追加")
        alert.addButton(withTitle: "キャンセル")

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 150, height: 24))
        popup.addItems(withTitles: ["UTF-8", "EUC-JP"])
        alert.accessoryView = popup

        if alert.runModal() == .alertFirstButtonReturn {
            let encoding = popup.indexOfSelectedItem == 1 ? "eucjp" : "utf8"
            Settings.shared.additionalDictPaths.append("\(url.path):\(encoding)")
            userDictTableView.reloadData()
            akazaServerProcess.restart()
        }
    }

    @objc func removeDictButtonClicked(_ sender: NSButton) {
        let row = userDictTableView.selectedRow
        guard row >= 0 else { return }
        Settings.shared.additionalDictPaths.remove(at: row)
        userDictTableView.reloadData()
        akazaServerProcess.restart()
    }

    @objc func punctuationStyleChanged(_ sender: NSPopUpButton) {
        if let style = PunctuationStyle(rawValue: sender.indexOfSelectedItem) {
            Settings.shared.punctuationStyle = style
        }
    }

    @objc func showPredictiveCandidatesChanged(_ sender: NSButton) {
        Settings.shared.showPredictiveCandidates = sender.state == .on
    }

    func loadModelInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let info = akazaClient.modelInfoSync()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.modelVersionLabel.stringValue = info?.akazaDataVersion ?? "(不明)"
                self.modelBuildTimestampLabel.stringValue = info?.buildTimestamp ?? "(不明)"
            }
        }
    }
}

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
