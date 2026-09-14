# Parity review 1: CP-00 to CP-03, iOS

- Reviewer: `parity-reviewer` agent (Nativestarter Migration Pack), run on 2026-09-15
- Code reviewed: `ios/` at commit `9fead7d`, against bluesky-social/social-app at `2bfb94d`
- Verdict: **Blockers found: 14**
- Paths: native paths are relative to `ios/BlueskyNative/` unless they start with `ios/`. RN paths are relative to the upstream repo.

## Blockers

| # | Area | Finding | Native evidence | RN reference | Fix |
|---|---|---|---|---|---|
| P1 | Visual, thread | No "Write your reply" prompt above the bottom bar; the border under the last reply is missing (RN y 1105). PARITY.md wrongly says no element is missing. | `Features/Thread/ThreadScreen.swift:34-40`; `ios/parity/shots/ios-thread.png` (diff AE 9,606 in y 2200–2378) | `src/screens/PostThread/index.tsx:694-696`, `:610-627` | Put the prompt in the shell bottom inset above BottomBar. Add the footer border. Correct PARITY.md. |
| P2 | Visual, home gate | Home 0.0342 is above the 0.02 threshold. Each feed row is 1 px taller, so the rows drift +5 px by the bottom (borders RN 645/1166/1439/1712/1985/2169, native 646/1169/1443/1717/1990/2174). Shifting native −5 px cuts AE in y 1975–2370 from 47,865 to 25,742. | `Features/Post/PostViews.swift:36-38` (sub-point offsets), `Features/Feed/PostFeedItemView.swift:37` | `src/view/com/posts/PostFeedItem.tsx:280-291,579-601`; `src/view/com/util/PostMeta.tsx:63-72` | Make each plain row exactly 273 px at 3x. Verify on border rows. Remeasure. |
| P3 | Data, home | Feed tuners missing: only dedup is ported. removeOrphans, followedRepliesOnly, removeMutedThreads and the hideReposts/hideReplies/hideQuotePosts preferences are absent. | `Features/Feed/FeedTuner.swift:66-89` | `src/state/preferences/feed-tuners.tsx:27-46`; `src/lib/api/feed-manip.ts:542-566` | Port the tuners and preferences, with tests. |
| P4 | Behaviour, time-ago | `TimelineView(.everyMinute)` passes the start of the minute, so posts under 60 s show "now" (RN shows "10s"). Minute and hour boundaries read low. The mask hid this. | `Features/Post/PostViews.swift:23-31`; `ios/parity/compare.sh:27` | `src/view/com/util/TimeElapsed.tsx:18-22`; `src/lib/hooks/useTimeAgo.ts:56-66` | Compute from `Date()` at render; tick every 60 s from mount; add a test. |
| P5 | Errors, pagination | A failed loadMore sets hasMore=false and shows "You've reached the end of your feed!" with no retry. | `Features/Feed/FeedModel.swift:73-76`; `Features/Feed/HomeScreen.swift:55-59` | `src/view/com/posts/PostFeed.tsx:688-693,822-828,950-951` | Load-more error row with retry; keep hasMore; hide end-of-feed on error. |
| P6 | Events | The native app sends no analytics events, and the report has no event diff. | grep `metric|analytics|logEvent` in `ios/BlueskyNative` → none | `src/state/queries/post.ts:201,238,326,350`; `src/components/PostControls/index.tsx:176,228`; `src/view/com/posts/PostFeedItem.tsx:216,255`; `src/view/shell/bottom-bar/BottomBar.tsx:99`; `src/view/com/posts/PostFeed.tsx:748,776`; `src/view/screens/Home.tsx:178`; `src/view/com/feeds/ComposerPrompt.tsx:40` | Port event calls with the same names and properties to a local event log; add an event diff. |
| P7 | Visual, dark mode | The app forces light mode; RN follows the system. Not recorded or accepted. | `Info.plist:41-42` | `src/state/shell/color-mode.tsx:15` | Port light, dark and dim themes. |
| P8 | Data, records | Like and repost records have no `via`; the repost reason `uri`/`cid` is not decoded, so reposters get no notification. | `Core/Networking/BlueskyAPI.swift:138-147`; `Core/Models/Lexicon.swift:127-141` | `src/state/queries/post.ts:136-140,220-224`; `src/view/com/posts/PostFeedItem.tsx:306-317` | Decode the reason, pass `viaRepost`, encode `via`. |
| P9 | Behaviour, thread API | Uses getPostThread (depth 10, parentHeight 10) and flattens it: no `sort: top` or OP-first order, no hidden or "other replies" bucket, blocked or not-found items dropped silently. | `Core/Networking/BlueskyAPI.swift:96-103`; `Features/Thread/ThreadModel.swift:65-94` | `src/state/queries/usePostThread/index.ts:78-83,118,191-200`; `const.ts`; `preferences/useThreadPreferences.ts:40` | Use `app.bsky.unspecced.getPostThreadV2` with the same parameters; render tombstones and other replies. |
| P10 | Behaviour, back | The hidden navigation bar disables swipe-back. | `Features/Thread/ThreadScreen.swift:42` | native-stack gesture, `src/Navigation.tsx` | Keep the interactive pop gesture. |
| P11 | Visual, profile | The bottom-bar top border is missing on Profile after visiting a thread; the flag is tied to onAppear/onDisappear while the home stack stays alive. | `Features/Thread/ThreadScreen.swift:44-45`; `Features/Shell/TabShell.swift:62-68` | `src/screens/PostThread/components/ThreadComposePrompt.tsx:37` | Derive the flag from the selected tab and route. |
| P12 | Visual, thread | The anchor has no engagement stats row ("N reposts / N quotes / N likes / N saves"). | `Features/Thread/ThreadScreen.swift:99-123` | `src/screens/PostThread/components/ThreadItemAnchor.tsx:439-512`; `LikesStat.tsx:22-40` | Port the stats row; capture both apps after the interaction flow. |
| P13 | Accessibility, font scale | Fixed font sizes with no Dynamic Type. | `DesignSystem/Typography.swift:19-35` | `src/components/Typography.tsx:26,40` | Scale with UIFontMetrics, matching RN's multiplier and cap. |
| P14 | Visual, content | Rich text facets and embeds are not rendered, and the spec does not put them out of scope. | `Features/Post/PostViews.swift:51-63` | `src/view/com/posts/PostFeedItem.tsx:523-573` | Port facets. Record embeds in the spec with an acceptor, or port them. |

## Major

| # | Area | Finding | Native evidence | RN reference |
|---|---|---|---|---|
| P15 | Copy | Never "Reposted by you", "Replied to you" or "Replied to a blocked post"; the pin reason renders nothing. | `Features/Feed/PostFeedItemView.swift:80-106`; `Core/Networking/BlueskyAPI.swift:90` | `src/view/com/posts/PostFeedReason.tsx`; `src/components/Post/PostRepliedTo.tsx:27-45` |
| P16 | Errors, feed | Raw server message on first-load error; a failed refresh with rows present is silent. | `Features/Feed/HomeScreen.swift:36-37,216-231`; `Features/Feed/FeedModel.swift:58-62,105-108` | `src/view/com/posts/PostFeedErrorMessage.tsx`; `ErrorMessage.tsx:29,53-55`; `src/lib/strings/errors.ts:39-54` |
| P17 | Errors, thread | Thread failure shows feed copy; not-found retry does nothing. | `Features/Thread/ThreadScreen.swift:53-56`; `ThreadModel.swift:55-58` | `src/screens/PostThread/components/ThreadError.tsx:26-35,75-86` |
| P18 | States, thread | Feed skeleton instead of cached anchor plus reply skeletons; pull-to-refresh that RN does not have. | `Features/Thread/ThreadScreen.swift:32,52` | `src/state/queries/usePostThread/index.ts:141-151`; `src/screens/PostThread/index.tsx:580-640` |
| P19 | States, profile | Profile status is never read: no error screen, placeholder or RN empty state. | `Features/Profile/ProfileScreen.swift:63-88,144,233-239` | `src/view/screens/Profile.tsx:131-156,437-452`; `src/screens/Profile/Header/Shell.tsx` |
| P20 | States, empty | An empty Following feed hides the end-of-feed block because the fallback marker is not a row. | `Features/Feed/HomeScreen.swift:52-59` | `src/lib/api/feed/home.ts:95-101`; `PostFeed.tsx:950-951` |
| P21 | Post shadow | `reset(uris:)` is never called, so local state overrides fresh server state for the session. | `Features/Post/PostShadowStore.swift:40-42` | `src/state/cache/post-shadow.ts:37-40,50-56` |
| P22 | Rollback | `try? deleteLike` hides a failed compensating delete. | `Features/Post/PostShadowStore.swift:107-112,140-144` | `src/lib/hooks/useToggleMutationQueue.ts:59-71` |
| P23 | Control guards | No blocked toast, replyDisabled or embeddingDisabled handling. | `Features/Post/PostViews.swift:82-103,180-185` | `src/components/PostControls/index.tsx:91-108,215-221`; `RepostButton.tsx:170-200` |
| P24 | Gestures | No long-press quote, haptics, like icon animation or count wheel. | `Features/Post/PostViews.swift:142-162` | `RepostButton.tsx:47-54`; `PostControlButton.tsx:62-76`; `index.tsx:291-305` |
| P25 | Long text | No MAX_POST_LINES limit or "Show more". | `Features/Post/PostViews.swift:51-63` | `src/view/com/posts/PostFeedItem.tsx:496-548`; `ThreadItemPost.tsx` |
| P26 | Soft reset | Re-tapping the active tab or the header mark does not scroll to top and refresh. | `Features/Shell/TabShell.swift:124-133`; `Features/Feed/HomeScreen.swift:70` | `src/view/shell/bottom-bar/BottomBar.tsx:103-106`; `HomeHeaderLayoutMobile.tsx` |
| P27 | Unread badge | Loaded once; no 30 s poll, no app-active refresh, no chat badge. | `Features/Shell/TabShell.swift:100-103,160-163`; `BottomBar.swift:26-28` | `src/state/queries/notifications/unread.tsx:28,88-93,141-150` |
| P28 | Session refresh | Parallel refreshes with one single-use refresh token; a failed refresh does not sign out. | `Core/Networking/BlueskyAPI.swift:185-201` | `src/state/session/index.tsx` |
| P29 | Header | The header and bottom bar do not hide on scroll. | `Features/Feed/HomeScreen.swift:24` | `HomeHeaderLayoutMobile.tsx` (minimal shell transform) |
| P30 | Accessibility | Bottom bar has labels only: no tab role and no unread hint. | `Features/Shell/BottomBar.swift:85-87` | `BottomBar.tsx:195-197,215-217,241-259,278-290` |
| P31 | Accessibility | Labels differ ("Share" vs "Invite friends"; missing "Edit profile", avatar, banner and "View profile" labels). | `Features/Profile/ProfileScreen.swift:105-134`; `DesignSystem/UserAvatar.swift:33`; `Features/Post/PostViews.swift:14-22` | `ProfileHeaderStandard.tsx:336,358`; `Shell.tsx:161-166,255-259`; `PostMeta.tsx:93,121` |
| P32 | testIDs | Missing likeCount, repostCount, *-expanded, errorMessageTryAgainButton, homeScreen, followingFeedPage, postsFeed, postsFeed-flatlist, profileScreen, profileErrorScreen, homeScreenFeedTabs-selector and the item IDs. | `Features/Post/PostViews.swift:147-153`; `DesignSystem/Components.swift:92,108` | `index.tsx:301`; `RepostButton.tsx:90`; `TabBar.tsx:326,439,447`; `Home.tsx:95,280,320`; `Sections/Feed.tsx:101` |
| P33 | Evidence | Icon masks cover whole control rows, including counts; masks do not follow the drift; no same-build noise floor. | `ios/parity/compare.sh:48,55-56,60`; `PARITY.md:71` | – |
| P34 | Evidence | No captures of loading, error, empty, load-more, refresh, reason rows, long text, dark mode, large text or interaction states in either app. | spec `plan/slice-plan.md` | – |
| P35 | Recorded differences | The accepted-differences table names no acceptor; some rows are wrong. | `PARITY.md:69-93` | `plan/slice-plan.md` gate |

## Minor

| # | Finding | Native evidence | RN reference |
|---|---|---|---|
| P36 | Thread reply row 3 px high (11 pt spacer vs 12); profile tab hairline and home bottom-bar border 1 px off. | `Features/Thread/ThreadScreen.swift:147-148` | `ThreadItemPost.tsx` |
| P37 | Empty display name shows blank on the anchor; incomplete-thread "Replied to" rule. | `Features/Thread/ThreadScreen.swift:86`; `Features/Feed/FeedModel.swift:146` | `ThreadItemAnchor.tsx:357-359`; `PostFeed.tsx:657-659` |
| P38 | Composer prompt camera and image are not separate actions; repost label counts reposts only. | `Features/Feed/HomeScreen.swift:99-122`; `Features/Post/PostViews.swift:93` | `ComposerPrompt.tsx:161,215,237`; `RepostButton.tsx:69-85` |
| P39 | Count formatting fixed to en_US. | `Core/Formatting/Formatting.swift:45` | `src/components/PostControls/util.ts:15-19` |

## Commands the reviewer ran

- `compare.sh` reproduced PARITY.md exactly: home 0.0512/0.0465/0.0342, thread 0.0212/0.0168/0.0109, profile 0.0191/0.0165/0.0123.
- Border-row and band profiles with `magick -scale 1xN txt:` found the +1 px per row drift, the missing thread border and prompt, and the missing profile bar border.
- Not run: xcodebuild tests, Maestro, live server interactions, Android.
