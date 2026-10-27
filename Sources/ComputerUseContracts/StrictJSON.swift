import Foundation

/// Foundation validates JSON syntax; this bounded UTF-8 walk additionally rejects duplicate
/// object members before normalized dictionaries can hide them.
package enum StrictJSON {
    package static func object(_ data: Data) throws -> Any {
        guard data.count <= 262_144 else { throw HarnessError.resourceLimit }
        guard String(data: data, encoding: .utf8) != nil, !data.contains(0) else { throw HarnessError.protocolMismatch }
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            throw HarnessError.protocolMismatch
        }
        var scanner = Scanner(bytes: Array(data))
        try scanner.value(depth: 0)
        scanner.whitespace()
        guard scanner.index == scanner.bytes.count else { throw HarnessError.protocolMismatch }
        return object
    }

    private struct Scanner {
        let bytes: [UInt8]
        var index = 0
        mutating func whitespace() {
            while index < bytes.count && [9, 10, 13, 32].contains(bytes[index]) { index += 1 }
        }
        mutating func consume(_ byte: UInt8) throws {
            whitespace()
            guard index < bytes.count, bytes[index] == byte else { throw HarnessError.protocolMismatch }
            index += 1
        }
        mutating func string() throws -> Range<Int> {
            whitespace()
            let start = index
            try consume(34)
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                if byte == 34 { return start..<index }
                if byte == 92 {
                    guard index < bytes.count else { throw HarnessError.protocolMismatch }
                    index += 1
                }
            }
            throw HarnessError.protocolMismatch
        }
        mutating func value(depth: Int) throws {
            guard depth <= 64 else { throw HarnessError.resourceLimit }
            whitespace()
            guard index < bytes.count else { throw HarnessError.protocolMismatch }
            switch bytes[index] {
            case 123: // object
                index += 1
                whitespace()
                if index < bytes.count && bytes[index] == 125 { index += 1; return }
                var keys = Set<String>()
                while true {
                    let range = try string()
                    guard let key = try? JSONDecoder().decode(String.self, from: Data(bytes[range])),
                          keys.insert(key).inserted else { throw HarnessError.protocolMismatch }
                    try consume(58)
                    try value(depth: depth + 1)
                    whitespace()
                    if index < bytes.count && bytes[index] == 125 { index += 1; return }
                    try consume(44)
                }
            case 91: // array
                index += 1
                whitespace()
                if index < bytes.count && bytes[index] == 93 { index += 1; return }
                while true {
                    try value(depth: depth + 1)
                    whitespace()
                    if index < bytes.count && bytes[index] == 93 { index += 1; return }
                    try consume(44)
                }
            case 34:
                _ = try string()
            case 45, 48...57, 116, 102, 110: // number, true, false, null; syntax already validated
                while index < bytes.count && ![9, 10, 13, 32, 44, 93, 125].contains(bytes[index]) { index += 1 }
            default:
                throw HarnessError.protocolMismatch
            }
        }
    }
}
