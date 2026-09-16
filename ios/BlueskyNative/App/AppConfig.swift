import Foundation

enum AppConfig {
    #if E2E
    /// PDS used by the debug sign-in controls (the local dev network). Debug builds only.
    static let e2eService = URL(string: "http://localhost:3000")!
    /// `E2E_APPVIEW_DID` from RN `dev-env/constants.ts`, as set by `TestCtrls.e2e.tsx`.
    static let appViewProxy: String? = "did:plc:bw7ad3erl7btq6qwf66yqiov#bsky_appview"
    /// The dev network's handles end in `.test`, which is not a real top-level domain. Only the
    /// E2E build treats it as one, so mentions linkify in a capture (review finding A67).
    static let treatsTestTLDAsValid = true
    #else
    /// RN default `BLUESKY_PROXY_DID` (`src/lib/constants.ts`).
    static let appViewProxy: String? = "did:web:api.bsky.app#bsky_appview"
    /// Release matches the SDK: `.test` is not a top-level domain, so such mentions stay plain
    /// text (review finding A67).
    static let treatsTestTLDAsValid = false
    #endif
}
