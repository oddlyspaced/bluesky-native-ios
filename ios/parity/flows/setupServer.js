// Reseeds the local dev network (copied from the RN e2e helpers). SERVER_PATH selects the seed.
// eslint-disable-next-line no-undef, typescript/no-unsafe-call, typescript/no-unsafe-member-access
http.post('http://localhost:1986/' + SERVER_PATH, {
  headers: {'Content-Type': 'text/plain'},
  body: '',
})
