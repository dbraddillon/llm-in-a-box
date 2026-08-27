<script setup>
import { ref, onMounted } from 'vue';

const manifest = ref({ packs: [], models: [] });
const log = ref('');

async function loadManifest() {
  const res = await fetch('/api/manifest');
  manifest.value = await res.json();
}

function runStream(url) {
  log.value += `\n--- running ${url} ---\n`;
  const es = new EventSource(url);
  es.onmessage = (e) => {
    const line = JSON.parse(e.data);
    log.value += line;
    if (line.startsWith('__done__')) es.close();
  };
  es.onerror = () => es.close();
}

function fetchContent(pack) { runStream(`/api/run/fetch-content?pack=${pack}`); }
function buildPack(pack) { runStream(`/api/run/build-pack?pack=${pack}`); }
function fetchModel(model) { runStream(`/api/run/fetch-model?model=${model}`); }

onMounted(loadManifest);
</script>

<template>
  <main>
    <h1>LLM in a Box — Builder</h1>
    <p>This is a UI wrapper only. Every button here just runs the same scripts you could run by hand.</p>

    <section>
      <h2>Packs</h2>
      <div v-for="p in manifest.packs" :key="p.dir">
        <strong>{{ p.label ?? p.id }}</strong> ({{ p.dir }})
        <button @click="fetchContent(p.dir)">Fetch content</button>
        <button @click="buildPack(p.dir)">Build index</button>
      </div>
    </section>

    <section>
      <h2>Models</h2>
      <div v-for="m in manifest.models" :key="m.id">
        <strong>{{ m.label }}</strong> — ~{{ m.approx_size_gb }} GB, {{ m.min_ram_gb }} GB RAM min
        <button @click="fetchModel(m.id)">Fetch model</button>
      </div>
    </section>

    <section>
      <h2>Log</h2>
      <pre>{{ log }}</pre>
    </section>
  </main>
</template>

<style>
body { font-family: system-ui, sans-serif; max-width: 800px; margin: 2rem auto; }
pre { background: #111; color: #0f0; padding: 1rem; min-height: 200px; white-space: pre-wrap; }
</style>
