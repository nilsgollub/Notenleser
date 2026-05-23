<template>
  <div class="sheet-wrapper">
    <div v-if="loading" class="sheet-loading">
      <div class="spinner"></div>
      <p>Noten werden geladen…</p>
    </div>
    <div v-if="error" class="sheet-error">{{ error }}</div>
    <div ref="containerRef" class="sheet-container" :class="{ hidden: loading || error }"></div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'

const props = defineProps({
  musicxmlUrl: String,
  cursorVisible: { type: Boolean, default: false },
})

const emit = defineEmits(['ready', 'cursor-update'])

const containerRef = ref(null)
const loading = ref(true)
const error = ref(null)
let osmd = null

onMounted(async () => {
  if (!props.musicxmlUrl) return
  await initOSMD()
})

onUnmounted(() => {
  osmd = null
})

watch(() => props.cursorVisible, (v) => {
  if (!osmd) return
  if (v) { osmd.cursor.show() } else { osmd.cursor.hide() }
})

async function initOSMD() {
  loading.value = true
  error.value = null
  try {
    const { OpenSheetMusicDisplay } = await import('opensheetmusicdisplay')
    osmd = new OpenSheetMusicDisplay(containerRef.value, {
      autoResize: true,
      drawTitle: true,
      drawComposer: true,
      drawCredits: false,
      followCursor: true,
      cursorOptions: [{ type: 0, color: '#ffd700', alpha: 0.55 }],
    })
    const res = await fetch(props.musicxmlUrl)
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const xml = await res.text()
    await osmd.load(xml)
    osmd.render()
    emit('ready', osmd)
  } catch (e) {
    error.value = `Noten konnten nicht geladen werden: ${e.message}`
  } finally {
    loading.value = false
  }
}

// Öffentliche Methoden für den Player
function getCursorRef() { return osmd?.cursor }
function resetCursor() { osmd?.cursor.reset() }
function nextCursor() { osmd?.cursor.next() }

defineExpose({ getCursorRef, resetCursor, nextCursor })
</script>

<style scoped>
.sheet-wrapper { position: relative; width: 100%; }
.sheet-loading, .sheet-error {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 48px 24px;
  color: var(--text-secondary);
}
.sheet-error { color: var(--error); }
.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--primary-dim);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.sheet-container { width: 100%; background: #fff; border-radius: var(--radius); }
.sheet-container.hidden { visibility: hidden; height: 0; overflow: hidden; }

/* OSMD Karaoke-Cursor gold + Puls */
:deep(.vf-cursor) {
  opacity: 0.55;
  animation: cursor-pulse 1s ease-in-out infinite;
}
@keyframes cursor-pulse {
  0%, 100% { opacity: 0.55; }
  50% { opacity: 0.85; }
}
</style>
