<template>
  <div class="player">
    <!-- Fortschrittsbalken -->
    <div class="progress-row">
      <span class="time">{{ fmtTime(currentTime) }}</span>
      <div class="track" @click="seek" ref="trackRef">
        <div class="track-fill" :style="{ width: (progress * 100) + '%' }"></div>
        <div class="thumb-dot" :style="{ left: (progress * 100) + '%' }"></div>
      </div>
      <span class="time">{{ fmtTime(duration) }}</span>
    </div>

    <!-- Steuerung -->
    <div class="controls">
      <!-- Tempo -->
      <div class="tempo-wrap">
        <span class="tempo-label">♩ {{ Math.round(tempo * 100) }}%</span>
        <input type="range" min="0.4" max="1.5" step="0.05" :value="tempo"
          @input="onTempoChange" class="tempo-slider" />
      </div>

      <!-- Zurück -->
      <button class="ctrl-btn" @click="restart" title="Zum Anfang">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">
          <path d="M6 6h2v12H6zm3.5 6 8.5 6V6z"/>
        </svg>
      </button>

      <!-- Play / Pause -->
      <button class="play-btn" @click="togglePlay">
        <svg v-if="!isPlaying" width="28" height="28" viewBox="0 0 24 24" fill="currentColor">
          <path d="M8 5v14l11-7z"/>
        </svg>
        <svg v-else width="28" height="28" viewBox="0 0 24 24" fill="currentColor">
          <path d="M6 19h4V5H6zm8-14v14h4V5z"/>
        </svg>
      </button>

      <!-- Karaoke-Toggle -->
      <button class="ctrl-btn karaoke-btn" :class="{ active: isKaraoke }" @click="$emit('toggle-karaoke')" title="Karaoke-Modus">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"/>
          <path d="M12 8c-1.7 0-3 1.3-3 3v2c0 1.7 1.3 3 3 3s3-1.3 3-3v-2c0-1.7-1.3-3-3-3z"/>
          <path d="M8 17v1a4 4 0 0 0 8 0v-1"/>
        </svg>
      </button>
    </div>

    <!-- Karaoke-Badge -->
    <div v-if="isKaraoke" class="karaoke-badge">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="var(--accent)"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 21 12 17.77 5.82 21 7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
      Karaoke aktiv
    </div>

    <!-- Verstecktes Audio-Element -->
    <audio ref="audioRef" :src="audioSrc" :playbackRate="tempo"
      @timeupdate="onTimeUpdate" @durationchange="onDuration"
      @ended="onEnded" @play="onPlay" @pause="onPause" preload="auto" />
  </div>
</template>

<script setup>
import { ref, computed, watch, onUnmounted } from 'vue'

const props = defineProps({
  songId: Number,
  hasAudio: Boolean,
  isKaraoke: Boolean,
})
const emit = defineEmits(['toggle-karaoke', 'time-update', 'play', 'pause', 'ended'])

const audioRef = ref(null)
const trackRef = ref(null)
const isPlaying = ref(false)
const currentTime = ref(0)
const duration = ref(0)
const tempo = ref(1.0)

const progress = computed(() => duration.value ? currentTime.value / duration.value : 0)
const audioSrc = computed(() => props.hasAudio ? `/playback/${props.songId}/audio` : null)

function togglePlay() {
  if (!audioRef.value) return
  if (isPlaying.value) { audioRef.value.pause() } else { audioRef.value.play() }
}
function restart() {
  if (!audioRef.value) return
  audioRef.value.currentTime = 0
  if (!isPlaying.value) audioRef.value.play()
}
function seek(e) {
  if (!trackRef.value || !audioRef.value || !duration.value) return
  const rect = trackRef.value.getBoundingClientRect()
  const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width))
  audioRef.value.currentTime = ratio * duration.value
}
function onTempoChange(e) {
  tempo.value = parseFloat(e.target.value)
  if (audioRef.value) audioRef.value.playbackRate = tempo.value
}
function onTimeUpdate() {
  currentTime.value = audioRef.value?.currentTime || 0
  emit('time-update', currentTime.value)
}
function onDuration() { duration.value = audioRef.value?.duration || 0 }
function onEnded() { isPlaying.value = false; emit('ended') }
function onPlay() { isPlaying.value = true; emit('play') }
function onPause() { isPlaying.value = false; emit('pause') }

function fmtTime(s) {
  if (!s || isNaN(s)) return '0:00'
  const m = Math.floor(s / 60)
  const sec = Math.floor(s % 60).toString().padStart(2, '0')
  return `${m}:${sec}`
}

// Öffentliche API für karaoke sync
function getAudioTime() { return audioRef.value?.currentTime || 0 }
function getAudioEl() { return audioRef.value }

defineExpose({ getAudioTime, getAudioEl, togglePlay, restart })
</script>

<style scoped>
.player {
  background: var(--bg-card);
  border-top: 1px solid var(--border);
  padding: 14px 20px;
  padding-bottom: calc(14px + env(safe-area-inset-bottom));
}
.progress-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
}
.time { font-size: 0.78rem; color: var(--text-secondary); width: 36px; text-align: center; }
.track {
  flex: 1;
  height: 4px;
  background: var(--bg-input);
  border-radius: 2px;
  cursor: pointer;
  position: relative;
}
.track-fill {
  height: 100%;
  background: var(--primary);
  border-radius: 2px;
  transition: width 0.1s linear;
}
.thumb-dot {
  position: absolute;
  top: 50%;
  transform: translate(-50%, -50%);
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--primary);
  box-shadow: 0 0 0 3px rgba(124, 111, 247, 0.3);
}
.controls {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
}
.tempo-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  margin-right: auto;
}
.tempo-label { font-size: 0.7rem; color: var(--text-secondary); }
.tempo-slider {
  width: 80px;
  height: 4px;
  -webkit-appearance: none;
  appearance: none;
  background: var(--bg-input);
  border-radius: 2px;
  cursor: pointer;
}
.tempo-slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 14px;
  height: 14px;
  border-radius: 50%;
  background: var(--primary);
}
.ctrl-btn {
  width: 42px;
  height: 42px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  transition: background var(--transition), color var(--transition);
}
.ctrl-btn:hover { background: var(--primary-dim); color: var(--primary); }
.karaoke-btn.active { color: var(--accent); background: var(--accent-dim); }
.play-btn {
  width: 54px;
  height: 54px;
  border-radius: 50%;
  background: var(--primary);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform var(--transition), background var(--transition);
}
.play-btn:hover { background: var(--primary-hover); transform: scale(1.06); }
.karaoke-badge {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  margin-top: 10px;
  font-size: 0.78rem;
  color: var(--accent);
  font-weight: 600;
  animation: fade-in 0.3s ease;
}
@keyframes fade-in { from { opacity: 0 } to { opacity: 1 } }
</style>
