import Foundation

struct ConvertCandidate: Decodable {
    let surface: String
    let yomi: String
    let cost: Float
}

typealias ConvertResult = [[ConvertCandidate]]

class JSONRPCClient {
    private let serverProcess: AkazaServerProcess
    private var nextID = 1
    private let requestQueue = DispatchQueue(label: "im.akaza.jsonrpc.request")
    private var readerQueue: DispatchQueue?

    private let lock = NSLock()
    private var pendingRequests: [Int: (Data?) -> Void] = [:]

    init(serverProcess: AkazaServerProcess) {
        self.serverProcess = serverProcess
        self.serverProcess.onRestart = { [weak self] in
            self?.startReaderLoop()
        }
    }

    func startReaderLoop() {
        guard let stdout = serverProcess.stdoutPipe else { return }

        let queue = DispatchQueue(label: "im.akaza.jsonrpc.reader")
        self.readerQueue = queue

        queue.async { [weak self] in
            let handle = stdout.fileHandleForReading
            var buffer = Data()

            while true {
                let chunk = handle.availableData
                if chunk.isEmpty {
                    // EOF - server terminated
                    self?.failAllPending()
                    break
                }
                buffer.append(chunk)

                // Process complete lines
                while let newlineRange = buffer.range(of: Data([0x0A])) {
                    let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                    buffer.removeSubrange(buffer.startIndex...newlineRange.lowerBound)

                    guard !lineData.isEmpty else { continue }
                    self?.handleResponse(lineData)
                }
            }
        }
    }

    func learnSync(candidates: [(surface: String, yomi: String)]) {
        let params: [String: Any] = [
            "candidates": candidates.map { ["surface": $0.surface, "yomi": $0.yomi] }
        ]
        _ = sendRequestSync(method: "learn", params: params)
    }

    func convertSync(yomi: String, forceRanges: [[Int]]? = nil) -> ConvertResult? {
        var params: [String: Any] = ["yomi": yomi]
        if let forceRanges = forceRanges {
            params["force_ranges"] = forceRanges
        }

        guard let data = sendRequestSync(method: "convert", params: params) else { return nil }

        do {
            return try JSONDecoder().decode(ConvertResult.self, from: data)
        } catch {
            NSLog("AkazaIME: failed to decode convert result: \(error)")
            return nil
        }
    }

    private func sendRequestSync(method: String, params: [String: Any]) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?

        let requestID = requestQueue.sync { () -> Int in
            let id = self.nextID
            self.nextID += 1
            return id
        }

        lock.lock()
        pendingRequests[requestID] = { data in
            resultData = data
            semaphore.signal()
        }
        lock.unlock()

        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestID,
            "method": method,
            "params": params
        ]

        requestQueue.async { [weak self] in
            guard let self = self,
                  let stdin = self.serverProcess.stdinPipe else {
                self?.completePending(id: requestID, data: nil)
                return
            }

            do {
                var data = try JSONSerialization.data(withJSONObject: request)
                data.append(0x0A) // newline
                stdin.fileHandleForWriting.write(data)
            } catch {
                NSLog("AkazaIME: failed to serialize JSON-RPC request: \(error)")
                self.completePending(id: requestID, data: nil)
            }
        }

        let timeout = semaphore.wait(timeout: .now() + 1.0)
        if timeout == .timedOut {
            NSLog("AkazaIME: JSON-RPC request timed out (id=\(requestID))")
            lock.lock()
            pendingRequests.removeValue(forKey: requestID)
            lock.unlock()
            return nil
        }

        return resultData
    }

    private func handleResponse(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["id"] as? Int else {
            return
        }

        if let result = json["result"] {
            if JSONSerialization.isValidJSONObject(result),
               let resultData = try? JSONSerialization.data(withJSONObject: result) {
                completePending(id: id, data: resultData)
            } else {
                completePending(id: id, data: nil)
            }
        } else {
            if let error = json["error"] as? [String: Any] {
                NSLog("AkazaIME: JSON-RPC error (id=\(id)): \(error)")
            }
            completePending(id: id, data: nil)
        }
    }

    private func completePending(id: Int, data: Data?) {
        lock.lock()
        let callback = pendingRequests.removeValue(forKey: id)
        lock.unlock()
        callback?(data)
    }

    private func failAllPending() {
        lock.lock()
        let callbacks = pendingRequests
        pendingRequests.removeAll()
        lock.unlock()

        for (_, callback) in callbacks {
            callback(nil)
        }
    }
}
