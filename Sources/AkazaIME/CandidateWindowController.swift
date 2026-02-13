import Cocoa

class CandidateWindowController {
    private let panel: NSPanel
    private let stackView: NSStackView
    private let maxDisplayCount = 9
    private var candidateLabels: [NSTextField] = []

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.ignoresMouseEvents = true

        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        panel.contentView?.addSubview(stackView)
        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
                stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
    }

    func show(candidates: [ConvertCandidate], selectedIndex: Int, cursorRect: NSRect) {
        for label in candidateLabels {
            stackView.removeArrangedSubview(label)
            label.removeFromSuperview()
        }
        candidateLabels.removeAll()

        let displayCount = min(candidates.count, maxDisplayCount)
        guard displayCount > 0 else {
            hide()
            return
        }

        for idx in 0..<displayCount {
            let candidate = candidates[idx]
            let label = NSTextField(labelWithString: "\(idx + 1). \(candidate.surface)")
            label.font = NSFont.systemFont(ofSize: 14)
            label.translatesAutoresizingMaskIntoConstraints = false

            if idx == selectedIndex {
                label.backgroundColor = NSColor.selectedContentBackgroundColor
                label.textColor = NSColor.white
                label.drawsBackground = true
            } else {
                label.backgroundColor = .clear
                label.textColor = NSColor.labelColor
                label.drawsBackground = false
            }

            stackView.addArrangedSubview(label)
            candidateLabels.append(label)
        }

        stackView.layoutSubtreeIfNeeded()
        let contentSize = stackView.fittingSize
        let panelWidth = max(contentSize.width + 16, 120)
        let panelHeight = contentSize.height + 8

        var origin = NSPoint(x: cursorRect.origin.x, y: cursorRect.origin.y - panelHeight)

        // cursorRect が zero の場合のフォールバック
        if cursorRect == .zero {
            origin = NSPoint(x: 100, y: 100)
        }

        // 画面下端からはみ出す場合はカーソルの上に表示
        if let screen = NSScreen.main {
            if origin.y < screen.visibleFrame.origin.y {
                origin.y = cursorRect.origin.y + cursorRect.size.height
            }
        }

        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: panelWidth, height: panelHeight), display: true)
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }
}
