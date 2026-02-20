import Cocoa

class GeneralSettingsView: NSView {
    private let punctuationPopUp = NSPopUpButton()
    private let modelVersionLabel = NSTextField(labelWithString: "読み込み中...")
    private let modelBuildTimestampLabel = NSTextField(labelWithString: "")

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

        NSLayoutConstraint.activate([
            punctuationLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            punctuationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            punctuationPopUp.centerYAnchor.constraint(equalTo: punctuationLabel.centerYAnchor),
            punctuationPopUp.leadingAnchor.constraint(equalTo: punctuationLabel.trailingAnchor, constant: 8),
            punctuationPopUp.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])

        setupModelInfoViews(below: punctuationLabel)
    }

    private func setupModelInfoViews(below aboveView: NSView) {
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
    }

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

    @objc private func punctuationStyleChanged(_ sender: NSPopUpButton) {
        if let style = PunctuationStyle(rawValue: sender.indexOfSelectedItem) {
            Settings.shared.punctuationStyle = style
        }
    }
}
