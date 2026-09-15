import Foundation

enum AppConfig {
    #if E2E
    /// PDS used by the debug sign-in controls (the local dev network). Debug builds only.
    static let e2eService = URL(string: "http://localhost:3000")!
    /// `E2E_APPVIEW_DID` from RN `dev-env/constants.ts`, as set by `TestCtrls.e2e.tsx`.
    static let appViewProxy: String? = "did:plc:bw7ad3erl7btq6qwf66yqiov#bsky_appview"
    #else
    /// RN default `BLUESKY_PROXY_DID` (`src/lib/constants.ts`).
    static let appViewProxy: String? = "did:web:api.bsky.app#bsky_appview"
    #endif
}
