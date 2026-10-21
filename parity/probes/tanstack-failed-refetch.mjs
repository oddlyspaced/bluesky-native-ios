/*
 * What does TanStack Query leave behind when `truncateAndInvalidate` truncates an infinite query
 * to page 1 and the refetch then fails?
 *
 * This is the shape of Bluesky's home feed on the parity `error` state: page 1 holds five posts
 * and a cursor, page 2 holds the fallback marker and no cursor, and after the reseed every
 * request fails. Both ports model the result as `hasNextPage = page1.cursor != null`. The
 * captured RN app logged zero `feed:endReached` and drew the end-of-feed block, which needs
 * `hasNextPage` false and `isError` false. This settles which of those the library produces.
 *
 * Run it against the RN app's own installed copy of the library, so the answer is the version RN
 * builds against and not a guess:
 *
 *   cd showcases/bluesky-social-app
 *   node --input-type=module -e "$(cat ../bluesky-native/parity/probes/tanstack-failed-refetch.mjs)"
 *
 * Measured on @tanstack/query-core 5.100.10:
 *
 *   after first load                   pages=1 items=5 hasNextPage=true  status=success isError=false
 *   after fetchNextPage (marker)       pages=2 items=6 hasNextPage=false status=success isError=false
 *   after truncate, before refetch     pages=1 items=5 hasNextPage=true  status=success isError=false
 *   after failed refetch               pages=1 items=5 hasNextPage=true  status=error   isError=true
 *
 * So a failed refetch over existing data IS an error state, and `hasNextPage` stays true. Neither
 * matches the captured RN screen, which is recorded as difference 2 in android/PARITY.md.
 */
import {InfiniteQueryObserver, QueryClient} from '@tanstack/query-core'

const queryKey = ['feed']
let dead = false

const client = new QueryClient({
  defaultOptions: {queries: {retry: false, gcTime: Infinity, staleTime: Infinity}},
})

const observer = new InfiniteQueryObserver(client, {
  queryKey,
  initialPageParam: undefined,
  // src/lib/api/feed/home.ts: Following runs out, so the page gets the marker and no cursor
  queryFn: async ({pageParam}) => {
    if (dead) throw new Error('HTTP 500 InternalServerError')
    if (!pageParam) return {cursor: 'CURSOR-1', feed: ['p1', 'p2', 'p3', 'p4', 'p5']}
    return {cursor: undefined, feed: ['fallback-marker-post']}
  },
  // src/state/queries/post-feed.ts
  getNextPageParam: last => (last.cursor ? {cursor: last.cursor} : undefined),
})
const unsubscribe = observer.subscribe(() => {})

function show(label) {
  const r = observer.getCurrentResult()
  console.log(
    `${label.padEnd(34)} pages=${r.data?.pages.length ?? 0}` +
      ` items=${r.data?.pages.flatMap(p => p.feed).length ?? 0}` +
      ` hasNextPage=${r.hasNextPage} status=${r.status} isError=${r.isError}`,
  )
}

await observer.refetch()
show('after first load')
await observer.fetchNextPage()
show('after fetchNextPage (marker)')

// src/state/queries/util.ts truncateAndInvalidate, verbatim
client.setQueriesData({queryKey}, data =>
  data ? {pageParams: data.pageParams.slice(0, 1), pages: data.pages.slice(0, 1)} : data,
)
show('after truncate, before refetch')

dead = true
await client.invalidateQueries({queryKey}).catch(() => {})
await new Promise(resolve => setTimeout(resolve, 50))
show('after failed refetch')

unsubscribe()
