import Foundation

enum AppConfig {
    /// PDS used by the debug sign-in controls (the local dev network).
    static let e2eService = URL(string: "http://localhost:3000")!

    #if E2E
    /// `E2E_APPVIEW_DID` from RN `dev-env/constants.ts`, as set by `TestCtrls.e2e.tsx`.
    static let appViewProxy: String? = "did:plc:kmmukaomzqnk3fln2m5guony#bsky_appview"
    #else
    /// RN default `BLUESKY_PROXY_DID` (`src/lib/constants.ts`).
    static let appViewProxy: String? = "did:web:api.bsky.app#bsky_appview"
    #endif
}
