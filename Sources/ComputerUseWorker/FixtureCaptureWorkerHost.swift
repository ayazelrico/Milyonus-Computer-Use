import AppKit
import ComputerUseContracts
import ComputerUseCore
import ComputerUseMacOS
import ComputerUseIPC

private final class CaptureWorkerSelection: @unchecked Sendable {
    private let lock = NSLock()
    private var child: OwnedReadWorkerProcess?
    func select(_ child: OwnedReadWorkerProcess) { lock.lock(); self.child = child; lock.unlock() }
    func binding() -> BrokerOwnedPeer? {
        lock.lock(); let selected = child; lock.unlock()
        guard let selected, let pid = selected.runningProcessIdentifier else { return nil }
        return BrokerOwnedPeer(pid: pid, isLive: { selected.runningProcessIdentifier == pid })
    }
}

/// Trusted development startup configuration. Keep one host across captures. The
/// helper is always this executable, never a path or identity supplied by RPC.
@MainActor
package final class FixtureCaptureWorkerHost {
    private let slot: ReadWorkerProcessSlot
    private let selection = CaptureWorkerSelection()
    private var listener: BrokerHandshakeListener?
    private var active: FixtureCaptureWorkerTransport?
    private var lastChild: OwnedReadWorkerProcess?
    package var retired: Bool { lastChild?.isRetired ?? true }
    package var processState: ReadWorkerProcessState? { lastChild?.state }

    package init(service: String) throws {
        guard BrokerPeerIdentity.validIdentifier(service), let executable = Bundle.main.executableURL else {
            throw HarnessError.invalidRequest
        }
        let peer = try FixtureWorkerIdentity.current()
        let parent = ProcessInfo.processInfo.processIdentifier
        slot = ReadWorkerProcessSlot {
            try OwnedReadWorkerProcess(executable: executable,
                arguments: [FixtureWorkerRuntime.captureRole, service, String(parent)])
        }
        let selected = selection
        listener = try BrokerHandshakeListener(serviceName: service, peer: peer,
            ownedPeer: { selected.binding() }, onDisconnect: { [weak self] id in
                Task { @MainActor in self?.active?.disconnected(id) }
            }, requestHandler: { [weak self] context, data in
                guard let self else { return Data() }
                return await self.receive(context, data)
            })
        try listener?.start()
    }

    package func makeTransport() throws -> any CaptureWorkerTransport {
        guard let listener, listener.connectionCount == 0 else { throw HarnessError.leaseBusy }
        let child = try slot.acquire()
        selection.select(child); lastChild = child
        let transport = FixtureCaptureWorkerTransport(child: child, listener: listener)
        active = transport
        return transport
    }

    private func receive(_ context: BrokerConnectionContext, _ data: Data) -> Data {
        active?.receive(context, data) ?? Data()
    }

    package func cancel() { active?.stop(); slot.cancel() }

    isolated deinit { active?.stop(); slot.cancel(); listener?.close() }
}

@MainActor
private final class FixtureCaptureWorkerTransport: CaptureWorkerTransport {
    private let child: OwnedReadWorkerProcess
    private let listener: BrokerHandshakeListener
    private var launch: Task<Void, Never>?
    private var completion: (@MainActor @Sendable (Result<CaptureWorkerReply, HarnessError>) -> Void)?
    private var ticket: ReadWorkerTicket?
    private var connectionID: UUID?
    private var sentTicket = false
    private var stopped = false
    private var completed = false

    init(child: OwnedReadWorkerProcess, listener: BrokerHandshakeListener) {
        self.child = child; self.listener = listener
    }

    func start(_ ticket: ReadWorkerTicket,
               completion: @escaping @MainActor @Sendable (Result<CaptureWorkerReply, HarnessError>) -> Void) throws {
        guard self.ticket == nil, !stopped else { throw HarnessError.cancelled }
        try ReadWorkerWire.validate(ticket)
        guard ticket.target.windowID != nil else { throw HarnessError.invalidRequest }
        self.ticket = ticket; self.completion = completion
        launch = Task { [weak self, child] in
            do {
                try await child.launch()
                while !Task.isCancelled {
                    guard let self, !self.stopped, !self.completed else { return }
                    if child.isRetired { self.finish(.failure(.cancelled)); return }
                    try await Task.sleep(for: .milliseconds(10))
                }
            } catch { self?.finish(.failure((error as? HarnessError) ?? .cancelled)) }
        }
    }

    func disconnected(_ id: UUID) {
        if connectionID == id { finish(.failure(.cancelled)) }
    }

    func receive(_ context: BrokerConnectionContext, _ data: Data) -> Data {
        guard !stopped, !completed, context.isConnected, !Task.isCancelled, let ticket else { return Data() }
        do {
            if !sentTicket {
                guard data == FixtureWorkerRuntime.captureNext else { throw HarnessError.protocolMismatch }
                connectionID = context.id; sentTicket = true
                return try CaptureWorkerWire.encodeRequest(ticket)
            }
            guard context.id == connectionID else { throw HarnessError.unauthorized }
            let result = try CaptureWorkerWire.decodeReply(data, expected: ticket)
            guard context.isConnected, !Task.isCancelled else { throw HarnessError.cancelled }
            finish(result)
            return Data("accepted".utf8)
        } catch {
            finish(.failure((error as? HarnessError) ?? .protocolMismatch))
            return Data()
        }
    }

    private func finish(_ result: Result<CaptureWorkerReply, HarnessError>) {
        guard !stopped, !completed else { return }
        completed = true
        let callback = completion; completion = nil
        callback?(result)
    }

    func stop() {
        guard !stopped else { return }
        stopped = true; completion = nil
        child.stop()
        if let connectionID { listener.closeConnection(connectionID) }
        launch?.cancel(); launch = nil
    }

    isolated deinit { child.stop(); launch?.cancel() }
}
