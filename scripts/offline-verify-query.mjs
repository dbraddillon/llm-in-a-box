// Run inside the offline-verify container by verify-offline.ps1 (docker exec ... node
// this-file). A real HTTP request, not a health check -- proves the whole chain
// (retrieval embedder -> sqlite scan -> llama-server -> streamed response) works with
// zero network access. Baked into the box's Docker image as a plain file rather than
// passed as an inline -e string, since PowerShell's native-argument quoting mangles a
// multi-line double-quoted JS string passed through `docker exec`.
fetch('http://127.0.0.1:7860/api/chat', {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ message: 'What information do you have access to?', history: [] }),
})
  .then(async (r) => {
    const text = await r.text();
    console.log(JSON.stringify({ status: r.status, sources: r.headers.get('x-sources'), text }));
  })
  .catch((e) => {
    console.log(JSON.stringify({ error: e.message }));
    process.exitCode = 1;
  });
