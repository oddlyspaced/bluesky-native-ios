# Notice

This repository contains a native SwiftUI and Jetpack Compose port of part of the Bluesky Social app. It is a showcase of the Nativestarter Migration Pack.

Not affiliated with, endorsed by, or officially connected to Bluesky Social PBC. "Bluesky" and the butterfly logo are trademarks of Bluesky Social PBC. This repository uses the name only to identify the app it was ported from.

## Upstream

- Project: bluesky-social/social-app (https://github.com/bluesky-social/social-app)
- Commit: 2bfb94d (2026-09-14)
- Licence: MIT for source code, with the asset carve-outs in the upstream `ASSETS.md`

The port reuses upstream source code only: the design tokens in `src/alf` and the UI structure of the ported screens. The upstream MIT licence applies to that material.

The port does not include these upstream assets, because the MIT licence does not cover them (`ASSETS.md` sections 2 and 3):

- The UI icon glyphs in `assets/icons/`. They are the Central icon system by Iconists, licensed to Bluesky for its own use only. The native apps use an openly licensed icon set instead. Its licence file is kept next to the icons.
- The Bluesky logo, logomark, app icons, default avatar, verification checks and starter pack marks. The native apps use a neutral placeholder mark.

These substitutions are recorded as accepted design differences in `ios/PARITY.md` and `android/PARITY.md`.

The upstream MIT licence:

```
Copyright 2023–2026 Bluesky Social PBC

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

## Inter

The Inter typeface is by Rasmus Andersson and is licensed under the SIL Open Font License 1.1 (https://github.com/rsms/inter). The font files keep their licence.

## Screenshots

`parity/baseline/rn/` holds screenshots of the upstream React Native app. They show test data from the upstream e2e dev network (users alice.test, bob.test, carla.test). They hold no real user data.
