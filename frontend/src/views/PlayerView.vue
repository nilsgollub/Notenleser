<template>
  <div class="player-view">
    <!-- Song-Header -->
    <div class="song-header" v-if="song">
      <button class="back-btn" @click="$router.back()">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round">
          <path d="M19 12H5M12 5l-7 7 7 7"/>
        </svg>
      </button>
      <div class="meta">
        <h1 class="song-title">{{ song.title }}</h1>
        <p class="song-sub" v-if="song.composer || song.key_signature">
          <span v-if="song.composer">{{ song.composer }}</span>
          <span v-if="song.key_signature" class="badge">{{ song.key_signature }}</span>
          <span v-if="song.time_signature" class="badge">{{ song.time_signature }}</span>
          <span v-if="song.tempo_bpm" class="badge">♩={{ song.tempo_bpm }}</span>
        </p>
      </div>
      <div class="header-actions">
        <a :href="`/playback/${props.id}/midi`" download class="icon-btn" title="MIDI herunterladen">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/>
          </svg>
        </a>
      </div>
    </div>

    <!-- Karaoke-Banner -->
    <transition name="slide-down">
      <div v-if="playerStore.isKaraoke" class="karaoke-banner">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="var(--accent)">
          <path d="M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 21 12 17.77 5.82 21 7 14.14 2 9.27l6.91-1.01L12 2z"/>
        </svg>
        <span>Karaoke-Modus – der Cursor folgt der Melodie</span>
        <span v-if="!hasTiming" class="karaoke-warn">⚠ Timing-Daten werden noch geladen…</span>
      </div>
    </transition>

    <!-- Notenblatt -->
    <div class="sheet-scroll">
      <SheetViewer
        v-if="song && song.musicxml_path"
        ref="sheetRef"
        :musicxml-url="`/playback/${props.id}/musicxml`"
        :cursor-visible="playerStore.isKaraoke"
        @ready="onSheetReady"
      />
      <div v-else-if="song && !song.musicxml_path" class="no-sheet">
        <p>MusicXML noch nicht verfügbar – bitte warten oder erneut scannen.</p>
      </div>
      <div v-else-if="!song" class="no-sheet">
        <div class="spinner"></div>
      </div>
    </div>

    <!-- Player-Leiste (nur wenn Audio vorhanden) -->
    <div v-if="song" class="player-sticky">
      <!-- MIDI-Fallback Banner -->
      <div v-if="!song.audio_path && song.midi_path" class="midi-fallback">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--text-secondary)" stroke-width="2">
          <circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>
        </svg>
        Kein WAV verfügbar – Wiedergabe via Browser-Synth
        <button class="btn btn-ghost midi-play-btn" @click="toggleMidiPlay" style="padding:6px 14px;font-size:0.82rem;">
          {{ midiPlaying ? 'Stopp' : 'Abspielen' }}
        </button>
      </div>

      <AudioPlayer
        v-if="song.audio_path"
        ref="playerRef"
        :song-id="Number(props.id)"
        :has-audio="!!song.audio_path"
        :is-karaoke="playerStore.isKaraoke"
        @toggle-karaoke="playerStore.toggleKaraoke()"
        @time-update="onTimeUpdate"
        @play="onPlay"
        @pause="onPause"
        @ended="onEnded"
      />

      <!-- Karaoke-Toggle wenn kein WAV (Midi-Mode) -->
      <div v-if="!song.audio_path" class="karaoke-toggle-row">
        <button class="btn" :class="playerStore.isKaraoke ? 'btn-accent' : 'btn-ghost'"
          @click="playerStore.toggleKaraoke()">
          ★ Karaoke
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import { useSongsStore } from '../stores/songs.js'
import { usePlayerStore } from '../stores/player.js'
import SheetViewer from '../components/SheetViewer.vue'
import AudioPlayer from '../components/AudioPlayer.vue'

const props = defineProps({ id: String })

const songStore = useSongsStore()
const playerStore = usePlayerStore()

const song = ref(null)
const sheetRef = ref(null)
const playerRef = ref(null)
const timingData = ref(null)
const hasTiming = ref(false)
const midiPlaying = ref(false)

// Karaoke state
let cursorStep = 0
let rafId = null
let toneTransport = null
let toneSynth = null

onMounted(async () => {
  song.value = await songStore.fetchSong(props.id)
  playerStore.setSong(song.value)

  // Timing laden
  const t = await songStore.getTiming(props.id)
  if (t) {
    timingData.value = t
    hasTiming.value = true
  }
})

onUnmounted(() => {
  stopKaraoke()
  stopMidi()
})

function onSheetReady() {
  if (playerStore.isKaraoke) startKaraoke()
}

watch(() => playerStore.isKaraoke, (val) => {
  if (val) startKaraoke()
  else stopKaraoke()
})

// ─── Karaoke-Sync via requestAnimationFrame ───────────────────────────────

function startKaraoke() {
  if (!sheetRef.value || !timingData.value) return
  sheetRef.value.resetCursor()
  cursorStep = 0
  rafId = requestAnimationFrame(karaokeLoop)
}

function stopKaraoke() {
  if (rafId) { cancelAnimationFrame(rafId); rafId = null }
  sheetRef.value?.resetCursor()
}

function karaokeLoop() {
  const events = timingData.value?.events
  if (!events) return

  // Aktuelle Abspielzeit ermitteln (WAV oder Tone.js)
  let t = 0
  if (playerRef.value) {
    t = playerRef.value.getAudioTime()
  } else if (toneTransport) {
    t = toneTransport.seconds
  }

  // Cursor entsprechend der Zeit vorspulen
  while (cursorStep < events.length && t >= events[cursorStep].time) {
    if (cursorStep > 0) sheetRef.value?.nextCursor()
    cursorStep++
  }

  rafId = requestAnimationFrame(karaokeLoop)
}

// ─── Seek-Resync ──────────────────────────────────────────────────────────
function onTimeUpdate(t) {
  // Wenn Karaoke aktiv und gesprungen: Cursor resynchronisieren
  if (!playerStore.isKaraoke || !timingData.value) return
  const events = timingData.value.events
  const expectedStep = events.filter(e => e.time <= t).length

  // Mehr als 2 Schritte Abweichung → Cursor reset + resync
  if (Math.abs(expectedStep - cursorStep) > 2) {
    stopKaraoke()
    startKaraokeAt(t)
  }
}

function startKaraokeAt(t) {
  if (!sheetRef.value || !timingData.value) return
  const events = timingData.value.events
  sheetRef.value.resetCursor()
  cursorStep = 0
  while (cursorStep < events.length && events[cursorStep].time < t) {
    if (cursorStep > 0) sheetRef.value.nextCursor()
    cursorStep++
  }
  rafId = requestAnimationFrame(karaokeLoop)
}

function onPlay() { playerStore.setPlaying(true) }
function onPause() { playerStore.setPlaying(false) }
function onEnded() { playerStore.setPlaying(false); stopKaraoke() }

// ─── Tone.js MIDI-Fallback-Wiedergabe ─────────────────────────────────────
async function toggleMidiPlay() {
  if (midiPlaying.value) { stopMidi(); return }
  await startMidi()
}

async function startMidi() {
  const { default: Tone } = await import('tone')
  await Tone.start()
  stopMidi()

  toneSynth = new Tone.PolySynth(Tone.Synth, {
    oscillator: { type: 'triangle' },
    envelope: { attack: 0.02, decay: 0.1, sustain: 0.5, release: 0.8 },
  }).toDestination()
  toneSynth.volume.value = -6

  toneTransport = Tone.Transport
  toneTransport.cancel()
  toneTransport.stop()
  toneTransport.position = 0

  if (timingData.value) {
    timingData.value.events.forEach(ev => {
      toneTransport.schedule(time => {
        toneSynth.triggerAttackRelease(ev.pitches, ev.duration, time)
      }, ev.time)
    })
    toneTransport.schedule(() => {
      midiPlaying.value = false
      stopKaraoke()
    }, timingData.value.total_duration + 0.5)
  }

  toneTransport.start()
  midiPlaying.value = true
  if (playerStore.isKaraoke) startKaraoke()
}

function stopMidi() {
  if (toneTransport) { toneTransport.stop(); toneTransport.cancel() }
  if (toneSynth) { toneSynth.dispose(); toneSynth = null }
  midiPlaying.value = false
}
</script>

<style scoped>
.player-view {
  display: flex;
  flex-direction: column;
  height: 100%;
}
.song-header {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  border-bottom: 1px solid var(--border);
}
.back-btn {
  color: var(--text-secondary);
  padding: 4px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
  margin-top: 2px;
}
.back-btn:hover { color: var(--text); background: var(--border); }
.meta { flex: 1; min-width: 0; }
.song-title { font-size: 1.2rem; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.song-sub { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin-top: 4px; font-size: 0.82rem; color: var(--text-secondary); }
.header-actions { display: flex; gap: 8px; }
.icon-btn {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  border: 1px solid var(--border);
}
.icon-btn:hover { color: var(--text); border-color: var(--text-secondary); }
.karaoke-banner {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: var(--accent-dim);
  border-bottom: 1px solid rgba(255, 215, 0, 0.2);
  font-size: 0.82rem;
  color: var(--accent);
  font-weight: 500;
}
.karaoke-warn { color: var(--text-secondary); margin-left: auto; }
.sheet-scroll { flex: 1; overflow-y: auto; padding: 16px; }
.no-sheet {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 48px;
  color: var(--text-secondary);
  text-align: center;
}
.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--primary-dim);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}
@keyframes spin { to { transform: rotate(360deg); } }
.player-sticky { flex-shrink: 0; }
.midi-fallback {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 16px;
  background: var(--bg-card);
  border-top: 1px solid var(--border);
  font-size: 0.82rem;
  color: var(--text-secondary);
}
.midi-play-btn { margin-left: auto; }
.karaoke-toggle-row {
  display: flex;
  justify-content: center;
  padding: 12px 16px;
  background: var(--bg-card);
  border-top: 1px solid var(--border);
}
.slide-down-enter-active, .slide-down-leave-active { transition: max-height 0.3s, opacity 0.3s; max-height: 60px; }
.slide-down-enter-from, .slide-down-leave-to { max-height: 0; opacity: 0; }
</style>
