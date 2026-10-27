import AppKit
import ApplicationServices
import ComputerUseContracts
import ComputerUseCore

/// AX calls have individual native timeouts and a bounded traversal. A separate worker
/// process is still required before claiming isolation from arbitrary hostile AX servers.
@MainActor
public final class AccessibilityDesktop: DesktopDriver {
    private struct Target {
        let element: AXUIElement
        let window: AXUIElement
        let app: NSRunningApplication
        let role: String
        let identifier: String?
        let bounds: Rect?
        let actions: [ActionKind]
    }
    private var targets: [String: Target] = [:]
    private var observation: Observation?
    private var observedAt: TimeInterval = 0
    private var observationGeneration = 0
    public init() {}
    public func invalidate() { targets.removeAll(); observation = nil }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    private func string(_ element: AXUIElement, _ name: String) -> String? {
        guard let value = attribute(element, name) as? String else { return nil }
        return String(value.prefix(1024))
    }
    private func rect(_ element: AXUIElement) -> Rect? {
        guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var dimensions = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &dimensions) else { return nil }
        let result = Rect(x: point.x, y: point.y, width: dimensions.width, height: dimensions.height)
        return result.isValid ? result : nil
    }
    private func focusedWindow(_ app: AXUIElement) -> AXUIElement? {
        for name in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let value = attribute(app, name), CFGetTypeID(value) == AXUIElementGetTypeID() {
                return unsafeDowncast(value, to: AXUIElement.self)
            }
        }
        // Some AppKit lifecycle states expose no focused-window attribute. A single
        // non-minimized window is unambiguous while the owning app is active.
        if let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement], windows.count == 1,
           let window = windows.first, (attribute(window, kAXMinimizedAttribute) as? Bool) != true {
            return window
        }
        return nil
    }
    public func observe(session: Session) throws -> Observation {
        invalidate()
        try Task.checkCancellation()
        let capturedAt = Date()
        let start = ProcessInfo.processInfo.systemUptime
        var budget = ObservationTraversalBudget()
        var pendingTargets: [String: Target] = [:]
        guard AXIsProcessTrusted() else { throw HarnessError.permissionRequired }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: session.bundleId)
        guard apps.count == 1, let app = apps.first, !app.isTerminated else { throw HarnessError.targetAmbiguous }
        guard app.isActive else { throw HarnessError.focusChanged }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.05)
        guard let window = focusedWindow(root) else { throw HarnessError.targetNotFound }
        var nodes: [ElementSnapshot] = []
        var stack: [(AXUIElement, Int)] = [(window, 0)]
        var visited: [AXUIElement] = []
        var truncated = false
        while let (element, depth) = stack.popLast() {
            try Task.checkCancellation()
            guard !visited.contains(where: { CFEqual($0, element) }) else { continue }
            guard budget.visit(depth: depth) else { truncated = true; break }
            visited.append(element)
            let role = string(element, kAXRoleAttribute) ?? "AXUnknown"
            let subrole = string(element, kAXSubroleAttribute)
            if subrole == kAXSecureTextFieldSubrole { continue }
            let id = UUID().uuidString
            let identifier = string(element, kAXIdentifierAttribute)
            let bounds = rect(element)
            let enabled = (attribute(element, kAXEnabledAttribute) as? Bool) ?? false
            var nativeActions: CFArray?
            _ = AXUIElementCopyActionNames(element, &nativeActions)
            var actions: [ActionKind] = []
            if enabled, (nativeActions as? [String])?.contains(kAXPressAction) == true { actions.append(.press) }
            var settable = DarwinBoolean(false)
            if enabled, role == kAXTextFieldRole,
               AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable) == .success, settable.boolValue {
                actions.append(.setValue)
            }
            if enabled, role == kAXGroupRole, identifier == "fixture.drag.canvas" { actions.append(.drag) }
            if enabled, role == kAXScrollAreaRole, identifier == "fixture.scroll" { actions.append(.scroll) }
            // Only the purpose-built fixture exports values in this first implementation.
            var value = string(element, kAXValueAttribute)
            if role == kAXScrollBarRole, let number = attribute(element, kAXValueAttribute) as? NSNumber,
               CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite,
               (0...1).contains(number.doubleValue) { value = String(number.doubleValue) }
            let label = string(element, kAXTitleAttribute)
            let textBytes = role.utf8.count + (value?.utf8.count ?? 0)
                + (label?.utf8.count ?? 0) + (identifier?.utf8.count ?? 0)
            guard budget.admitText(bytes: textBytes) else { truncated = true; break }
            nodes.append(ElementSnapshot(id: id, role: role, identifier: identifier,
                                         label: label, value: value,
                                         bounds: bounds, enabled: enabled, actions: actions))
            pendingTargets[id] = Target(element: element, window: window, app: app, role: role,
                                 identifier: identifier, bounds: bounds, actions: actions)
            if let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] {
                stack.append(contentsOf: children.prefix(300).reversed().map { ($0, depth + 1) })
                if children.count > 300 { truncated = true }
            }
        }
        try Task.checkCancellation()
        guard AXIsProcessTrusted() else { throw HarnessError.permissionRevoked }
        guard !app.isTerminated, app.isActive else { throw HarnessError.focusChanged }
        guard let currentWindow = focusedWindow(root), CFEqual(currentWindow, window) else { throw HarnessError.focusChanged }
        try Task.checkCancellation()
        guard AXIsProcessTrusted() else { throw HarnessError.permissionRevoked }
        guard !app.isTerminated, app.isActive else { throw HarnessError.focusChanged }
        // A late final AX read must not turn an expired traversal into a fresh result.
        let complete = budget.finish()
        truncated = truncated || !complete
        let result = Observation(id: UUID().uuidString, sessionId: session.id, bundleId: session.bundleId,
                                 pid: app.processIdentifier, capturedAt: capturedAt, elements: nodes, truncated: truncated)
        targets = truncated ? [:] : pendingTargets
        observation = result; observedAt = start; observationGeneration = session.generation
        return result
    }
    private func resolve(_ request: ActionRequest, session: Session) throws -> Target {
        guard AXIsProcessTrusted() else { throw HarnessError.permissionRevoked }
        guard session.id == request.sessionId, observation?.sessionId == session.id,
              observation?.id == request.observationId, observation?.truncated == false,
              observationGeneration == session.generation,
              ProcessInfo.processInfo.systemUptime - observedAt < 10 else { throw HarnessError.staleObservation }
        guard let target = targets[request.elementId], !target.app.isTerminated,
              target.app.bundleIdentifier == session.bundleId else { throw HarnessError.targetNotFound }
        guard target.app.isActive else { throw HarnessError.focusChanged }
        let root = AXUIElementCreateApplication(target.app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.05)
        guard let currentWindow = focusedWindow(root), CFEqual(currentWindow, target.window) else { throw HarnessError.focusChanged }
        guard string(target.element, kAXSubroleAttribute) != kAXSecureTextFieldSubrole,
              string(target.element, kAXRoleAttribute) == target.role,
              string(target.element, kAXIdentifierAttribute) == target.identifier,
              rect(target.element) == target.bounds,
              (attribute(target.element, kAXEnabledAttribute) as? Bool) == true else { throw HarnessError.staleObservation }
        guard target.actions.contains(request.kind) else { throw HarnessError.unsupportedCapability }
        // Explicit effect allowlist: arbitrary buttons are not authorized by their labels.
        switch request.kind {
        case .drag: guard target.identifier == "fixture.drag.canvas", target.role == kAXGroupRole else { throw HarnessError.policyDenied }
        case .scroll: guard target.identifier == "fixture.scroll", target.role == kAXScrollAreaRole else { throw HarnessError.policyDenied }
        case .press: guard target.identifier == "fixture.save" else { throw HarnessError.policyDenied }
        case .setValue: guard target.identifier == "fixture.input" else { throw HarnessError.policyDenied }
        }
        return target
    }
    public func preflight(_ request: ActionRequest, session: Session) throws {
        let target = try resolve(request, session: session)
        if request.kind == .drag {
            _ = try dragStatus()
            let steps = try dragSteps(target)
            for step in steps { try dragHitTest(target, event: step.event) }
        }
        if request.kind == .scroll {
            guard let pixels = request.scrollPixels else { throw HarnessError.invalidRequest }
            let (_, value) = try verticalScrollState(target)
            guard pixels > 0 ? value > 0 : value < 1 else { throw HarnessError.policyDenied }
            try scrollHitTest(target)
        }
    }
    public func execute(_ request: ActionRequest, session: Session) throws -> ActionResult {
        let target = try resolve(request, session: session)
        let statusTarget = targets.values.first { $0.identifier == "fixture.status" }
        let inputTarget = targets.values.first { $0.identifier == "fixture.input" }
        let oldStatus = statusTarget.flatMap { attribute($0.element, kAXValueAttribute) as? String }
        let inputValue = inputTarget.flatMap { attribute($0.element, kAXValueAttribute) as? String }
        let expectedSave: String?
        if let oldStatus, let inputValue {
            if oldStatus == "Not saved" { expectedSave = "Saved 1: " + inputValue }
            else if oldStatus.hasPrefix("Saved "), let separator = oldStatus.firstIndex(of: ":"),
                    let count = Int(oldStatus[oldStatus.index(oldStatus.startIndex, offsetBy: 6)..<separator]), count < Int.max {
                expectedSave = "Saved \(count + 1): " + inputValue
            } else { expectedSave = nil }
        } else { expectedSave = nil }
        let status: AXError
        switch request.kind {
        case .scroll, .drag: throw HarnessError.unsupportedCapability
        case .press: status = AXUIElementPerformAction(target.element, kAXPressAction as CFString)
        case .setValue:
            status = AXUIElementSetAttributeValue(target.element, kAXValueAttribute as CFString, (request.text ?? "") as CFString)
        }
        // Native timeout/failure does not prove that the remote application had no effect.
        guard status == .success else {
            invalidate()
            return ActionResult(requestId: request.requestId, effect: .unknown, verification: .unavailable, error: .effectUnknown)
        }
        let verification: Verification
        if request.kind == .setValue {
            verification = (attribute(target.element, kAXValueAttribute) as? String) == request.text ? .passed : .failed
        } else {
            // Verify the fixture's independent counter and saved text, not AXPress's return code.
            if let expectedSave, let statusTarget {
                verification = (attribute(statusTarget.element, kAXValueAttribute) as? String) == expectedSave ? .passed : .failed
            } else { verification = .unavailable }
        }
        invalidate()
        return ActionResult(requestId: request.requestId, effect: .applied, verification: verification,
                            error: verification == .failed ? .verificationFailed : nil)
    }
    private func dragSteps(_ target: Target) throws -> [InputStep] {
        guard let bounds = target.bounds, bounds.width >= 40, bounds.height >= 20 else { throw HarnessError.targetNotFound }
        return try PointerGesture.drag(from: .init(x: bounds.x + bounds.width / 4, y: bounds.y + bounds.height / 2),
                                       to: .init(x: bounds.x + bounds.width * 3 / 4, y: bounds.y + bounds.height / 2),
                                       within: .init(origin: .init(x: bounds.x, y: bounds.y), width: bounds.width, height: bounds.height))
    }
    private func dragStatus() throws -> (Target, Int) {
        let candidates = targets.values.filter { $0.identifier == "fixture.drag.status" }
        guard candidates.count == 1, let target = candidates.first,
              let value = attribute(target.element, kAXValueAttribute) as? String else { throw HarnessError.targetNotFound }
        return (target, try FixtureDragReceipt.previousCount(value))
    }
    private func dragHitTest(_ target: Target, event: InputEvent) throws {
        let x: Double, y: Double
        switch event {
        case .move(let px, let py), .mouseDown(let px, let py), .mouseUp(let px, let py), .drag(let px, let py):
            x = px; y = py
        default: throw HarnessError.invalidRequest
        }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(x), Float(y), &hit) == .success,
              let hit, CFEqual(hit, target.element) else { throw HarnessError.staleObservation }
    }
    /// Fixed horizontal sweep inside the fixture canvas; no arbitrary drag/drop targets.
    public func executeNativeDrag(_ request: ActionRequest, session: Session,
                                  authorize: @MainActor () throws -> Void) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .drag else { throw HarnessError.invalidRequest }
        let target = try resolve(request, session: session)
        guard let bounds = target.bounds else { throw HarnessError.targetNotFound }
        let (status, before) = try dragStatus()
        let steps = try dragSteps(target)
        let sequence = try InputSequenceExecutor(emitter: NativeInputEmitter())
        var index = 0
        try await sequence.execute(steps) {
            try authorize()
            _ = try self.resolve(request, session: session)
            try self.dragHitTest(target, event: steps[index].event)
            index += 1
        }
        for _ in 0..<50 {
            try authorize()
            _ = try resolve(request, session: session)
            guard self.string(status.element, kAXIdentifierAttribute) == "fixture.drag.status",
                  let value = attribute(status.element, kAXValueAttribute) as? String else { throw HarnessError.staleObservation }
            if let receipt = try? FixtureDragReceipt(value), receipt.matches(previousCount: before, width: bounds.width, height: bounds.height) {
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        return ActionResult(requestId: request.requestId, effect: .unknown, verification: .unavailable, error: .effectUnknown)
    }
    private func verticalScrollState(_ target: Target) throws -> (AXUIElement, Double) {
        guard let raw = attribute(target.element, kAXVerticalScrollBarAttribute),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { throw HarnessError.unsupportedCapability }
        let bar = unsafeDowncast(raw, to: AXUIElement.self)
        guard let number = attribute(bar, kAXValueAttribute) as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { throw HarnessError.verificationFailed }
        let value = number.doubleValue
        guard value.isFinite, (0...1).contains(value) else { throw HarnessError.verificationFailed }
        return (bar, value)
    }
    private func scrollHitTest(_ target: Target) throws {
        guard let bounds = target.bounds else { throw HarnessError.targetNotFound }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(bounds.x + bounds.width / 2),
                                               Float(bounds.y + bounds.height / 2), &hit) == .success else {
            throw HarnessError.staleObservation
        }
        // Scroll views normally hit a document child. Only a bounded, exact ancestry
        // chain to this resolved scroll area is accepted; unrelated overlays fail.
        for _ in 0..<20 {
            guard let element = hit else { break }
            if CFEqual(element, target.element) { return }
            guard let parent = attribute(element, kAXParentAttribute),
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            hit = unsafeDowncast(parent, to: AXUIElement.self)
        }
        throw HarnessError.staleObservation
    }
    /// Experimental vertical fixture scrolling. No arbitrary coordinates or horizontal effects.
    public func executeNativeScroll(_ request: ActionRequest, session: Session,
                                    authorize: @MainActor () throws -> Void) async throws -> ActionResult {
        try request.validate()
        guard request.kind == .scroll, let pixels = request.scrollPixels else { throw HarnessError.invalidRequest }
        let target = try resolve(request, session: session)
        guard let bounds = target.bounds else { throw HarnessError.targetNotFound }
        let (bar, before) = try verticalScrollState(target)
        let steps = try PointerGesture.scroll(at: .init(x: bounds.x + bounds.width / 2, y: bounds.y + bounds.height / 2),
                                              within: .init(origin: .init(x: bounds.x, y: bounds.y), width: bounds.width, height: bounds.height),
                                              vertical: Int32(pixels), horizontal: 0)
        let sequence = try InputSequenceExecutor(emitter: NativeInputEmitter())
        try await sequence.execute(steps) {
            try authorize()
            _ = try self.resolve(request, session: session)
            let (currentBar, _) = try self.verticalScrollState(target)
            guard CFEqual(currentBar, bar) else { throw HarnessError.staleObservation }
            try self.scrollHitTest(target)
        }
        for _ in 0..<50 {
            try authorize()
            _ = try resolve(request, session: session)
            let (currentBar, after) = try verticalScrollState(target)
            guard CFEqual(currentBar, bar) else { throw HarnessError.staleObservation }
            if pixels > 0 ? after < before : after > before {
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        return ActionResult(requestId: request.requestId, effect: .unknown, verification: .unavailable, error: .effectUnknown)
    }
    /// Click only the resolved fixture Save button; caller-supplied desktop coordinates are not accepted.
    public func executeNativeClick(_ request: ActionRequest, session: Session,
                                   authorize: @MainActor () throws -> Void) async throws -> ActionResult {
        guard request.kind == .press else { throw HarnessError.invalidRequest }
        let target = try resolve(request, session: session)
        guard let bounds = target.bounds,
              let statusTarget = targets.values.first(where: { $0.identifier == "fixture.status" }),
              let inputTarget = targets.values.first(where: { $0.identifier == "fixture.input" }),
              let oldStatus = attribute(statusTarget.element, kAXValueAttribute) as? String,
              let input = attribute(inputTarget.element, kAXValueAttribute) as? String else { throw HarnessError.targetNotFound }
        let count: Int
        if oldStatus == "Not saved" { count = 0 }
        else if oldStatus.hasPrefix("Saved "), let colon = oldStatus.firstIndex(of: ":"),
                let parsed = Int(oldStatus[oldStatus.index(oldStatus.startIndex, offsetBy: 6)..<colon]), parsed < Int.max {
            count = parsed
        } else { throw HarnessError.verificationFailed }
        let expected = "Saved \(count + 1): " + input
        let x = bounds.x + bounds.width / 2, y = bounds.y + bounds.height / 2
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.05)
        let sequence = try InputSequenceExecutor(emitter: NativeInputEmitter())
        try await sequence.execute([InputStep(.move(x: x, y: y), delayAfterMilliseconds: 10),
                                    InputStep(.mouseDown(x: x, y: y), delayAfterMilliseconds: 30),
                                    InputStep(.mouseUp(x: x, y: y))]) {
            try authorize()
            _ = try self.resolve(request, session: session)
            var hit: AXUIElement?
            guard AXUIElementCopyElementAtPosition(system, Float(x), Float(y), &hit) == .success,
                  let hit, CFEqual(hit, target.element) else { throw HarnessError.staleObservation }
        }
        for _ in 0..<50 {
            try authorize()
            _ = try resolve(request, session: session)
            if (attribute(statusTarget.element, kAXValueAttribute) as? String) == expected {
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        return ActionResult(requestId: request.requestId, effect: .unknown, verification: .unavailable, error: .effectUnknown)
    }

    /// Native keyboard replacement uses the same target checks and intent journal as AX actions.
    public func executeNativeText(_ request: ActionRequest, session: Session,
                                  authorize: @MainActor () throws -> Void) async throws -> ActionResult {
        guard request.kind == .setValue, let text = request.text, text.utf16.count <= 1024 else {
            throw HarnessError.invalidRequest
        }
        let target = try resolve(request, session: session)
        try authorize()
        guard let existing = attribute(target.element, kAXValueAttribute) as? String else { throw HarnessError.targetNotFound }
        guard AXUIElementSetAttributeValue(target.element, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else {
            throw HarnessError.focusChanged
        }
        var range = CFRange(location: 0, length: existing.utf16.count)
        guard let selection = AXValueCreate(.cfRange, &range),
              AXUIElementSetAttributeValue(target.element, kAXSelectedTextRangeAttribute as CFString, selection) == .success else {
            throw HarnessError.unsupportedCapability
        }
        let sequence = try InputSequenceExecutor(emitter: NativeInputEmitter())
        let steps: [InputStep] = text.isEmpty
            ? [InputStep(.keyDown(code: 51)), InputStep(.keyUp(code: 51))]
            : [InputStep(.textDown(text)), InputStep(.textUp)]
        try await sequence.execute(steps) {
            try authorize()
            _ = try self.resolve(request, session: session)
            let root = AXUIElementCreateApplication(target.app.processIdentifier)
            AXUIElementSetMessagingTimeout(root, 0.05)
            guard let focused = self.attribute(root, kAXFocusedUIElementAttribute),
                  CFGetTypeID(focused) == AXUIElementGetTypeID(), CFEqual(focused, target.element) else {
                throw HarnessError.focusChanged
            }
        }
        for _ in 0..<50 {
            try authorize()
            _ = try resolve(request, session: session)
            if (attribute(target.element, kAXValueAttribute) as? String) == text {
                return ActionResult(requestId: request.requestId, effect: .applied, verification: .passed)
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        return ActionResult(requestId: request.requestId, effect: .unknown, verification: .unavailable, error: .effectUnknown)
    }

}
