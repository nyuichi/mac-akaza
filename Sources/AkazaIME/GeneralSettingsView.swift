import Cocoa

class GeneralSettingsView: NSView {
    private let punctuationPopUp = NSPopUpButton()
    private let modelVersionLabel = NSTextField(labelWithString: "読み込み中...")
    private let modelBuildTimestampLabel = NSTextField(labelWithString: "")
    private let skkJisyoStatusLabel = NSTextField(labelWithString: "確認中...")
    private let skkJisyoDownloadButton = NSButton(title: "ダウンロード", target: nil, action: nil)
    private let userDictTableView = NSTableView()
    private let addDictButton = NSButton(title: "+ 追加", target: nil, action: nil)
    private let removeDictButton = NSButton(title: "- 削除", target: nil, action: nil)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupUI()
        loadModelInfo()
        updateSKKJisyoStatus()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        loadModelInfo()
        updateSKKJisyoStatus()
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

        NSLayoutConstraint.activate([
            punctuationLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            punctuationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            punctuationPopUp.centerYAnchor.constraint(equalTo: punctuationLabel.centerYAnchor),
            punctuationPopUp.leadingAnchor.constraint(equalTo: punctuationLabel.trailingAnchor, constant: 8),
            punctuationPopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])

        let lastModelView = setupModelInfoViews(below: punctuationLabel)
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

        let skkLabel = NSTextField(labelWithString: "SKK-JISYO.L")
        skkLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skkLabel)

        skkJisyoStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skkJisyoStatusLabel)

        skkJisyoDownloadButton.translatesAutoresizingMaskIntoConstraints = false
        skkJisyoDownloadButton.target = self
        skkJisyoDownloadButton.action = #selector(downloadSKKJisyoButtonClicked(_:))
        addSubview(skkJisyoDownloadButton)

        NSLayoutConstraint.activate([
            sysLabel.topAnchor.constraint(equalTo: aboveView.bottomAnchor, constant: 8),
            sysLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            skkLabel.topAnchor.constraint(equalTo: sysLabel.bottomAnchor, constant: 6),
            skkLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            skkJisyoStatusLabel.centerYAnchor.constraint(equalTo: skkLabel.centerYAnchor),
            skkJisyoStatusLabel.leadingAnchor.constraint(equalTo: skkLabel.trailingAnchor, constant: 12),

            skkJisyoDownloadButton.centerYAnchor.constraint(equalTo: skkLabel.centerYAnchor),
            skkJisyoDownloadButton.leadingAnchor.constraint(
                equalTo: skkJisyoStatusLabel.trailingAnchor, constant: 8)
        ])

        return skkLabel
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

    // MARK: - Private actions

    fileprivate func updateSKKJisyoStatus() {
        let exists = akazaServerProcess.skkJisyoLPath()
            .map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        if exists {
            skkJisyoStatusLabel.stringValue = "読み込み済み"
            skkJisyoStatusLabel.textColor = .systemGreen
        } else {
            skkJisyoStatusLabel.stringValue = "未ダウンロード"
            skkJisyoStatusLabel.textColor = .systemOrange
        }
    }

    @objc private func downloadSKKJisyoButtonClicked(_ sender: NSButton) {
        sender.isEnabled = false
        akazaServerProcess.downloadSKKDictIfNeeded {
            DispatchQueue.main.async { [weak self] in
                sender.isEnabled = true
                self?.updateSKKJisyoStatus()
                akazaServerProcess.restart()
            }
        }
    }

    @objc private func addDictButtonClicked(_ sender: NSButton) {
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

    fileprivate func selectEncoding(for url: URL) {
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

    @objc private func removeDictButtonClicked(_ sender: NSButton) {
        let row = userDictTableView.selectedRow
        guard row >= 0 else { return }
        Settings.shared.additionalDictPaths.remove(at: row)
        userDictTableView.reloadData()
        akazaServerProcess.restart()
    }

    @objc private func punctuationStyleChanged(_ sender: NSPopUpButton) {
        if let style = PunctuationStyle(rawValue: sender.indexOfSelectedItem) {
            Settings.shared.punctuationStyle = style
        }
    }

    // MARK: - Private helpers

    private func loadModelInfo() {
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
