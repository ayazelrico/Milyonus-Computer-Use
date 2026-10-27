import Foundation

@MainActor var failureCount = 0
@MainActor var testCount = 0
@MainActor var assertionCount = 0
@MainActor
class TestCase {
    private var cleanups: [() throws -> Void] = []
    func addTeardownBlock(_ block: @escaping () throws -> Void) { cleanups.append(block) }
    func tearDown() { for block in cleanups.reversed() { try? block() } }
}
@MainActor
func fail(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    failureCount += 1; print("FAIL \(file):\(line): \(message)")
}
@MainActor
func expectEqual<T: Equatable>(_ actual: @autoclosure () throws -> T, _ expected: @autoclosure () throws -> T,
                               file: StaticString = #filePath, line: UInt = #line) {
    assertionCount += 1
    do {
        let a = try actual(), b = try expected()
        if a != b { fail("\(a) != \(b)", file: file, line: line) }
    } catch { fail("Unexpected error: \(error)", file: file, line: line) }
}
@MainActor
func expectFalse(_ expression: @autoclosure () throws -> Bool, file: StaticString = #filePath, line: UInt = #line) {
    assertionCount += 1
    do { if try expression() { fail("Expected false", file: file, line: line) } }
    catch { fail("Unexpected error: \(error)", file: file, line: line) }
}
@MainActor
func expectThrows<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line,
                     _ verify: ((Error) -> Void)? = nil) {
    assertionCount += 1
    do { _ = try expression(); fail("Expected error", file: file, line: line) } catch { verify?(error) }
}
func requireValue<T>(_ value: T?) throws -> T {
    guard let value else { throw NSError(domain: "TestAssertion", code: 1) }; return value
}
@MainActor
func runCase(_ name: String, _ body: () throws -> Void) {
    testCount += 1; let before = failureCount
    do { try body() } catch { fail("\(name): unexpected error \(error)") }
    print("\(failureCount == before ? "PASS" : "FAIL"): \(name)")
}

@MainActor
func runAsyncCase(_ name: String, _ body: @MainActor () async throws -> Void) async {
    testCount += 1; let before = failureCount
    do { try await body() } catch { fail("\(name): unexpected error \(error)") }
    print("\(failureCount == before ? "PASS" : "FAIL"): \(name)")
}
