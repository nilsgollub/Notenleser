<template>
  <div class="library-view">
    <div class="search-bar">
      <svg class="search-icon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/>
      </svg>
      <input v-model="query" type="search" placeholder="Lied suchen…" @input="onSearch" />
    </div>

    <div v-if="store.loading" class="state-msg">
      <div class="spinner"></div>
    </div>

    <div v-else-if="store.songs.length === 0" class="state-msg">
      <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="var(--text-secondary)" stroke-width="1.2">
        <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
      </svg>
      <p>Noch keine Lieder</p>
      <router-link to="/scan" class="btn btn-primary">Erstes Lied scannen</router-link>
    </div>

    <div v-else class="song-list">
      <SongCard
        v-for="song in store.songs"
        :key="song.id"
        :song="song"
        @delete="confirmDelete(song.id)"
      />
    </div>

    <!-- Bestätigungs-Dialog -->
    <transition name="fade">
      <div v-if="deleteTarget" class="dialog-backdrop" @click.self="deleteTarget = null">
        <div class="dialog card">
          <p>Lied wirklich löschen?</p>
          <div class="dialog-btns">
            <button class="btn btn-ghost" @click="deleteTarget = null">Abbrechen</button>
            <button class="btn" style="background:var(--error);color:#fff" @click="doDelete">Löschen</button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useSongsStore } from '../stores/songs.js'
import SongCard from '../components/SongCard.vue'

const store = useSongsStore()
const query = ref('')
const deleteTarget = ref(null)

onMounted(() => store.fetchSongs())

function onSearch() { store.fetchSongs(query.value) }
function confirmDelete(id) { deleteTarget.value = id }
async function doDelete() {
  await store.deleteSong(deleteTarget.value)
  deleteTarget.value = null
}
</script>

<style scoped>
.library-view { padding: 16px; }
.search-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--bg-card);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 10px 14px;
  margin-bottom: 16px;
}
.search-icon { color: var(--text-secondary); flex-shrink: 0; }
.search-bar input {
  flex: 1;
  background: none;
  border: none;
  padding: 0;
  font-size: 0.95rem;
}
.state-msg {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 16px;
  padding: 64px 24px;
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
.song-list { display: flex; flex-direction: column; gap: 10px; }
.dialog-backdrop {
  position: fixed;
  inset: 0;
  background: rgba(0,0,0,0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
}
.dialog { padding: 24px; text-align: center; max-width: 320px; width: 90%; }
.dialog p { margin-bottom: 20px; font-size: 1rem; }
.dialog-btns { display: flex; gap: 12px; justify-content: center; }
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
