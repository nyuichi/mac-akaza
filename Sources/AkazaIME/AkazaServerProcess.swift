import Cocoa

class AkazaServerProcess {
    private var process: Process?
    private(set) var stdinPipe: Pipe?
    private(set) var stdoutPipe: Pipe?

    private var restartCount = 0
    private var shouldRestart = true

    var onRestart: (() -> Void)?

    func start() {
        let serverPath = Bundle.main.bundlePath + "/Contents/MacOS/akaza-server"
        let modelPath = Bundle.main.bundlePath + "/Contents/Resources/model"

        guard FileManager.default.fileExists(atPath: serverPath) else {
            NSLog("AkazaIME: akaza-server not found at \(serverPath)")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: serverPath)
        proc.arguments = [modelPath]

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
