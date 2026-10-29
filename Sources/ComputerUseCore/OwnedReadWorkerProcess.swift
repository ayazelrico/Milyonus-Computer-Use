import Foundation
import Darwin
import ComputerUseContracts

package enum ReadWorkerProcessState: Sendable, Equatable {
    case idle, launching, running(Int32), exited(status: Int32, signalled: Bool), failed
}

/// Direct-child ownership only, not executable authentication. The trusted
/// broker launcher must separately pin its helper and authenticate its channel.
/// No RPC accepts this executable, arguments or an external PID.
package final class OwnedReadWorkerProcess: Sendable {
    private let storage: Storage

    package init(executable: URL, arguments: [String] = [], terminationGrace: Duration = .seconds(1)) throws {
        guard executable.isFileURL, executable.path.hasPrefix("/"),
              FileManager.default.isExecutableFile(atPath: executable.path),
              terminationGrace > .zero, terminationGrace <= .seconds(1) else { throw HarnessError.invalidRequest }
        storage = Storage(executable: executable, arguments: arguments, grace: terminationGrace)
    }

    deinit { storage.stop() }

    package var state: ReadWorkerProcessState { storage.snapshot() }
    /// Authentication admission uses this latch, not a PID retained after Stop.
    package var runningProcessIdentifier: Int32? { storage.runningPID() }
    package var isRetired: Bool { storage.isRetired() }

    package func launch() async throws {
        let storage = storage
        if Task.isCancelled { storage.stop(); throw HarnessError.cancelled }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                storage.launch { continuation.resume(with: $0.mapError { $0 as Error }) }
            }
            try Task.checkCancellation()
            try storage.checkActive()
        } onCancel: { storage.stop() }
    }

    package func stop() { storage.stop() }

    /// Process operations run only on this queue. The lock protects the small
    /// published state and stop latch; it is never held across launch or wait.
    private final class Storage: @unchecked Sendable {
        private let queue = DispatchQueue(label: "com.milyonus.read-worker.process", qos: .utility)
        private let lock = NSLock()
        private let process = Process()
        private let grace: Duration
        private var state: ReadWorkerProcessState = .idle
        private var stopped = false
        private var terminationStarted = false // queue-confined

        init(executable: URL, arguments: [String], grace: Duration) {
            self.grace = grace
            process.executableURL = executable; process.arguments = arguments
            process.environment = ["PATH": "/usr/bin:/bin"]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
        }

        func snapshot() -> ReadWorkerProcessState {
            lock.lock(); defer { lock.unlock() }; return state
        }

        func runningPID() -> Int32? {
            lock.lock(); defer { lock.unlock() }
            guard !stopped, case .running(let pid) = state else { return nil }
            return pid
        }

        func isRetired() -> Bool {
            lock.lock(); defer { lock.unlock() }
            switch state {
            case .failed, .exited: return true
            case .idle: return stopped
            case .launching, .running: return false
            }
        }

        private func publish(_ state: ReadWorkerProcessState) {
            lock.lock(); self.state = state; lock.unlock()
        }

        private var stopRequested: Bool {
            lock.lock(); defer { lock.unlock() }; return stopped
        }

        func checkActive() throws {
            guard !stopRequested else { throw HarnessError.cancelled }
        }

        func launch(_ completion: @escaping @Sendable (Result<Void, HarnessError>) -> Void) {
            lock.lock()
            guard state == .idle, !stopped else {
                let error: HarnessError = stopped ? .cancelled : .leaseBusy
                lock.unlock(); completion(.failure(error)); return
            }
            state = .launching
            lock.unlock()
            queue.async { [self] in
                guard !stopRequested else { publish(.failed); completion(.failure(.cancelled)); return }
                process.terminationHandler = { [self] child in
                    let status = child.terminationStatus
                    let signalled = child.terminationReason == .uncaughtSignal
                    queue.async { [self] in
                        publish(.exited(status: status, signalled: signalled))
                        process.terminationHandler = nil
                    }
                }
                do {
                    try process.run()
                    publish(.running(process.processIdentifier))
                    if stopRequested {
                        terminateOnQueue()
                        completion(.failure(.cancelled))
                    } else { completion(.success(())) }
                } catch {
                    process.terminationHandler = nil
                    publish(.failed)
                    completion(.failure(.protocolMismatch))
                }
            }
        }

        func stop() {
            lock.lock(); stopped = true; lock.unlock()
            queue.async { [self] in terminateOnQueue() }
        }

        private func terminateOnQueue() {
            guard !terminationStarted, process.isRunning else { return }
            terminationStarted = true
            process.terminate()
            let seconds = Double(grace.components.seconds) + Double(grace.components.attoseconds) / 1e18
            queue.asyncAfter(deadline: .now() + seconds) { [self] in
                // Only this directly launched, still-running Process is eligible.
                // Never accept a remote PID or signal a process group.
                guard process.isRunning else { return }
                _ = Darwin.kill(process.processIdentifier, SIGKILL)
            }
        }
    }
}
