import AppKit
@preconcurrency import ApplicationServices
import ScreenCaptureKit
import ComputerUseContracts

public enum Permissions {
    public static func status() -> [String: Bool] {
        ["accessibility": AXIsProcessTrusted(), "screenRecording": CGPreflightScreenCaptureAccess()]
    }
    @MainActor public static func requestAccessibilityFromNativeUI() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
    @MainActor public static func requestCaptureFromNativeUI() { _ = CGRequestScreenCaptureAccess() }
}
