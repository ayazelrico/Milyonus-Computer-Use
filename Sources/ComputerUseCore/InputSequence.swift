import Foundation
import ComputerUseContracts

/// Internal normalized input events. These are not an RPC surface or an authorization grant.
public enum InputEvent: Sendable, Equatable {
    case move(x: Double, y: Double)
    case mouseDown(x: Double, y: Double)
    case mouseUp(x: Double, y: Double)
    case drag(x: Double, y: Double)
    case keyDown(code: UInt16)
    case keyUp(code: UInt16)
    case textDown(String)
    case textUp
    case scroll(vertical: Int32, horizontal: Int32)
}
public struct InputStep: Sendable {
    public let event: InputEvent
    public let delayAfterMilliseconds: Int
    public init(_ event: InputEvent, delayAfterMilliseconds: Int = 0) {
        self.event = event; self.delayAfterMilliseconds = delayAfterMilliseconds
    }
}
@MainActor
public protocol InputEmitter: AnyObject { func emit(_ event: InputEvent) throws }

/// Serializes a bounded sequence and checks authorization before every new event.
/// Release events are cleanup and are attempted even after cancellation or permission loss.
@MainActor
public final class InputSequenceExecutor {
    private let emitter: any InputEmitter
    private var generation = 0
    private var running = false
    private var keys = Set<UInt16>()
    private var mouse: (Double, Double)?
    private var textHeld = false
    public init(emitter: any InputEmitter) { self.emitter = emitter }
    public func cancel() { generation += 1; releaseHeldInputs() }
    private func releaseHeldInputs() {
        for key in keys.sorted() { try? emitter.emit(.keyUp(code: key)) }
        keys.removeAll()
        if let mouse { try? emitter.emit(.mouseUp(x: mouse.0, y: mouse.1)) }
        mouse = nil
        if textHeld { try? emitter.emit(.textUp) }; textHeld = false
    }
    public func execute(_ steps: [InputStep], authorize: @MainActor () throws -> Void) async throws {
        guard !running else { throw HarnessError.leaseBusy }
        guard !steps.isEmpty, steps.count <= 1024 else { throw HarnessError.resourceLimit }
        var totalDelay = 0
        for step in steps {
            guard (0...1000).contains(step.delayAfterMilliseconds) else { throw HarnessError.invalidRequest }
            totalDelay += step.delayAfterMilliseconds
            switch step.event {
            case .move(let x, let y), .mouseDown(let x, let y), .mouseUp(let x, let y), .drag(let x, let y):
                guard x.isFinite, y.isFinite, abs(x) <= 100_000, abs(y) <= 100_000 else { throw HarnessError.invalidRequest }
            case .textDown(let text):
                guard !text.isEmpty, text.utf16.count <= 1024, !text.contains("\0") else { throw HarnessError.resourceLimit }
            case .scroll(let vertical, let horizontal):
                guard abs(Int64(vertical)) <= 10_000, abs(Int64(horizontal)) <= 10_000 else { throw HarnessError.resourceLimit }
            case .keyDown(let code), .keyUp(let code):
                guard code <= 127 else { throw HarnessError.invalidRequest }
            case .textUp: break
            }
        }
        guard totalDelay <= 10_000 else { throw HarnessError.resourceLimit }
        generation += 1; let run = generation; running = true
        defer { releaseHeldInputs(); running = false }
        for step in steps {
            guard run == generation, !Task.isCancelled else { throw HarnessError.cancelled }
            try authorize()
            switch step.event {
            case .keyDown(let code): keys.insert(code)
            case .mouseDown(let x, let y), .drag(let x, let y): mouse = (x, y)
            case .textDown: textHeld = true
            default: break
            }
            try emitter.emit(step.event)
            switch step.event {
            case .keyUp(let code): keys.remove(code)
            case .mouseUp: mouse = nil
            case .textUp: textHeld = false
            default: break
            }
            if step.delayAfterMilliseconds > 0 { try await Task.sleep(for: .milliseconds(step.delayAfterMilliseconds)) }
        }
    }
}
