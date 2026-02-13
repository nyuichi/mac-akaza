import Cocoa
import InputMethodKit

private func setupLogging() {
    let logDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/AkazaIME")
    try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

    let logFile = logDir.appendingPathComponent("akaza.log")
    if !FileManager.default.fileExists(atPath: logFile.path) {
        FileManager.default.createFile(atPath: logFile.path, contents: nil)
    }

    if let handle = FileHandle(forWritingAtPath: logFile.path) {
        handle.seekToEndOfFile()
        // stderr をログファイルにリダイレクト
        dup2(handle.fileDescriptor, STDERR_FILENO)
    }
}

private func getConnectionName() -> String {
    if let name = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String {
        return name
    }
    return "AkazaIME_1_Connection"
}

setupLogging()
NSLog("AkazaIME: starting")

let connectionName = getConnectionName()
NSLog("AkazaIME: connection name = \(connectionName)")

guard let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier) else {
    NSLog("AkazaIME: failed to create IMKServer")
    exit(1)
}
_ = server // IMKServer を保持

NSLog("AkazaIME: IMKServer created successfully")
NSApplication.shared.run()
