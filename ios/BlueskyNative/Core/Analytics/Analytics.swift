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

/// Appends events to `Documents/events.jsonl`, one JSON object per line.
///
/// Writes run in order on a serial background queue, so the main actor never does file I/O.
/// Maestro `clearState` deletes the Documents directory, so each capture run starts empty.
final class JSONLinesEventLog: AnalyticsSink {
    static let fileName = "events.jsonl"

    let fileURL: URL
    private let queue = DispatchQueue(label: "io.nativestarter.showcase.bluesky.events", qos: .utility)

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func documents() -> JSONLinesEventLog {
        let documents = URL.documentsDirectory
        return JSONLinesEventLog(fileURL: documents.appending(path: fileName))
    }

    func record(_ event: AnalyticsEvent) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard var line = try? encoder.encode(event) else { return }
        line.append(0x0A)
        let url = fileURL
        queue.async {
            Self.append(line, to: url)
        }
    }

    /// Blocks until queued writes finish. Tests only.
    func flush() {
        queue.sync {}
    }

    private static func append(_ data: Data, to url: URL) {
        let manager = FileManager.default
        if !manager.fileExists(atPath: url.path) {
            try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            manager.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    }
}

extension EnvironmentValues {
    @Entry var analytics: any AnalyticsSink = NoopAnalytics()
}
