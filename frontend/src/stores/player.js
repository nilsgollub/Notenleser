import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const usePlayerStore = defineStore('player', () => {
  const song = ref(null)
  const isPlaying = ref(false)
  const currentTime = ref(0)
  const duration = ref(0)
  const tempo = ref(1.0)      // Playback-Rate (0.5 – 2.0)
  const isKaraoke = ref(false)
  const isMidiMode = ref(false) // Tone.js statt HTML5-Audio

  const progress = computed(() => duration.value ? currentTime.value / duration.value : 0)

  function setSong(s) { song.value = s }
  function setPlaying(v) { isPlaying.value = v }
  function setTime(t) { currentTime.value = t }
  function setDuration(d) { duration.value = d }
  function setTempo(t) { tempo.value = t }
  function toggleKaraoke() { isKaraoke.value = !isKaraoke.value }
  function setMidiMode(v) { isMidiMode.value = v }

  return {
    song, isPlaying, currentTime, duration, tempo,
    isKaraoke, isMidiMode, progress,
    setSong, setPlaying, setTime, setDuration, setTempo, toggleKaraoke, setMidiMode,
  }
})
