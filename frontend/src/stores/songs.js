import { defineStore } from 'pinia'
import { ref } from 'vue'
import axios from 'axios'

export const useSongsStore = defineStore('songs', () => {
  const songs = ref([])
  const loading = ref(false)
  const error = ref(null)

  async function fetchSongs(q = '') {
    loading.value = true
    error.value = null
    try {
      const { data } = await axios.get('/songs/', { params: q ? { q } : {} })
      songs.value = data
    } catch (e) {
      error.value = e.message
    } finally {
      loading.value = false
    }
  }

  async function fetchSong(id) {
    const { data } = await axios.get(`/songs/${id}`)
    return data
  }

  async function deleteSong(id) {
    await axios.delete(`/songs/${id}`)
    songs.value = songs.value.filter(s => s.id !== id)
  }

  async function uploadScan(file, title) {
    const form = new FormData()
    form.append('file', file)
    form.append('title', title || '')
    const { data } = await axios.post('/scan/upload', form)
    return data // { job_id, song_id }
  }

  async function getTiming(songId) {
    try {
      const { data } = await axios.get(`/playback/${songId}/timing`)
      return data
    } catch {
      return null
    }
  }

  return { songs, loading, error, fetchSongs, fetchSong, deleteSong, uploadScan, getTiming }
})
