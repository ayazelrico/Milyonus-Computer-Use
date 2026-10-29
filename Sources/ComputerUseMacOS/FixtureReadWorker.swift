import AppKit
import ApplicationServices
import Darwin
import ComputerUseContracts
import ComputerUseCore

/// Kernel-derived process identity, independent of worker-supplied metadata.
package enum ReadWorkerProcessIdentity {
    package static func read(pid: Int32) throws -> ReadWorkerTarget {
        guard pid > 0 else { throw HarnessError.invalidRequest }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size,
              info.pbi_pid == UInt32(pid),
              let seconds = Int64(exactly: info.pbi_start_tvsec),
              let microseconds = Int32(exactly: info.pbi_start_tvusec) else { throw HarnessError.targetNotFound }
        return try ReadWorkerTarget(pid: pid, startSeconds: seconds, startMicroseconds: microseconds)
    }
}

/// Call only inside the separately authenticated read worker. No native grant,
/// activation, input, permission request or caller-selectable app is exposed.
@MainActor
package enum FixtureReadWorker {
    package static func collect(_ ticket: ReadWorkerTicket) throws -> ReadWorkerReply {
        try Task.checkCancellation()
        try ReadWorkerWire.validate(ticket)
        // A known CGWindow identity cannot silently be downgraded to AX-only.
        // This first collector does not yet support the explicit-window route.
        guard ticket.target.windowID == nil else { throw HarnessError.unsupportedCapability }
        let start = ContinuousClock.now
        let deadline = start.advanced(by: ticket.timeout)
        func admit() throws {
            try Task.checkCancellation()
            guard ContinuousClock.now < deadline else { throw HarnessError.timeout }
            guard try ReadWorkerProcessIdentity.read(pid: ticket.target.pid) == ticket.target else {
                throw HarnessError.staleObservation
            }
            guard let app = NSRunningApplication(processIdentifier: ticket.target.pid),
                  !app.isTerminated, app.bundleIdentifier == SessionController.fixtureBundleID else {
                throw HarnessError.policyDenied
            }
            guard AXIsProcessTrusted() else { throw HarnessError.permissionRequired }
        }
        try admit()
        // This value scopes read-only driver metadata. It is not SessionController
        // state and cannot approve or renew the broker's native session.
        let scope = Session(id: ticket.sessionID, bundleId: SessionController.fixtureBundleID,
                            generation: ticket.generation, state: .ready, expiresAt: Date())
        let desktop = AccessibilityDesktop()
        defer { desktop.invalidate() }
        let observation = try desktop.observe(session: scope)
        try admit()
        guard observation.pid == ticket.target.pid else { throw HarnessError.staleObservation }
        return ReadWorkerReply(ticket: ticket, observation: observation, elapsed: start.duration(to: .now))
    }
}
