import Foundation

/// Port of `cleanError` (`src/lib/strings/errors.ts:28-80`): user-facing copy for an error.
///
/// RN matches substrings of `e.toString()`, which holds the error class, the XRPC error code and
/// the message, so a branch matches on the code or the message (review finding N9). The port builds
/// the same string from `XRPCError` and runs the same checks in the same order.
enum ErrorText {
    static func clean(_ error: any Error) -> String {
        switch error {
        case XRPCError.http(_, let code, let message):
            // RN's fallback for an XRPC error is `e.message || e.error` (`toDisplayString`, :18-26).
            let full = [code, message].compactMap { $0 }.joined(separator: ": ")
            return matched(full) ?? message ?? code ?? ""
        case let urlError as URLError where urlError.code != .cancelled:
            return cleanString("Network request failed")
        default:
            // XRPCError and InjectedFault are LocalizedError, so this is never "The operation
            // couldn't be completed" for the app's own errors (review finding N10).
            return cleanString(error.localizedDescription)
        }
    }

    static func cleanString(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        if let matched = matched(value) { return matched }
        if value.hasPrefix("Error: ") {
            return String(value.dropFirst("Error: ".count))
        }
        return value
    }

    /// The branches of `cleanError` before its fallback, in RN's order.
    private static func matched(_ value: String) -> String? {
        let networkMarkers = ["Abort", "Network request failed", "Failed to fetch", "fetch failed", "Load failed",
                              "Upstream service unreachable", "NetworkError when attempting to fetch resource"]
        if networkMarkers.contains(where: value.contains) {
            return "Unable to connect. Please check your internet connection and try again."
        }
        let upstreamMarkers = ["Upstream Failure", "UpstreamFailure", "NotEnoughResources", "pipethrough network error"]
        if upstreamMarkers.contains(where: value.contains) {
            return "The server appears to be experiencing issues. Please try again in a few moments."
        }
        // Review finding N8: the remaining branches (`errors.ts:55-74`).
        if value.contains("Do not have authorization to set preferences"),
           value.contains("app.bsky.actor.defs#personalDetailsPref") {
            return "You cannot update your birthdate while using an app password. Please sign in with your main password to update your birthdate."
        }
        if value.contains("Bad token scope") || value.contains("Bad token method") {
            return "This feature is not available while using an App Password. Please sign in with your main password."
        }
        if value.contains("Account has been suspended") { return "Account has been suspended" }
        if value.contains("Account is deactivated") { return "Account is deactivated" }
        if value.contains("Profile not found") { return "Profile not found" }
        if value.contains("Unable to resolve handle") { return "Unable to resolve handle" }
        return nil
    }
}

extension XRPCError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .http(_, let code, let message): message ?? code ?? "Request failed"
        case .invalidResponse(let detail): "Invalid response: \(detail)"
        case .invalidRequest(let detail): "Invalid request: \(detail)"
        case .sessionInvalidated: "Session ended"
        }
    }
}
