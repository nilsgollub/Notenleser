<template>
  <div class="scan-progress card">
    <div class="progress-header">
      <div class="spinner" v-if="status !== 'done' && !isError"></div>
      <svg v-if="status === 'done'" class="check" width="24" height="24" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="11" fill="var(--success)" opacity="0.2"/>
        <path d="M7 12l3.5 3.5L17 8" stroke="var(--success)" stroke-width="2.5" stroke-linecap="round"/>
      </svg>
      <svg v-if="isError" class="err-icon" width="24" height="24" viewBox="0 0 24 24" fill="none">
        <circle cx="12" cy="12" r="11" fill="var(--error)" opacity="0.2"/>
        <path d="M12 8v4M12 16h.01" stroke="var(--error)" stroke-width="2.5" stroke-linecap="round"/>
      </svg>
      <span class="label">{{ label }}</span>
    </div>
    <div class="bar-track">
      <div class="bar-fill" :style="{ width: progress + '%' }" :class="{ error: isError }"></div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({ status: String })

const steps = ['omr', 'metadata', 'timing', 'midi', 'audio', 'done']
const labels = {
  pending: 'Warte auf Start…',
  omr: 'Noten werden erkannt…',
  metadata: 'Metadaten werden ausgelesen…',
  timing: 'Timing wird berechnet…',
  midi: 'MIDI wird erzeugt…',
  audio: 'Audio wird gerendert…',
  done: 'Fertig!',
}

const isError = computed(() => props.status?.startsWith('error'))
const label = computed(() => {
  if (isError.value) return 'Fehler beim Scannen'
  return labels[props.status] || 'Verarbeitung läuft…'
})
const progress = computed(() => {
  if (isError.value) return 100
  const i = steps.indexOf(props.status)
  return i < 0 ? 5 : Math.round(((i + 1) / steps.length) * 100)
})
</script>

<style scoped>
.scan-progress { padding: 20px; }
.progress-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 14px;
  font-weight: 500;
}
.spinner {
  width: 22px;
  height: 22px;
  border: 2.5px solid var(--primary-dim);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  flex-shrink: 0;
}
@keyframes spin { to { transform: rotate(360deg); } }
.bar-track {
  height: 6px;
  background: var(--bg-input);
  border-radius: 3px;
  overflow: hidden;
}
.bar-fill {
  height: 100%;
  background: var(--primary);
  border-radius: 3px;
  transition: width 0.4s ease;
}
.bar-fill.error { background: var(--error); }
</style>
