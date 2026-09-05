import Darwin
import Foundation

enum CommandExecutor {
    static func runAsync(_ command: [String], stdin: String? = nil, timeout: TimeInterval = 35) async -> CommandOutput {
        let task = Task.detached(priority: .utility) {
            run(command, stdin: stdin, timeout: timeout, isCancelled: { Task.isCancelled })
        }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func run(
        _ command: [String],
        stdin: String? = nil,
        timeout: TimeInterval = 3,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isCancelled: () -> Bool = { false }
    ) -> CommandOutput {
        guard let executable = command.first else {
            return CommandOutput(exitCode: 1, stdout: "", stderr: "Missing executable")
        }
        guard !isCancelled() else {
            return CommandOutput(exitCode: 130, stdout: "", stderr: "Command cancelled")
        }

        let process = Process()
        let output = Pipe()
        let error = Pipe()
        let input = Pipe()
        process.executableURL = URL(fileURLWithPath: executable.hasPrefix("/") ? executable : "/usr/bin/env")
        process.arguments = executable.hasPrefix("/") ? Array(command.dropFirst()) : command
        process.environment = VersionRefreshService.processEnvironment(for: command, baseEnvironment: environment)
        process.standardOutput = output
        process.standardError = error
        process.standardInput = input
        defer {
            for handle in [output.fileHandleForReading, output.fileHandleForWriting,
                           error.fileHandleForReading, error.fileHandleForWriting,
                           input.fileHandleForReading, input.fileHandleForWriting] {
                try? handle.close()
            }
        }

        do {
            try process.run()
        } catch {
            return CommandOutput(exitCode: 1, stdout: "", stderr: error.localizedDescription)
        }
        try? output.fileHandleForWriting.close()
        try? error.fileHandleForWriting.close()
        try? input.fileHandleForReading.close()

        let outputFD = output.fileHandleForReading.fileDescriptor
        let errorFD = error.fileHandleForReading.fileDescriptor
        let inputFD = input.fileHandleForWriting.fileDescriptor
        for fd in [outputFD, errorFD, inputFD] {
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        }
        _ = fcntl(inputFD, F_SETNOSIGPIPE, 1)

        let inputData = Data((stdin ?? "").utf8)
        var inputOffset = 0
        var inputClosed = false
        var stdout = Data()
        var stderr = Data()
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var stopCode: Int32?
        var killDeadline: TimeInterval?

        // Pump all three streams together. Waiting for exit first can deadlock on a full pipe.
        repeat {
            drain(outputFD, into: &stdout)
            drain(errorFD, into: &stderr)
            if !inputClosed {
                if inputOffset < inputData.count {
                    let count = inputData.withUnsafeBytes { bytes in
                        Darwin.write(inputFD, bytes.baseAddress!.advanced(by: inputOffset), min(16_384, inputData.count - inputOffset))
                    }
                    if count > 0 {
                        inputOffset += count
                    } else if count < 0 && errno != EAGAIN && errno != EINTR {
                        inputOffset = inputData.count
                    }
                }
                if inputOffset == inputData.count {
                    try? input.fileHandleForWriting.close()
                    inputClosed = true
                }
            }
            let now = ProcessInfo.processInfo.systemUptime
            if stopCode == nil && (isCancelled() || now >= deadline) && process.isRunning {
                stopCode = isCancelled() ? 130 : 124
                process.terminate()
                killDeadline = now + 0.2
            }
            if let killDeadline, now >= killDeadline, process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            if process.isRunning {
                Thread.sleep(forTimeInterval: 0.005)
            }
        } while process.isRunning
        process.waitUntilExit()
        drain(outputFD, into: &stdout)
        drain(errorFD, into: &stderr)

        var errorText = String(decoding: stderr, as: UTF8.self)
        if let stopCode {
            let reason = stopCode == 130 ? "Command cancelled" : "Command timed out after \(timeout.formatted()) seconds"
            errorText += (errorText.isEmpty ? "" : "\n") + reason
        }
        return CommandOutput(exitCode: stopCode ?? process.terminationStatus,
                             stdout: String(decoding: stdout, as: UTF8.self), stderr: errorText)
    }

    private static func drain(_ fd: Int32, into data: inout Data) {
        var buffer = [UInt8](repeating: 0, count: 16_384)
        // Bound each pass so a noisy process cannot starve timeout or stdin handling.
        for _ in 0..<64 {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count > 0 {
                data.append(contentsOf: buffer.prefix(count))
            } else if count < 0 && errno == EINTR {
                continue
            } else {
                break
            }
        }
    }
}
