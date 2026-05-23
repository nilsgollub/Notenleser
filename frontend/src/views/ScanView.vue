<template>
  <div class="scan-view">
    <div v-if="!jobId" class="upload-section">
      <h2 class="section-title">Noten scannen</h2>

      <!-- Drop-Zone / Kamera -->
      <div
        class="drop-zone card"
        :class="{ dragging, 'has-file': previewUrl }"
        @dragover.prevent="dragging = true"
        @dragleave="dragging = false"
        @drop.prevent="onDrop"
        @click="triggerFile"
      >
        <img v-if="previewUrl" :src="previewUrl" class="preview-img" alt="Vorschau" />
        <template v-else>
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--primary)" stroke-width="1.5">
            <rect x="3" y="3" width="18" height="18" rx="3"/>
            <path d="M12 8v8M8 12h8"/>
          </svg>
          <p class="drop-text">Foto hierher ziehen oder<br><strong>antippen zum Auswählen</strong></p>
          <p class="drop-sub">JPG, PNG, PDF</p>
        </template>
        <input ref="fileInput" type="file" accept="image/*,application/pdf" @change="onFileChange" hidden />
      </div>

      <!-- Kamera-Button (mobil) -->
      <button class="btn btn-ghost camera-btn" @click="triggerCamera">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
          <circle cx="12" cy="13" r="4"/>
        </svg>
        Kamera öffnen
      </button>
      <input ref="cameraInput" type="file" accept="image/*" capture="environment" @change="onFileChange" hidden />

      <!-- Titel -->
      <div class="field">
        <label>Titel (optional)</label>
        <input v-model="title" type="text" placeholder="z. B. Hänschen Klein" />
      </div>

      <button class="btn btn-primary upload-btn" :disabled="!file" @click="startScan">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M4 14.899A7 7 0 1 1 15.71 8h1.79a4.5 4.5 0 0 1 2.5 8.242M12 12v9M8 17l4-5 4 5"/>
        </svg>
        Scan starten
      </button>
    </div>

    <!-- Fortschritt -->
    <div v-else class="progress-section">
      <ScanProgress :status="scanStatus" />

      <div v-if="scanStatus === 'done'" class="done-actions">
        <p class="done-text">Lied wurde erfasst!</p>
        <router-link :to="`/songs/${songId}`" class="btn btn-primary">Jetzt anhören</router-link>
        <button class="btn btn-ghost" @click="reset">Weiteres Lied scannen</button>
      </div>

      <div v-if="scanStatus?.startsWith('error')" class="done-actions">
        <p class="error-text">Scan fehlgeschlagen. Bitte besseres Bild versuchen.</p>
        <button class="btn btn-ghost" @click="reset">Nochmal versuchen</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useSongsStore } from '../stores/songs.js'
import ScanProgress from '../components/ScanProgress.vue'

const store = useSongsStore()
const fileInput = ref(null)
const cameraInput = ref(null)

const file = ref(null)
const previewUrl = ref(null)
const title = ref('')
const dragging = ref(false)
const jobId = ref(null)
const songId = ref(null)
const scanStatus = ref('pending')
let ws = null

function triggerFile() { fileInput.value?.click() }
function triggerCamera() { cameraInput.value?.click() }

function onDrop(e) {
  dragging.value = false
  const f = e.dataTransfer?.files?.[0]
  if (f) setFile(f)
}

function onFileChange(e) {
  const f = e.target.files?.[0]
  if (f) setFile(f)
}

function setFile(f) {
  file.value = f
  previewUrl.value = URL.createObjectURL(f)
  if (!title.value) title.value = f.name.replace(/\.[^.]+$/, '')
}

async function startScan() {
  if (!file.value) return
  const result = await store.uploadScan(file.value, title.value)
  jobId.value = result.job_id
  songId.value = result.song_id
  scanStatus.value = 'pending'
  connectWs(result.job_id)
}

function connectWs(id) {
  const proto = location.protocol === 'https:' ? 'wss' : 'ws'
  ws = new WebSocket(`${proto}://${location.host}/scan/ws/${id}`)
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data)
    scanStatus.value = msg.status
    if (msg.status === 'done' || msg.status?.startsWith('error')) ws.close()
  }
  ws.onerror = () => { scanStatus.value = 'error:Verbindung unterbrochen' }
}

function reset() {
  if (ws) ws.close()
  file.value = null
  previewUrl.value = null
  title.value = ''
  jobId.value = null
  songId.value = null
  scanStatus.value = 'pending'
}
</script>

<style scoped>
.scan-view { padding: 20px; max-width: 520px; margin: 0 auto; }
.section-title { font-size: 1.4rem; font-weight: 700; margin-bottom: 20px; }
.drop-zone {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  min-height: 220px;
  border: 2px dashed var(--border);
  cursor: pointer;
  padding: 32px;
  transition: border-color var(--transition), background var(--transition);
  text-align: center;
  overflow: hidden;
}
.drop-zone:hover, .drop-zone.dragging {
  border-color: var(--primary);
  background: var(--primary-dim);
}
.drop-zone.has-file { padding: 0; border-style: solid; border-color: var(--primary); }
.drop-text { font-size: 0.95rem; color: var(--text-secondary); }
.drop-sub { font-size: 0.8rem; color: var(--text-secondary); }
.preview-img { width: 100%; height: 100%; object-fit: contain; max-height: 280px; }
.camera-btn { width: 100%; justify-content: center; margin-top: 10px; }
.field { margin-top: 18px; display: flex; flex-direction: column; gap: 6px; }
.field label { font-size: 0.85rem; font-weight: 500; color: var(--text-secondary); }
.field input { width: 100%; }
.upload-btn { width: 100%; justify-content: center; margin-top: 18px; padding: 14px; font-size: 1rem; }
.progress-section { padding-top: 20px; display: flex; flex-direction: column; gap: 20px; }
.done-actions { display: flex; flex-direction: column; gap: 12px; align-items: center; }
.done-text { font-size: 1rem; font-weight: 600; color: var(--success); }
.error-text { font-size: 0.9rem; color: var(--error); text-align: center; }
.btn { width: 100%; justify-content: center; }
</style>
