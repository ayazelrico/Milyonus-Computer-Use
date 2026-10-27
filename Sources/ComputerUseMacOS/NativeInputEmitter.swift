import Foundation
import CoreGraphics
import ComputerUseContracts
import ComputerUseCore

/// A native backend only. Call through InputSequenceExecutor with session, focus, frame,
/// visibility and scope checks. No RPC currently exposes this low-level backend.
@MainActor
public final class NativeInputEmitter: InputEmitter {
    public static let eventMarker: Int64 = 0x4D494C594355
    private let source: CGEventSource
    public init() throws {
        guard let source = CGEventSource(stateID: .privateState) else { throw HarnessError.unsupportedCapability }
        self.source = source
    }
    public func emit(_ input: InputEvent) throws {
        let event: CGEvent?
        switch input {
        case .move(let x, let y): event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
        case .mouseDown(let x, let y): event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
        case .mouseUp(let x, let y): event = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
        case .drag(let x, let y): event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDragged, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)
        case .keyDown(let code): event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        case .keyUp(let code): event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
        case .textDown(let text):
            event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let units = Array(text.utf16)
            units.withUnsafeBufferPointer { event?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: $0.baseAddress) }
        case .textUp: event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        case .scroll(let vertical, let horizontal):
            event = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: vertical, wheel2: horizontal, wheel3: 0)
        }
        guard let event else { throw HarnessError.unsupportedCapability }
        event.flags = []
        switch input {
        case .mouseDown, .mouseUp: event.setIntegerValueField(.mouseEventClickState, value: 1)
        default: break
        }
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventMarker)
        event.post(tap: .cghidEventTap)
    }
}
