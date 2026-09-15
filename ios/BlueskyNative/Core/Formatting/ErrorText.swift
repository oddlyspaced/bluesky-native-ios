import Foundation

/// Port of `cleanError` (`src/lib/strings/errors.ts:28-80`): user-facing copy for an error.
enum ErrorText {
    static func clean(_ error: any Error) -> String {
        if case XRPCError.http(_, let code, let message) = error {
            return cleanString(message ?? code ?? "")
        }
        if let urlError = error as? URLError, urlError.code != .cancelled {
            return cleanString("Network request failed")
        }
        return cleanString(error.localizedDescription)
    }

    static func cleanString(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        let networkMarkers = ["Abort", "Network request failed", "Failed to fetch", "fetch failed", "Load failed",
                              "Upstream service unreachable", "NetworkError when attempting to fetch resource"]
        if networkMarkers.contains(where: value.contains) {
            return "Unable to connect. Please check your internet connection and try again."
        }
        let upstreamMarkers = ["Upstream Failure", "UpstreamFailure", "NotEnoughResources", "pipethrough network error"]
        if upstreamMarkers.contains(where: value.contains) {
            return "The server appears to be experiencing issues. Please try again in a few moments."
        }
        if value.contains("Bad token scope") || value.contains("Bad token method") {
            return "This feature is not available while using an App Password. Please sign in with your main password."
        }
        if value.hasPrefix("Error: ") {
            return String(value.dropFirst("Error: ".count))
        }
        return value
    }
}
