import Foundation
import SwiftUI

/// A JSON value for an event property.
enum EventValue: Sendable, Hashable, Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

extension EventValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .int(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
}

/// One analytics event, in the line format of `check-parity/scripts/events.mjs`:
/// `{"name": "...", "props": {...}}`.
struct AnalyticsEvent: Sendable, Hashable, Encodable {
    var name: String
    var props: [String: EventValue]
}

/// Receives analytics events. Screens and models depend on this protocol only.
protocol AnalyticsSink: Sendable {
    func record(_ event: AnalyticsEvent)
}

extension AnalyticsSink {
    /// Port of RN `ax.metric(name, props)`: same event names and property keys.
    func metric(_ name: String, _ props: [String: EventValue] = [:]) {
        record(AnalyticsEvent(name: name, props: props))
    }
}

/// Discards events. Used by previews and as the environment default.
struct NoopAnalytics: AnalyticsSink {
    func record(_ event: AnalyticsEvent) {}
}

#if E2E
/// Appends events to `Documents/events.jsonl`, one JSON object per line.
///
/// E2E builds only (review finding A60): the log holds post URIs, DIDs and visited link URLs, so
/// Release builds use `NoopAnalytics`. The parity event diff reads this file.
///
/// One serial queue owns the encoder and the file handle; `record` only enqueues, so the main
/// actor never encodes or does file I/O. Maestro `clearState` deletes the Documents directory,
/// so each capture run starts empty.
final class JSONLinesEventLog: AnalyticsSink, @unchecked Sendable {
    static let fileName = "events.jsonl"

    let fileURL: URL
    private let queue = DispatchQueue(label: "io.nativestarter.showcase.bluesky.events", qos: .utility)
    // Confined to `queue`.
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
    // Confined to `queue`.
    private var handle: FileHandle?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    deinit {
        try? handle?.close()
    }

    static func documents() -> JSONLinesEventLog {
        JSONLinesEventLog(fileURL: URL.documentsDirectory.appending(path: fileName))
    }

    func record(_ event: AnalyticsEvent) {
        queue.async { [self] in write(event) }
    }

    /// Blocks until queued writes finish. Tests only.
    func flush() {
        queue.sync {}
    }

    private func write(_ event: AnalyticsEvent) {
        guard var line = try? encoder.encode(event) else { return }
        line.append(0x0A)
        if handle == nil {
            let manager = FileManager.default
            if !manager.fileExists(atPath: fileURL.path) {
                try? manager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                manager.createFile(atPath: fileURL.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: fileURL)
            _ = try? handle?.seekToEnd()
        }
        try? handle?.write(contentsOf: line)
    }
}
#endif

extension EnvironmentValues {
    @Entry var analytics: any AnalyticsSink = NoopAnalytics()
}
