import Cocoa

private let skkJisyoLURL = "https://raw.githubusercontent.com/skk-dev/dict/master/SKK-JISYO.L"

class AkazaServerProcess {
    private var process: Process?
    private(set) var stdinPipe: Pipe?
    private(set) var stdoutPipe: Pipe?

    private var restartCount = 0
    private var shouldRestart = true

    var onRestart: (() -> Void)?

    func skkJisyoLPath() -> URL? {
        guard let xdgData = ProcessInfo.processInfo.environment["XDG_DATA_HOME"]
            .map({ URL(fileURLWithPath: $0) })
            ?? Optional(FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/share"))
        else { return nil }
        return xdgData.appendingPathComponent("akaza/SKK-JISYO.L")
    }

    func downloadSKKDictIfNeeded(completion: @escaping () -> Void) {
        guard let dest = skkJisyoLPath() else {
            completion()
            return
        }
        guard !FileManager.default.fileExists(atPath: dest.path) else {
            completion()
            return
        }

        NSLog("AkazaIME: SKK-JISYO.L not found, downloading...")
        let dirURL = dest.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)

        guard let url = URL(string: skkJisyoLURL) else {
            completion()
            return
        }
        URLSession.shared.downloadTask(with: url) { tmpURL, _, error in
            if let error = error {
                NSLog("AkazaIME: failed to download SKK-JISYO.L: \(error)")
                completion()
                return
            }
            guard let tmpURL = tmpURL else {
                completion()
                return
            }
            do {
                try FileManager.default.moveItem(at: tmpURL, to: dest)
                NSLog("AkazaIME: SKK-JISYO.L downloaded to \(dest.path)")
            } catch {
                NSLog("AkazaIME: failed to save SKK-JISYO.L: \(error)")
            }
            completion()
        }.resume()
    }

    func start() {
        let serverPath = Bundle.main.bundlePath + "/Contents/MacOS/akaza-server"
        let modelPath = Bundle.main.bundlePath + "/Contents/Resources/model"

        guard FileManager.default.fileExists(atPath: serverPath) else {
            NSLog("AkazaIME: akaza-server not found at \(serverPath)")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: serverPath)
        proc.arguments = [modelPath] + Settings.shared.additionalDictPaths

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout

        proc.terminationHandler = { [weak self] terminatedProcess in
            guard let self = self else { return }
            let status = terminatedProcess.terminationStatus
            NSLog("AkazaIME: akaza-server terminated with status \(status)")

            guard self.shouldRestart else { return }

            let delay = min(pow(2.0, Double(self.restartCount)), 60.0)
            self.restartCount += 1
            NSLog("AkazaIME: restarting akaza-server in \(delay)s (attempt \(self.restartCount))")

            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.shouldRestart else { return }
                self.start()
                self.onRestart?()
            }
        }

        do {
            try proc.run()
            NSLog("AkazaIME: akaza-server started (pid=\(proc.processIdentifier))")
            self.process = proc
            self.stdinPipe = stdin
            self.stdoutPipe = stdout
            self.restartCount = 0
        } catch {
            NSLog("AkazaIME: failed to start akaza-server: \(error)")
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    func restart() {
        shouldRestart = false
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        shouldRestart = true
        restartCount = 0
        start()
        onRestart?()
    }

    func stop() {
        shouldRestart = false
        guard let proc = process, proc.isRunning else { return }
        NSLog("AkazaIME: stopping akaza-server")
        proc.terminate()
        proc.waitUntilExit()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
    }
}
