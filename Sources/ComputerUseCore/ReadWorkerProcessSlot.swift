import ComputerUseContracts

/// The broker retains this slot across reads. Cancelling a read does not free
/// process capacity until the old child actually exits (or never launched).
@MainActor
package final class ReadWorkerProcessSlot {
    private let factory: @MainActor () throws -> OwnedReadWorkerProcess
    private var current: OwnedReadWorkerProcess?
    private var acquiring = false

    package init(factory: @escaping @MainActor () throws -> OwnedReadWorkerProcess) {
        self.factory = factory
    }

    package func acquire() throws -> OwnedReadWorkerProcess {
        guard !acquiring, current?.isRetired != false else { throw HarnessError.leaseBusy }
        acquiring = true
        defer { acquiring = false }
        current = nil
        let child = try factory()
        current = child
        return child
    }

    package func cancel() { current?.stop() }

    isolated deinit { current?.stop() }
}
