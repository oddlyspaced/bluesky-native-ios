// API setup step for parity states that no upstream seed creates (review findings F7, F9).
// Runs right after the seed step, under the seed lock that run-pair.sh holds. It writes records
// through the PDS XRPC API only; the upstream repository is not changed.
//
// SETUP selects the records:
//   wrapped  alice posts one text that wraps to three lines in the feed (F7)
//   api      bob reposts a carla post (reason row), bob gates replies on "Thread root" (reply
//            disabled), alice posts text with link, mention and tag facets, and alice's bio gets
//            the same facets (F4, F9)
/* eslint-disable no-undef */
var PDS = 'http://localhost:3000/xrpc/'

function call(method, token, body) {
  var headers = {'Content-Type': 'application/json'}
  if (token) headers.Authorization = 'Bearer ' + token
  var response = http.post(PDS + method, {headers: headers, body: JSON.stringify(body)})
  if (!response.ok) throw new Error(method + ' failed: ' + response.status + ' ' + response.body)
  return json(response.body)
}

function get(method, query) {
  var response = http.get(PDS + method + '?' + query)
  if (!response.ok) throw new Error(method + ' failed: ' + response.status + ' ' + response.body)
  return json(response.body)
}

// Wall-clock bound for one AppView wait, and the gap between two polls (review finding A90).
// APPVIEW_TIMEOUT (--env) shortens the bound for a test of this file.
var APPVIEW_TIMEOUT_MS = typeof APPVIEW_TIMEOUT === 'undefined' ? 60000 : Number(APPVIEW_TIMEOUT)
var APPVIEW_POLL_MS = 500

function report(message) {
  output.setupLog = (output.setupLog ? output.setupLog + '\n' : '') + message
  if (typeof console !== 'undefined' && console.log) console.log(message)
}

function pace(until) {
  // Maestro's script runtime has no timer, so this is the only way to leave a gap between two
  // polls. It never decides how long the wait runs: waitForAppView stops at its own deadline.
  while (Date.now() < until) {
    // wait
  }
}

// The records are written to the PDS, but both apps read the timeline through the AppView, which
// indexes from the firehose. Without this wait a flow can launch before the new rows exist and then
// fail to find them (review findings F7, F9). The wait is bounded by the wall clock and reports
// what it waited for, how long it took and how many polls it made (review finding A90).
function waitForAppView(token, what, needle) {
  var url = PDS + 'app.bsky.feed.getTimeline?limit=30'
  var started = Date.now()
  var polls = 0
  var last = 'no response'
  while (Date.now() - started < APPVIEW_TIMEOUT_MS) {
    var next = Date.now() + APPVIEW_POLL_MS
    polls++
    var response = http.get(url, {
      headers: {
        Authorization: 'Bearer ' + token,
        'atproto-proxy': 'did:plc:bw7ad3erl7btq6qwf66yqiov#bsky_appview',
      },
    })
    last = 'status ' + response.status
    if (response.ok && response.body.indexOf(needle) !== -1) {
      report('setupApi: the AppView indexed ' + what + ' after ' + (Date.now() - started) +
        ' ms in ' + polls + ' polls')
      return true
    }
    pace(next)
  }
  throw new Error('setupApi: waited ' + (Date.now() - started) + ' ms in ' + polls + ' polls for ' +
    what + ' in the timeline (needle "' + needle + '", last ' + last + '). The AppView did not index it.')
}

function login(handle) {
  var session = call('com.atproto.server.createSession', null, {identifier: handle, password: 'hunter2'})
  return {did: session.did, token: session.accessJwt}
}

function now() {
  return new Date().toISOString()
}

function findPost(handle, text) {
  var page = get('com.atproto.repo.listRecords', 'repo=' + handle + '&collection=app.bsky.feed.post&limit=100')
  for (var i = 0; i < page.records.length; i++) {
    if (text === null || page.records[i].value.text === text) return page.records[i]
  }
  throw new Error('no post by ' + handle + ' with text ' + text)
}

// Byte offsets of an ASCII substring (every facet text below is ASCII).
function range(text, part) {
  var start = text.indexOf(part)
  return {byteStart: start, byteEnd: start + part.length}
}

function facets(text, bobDid) {
  return [
    {index: range(text, '@bob.test'), features: [{$type: 'app.bsky.richtext.facet#mention', did: bobDid}]},
    {index: range(text, 'example.com/parity'),
      features: [{$type: 'app.bsky.richtext.facet#link', uri: 'https://example.com/parity'}]},
    {index: range(text, '#parity'), features: [{$type: 'app.bsky.richtext.facet#tag', tag: 'parity'}]},
  ]
}

var alice = login('alice.test')

if (SETUP === 'wrapped') {
  call('com.atproto.repo.createRecord', alice.token, {
    repo: alice.did,
    collection: 'app.bsky.feed.post',
    record: {
      $type: 'app.bsky.feed.post',
      text: 'Wrapped text check for the parity report: this post is long enough to wrap onto three lines in the feed row.',
      createdAt: now(),
    },
  })
  waitForAppView(alice.token, 'the wrapped post', 'Wrapped text check for the parity report')
} else if (SETUP === 'api') {
  var bob = login('bob.test')

  var carlaPost = findPost('carla.test', null)
  call('com.atproto.repo.createRecord', bob.token, {
    repo: bob.did,
    collection: 'app.bsky.feed.repost',
    record: {$type: 'app.bsky.feed.repost', subject: {uri: carlaPost.uri, cid: carlaPost.cid}, createdAt: now()},
  })

  var root = findPost('bob.test', 'Thread root')
  call('com.atproto.repo.createRecord', bob.token, {
    repo: bob.did,
    collection: 'app.bsky.feed.threadgate',
    rkey: root.uri.split('/').pop(),
    record: {$type: 'app.bsky.feed.threadgate', post: root.uri, allow: [], createdAt: now()},
  })

  var postText = 'Facets: @bob.test example.com/parity #parity'
  call('com.atproto.repo.createRecord', alice.token, {
    repo: alice.did,
    collection: 'app.bsky.feed.post',
    record: {$type: 'app.bsky.feed.post', text: postText, facets: facets(postText, bob.did), createdAt: now()},
  })

  var profile = get('com.atproto.repo.getRecord', 'repo=' + alice.did + '&collection=app.bsky.actor.profile&rkey=self')
  var record = profile.value
  record.description = 'Bio facets: @bob.test example.com/parity #parity'
  call('com.atproto.repo.putRecord', alice.token, {
    repo: alice.did, collection: 'app.bsky.actor.profile', rkey: 'self', record: record,
  })

  // The timeline must show the facets post and bob's repost before the flow launches an app.
  waitForAppView(alice.token, 'the facets post', 'Facets: ')
  waitForAppView(alice.token, "bob's repost reason row", 'app.bsky.feed.defs#reasonRepost')
} else {
  throw new Error('unknown SETUP ' + SETUP)
}
output.setupDone = SETUP
